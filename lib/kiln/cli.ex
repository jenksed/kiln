defmodule Kiln.CLI do
  @moduledoc """
  The foundation CLI dispatcher.

  The CLI exposes a tiny P1-S01 surface (`start`, `status`, `inspect`, `cancel`,
  `resume`) over the accepted domain and store boundaries. It is non-authoritative
  presentation: every command routes through `Kiln.CLI.Request`,
  `Kiln.Store.start/1`, `Kiln.Journal.Replay`, `Kiln.Restart`, and
  `Kiln.Store.Journal.commit/4`. The CLI never invents or repairs state, never
  reads the Repository, the provider, the transcript, or external Commands, and
  never applies a Patch or accepts completion (P1-S01-T04-R12, R13, R14).

  Run a single command through `run/1`. The return value is a `{Result.t(),
  exit_code}` tuple so the caller (the `mix kiln` Mix task) can set the process
  exit code. Help and version are produced by the renderer so they share the
  same envelope as everything else.
  """

  alias Kiln.CLI.{Request, Result}
  alias Kiln.Domain.{Action, Id, ProjectObservation}
  alias Kiln.Domain.Session, as: DomainSession
  alias Kiln.Projections.Session, as: ProjectionSession
  alias Kiln.Store
  alias Kiln.Store.Journal

  @supported_commands Request.commands()
  @version Kiln.version()

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

  def run(%Request{} = request), do: run_with_store(request)

  defp run_with_store(%Request{} = request) do
    case open_store(request) do
      {:ok, store} ->
        try do
          case dispatch(request, store) do
            {:ok, %Result{} = result} -> {result, result.exit_code}
            {:error, %Result{} = result} -> {result, result.exit_code}
          end
        after
          stop_store(store)
        end

      {:blocked, state, error} when is_atom(state) ->
        result = blocked_result(request, state, error)
        {result, result.exit_code}

      {:error, %Result{} = result} ->
        {result, result.exit_code}
    end
  end

  defp open_store(%Request{command: command, kiln_home: nil}) do
    {:error,
     Result.error(atom_to_command(command), :denied,
       exit_code: 2,
       errors: [Result.to_error("a --kiln-home path is required")]
     )}
  end

  defp open_store(%Request{kiln_home: path}) do
    case Store.start(path: state_path(path)) do
      {:ready, store} -> {:ok, store}
      {:blocked, state, error} -> {:blocked, state, error}
      {:error, reason} -> {:blocked, :unavailable, reason}
    end
  end

  defp state_path(home), do: Path.join(home, "state.sqlite3")

  defp stop_store(%{conn: conn}) when is_pid(conn) do
    if Process.alive?(conn), do: GenServer.stop(conn, :normal, 5_000)
    :ok
  catch
    :exit, _reason -> :ok
  end

  # -- dispatch --

  defp dispatch(%Request{command: :start, options: opts} = request, store) do
    start_session(request, store, opts)
  end

  defp dispatch(%Request{command: :status} = request, store) do
    with {:ok, reconstruction} <- read_reconstruction(store, "status") do
      {:ok, status_result(request, reconstruction)}
    end
  end

  defp dispatch(%Request{command: :inspect} = request, store) do
    with {:ok, reconstruction} <- read_reconstruction(store, "inspect") do
      {:ok, inspect_result(request, reconstruction)}
    end
  end

  defp dispatch(%Request{command: :cancel, options: opts} = request, store) do
    cancel_session(request, store, opts)
  end

  defp dispatch(%Request{command: :resume} = request, store) do
    with {:ok, reconstruction} <- read_reconstruction(store, "resume") do
      {:ok, resume_result(request, reconstruction)}
    end
  end

  # -- reconstruction --

  defp read_reconstruction(store, command) do
    case Kiln.Restart.reconstruct(store.conn) do
      {:ok, :empty} ->
        {:error,
         Result.error(command, :blocked,
           errors: [
             Result.to_error(%{
               code: :no_session,
               message: "no Session exists; start one with `mix kiln start`"
             })
           ]
         )}

      {:ok, reconstruction} ->
        {:ok, reconstruction}

      {:error, %{code: :multiple_sessions, detail: detail}} ->
        {:error,
         Result.error(command, :blocked,
           errors: [
             Result.to_error(%{
               code: :multiple_sessions,
               message: "more than one Session exists; the foundation CLI supports exactly one",
               details: detail
             })
           ]
         )}

      {:error, %{block: block}} ->
        {:error,
         Result.error(command, :unknown,
           errors: [
             Result.to_error(%{
               code: block.code,
               message: "journal is blocked at the failing boundary",
               details: block.detail
             })
           ]
         )}
    end
  end

  # -- start --

  defp start_session(%Request{}, store, opts) do
    with :ok <- ensure_no_session(store),
         {:ok, start_attrs} <- validate_start_opts(opts),
         {:ok, %{session: session, task: task, run: run}} <- DomainSession.start(start_attrs) do
      commit_start(store, session, task, run)
    else
      {:error, %Result{} = result} ->
        {:error, result}

      {:error, %Kiln.Domain.Error{} = error} ->
        {:error, Result.error("start", :denied, exit_code: 2, errors: [Result.to_error(error)])}

      {:error, message} when is_binary(message) ->
        {:error, Result.error("start", :denied, exit_code: 2, errors: [Result.to_error(message)])}
    end
  end

  defp ensure_no_session(store) do
    case Kiln.Restart.reconstruct(store.conn) do
      {:ok, :empty} ->
        :ok

      {:ok, _reconstruction} ->
        {:error,
         Result.error("start", :blocked,
           errors: [
             Result.to_error(%{
               code: :session_already_exists,
               message:
                 "a Session already exists; inspect or cancel it instead of starting another"
             })
           ]
         )}

      {:error, %{code: :multiple_sessions, detail: detail}} ->
        {:error,
         Result.error("start", :blocked,
           errors: [
             Result.to_error(%{
               code: :multiple_sessions,
               message: "more than one Session exists; no new Session can be started",
               details: detail
             })
           ]
         )}

      {:error, %{block: block}} ->
        {:error,
         Result.error("start", :unknown,
           errors: [
             Result.to_error(%{
               code: block.code,
               message: "the existing journal cannot be reconstructed safely",
               details: block.detail
             })
           ]
         )}
    end
  end

  defp validate_start_opts(opts) do
    with {:ok, repo_root} <- required_option(opts, "repo", :repo),
         {:ok, objective} <- required_option(opts, "objective", :objective),
         {:ok, criteria} <- criteria_list(opts),
         {:ok, constraints} <- optional_list(opts, "constraint"),
         {:ok, exclusions} <- optional_list(opts, "exclude") do
      {:ok,
       %{
         project_observation: build_project_observation(repo_root),
         objective: objective,
         criteria: criteria,
         constraints: constraints,
         exclusions: exclusions,
         started_at: DateTime.utc_now()
       }}
    end
  end

  defp required_option(opts, key, _field) do
    case Map.fetch(opts, key) do
      {:ok, value} when is_binary(value) and byte_size(value) > 0 ->
        {:ok, value}

      _ ->
        {:error, "--#{key} is required"}
    end
  end

  defp criteria_list(opts) do
    case Map.get(opts, "criterion") do
      nil ->
        {:error, "at least one --criterion is required"}

      true ->
        {:error, "at least one --criterion is required"}

      values when is_list(values) and values != [] ->
        if Enum.all?(values, &(is_binary(&1) and byte_size(&1) > 0)) do
          {:ok, values}
        else
          {:error, "every --criterion must be a non-empty string"}
        end

      _ ->
        {:error, "at least one --criterion is required"}
    end
  end

  defp optional_list(opts, key) do
    case Map.get(opts, key) do
      nil ->
        {:ok, []}

      true ->
        {:ok, []}

      values when is_list(values) ->
        if Enum.all?(values, &(is_binary(&1) and byte_size(&1) > 0)) do
          {:ok, values}
        else
          {:error, "every --#{key} must be a non-empty string"}
        end

      _ ->
        {:ok, []}
    end
  end

  defp build_project_observation(repo_root) do
    fingerprint =
      "sha256:" <>
        (:crypto.hash(:sha256, repo_root) |> Base.encode16(case: :lower))

    {:ok, observation} =
      ProjectObservation.new(%{
        repository_root: repo_root,
        repository_fingerprint: fingerprint,
        observed_at: DateTime.utc_now()
      })

    observation
  end

  defp commit_start(store, session, task, run) do
    action = build_start_action(session, task)

    result_data = %{
      session_id: session.id,
      task_id: task.id,
      root_run_id: run.id,
      objective: session.objective
    }

    entry = %{
      type: "session_started/v1",
      payload_schema: "session_started/v1",
      payload: %{
        "session" => %{"id" => session.id, "state" => "active"},
        "task" => %{"id" => task.id, "state" => "in_progress"},
        "run" => %{"id" => run.id, "state" => "ready", "root_run_id" => run.root_run_id},
        "workflow_step" => "intent",
        "objective" => session.objective,
        "criteria" => task.criteria,
        "constraints" => task.constraints,
        "exclusions" => task.exclusions,
        "objective_revision" => session.revision,
        "criteria_revision" => session.criteria_revision,
        "references" => %{"project_observation_id" => session.project_observation_id}
      }
    }

    case Journal.commit(store.conn, action, [entry], result: result_data) do
      {:ok, %{status: :committed} = committed} ->
        {:ok,
         Result.ok("start",
           data: result_data,
           session_revision: committed.session_revision,
           journal_digest: format_digest(ProjectionSession.digest(committed.projection)),
           warnings: [],
           next_actions: [
             Result.next_action("status", "show the current projection"),
             Result.next_action("inspect", "show the complete accepted state"),
             Result.next_action("cancel", "end the session safely if no work is in flight")
           ]
         )}

      {:ok, %{status: :replayed} = replayed} ->
        {:ok,
         Result.ok("start",
           data: replay_data(replayed.result),
           warnings: [
             Result.warning(
               "REPLAYED",
               "the idempotency key matched a previous start; no new journal entry was written"
             )
           ],
           session_revision: replayed_result_session_revision(replayed.result)
         )}

      {:error, %Kiln.Store.Error{} = error} ->
        {:error, classify_journal_error("start", error)}
    end
  end

  defp replay_data(%{session_id: id, task_id: task_id, root_run_id: run_id, objective: objective})
       when is_binary(id) and is_binary(task_id) and is_binary(run_id) and is_binary(objective),
       do: %{session_id: id, task_id: task_id, root_run_id: run_id, objective: objective}

  defp replay_data(%{
         "session_id" => id,
         "task_id" => task_id,
         "root_run_id" => run_id,
         "objective" => objective
       })
       when is_binary(id) and is_binary(task_id) and is_binary(run_id) and is_binary(objective),
       do: %{session_id: id, task_id: task_id, root_run_id: run_id, objective: objective}

  defp replay_data(_), do: %{note: "replayed result without standard fields"}

  defp replayed_result_session_revision(%{"session_revision" => rev}) when is_integer(rev),
    do: rev

  defp replayed_result_session_revision(%{session_revision: rev}) when is_integer(rev), do: rev
  defp replayed_result_session_revision(_), do: nil

  defp build_start_action(session, task) do
    {:ok, action_id} = Id.generate(:action)
    {:ok, idempotency_key} = Id.generate(:idempotency)

    {:ok, action} =
      Action.new(%{
        id: action_id,
        session_id: session.id,
        run_id: nil,
        expected_session_revision: 0,
        idempotency_key: idempotency_key,
        actor_kind: :local_user,
        actor_id: "user:local",
        kind: :start_session,
        request_digest: canonical_start_digest(session, task),
        payload: %{},
        causation_action_id: nil,
        correlation_id: nil,
        requested_at: DateTime.utc_now()
      })

    action
  end

  defp canonical_start_digest(session, task) do
    payload = %{
      "objective" => session.objective,
      "criteria" => task.criteria,
      "constraints" => task.constraints,
      "exclusions" => task.exclusions,
      "project_observation_id" => session.project_observation_id
    }

    "sha256:" <>
      (:crypto.hash(:sha256, :erlang.term_to_binary(payload)) |> Base.encode16(case: :lower))
  end

  # -- status / inspect --

  defp status_result(_request, reconstruction) do
    reconstruction_result("status", reconstruction, status_data(reconstruction))
  end

  defp status_data(reconstruction) do
    projection = reconstruction.projection

    %{
      session_id: projection["session"]["id"],
      session_state: projection["session"]["state"],
      task_id: projection["task"]["id"],
      task_state: projection["task"]["state"],
      root_run_id: projection["run"]["id"],
      run_state: projection["run"]["state"],
      workflow_step: projection["workflow_step"],
      pending_decision: summarize_pending_decision(projection["pending_decision"]),
      operation: summarize_operation(projection["operation"]),
      cache_status: to_string(reconstruction.cache_status),
      orphaned: reconstruction.orphaned,
      journal_head: format_digest(reconstruction.journal_head_digest)
    }
  end

  defp inspect_result(_request, reconstruction) do
    reconstruction_result("inspect", reconstruction, inspect_data(reconstruction))
  end

  defp inspect_data(reconstruction) do
    projection = reconstruction.projection
    objective = projection["objective"]
    criteria = projection["criteria"] || []

    %{
      session_id: projection["session"]["id"],
      session_state: projection["session"]["state"],
      task_id: projection["task"]["id"],
      task_state: projection["task"]["state"],
      root_run_id: projection["run"]["id"],
      run_state: projection["run"]["state"],
      workflow_step: projection["workflow_step"],
      objective_revision: projection["objective_revision"] || 0,
      criteria_revision: projection["criteria_revision"] || 0,
      objective: objective || "",
      criteria: criteria,
      constraints: projection["constraints"] || [],
      exclusions: projection["exclusions"] || [],
      pending_decision: summarize_pending_decision(projection["pending_decision"]),
      operation: summarize_operation(projection["operation"]),
      unknowns: projection["unknowns"] || [],
      project_observation_id: get_in(projection, ["references", "project_observation_id"]),
      journal_head_digest: format_digest(reconstruction.journal_head_digest),
      projection_digest: format_digest(reconstruction.reconstructed_projection_digest)
    }
  end

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

  # -- cancel --

  defp cancel_session(%Request{} = request, store, opts) do
    with {:ok, reconstruction} <- read_reconstruction(store, "cancel"),
         {:ok, projection} <- validate_cancel_state(reconstruction) do
      reason = Map.get(opts, "reason")
      commit_cancel(request, store, projection, reason, reconstruction)
    else
      {:error, %Result{} = error} -> {:error, error}
    end
  end

  defp validate_cancel_state(%{projection: projection}) do
    run_state = projection["run"]["state"]

    cond do
      run_state in ["completed", "failed", "canceled"] ->
        {:error,
         Result.error("cancel", :failed,
           errors: [
             Result.to_error(%{
               code: :terminal_run_state,
               message: "Run is already #{run_state}; cancel is not allowed from a terminal state"
             })
           ]
         )}

      projection["operation"] != nil ->
        {:error,
         Result.error("cancel", :blocked,
           errors: [
             Result.to_error(%{
               code: :active_operation,
               message: "Run owns an active or unknown operation; resolve it before canceling"
             })
           ]
         )}

      true ->
        {:ok, projection}
    end
  end

  defp commit_cancel(_request, store, projection, reason, reconstruction) do
    session_id = projection["session"]["id"]
    run_id = projection["run"]["id"]
    expected_revision = reconstruction.session_revision
    previous_run_state = projection["run"]["state"]

    action =
      build_transition_action(:cancel_session, session_id, run_id, expected_revision, reason)

    entry = %{
      type: "run_transitioned/v1",
      payload_schema: "run_transitioned/v1",
      payload: %{
        "run" => %{"from" => previous_run_state, "to" => "canceled"},
        "workflow_step" => projection["workflow_step"]
      }
    }

    result_map = %{"previous_run_state" => previous_run_state, "reason" => reason}

    case Journal.commit(store.conn, action, [entry], result: result_map) do
      {:ok, %{status: :committed, projection: committed_projection} = committed} ->
        {:ok,
         Result.ok("cancel",
           data: %{
             session_id: session_id,
             task_id: committed_projection["task"]["id"],
             root_run_id: run_id,
             previous_run_state: previous_run_state,
             run_state: "canceled"
           },
           session_revision: committed.session_revision,
           journal_digest: format_digest(ProjectionSession.digest(committed_projection)),
           next_actions: [
             Result.next_action("status", "show the canceled state"),
             Result.next_action("resume", "resume guidance for a new accepted start")
           ]
         )}

      {:ok, %{status: :replayed} = replayed} ->
        {:ok,
         Result.ok("cancel",
           data: %{
             note: "replayed cancel action",
             previous_run_state: previous_run_state,
             run_state: "canceled"
           },
           warnings: [
             Result.warning("REPLAYED", "the cancel idempotency key matched a previous action")
           ],
           session_revision: replayed_result_session_revision(replayed.result)
         )}

      {:error, %Kiln.Store.Error{} = error} ->
        {:error, classify_journal_error("cancel", error)}
    end
  end

  defp build_transition_action(kind, session_id, run_id, expected_revision, reason) do
    {:ok, action_id} = Id.generate(:action)
    {:ok, idempotency_key} = Id.generate(:idempotency)

    {:ok, action} =
      Action.new(%{
        id: action_id,
        session_id: session_id,
        run_id: run_id,
        expected_session_revision: expected_revision,
        idempotency_key: idempotency_key,
        actor_kind: :local_user,
        actor_id: "user:local",
        kind: kind,
        request_digest: canonical_reason_digest(reason),
        payload: %{reason: reason || ""},
        causation_action_id: nil,
        correlation_id: nil,
        requested_at: DateTime.utc_now()
      })

    action
  end

  defp canonical_reason_digest(reason) do
    payload = %{"reason" => reason || ""}

    "sha256:" <>
      (:crypto.hash(:sha256, :erlang.term_to_binary(payload)) |> Base.encode16(case: :lower))
  end

  # -- resume --

  defp resume_result(_request, reconstruction) do
    projection = reconstruction.projection

    data = %{
      session_id: projection["session"]["id"],
      task_id: projection["task"]["id"],
      root_run_id: projection["run"]["id"],
      session_state: projection["session"]["state"],
      task_state: projection["task"]["state"],
      run_state: projection["run"]["state"],
      workflow_step: projection["workflow_step"],
      next_actions: next_actions_for(reconstruction)
    }

    reconstruction_result("resume", reconstruction, data)
  end

  defp reconstruction_result(command, reconstruction, data) do
    opts = [
      data: data,
      warnings: projection_warnings(reconstruction.projection),
      session_revision: reconstruction.session_revision,
      journal_digest: format_digest(reconstruction.reconstructed_projection_digest),
      next_actions: next_actions_for(reconstruction)
    ]

    if reconstruction.orphaned do
      Result.error(
        command,
        :unknown,
        Keyword.put(opts, :errors, [
          Result.to_error(%{
            code: :orphaned_run,
            message: "the Run has an unresolved external effect and requires reconciliation"
          })
        ])
      )
    else
      Result.ok(command, opts)
    end
  end

  defp projection_warnings(projection) do
    Enum.map(projection["warnings"] || [], fn
      %{"code" => code, "message" => message} -> Result.warning(to_string(code), message)
      %{code: code, message: message} -> Result.warning(to_string(code), message)
      warning -> Result.warning("PROJECTION_WARNING", inspect(warning))
    end)
  end

  defp next_actions_for(%{projection: nil}),
    do: [Result.next_action("start", "create the first Session")]

  defp next_actions_for(%{} = reconstruction) do
    do_next_actions(reconstruction)
  end

  defp do_next_actions(%{projection: projection} = reconstruction) do
    run_state = projection["run"]["state"]

    cond do
      run_state == "completed" ->
        [Result.next_action("inspect", "review the accepted completion")]

      run_state == "failed" ->
        [Result.next_action("inspect", "review the known failure")]

      run_state == "canceled" ->
        [Result.next_action("status", "show the canceled state")]

      reconstruction.orphaned ->
        [
          Result.next_action("inspect", "review the unknown operation and orphan markers"),
          Result.next_action("status", "show the orphaned Run")
        ]

      projection["pending_decision"] != nil ->
        [
          Result.next_action("inspect", "review the pending decision"),
          Result.next_action("status", "show the waiting_for_user state")
        ]

      projection["operation"] != nil ->
        [
          Result.next_action("inspect", "review the active external operation"),
          Result.next_action("status", "show the running state")
        ]

      true ->
        [
          Result.next_action("inspect", "review the current state"),
          Result.next_action("cancel", "end the Session safely if no work is in flight")
        ]
    end
  end

  # -- error mapping --

  defp classify_journal_error(command, %Kiln.Store.Error{code: :idempotency_conflict} = error) do
    Result.error(command, :denied, errors: [Result.to_error(error)])
  end

  defp classify_journal_error(command, %Kiln.Store.Error{code: :stale_revision} = error) do
    Result.error(command, :stale, errors: [Result.to_error(error)])
  end

  defp classify_journal_error(command, %Kiln.Store.Error{code: :store_busy} = error) do
    Result.error(command, :blocked, errors: [Result.to_error(error)])
  end

  defp classify_journal_error(command, %Kiln.Store.Error{code: :integrity} = error) do
    Result.error(command, :blocked, errors: [Result.to_error(error)])
  end

  defp classify_journal_error(command, %Kiln.Store.Error{} = error) do
    Result.error(command, :failed, errors: [Result.to_error(error)])
  end

  defp blocked_result(%Request{command: command}, :migration_blocked, error) do
    Result.error(atom_to_command(command), :blocked,
      exit_code: 8,
      errors: [
        Result.to_error(error),
        Result.to_error("migration is blocked; preserve files and follow the diagnostic action")
      ]
    )
  end

  defp blocked_result(%Request{command: command}, :integrity_blocked, error) do
    Result.error(atom_to_command(command), :blocked,
      exit_code: 8,
      errors: [
        Result.to_error(error),
        Result.to_error("the store is corrupt; preserve files and run a manual recovery")
      ]
    )
  end

  defp blocked_result(%Request{command: command}, :version_blocked, error) do
    Result.error(atom_to_command(command), :blocked,
      exit_code: 8,
      errors: [
        Result.to_error(error),
        Result.to_error("the binary cannot open this store; use a compatible Kiln")
      ]
    )
  end

  defp blocked_result(%Request{command: command}, :unavailable, _reason) do
    Result.error(atom_to_command(command), :blocked,
      exit_code: 8,
      errors: [Result.to_error("the store could not be opened")]
    )
  end

  defp atom_to_command(nil), do: "kiln"
  defp atom_to_command(command) when is_atom(command), do: Atom.to_string(command)
  defp atom_to_command(command), do: command

  # -- helpers --

  defp format_digest(nil), do: nil
  defp format_digest("sha256:" <> _ = digest), do: digest
  defp format_digest(digest) when is_binary(digest), do: "sha256:" <> digest

  defp help_result do
    Result.ok("help",
      data: %{
        usage: "mix kiln [--format text|json] [--kiln-home PATH] <command> [options]",
        commands: command_summary(),
        global_options: [
          %{flag: "--format", description: "output format: text (default) or json"},
          %{flag: "--kiln-home", description: "local KILN_HOME path containing state.sqlite3"},
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
end
