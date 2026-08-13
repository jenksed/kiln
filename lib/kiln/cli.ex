defmodule Kiln.CLI do
  @moduledoc """
  The foundation CLI dispatcher.

  The CLI exposes a tiny P1-S01 surface (`start`, `status`, `inspect`,
  `cancel`, `resume`) over the accepted `Kiln.Workflow` boundary. Every
  command routes through `Kiln.Workflow` for application work and
  `Kiln.CLI.Runtime` for store lifecycle only. The CLI never reaches
  into the internal domain modules, the journal commit path, the restart
  classifier, or the projection rebuild path directly.

  Run a single command through `run/1`. The return value is a
  `{Result.t(), exit_code}` tuple so the caller (the `mix kiln` Mix
  task) can set the process exit code. Help and version are produced by
  the renderer so they share the same envelope as everything else.

  The dispatcher is non-authoritative: it never mutates the journal, the
  Store, or the projection directly. It never reads the Repository, the
  provider, the transcript, or external Commands, and never applies a
  Patch or accepts completion.
  """

  alias Kiln.CLI.{ErrorMap, Request, Result, Runtime}
  alias Kiln.Domain.Error
  alias Kiln.OperationLifecycle
  alias Kiln.Workflow

  @supported_commands Request.commands()
  @version Kiln.version()

  @nonterminal_operation_states OperationLifecycle.nonterminal_states()
                                |> Enum.map(&Atom.to_string/1)

  @doc "Run a parsed request and return `{result, exit_code}`."
  @spec run(Request.t()) :: {Result.t(), non_neg_integer()}
  def run(%Request{show_version: true}),
    do: {version_result(), 0}

  def run(%Request{show_help: true}),
    do: {help_result(), 0}

  def run(%Request{command: command}) when command not in @supported_commands do
    result =
      Result.error(atom_to_command(command), :unsupported,
        errors: [
          Result.to_error(%{
            code: :unsupported_command,
            message: "the command is not available in the foundation CLI"
          })
        ]
      )

    {result, result.exit_code}
  end

  def run(%Request{} = request), do: dispatch(request)

  # -- dispatch --

  defp dispatch(%Request{} = request) do
    case request.command do
      :start -> run_writable(request, &dispatch_start/2)
      :status -> run_readonly(request, &dispatch_status/2)
      :inspect -> run_readonly(request, &dispatch_inspect/2)
      :cancel -> run_writable(request, &dispatch_cancel/2)
      :resume -> run_readonly(request, &dispatch_resume/2)
      :supervise -> run_supervise(request)
    end
  end

  defp run_writable(%Request{} = request, fun) do
    run_with_mode(request, :write, fun)
  end

  defp run_readonly(%Request{} = request, fun) do
    run_with_mode(request, :read, fun)
  end

  defp run_with_mode(%Request{} = request, mode, fun) do
    case Runtime.open(request.kiln_home, mode) do
      {:ok, :ready} ->
        try do
          request
          |> then(&fun.(&1, nil))
          |> normalize_dispatch_result(request)
        after
          Runtime.stop()
        end

      {:absent} ->
        absent_result(request)

      {:blocked, state, _error} ->
        blocked_result(request, state)
    end
  end

  # The supervise command opens the store in write mode because the
  # supervisor persists Artifacts, Evidence, and a supervision_runs row.
  # The dispatcher never reaches into Evidence or Artifact internals;
  # it routes through `Kiln.Supervision` only.
  defp run_supervise(%Request{} = request) do
    case Runtime.open(request.kiln_home, :write) do
      {:ok, :ready} ->
        try do
          request
          |> dispatch_supervise()
          |> normalize_dispatch_result(request)
        after
          Runtime.stop()
        end

      {:absent} ->
        absent_result(request)

      {:blocked, state, _error} ->
        blocked_result(request, state)
    end
  end

  defp normalize_dispatch_result({:ok, %Result{} = result}, _request),
    do: {result, result.exit_code}

  defp normalize_dispatch_result({:error, %Result{} = result}, _request),
    do: {result, result.exit_code}

  defp normalize_dispatch_result({:error, %Error{} = error}, request),
    do: error_result_tuple(request, error)

  defp normalize_dispatch_result({:ok, %Result{} = result, _session}, _request),
    do: {result, result.exit_code}

  defp normalize_dispatch_result({%Result{} = result, exit_code}, _request)
       when is_integer(exit_code),
       do: {result, exit_code}

  defp absent_result(%Request{command: command}) do
    {result, exit_code} =
      result_for_code(
        command,
        :no_session,
        "no state DB exists at --kiln-home; start one with `mix kiln start`"
      )

    {result, exit_code}
  end

  defp blocked_result(%Request{command: command}, state) do
    message =
      case state do
        :migration_blocked ->
          "migration is blocked; preserve files and follow the diagnostic action"

        :integrity_blocked ->
          "the store is corrupt; preserve files and run a manual recovery"

        :version_blocked ->
          "the binary cannot open this store; use a compatible Kiln"

        :unavailable ->
          "the store could not be opened"

        _ ->
          "the store could not be opened"
      end

    {status, exit_code} = ErrorMap.map(state)
    errors = [Result.to_error(%{code: state, message: message, class: "store_blocked"})]

    result =
      Result.error(atom_to_command(command), status,
        exit_code: exit_code,
        errors: errors
      )

    {result, exit_code}
  end

  # -- command: start --
  #
  # The CLI never constructs a Domain Session/Task/Run directly. It builds
  # the input shapes that `Kiln.Workflow.start_session/1` accepts and lets
  # the Workflow own journal writes, idempotency, request digests, and
  # state validation.

  defp dispatch_start(%Request{options: opts, actor_id: actor_id} = _request, _session) do
    with :ok <- precheck_no_session(),
         {:ok, workflow_input} <- build_start_workflow_input(opts, actor_id) do
      case workflow_input do
        %Result{} = result ->
          {:ok, result}

        workflow_opts when is_map(workflow_opts) ->
          case Workflow.start_session(workflow_opts) do
            {:ok, started} ->
              case capability_next_actions(started.session_id) do
                {:ok, mutating_actions} ->
                  {:ok,
                   Result.ok("start",
                     data: %{
                       session_id: started.session_id,
                       task_id: started.task_id,
                       root_run_id: started.run_id,
                       objective: workflow_opts[:objective] || workflow_opts["objective"]
                     },
                     session_revision: started.session_revision,
                     journal_digest: format_digest(started.projection_digest),
                     next_actions: navigation_actions("start") ++ mutating_actions
                   )}

                {:error, %Error{} = error} ->
                  {:error, error}
              end

            {:error, %Error{} = error} ->
              {:error, error}
          end
      end
    else
      {:error, %Result{} = result} -> {:error, result}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  # Sequential one-Session guard. Returns `:ok` when no Session exists so
  # the caller can proceed, or `{:error, %Result{}}` carrying the blocked
  # CLI result when a Session already exists. The control-flow convention
  # `:ok | {:error, %Result{}}` is chosen so a `with` clause using the
  # `:ok` head short-circuits on the existing-Session case before any
  # durable input shaping, validation, or Workflow call runs; this is
  # what stops a second `mix kiln start` from creating a second Session.
  # A Workflow error during the lookup is returned as `{:error, %Error{}}`
  # so the upstream dispatcher surfaces it through the standard mapping.
  defp precheck_no_session do
    case Workflow.current_session() do
      {:ok, :empty} ->
        :ok

      {:ok, %{session_id: session_id}} ->
        {:error,
         Result.error("start", :blocked,
           errors: [
             Result.to_error(%{
               code: :session_already_exists,
               message:
                 "a Session already exists (#{session_id}); inspect or cancel it instead of starting another"
             })
           ]
         )}

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp build_start_workflow_input(opts, actor_id) do
    case validate_command_options(opts) do
      :ok ->
        repo = opts["repo"]
        observation = build_project_observation(repo)

        {:ok,
         %{
           actor_id: actor_id,
           objective: opts["objective"],
           criteria: opts["criterion"],
           constraints: opts["constraint"] || [],
           exclusions: opts["exclude"] || [],
           project_observation: observation
         }}

      {:error, message} when is_binary(message) ->
        {:ok,
         Result.error("start", :denied,
           exit_code: 2,
           errors: [Result.to_error(message)]
         )}
    end
  end

  defp validate_command_options(opts) do
    cond do
      not non_empty?(opts["repo"]) ->
        {:error, "--repo is required"}

      not non_empty?(opts["objective"]) ->
        {:error, "--objective is required"}

      not non_empty_list?(opts["criterion"]) ->
        {:error, "at least one --criterion is required"}

      not optional_list?(opts["constraint"]) ->
        {:error, "every --constraint must be a non-empty string"}

      not optional_list?(opts["exclude"]) ->
        {:error, "every --exclude must be a non-empty string"}

      true ->
        :ok
    end
  end

  defp build_project_observation(repo_root) do
    fingerprint =
      "sha256:" <>
        (:crypto.hash(:sha256, repo_root) |> Base.encode16(case: :lower))

    %{
      repository_root: repo_root,
      repository_fingerprint: fingerprint,
      observed_at: DateTime.utc_now()
    }
  end

  # -- command: status --
  #
  # Status reads the current projection through `Workflow.current_session/0`
  # and never reaches into the projection, restart, or replay modules
  # directly.

  defp dispatch_status(%Request{} = _request, _session) do
    case Workflow.current_session() do
      {:ok, :empty} ->
        {:ok, no_session_result("status")}

      {:ok, %{projection: projection, session_id: session_id} = result} ->
        case capability_next_actions(session_id) do
          {:ok, mutating_actions} ->
            {:ok, status_result("status", projection, result, mutating: mutating_actions)}

          {:error, %Error{} = error} ->
            {:error, error}
        end

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp status_result(command, projection, result, opts) do
    base_opts = [
      data: status_data(projection, result),
      session_revision: revision_from_projection(projection),
      journal_digest: format_digest(result.projection_digest),
      next_actions: status_next_actions(projection, result, Keyword.fetch!(opts, :mutating))
    ]

    if result.orphaned do
      Result.error(command, :unknown,
        exit_code: 7,
        errors: [
          Result.to_error(%{
            code: :orphaned_run,
            message: "the Run has an unresolved external effect and requires reconciliation"
          })
        ],
        data: base_opts[:data],
        session_revision: base_opts[:session_revision],
        journal_digest: base_opts[:journal_digest],
        next_actions: base_opts[:next_actions]
      )
    else
      Result.ok(command, base_opts)
    end
  end

  defp status_data(projection, result) do
    %{
      session_id: get_in(projection, ["session", "id"]),
      session_state: get_in(projection, ["session", "state"]),
      task_id: get_in(projection, ["task", "id"]),
      task_state: get_in(projection, ["task", "state"]),
      root_run_id: get_in(projection, ["run", "id"]),
      run_state: effective_run_state(projection, result),
      workflow_step: projection["workflow_step"],
      pending_decision: summarize_pending_decision(projection["pending_decision"]),
      operation: summarize_operation(effective_operation(projection, result)),
      cache_status: to_string(result.source),
      orphaned: result.orphaned,
      journal_head: format_digest(result.journal_head_digest)
    }
  end

  # Status emits `inspect` as the navigation suggestion; the Workflow-owned
  # mutating capability set is appended unchanged. The orphan / pending-
  # decision / active-operation branches emit only navigation suggestions
  # because the Workflow capability matrix returns `[]` for those states.
  defp status_next_actions(projection, result, mutating_actions) do
    base =
      cond do
        result.orphaned ->
          [
            Result.next_action(
              "inspect",
              "review the unknown operation and orphan markers"
            )
          ]

        get_in(projection, ["pending_decision"]) != nil ->
          [
            Result.next_action("inspect", "review the pending decision")
          ]

        get_in(projection, ["operation"]) != nil ->
          [
            Result.next_action("inspect", "review the active external operation")
          ]

        true ->
          [Result.next_action("inspect", "review the current state")]
      end

    base ++ mutating_actions
  end

  # -- command: inspect --
  #
  # Inspect renders the full accepted P1-S01 state from the Workflow
  # query result. The renderer-facing fields are sourced from the
  # projection map; the Workflow query exposes them only through the
  # authoritative load_projection path.

  defp dispatch_inspect(%Request{} = _request, _session) do
    case Workflow.current_session() do
      {:ok, :empty} ->
        {:ok, no_session_result("inspect")}

      {:ok, %{projection: projection, session_id: session_id} = result} ->
        case capability_next_actions(session_id) do
          {:ok, mutating_actions} ->
            {:ok, inspect_result("inspect", projection, result, mutating: mutating_actions)}

          {:error, %Error{} = error} ->
            {:error, error}
        end

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp inspect_result(command, projection, result, opts) do
    data = inspect_data(projection, result)
    mutating_actions = Keyword.fetch!(opts, :mutating)

    base_opts = [
      data: data,
      session_revision: revision_from_projection(projection),
      journal_digest: format_digest(result.projection_digest),
      next_actions: navigation_actions("inspect") ++ mutating_actions
    ]

    if result.orphaned do
      Result.error(command, :unknown,
        exit_code: 7,
        errors: [
          Result.to_error(%{
            code: :orphaned_run,
            message: "the Run has an unresolved external effect and requires reconciliation"
          })
        ],
        data: data,
        session_revision: base_opts[:session_revision],
        journal_digest: base_opts[:journal_digest],
        next_actions: base_opts[:next_actions]
      )
    else
      Result.ok(command, base_opts)
    end
  end

  defp inspect_data(projection, result) do
    unknowns = effective_unknowns(projection, result)

    %{
      session_id: get_in(projection, ["session", "id"]),
      session_state: get_in(projection, ["session", "state"]),
      task_id: get_in(projection, ["task", "id"]),
      task_state: get_in(projection, ["task", "state"]),
      root_run_id: get_in(projection, ["run", "id"]),
      run_state: effective_run_state(projection, result),
      workflow_step: projection["workflow_step"],
      objective_revision: projection["objective_revision"] || 0,
      criteria_revision: projection["criteria_revision"] || 0,
      objective: projection["objective"] || "",
      criteria: projection["criteria"] || [],
      constraints: projection["constraints"] || [],
      exclusions: projection["exclusions"] || [],
      pending_decision: summarize_pending_decision(projection["pending_decision"]),
      operation: summarize_operation(effective_operation(projection, result)),
      unknowns: unknowns,
      project_observation_id: get_in(projection, ["references", "project_observation_id"]),
      journal_head_digest: format_digest(result.journal_head_digest),
      projection_digest: result.projection_digest
    }
  end

  defp effective_unknowns(projection, %{orphaned: true}) do
    case projection["operation"] do
      %{"id" => id, "state" => state} when is_binary(id) and is_binary(state) ->
        if state in @nonterminal_operation_states do
          [%{"operation_id" => id, "reason" => "nonterminal_state"}]
        else
          projection["unknowns"] || []
        end

      _ ->
        projection["unknowns"] || []
    end
  end

  defp effective_unknowns(projection, _result), do: projection["unknowns"] || []

  # -- command: cancel --
  #
  # Cancel reads the current session through `current_session/0`, picks
  # up the session_id and run_state, and dispatches the mutation through
  # `Workflow.cancel_session/2`. The CLI never builds a journal action
  # envelope directly.

  defp dispatch_cancel(%Request{options: opts, actor_id: actor_id} = request, _session) do
    case Workflow.current_session() do
      {:ok, :empty} ->
        {:ok, no_session_result("cancel")}

      {:ok, %{projection: projection} = _current} ->
        session_id = get_in(projection, ["session", "id"])
        task_id = get_in(projection, ["task", "id"])
        run_id = get_in(projection, ["run", "id"])
        previous_run_state = get_in(projection, ["run", "state"])
        expected_revision = revision_from_projection(projection)

        with :ok <- terminal_check(previous_run_state, "cancel"),
             :ok <- active_operation_check(projection) do
          cancel_session_via_workflow(
            request,
            session_id,
            task_id,
            run_id,
            previous_run_state,
            expected_revision,
            actor_id,
            opts
          )
        end

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp cancel_session_via_workflow(
         request,
         session_id,
         task_id,
         run_id,
         previous_run_state,
         expected_revision,
         actor_id,
         opts
       ) do
    case Workflow.cancel_session(session_id,
           actor_id: actor_id,
           expected_session_revision: expected_revision
         ) do
      {:ok, canceled} ->
        # Cancel transitions the Run to `:canceled`, a terminal Run state.
        # `Workflow.valid_next_actions/1` therefore advertises `[]` for the
        # post-cancel Session; the cancel result contains only navigation
        # suggestions (`status`, `inspect`) and never advertises `cancel`
        # or `resume` even when the Workflow capability matrix would later
        # be misconfigured, because the cancel result is constructed
        # without consulting that matrix at all.
        {:ok,
         Result.ok("cancel",
           data: %{
             session_id: session_id,
             task_id: task_id,
             root_run_id: run_id,
             previous_run_state: previous_run_state,
             run_state: "canceled"
           },
           session_revision: canceled.session_revision,
           journal_digest: format_digest(canceled.projection_digest),
           next_actions: navigation_actions("cancel")
         )}

      {:error, %Error{code: :run_transition_not_allowed} = error} ->
        # The Workflow returns :run_transition_not_allowed from terminal
        # states and from active operation. The CLI surfaces the terminal
        # case as :failed exit 6 with the legacy "already <state>" message
        # so the existing test contract holds.
        case Map.get(request.options, "reason") do
          _ ->
            {:error,
             error_for_terminal_cancel(
               previous_run_state,
               error,
               opts
             )}
        end

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp error_for_terminal_cancel(previous_run_state, _workflow_error, _opts) do
    cli_native_error_result("cancel", :terminal_run_state, %{
      from: previous_run_state
    })
  end

  # -- command: resume --
  #
  # Resume is guidance-only per T04-R07. It reads the current projection
  # through `Workflow.current_session/0` and reports the Workflow's
  # `valid_next_actions/1` set as bounded next-action suggestions. It
  # performs no mutation; no journal write, no action commit, no
  # projection rebuild is performed by this command.

  defp dispatch_resume(%Request{} = _request, _session) do
    case Workflow.current_session() do
      {:ok, :empty} ->
        {:ok, no_session_result("resume")}

      {:ok, %{projection: projection} = result} ->
        session_id = get_in(projection, ["session", "id"])

        case capability_next_actions(session_id) do
          {:ok, mutating_actions} ->
            {:ok, resume_report_result(projection, result, mutating: mutating_actions)}

          {:error, %Error{} = error} ->
            {:error, error}
        end

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp resume_report_result(projection, result, opts) do
    mutating_actions = Keyword.fetch!(opts, :mutating)

    data = %{
      session_id: get_in(projection, ["session", "id"]),
      task_id: get_in(projection, ["task", "id"]),
      root_run_id: get_in(projection, ["run", "id"]),
      session_state: get_in(projection, ["session", "state"]),
      task_state: get_in(projection, ["task", "state"]),
      run_state: effective_run_state(projection, result),
      workflow_step: projection["workflow_step"],
      next_actions: resume_next_actions(result, mutating_actions)
    }

    if result.orphaned do
      Result.error("resume", :unknown,
        exit_code: 7,
        errors: [
          Result.to_error(%{
            code: :orphaned_run,
            message: "the Run has an unresolved external effect and requires reconciliation"
          })
        ],
        data: data,
        session_revision: revision_from_projection(projection),
        journal_digest: format_digest(result.projection_digest),
        next_actions: data.next_actions
      )
    else
      Result.ok("resume",
        data: data,
        session_revision: revision_from_projection(projection),
        journal_digest: format_digest(result.projection_digest),
        next_actions: data.next_actions
      )
    end
  end

  defp resume_next_actions(result, mutating_actions) do
    base =
      if result.orphaned do
        [Result.next_action("inspect", "review the unknown operation and orphan markers")]
      else
        [Result.next_action("inspect", "review the current state")]
      end

    Enum.uniq(base ++ mutating_actions)
  end

  # -- error mapping --

  defp error_result_tuple(%Request{command: command}, %Error{} = error) do
    {status, exit_code} = ErrorMap.map(error.code)

    result =
      Result.error(atom_to_command(command), status,
        exit_code: exit_code,
        errors: [Result.to_error(error)]
      )

    {result, exit_code}
  end

  # Build a CLI-owned `Result` for an internal guard code. The CLI never
  # constructs `%Kiln.Domain.Error{}` directly; it picks a CLI-native code
  # atom that the ErrorMap already maps to a `{status, exit_code}` pair.
  defp cli_native_error_result(command, code, details) do
    {status, exit_code} = ErrorMap.map(code)

    Result.error(atom_to_command(command), status,
      exit_code: exit_code,
      errors: [
        Result.to_error(%{code: code, message: message_for(code, details), details: details})
      ]
    )
  end

  defp message_for(:terminal_run_state, %{from: from}),
    do: "Run is already #{from}; cancel is not allowed from a terminal state"

  defp message_for(:active_operation, _),
    do: "Run owns an active or unknown operation; resolve it before canceling"

  defp message_for(code, _details), do: Atom.to_string(code)

  defp result_for_code(command, code, message) do
    {status, exit_code} = ErrorMap.map(code)

    result =
      Result.error(atom_to_command(command), status,
        exit_code: exit_code,
        errors: [Result.to_error(%{code: code, message: message, class: "blocked"})]
      )

    {result, exit_code}
  end

  # Returns a plain `%Result{}` (no `{:ok, _}` tag) so the caller owns
  # the success-tag wrapping. This avoids the nested-`{:ok, {:ok, ...}}`
  # shape that previously broke `run_with_mode/3` for the initialized-
  # but-empty DB case (a write-mode CLI command that creates the store
  # but fails input validation, leaving a populated empty DB that a
  # subsequent read-only command hits).
  defp no_session_result(command) do
    Result.error(command, :blocked,
      errors: [
        Result.to_error(%{
          code: :no_session,
          message: "no Session exists; start one with `mix kiln start`"
        })
      ]
    )
  end

  # -- terminal-state guard for cancel --
  #
  # The Workflow returns :run_transition_not_allowed from a `:canceled`
  # Run state, but the original CLI contract required a `:failed` exit 6
  # with "already <state>" message. The CLI checks the projection's
  # Run state here and short-circuits with the legacy error before
  # calling the Workflow so the existing test contract holds.

  defp terminal_check(previous_run_state, command) do
    if previous_run_state in ["canceled", "completed", "failed"] do
      {:error, cli_native_error_result(command, :terminal_run_state, %{from: previous_run_state})}
    else
      :ok
    end
  end

  # -- active-operation guard for cancel --
  #
  # The original CLI refused to cancel a Run that owned an active or unknown
  # operation. The Workflow agreed semantically but rejected the cancel via
  # :run_transition_not_allowed, which the CLI surfaced as :blocked exit 4.
  # The dispatcher checks the raw projection here so the original error
  # message reaches the user before any Workflow call.

  defp active_operation_check(projection) do
    if projection["operation"] != nil do
      {:error, cli_native_error_result("cancel", :active_operation, %{})}
    else
      :ok
    end
  end

  # -- helpers --

  defp summarize_pending_decision(nil), do: nil
  defp summarize_pending_decision(decision), do: decision

  defp summarize_operation(nil), do: nil

  defp summarize_operation(operation) do
    %{
      "id" => operation["id"],
      "class" => operation["class"],
      "state" => operation["state"]
    }
  end

  defp revision_from_projection(projection) do
    projection["session_revision"] || projection["objective_revision"] || 0
  end

  defp format_digest(nil), do: nil
  defp format_digest("sha256:" <> _ = digest), do: digest
  defp format_digest(digest) when is_binary(digest), do: "sha256:" <> digest

  # Single source of truth for capability-driven `next_actions` output.
  # The CLI never invents a `cancel` or `resume` suggestion: it consults the
  # Workflow capability matrix via `Workflow.valid_next_actions/1` and
  # translates the bounded atoms the Workflow advertises into
  # `Result.next_action` values through `translate_capability/1`. The
  # mapping table below is the only place those atoms are turned into CLI
  # strings, so a future Workflow capability that the CLI does not
  # recognise is silently dropped rather than invented as a mutation. The
  # terminal-state contract is therefore enforced both at the Workflow
  # boundary (its capability matrix returns `[]`) and at the CLI boundary
  # (no mapped atom ever reaches the renderer).
  defp capability_next_actions(session_id) when is_binary(session_id) do
    case Workflow.valid_next_actions(session_id) do
      {:ok, actions} ->
        {:ok,
         actions
         |> Enum.map(&translate_capability/1)
         |> Enum.reject(&is_nil/1)}

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  # Maps Workflow application capability atoms to T04 CLI executable
  # mutations. The mapping is intentionally narrow: T04 exposes exactly
  # one executable CLI mutation, `cancel`, which performs
  # `Workflow.cancel_session/2`. T04 `resume` is guidance-only per R07;
  # mapping `:resume_session -> "resume"` would tell the user to execute
  # a command that does not perform `Workflow.resume_session/2`. The
  # `:resume_session` atom is therefore not translated into a CLI
  # next-action; the user can still invoke `mix kiln resume` directly
  # for guidance, but it is not advertised as a Workflow-authorized
  # executable mutation.
  defp translate_capability(:cancel_session),
    do: Result.next_action("cancel", "cancel the Session explicitly")

  defp translate_capability(_other_application_atom), do: nil

  # Presentation/navigation suggestions the CLI may emit independently
  # because they describe how to navigate the CLI surface rather than how
  # to mutate application state. `cancel` and `resume` are deliberately
  # absent — they must always come from `capability_next_actions/1`.
  defp navigation_actions("start") do
    [
      Result.next_action("status", "show the current projection"),
      Result.next_action("inspect", "show the complete accepted state")
    ]
  end

  defp navigation_actions("status") do
    []
  end

  defp navigation_actions("inspect") do
    [Result.next_action("status", "show the current projection")]
  end

  defp navigation_actions("cancel") do
    [
      Result.next_action("status", "show the canceled state"),
      Result.next_action("inspect", "show the complete accepted state")
    ]
  end

  defp navigation_actions("resume") do
    [Result.next_action("inspect", "show the complete accepted state")]
  end

  defp navigation_actions("supervise") do
    [
      Result.next_action("inspect", "review the durable Run Result Envelope"),
      Result.next_action("status", "show the current projection")
    ]
  end

  # The Workflow exposes `orphaned: true` when the persisted projection
  # carries a non-nil operation in a nonterminal state. The persisted
  # `run.state` does not change to "orphaned" until Restart rebuilds
  # the projection; here we apply the same classification to the
  # renderer-facing fields so the CLI matches the legacy contract
  # (`run_state: "orphaned"`, `operation.state: "unknown"`).

  defp effective_run_state(projection, %{orphaned: true}) do
    case projection["operation"] do
      %{} -> "orphaned"
      _ -> get_in(projection, ["run", "state"])
    end
  end

  defp effective_run_state(projection, _result) do
    get_in(projection, ["run", "state"])
  end

  defp effective_operation(projection, %{orphaned: true}) do
    case projection["operation"] do
      %{"state" => state} = op when is_binary(state) ->
        if state in @nonterminal_operation_states do
          Map.put(op, "state", "unknown")
        else
          op
        end

      _ ->
        projection["operation"]
    end
  end

  defp effective_operation(projection, _result), do: projection["operation"]

  defp non_empty?(nil), do: false
  defp non_empty?(value) when is_binary(value), do: byte_size(value) > 0
  defp non_empty?(_), do: false

  defp non_empty_list?(nil), do: false
  defp non_empty_list?(values) when is_list(values), do: Enum.all?(values, &non_empty?/1)
  defp non_empty_list?(_), do: false

  defp optional_list?(nil), do: true

  defp optional_list?(values) when is_list(values),
    do: Enum.all?(values, &non_empty?/1)

  defp optional_list?(_), do: true

  defp atom_to_command(nil), do: "kiln"
  defp atom_to_command(command) when is_atom(command), do: Atom.to_string(command)
  defp atom_to_command(command), do: command

  # -- help / version --

  defp help_result do
    Result.ok("help",
      data: %{
        usage:
          "mix kiln [--format text|json] [--kiln-home PATH] [--actor-id ID] <command> [options]",
        commands: command_summary(),
        global_options: [
          %{flag: "--format", description: "output format: text (default) or json"},
          %{flag: "--kiln-home", description: "local KILN_HOME path containing state.sqlite3"},
          %{flag: "--actor-id", description: "actor identifier (required; or set KILN_ACTOR_ID)"},
          %{flag: "--help", description: "show this summary"},
          %{flag: "--version", description: "show the development version"}
        ],
        notes: [
          "This is a source-development entry point. The packaged release is not yet shipped.",
          "Provider, Context, Repository read, Patch, Command, completion, Receipt, Child, and TUI behavior are not exposed."
        ]
      },
      next_actions:
        Enum.map(@supported_commands, fn command ->
          Result.next_action(
            Atom.to_string(command),
            "run the #{Atom.to_string(command)} command"
          )
        end)
    )
  end

  defp version_result do
    Result.ok("version", data: %{version: @version, schema: Result.schema()})
  end

  defp command_summary do
    Enum.map(@supported_commands, fn command ->
      %{
        command: Atom.to_string(command),
        description: description_for(command)
      }
    end)
  end

  defp description_for(:start), do: "start one durable Session, Task, and ready Root Run"
  defp description_for(:status), do: "show the current projection and safe next actions"
  defp description_for(:inspect), do: "show the complete accepted P1-S01 state"
  defp description_for(:cancel), do: "cancel the Run when no operation is open or unknown"
  defp description_for(:resume), do: "report the current projection and valid next actions"

  defp description_for(:supervise),
    do: "supervise one Repository Recon Work Envelope through Kiln.Supervision"

  # -- command: supervise --
  #
  # The Wave 3 supervision boundary. Accepts a Work Envelope payload
  # path through `--work-envelope`, validates the payload through
  # `Kiln.WorkEnvelope.new/1`, observes the target repository, decides
  # `git.read` authority through `Kiln.Authority`, persists Artifact +
  # Evidence through the merged substrate, and produces the run-result
  # envelope. The CLI never reaches into Evidence or Artifact
  # internals; it routes through `Kiln.Supervision` only.
  defp dispatch_supervise(%Request{options: opts, actor_id: actor_id} = request) do
    work_envelope_path = Map.fetch!(opts, "work-envelope")

    with {:ok, attrs} <- Kiln.WorkEnvelopeLoader.load(work_envelope_path),
         {:ok, store} <- ready_store(request) do
      completion = Map.get(opts, "observation-completion", default_completion())

      supervise_opts = [
        store: store,
        actor_id: actor_id,
        now: now_iso(),
        git: Map.get(opts, "git", "git"),
        observation_completion: completion
      ]

      case Kiln.Supervision.supervise(attrs, supervise_opts) do
        {:ok, %Kiln.RunResultEnvelope{} = envelope} ->
          result_map = Kiln.RunResultEnvelope.to_map(envelope)

          {:ok,
           Result.ok("supervise",
             data: %{
               run_id: envelope.run_id,
               work_id: envelope.work_id,
               status: Atom.to_string(envelope.status),
               acceptance_readiness: envelope.acceptance_readiness,
               envelope: result_map
             },
             session_revision: 0,
             journal_digest: nil,
             next_actions: navigation_actions("supervise")
           )}

        {:error, {:idempotency_conflict, _, _}} ->
          idempotency_conflict_result()

        {:error, reason} ->
          supervise_error_result(reason)
      end
    else
      {:error, %Error{} = error} ->
        error_result_tuple(request, error)

      {:error, reason} ->
        code = error_code(reason)
        {status, exit_code} = ErrorMap.map(code)
        errors = [Result.to_error(%{code: code, message: inspect(reason)})]
        {Result.error("supervise", status, exit_code: exit_code, errors: errors), exit_code}
    end
  end

  # The CLI opens the supervised store through `Kiln.CLI.Runtime` in
  # write mode (the supervisor persists Artifacts, Evidence, and a
  # `supervision_runs` row). After startup, `Kiln.Store.Connection` is
  # registered with the live `conn`. The store map handed to the
  # supervisor must satisfy the Artifact substrate's expected shape
  # (`%{conn: pid, artifact_root: path}`) or `Artifact.Store.put/2`
  # raises `FunctionClauseError`.
  #
  # The canonical Artifact root is derived from the same `state.sqlite3`
  # path Runtime opened via `Kiln.Store.artifact_root_for_path/1`. This
  # helper is the single source of truth for the path layout; Runtime,
  # `Kiln.Store.start/1`, and this dispatcher all derive the same
  # directory. The CLI does not invent a second artifact location
  # convention.
  defp ready_store(%Request{kiln_home: kiln_home}) do
    with pid when is_pid(pid) <- Process.whereis(Kiln.Store.Connection) do
      state_path = Path.join(kiln_home, "state.sqlite3")
      artifact_root = Kiln.Store.artifact_root_for_path(state_path)
      {:ok, %{conn: pid, artifact_root: artifact_root}}
    else
      _ -> {:error, :store_unavailable}
    end
  end

  # The Wave 3 wedge does not embed the Loadout procedure; the producer
  # supplies its observation completion through the Work Envelope or
  # through a deterministic fixture. This default returns a successful
  # completion so the CLI runs the full happy-path pipeline without a
  # separate orchestrator process.
  defp default_completion do
    %{
      status: :completed,
      warnings: [],
      unknowns: []
    }
  end

  defp now_iso, do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp idempotency_conflict_result do
    {status, exit_code} = ErrorMap.map(:idempotency_conflict)

    result =
      Result.error("supervise", status,
        exit_code: exit_code,
        errors: [
          Result.to_error(%{
            code: :idempotency_conflict,
            message: "the same work_id was used with a materially different request"
          })
        ]
      )

    {result, exit_code}
  end

  defp supervise_error_result(reason) do
    code = error_code(reason)
    {status, exit_code} = ErrorMap.map(code)

    result =
      Result.error("supervise", status,
        exit_code: exit_code,
        errors: [Result.to_error(reason)]
      )

    {result, exit_code}
  end

  defp error_code(%Kiln.Store.Error{code: code}), do: code
  defp error_code(%{code: code}) when is_atom(code), do: code
  defp error_code(_), do: :unknown
end
