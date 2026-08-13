defmodule Kiln.WorkEnvelope do
  @moduledoc """
  The narrow intake validator for `engineering-system/work-envelope/v0` payloads.

  `Kiln.WorkEnvelope` is the single Kiln-side boundary that accepts a Work
  Envelope from a producer (Loadout in the accepted Wave 3 wedge) and rejects
  malformed or unsupported payloads *before* any durable Work identity is
  bound. It does not own repository access, Evidence, Artifact, journal
  writes, or authority decisions; those belong to `Kiln.Supervision`,
  `Kiln.Authority`, and the merged P1-S02-T01 substrate.

  ## Validation surfaces

    * Schema identity (`engineering-system/work-envelope/v0`).
    * `work_id` (required, non-blank, byte-bounded).
    * `producer` (`product` is `loadout`, `version` is non-blank).
    * `goal` (`title` and a non-empty `success_conditions` list).
    * `capability` (`id` is exactly `repository-recon`; `contract_version`
      is non-blank; `method_provenance` is a list of non-blank strings).
    * `project_state` (`repository` is non-blank; `base_commit` is a 40-char
      lowercase SHA; `workspace_state_digest` is non-blank).
    * `scope` (`included` and `excluded` are lists of non-blank strings).
    * `constraints` (`must` and `must_not` are lists of non-blank strings).
    * `proof_obligations` (a list of `{id, kind, requirement}` triples).
    * `authority_requests` (a list of typed capability/scope pairs).

  The module performs no I/O, no Store access, no filesystem access, no
  provider calls, and no process creation. It is pure validation.
  """

  alias Kiln.Store.Error

  @schema "engineering-system/work-envelope/v0"

  @accepted_capability_id "repository-recon"
  @accepted_producer_product "loadout"

  @max_identifier_bytes 256
  @max_text_bytes 1024
  @max_list_items 64
  @max_request_bytes 65_536

  @enforce_keys [
    :work_id,
    :producer,
    :goal,
    :capability,
    :project_state,
    :scope,
    :constraints,
    :proof_obligations,
    :authority_requests
  ]

  defstruct [
    :schema,
    :work_id,
    :created_at,
    :producer,
    :goal,
    :capability,
    :project_state,
    :scope,
    :constraints,
    :proof_obligations,
    :authority_requests,
    :context_refs
  ]

  @type producer :: %{product: String.t(), version: String.t()}
  @type goal :: %{title: String.t(), success_conditions: [String.t()]}
  @type method_provenance :: String.t()

  @type capability :: %{
          id: String.t(),
          contract_version: String.t(),
          method_provenance: [method_provenance()]
        }

  @type project_state :: %{
          repository: String.t(),
          base_commit: String.t(),
          workspace_state_digest: String.t()
        }

  @type scope :: %{included: [String.t()], excluded: [String.t()]}
  @type constraints :: %{must: [String.t()], must_not: [String.t()]}
  @type proof_obligation :: %{id: String.t(), kind: String.t(), requirement: String.t()}
  @type authority_request :: %{capability: String.t(), scope: String.t()}

  @type t :: %__MODULE__{
          schema: String.t(),
          work_id: String.t(),
          created_at: String.t() | nil,
          producer: producer(),
          goal: goal(),
          capability: capability(),
          project_state: project_state(),
          scope: scope(),
          constraints: constraints(),
          proof_obligations: [proof_obligation()],
          authority_requests: [authority_request()],
          context_refs: [String.t()]
        }

  @doc "The accepted Work Envelope v0 schema identifier."
  @spec schema() :: String.t()
  def schema, do: @schema

  @doc "The Wave 3 supported capability identifier."
  @spec accepted_capability_id() :: String.t()
  def accepted_capability_id, do: @accepted_capability_id

  @doc "The accepted producer product identifier."
  @spec accepted_producer_product() :: String.t()
  def accepted_producer_product, do: @accepted_producer_product

  @doc """
  Construct and validate a Work Envelope from the given attributes.

  The accepted payload shape is the engineering-system/work-envelope/v0
  YAML/JSON contract. The validator enforces the schema identity, required
  fields, byte/length bounds, and accepted vocabularies. It does not
  create any durable Work identity, allocate any Run identifier, or
  invoke the Store, filesystem, or authority modules.
  """
  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attrs) when is_map(attrs) do
    with :ok <- check_required_keys(attrs),
         {:ok, schema} <- check_schema(attrs),
         {:ok, work_id} <- check_identifier(Map.fetch!(attrs, "work_id"), "work_id"),
         {:ok, created_at} <- check_optional_timestamp(Map.get(attrs, "created_at"), "created_at"),
         {:ok, producer} <- check_producer(Map.fetch!(attrs, "producer"), attrs),
         {:ok, goal} <- check_goal(Map.fetch!(attrs, "goal")),
         {:ok, capability} <- check_capability(Map.fetch!(attrs, "capability")),
         {:ok, project_state} <- check_project_state(Map.fetch!(attrs, "project_state")),
         {:ok, scope} <- check_scope(Map.fetch!(attrs, "scope")),
         {:ok, constraints} <- check_constraints(Map.fetch!(attrs, "constraints")),
         {:ok, proof_obligations} <-
           check_proof_obligations(Map.fetch!(attrs, "proof_obligations")),
         {:ok, authority_requests} <-
           check_authority_requests(Map.fetch!(attrs, "authority_requests")),
         {:ok, context_refs} <- check_context_refs(Map.get(attrs, "context_refs", [])) do
      envelope = %__MODULE__{
        schema: schema,
        work_id: work_id,
        created_at: created_at,
        producer: producer,
        goal: goal,
        capability: capability,
        project_state: project_state,
        scope: scope,
        constraints: constraints,
        proof_obligations: proof_obligations,
        authority_requests: authority_requests,
        context_refs: context_refs
      }

      {:ok, envelope}
    end
  end

  @doc """
  Produce the canonical request digest that identifies one accepted Work
  Envelope semantically.

  Two Work Envelopes with identical semantically-bound fields produce the
  same digest. Fields excluded from the digest (idempotency-key inputs,
  caller-supplied timestamps when marked `:caller`, and the optional
  `context_refs` list) do not affect replay identity.
  """
  @spec request_digest(t()) :: String.t()
  def request_digest(%__MODULE__{} = envelope) do
    payload = %{
      "schema" => envelope.schema,
      "work_id" => envelope.work_id,
      "producer" => envelope.producer,
      "goal" => envelope.goal,
      "capability" => envelope.capability,
      "project_state" => envelope.project_state,
      "scope" => envelope.scope,
      "constraints" => envelope.constraints,
      "proof_obligations" => envelope.proof_obligations,
      "authority_requests" => envelope.authority_requests
    }

    :sha256
    |> :crypto.hash([@schema, "\n", Kiln.Store.Canonical.encode(payload)])
    |> Base.encode16(case: :lower)
    |> (fn hex -> "sha256:" <> hex end).()
  end

  @doc """
  Return the `requested` authority capabilities for an envelope.

  Each entry is the capability string the producer asked Kiln to authorize.
  The supervisor's authority decision is separate; this function only
  surfaces the request.
  """
  @spec requested_capabilities(t()) :: [String.t()]
  def requested_capabilities(%__MODULE__{} = envelope) do
    envelope.authority_requests |> Enum.map(& &1.capability) |> Enum.uniq() |> Enum.sort()
  end

  # -- validation helpers --

  defp check_required_keys(attrs) do
    required =
      ~w(work_id producer goal capability project_state scope constraints proof_obligations authority_requests)

    case Enum.find(required, fn key -> not Map.has_key?(attrs, key) end) do
      nil ->
        :ok

      missing ->
        {:error,
         Error.new(
           :precondition,
           :missing_field,
           "work envelope is missing a required field",
           %{field: missing}
         )}
    end
  end

  defp check_schema(attrs) do
    case Map.fetch(attrs, "schema") do
      {:ok, @schema} ->
        {:ok, @schema}

      {:ok, other} when is_binary(other) ->
        {:error,
         Error.new(
           :precondition,
           :unsupported_schema,
           "work envelope schema is not the accepted v0 identifier",
           %{expected: @schema, actual: other}
         )}

      _ ->
        {:error,
         Error.new(
           :precondition,
           :missing_schema,
           "work envelope is missing the schema identifier",
           %{}
         )}
    end
  end

  defp check_identifier(value, field) when is_binary(value) do
    cond do
      byte_size(value) == 0 ->
        {:error, empty_identifier_error(field)}

      byte_size(value) > @max_identifier_bytes ->
        {:error, limit_error(field, @max_identifier_bytes, byte_size(value))}

      has_disallowed_control?(value) ->
        {:error, control_byte_error(field)}

      true ->
        {:ok, value}
    end
  end

  defp check_identifier(_, field) do
    {:error, type_error(field, "binary")}
  end

  defp check_optional_timestamp(value, field) when is_binary(value) do
    cond do
      byte_size(value) == 0 ->
        {:error, empty_identifier_error(field)}

      byte_size(value) > @max_text_bytes ->
        {:error, limit_error(field, @max_text_bytes, byte_size(value))}

      has_disallowed_control?(value) ->
        {:error, control_byte_error(field)}

      true ->
        {:ok, value}
    end
  end

  defp check_optional_timestamp(nil, _field), do: {:ok, nil}

  defp check_optional_timestamp(_value, field) do
    {:error, type_error(field, "binary or nil")}
  end

  defp check_producer(value, attrs) when is_map(value) do
    with {:ok, product} <- map_field(value, "product", @accepted_producer_product, attrs),
         {:ok, version} <- map_field(value, "version", :any, attrs) do
      cond do
        product != @accepted_producer_product ->
          {:error,
           Error.new(
             :precondition,
             :unsupported_producer,
             "the producer product is not in the accepted set",
             %{expected: @accepted_producer_product, actual: product}
           )}

        byte_size(version) == 0 ->
          {:error, empty_identifier_error("producer.version")}

        byte_size(version) > @max_identifier_bytes ->
          {:error, limit_error("producer.version", @max_identifier_bytes, byte_size(version))}

        has_disallowed_control?(version) ->
          {:error, control_byte_error("producer.version")}

        true ->
          {:ok, %{product: product, version: version}}
      end
    end
  end

  defp check_producer(_, _) do
    {:error, type_error("producer", "map")}
  end

  defp check_goal(value) when is_map(value) do
    with {:ok, title} <- map_field(value, "title", :any, value),
         {:ok, success_conditions} <- map_field(value, "success_conditions", :any, value) do
      cond do
        not is_binary(title) or byte_size(title) == 0 ->
          {:error, empty_identifier_error("goal.title")}

        byte_size(title) > @max_text_bytes ->
          {:error, limit_error("goal.title", @max_text_bytes, byte_size(title))}

        has_disallowed_control?(title) ->
          {:error, control_byte_error("goal.title")}

        not is_list(success_conditions) or success_conditions == [] ->
          {:error,
           Error.new(
             :precondition,
             :missing_goal_conditions,
             "goal.success_conditions must be a non-empty list",
             %{}
           )}

        length(success_conditions) > @max_list_items ->
          {:error,
           limit_error("goal.success_conditions", @max_list_items, length(success_conditions))}

        not Enum.all?(success_conditions, &(is_binary(&1) and byte_size(&1) > 0)) ->
          {:error,
           Error.new(
             :precondition,
             :invalid_goal_condition,
             "every goal.success_conditions entry must be a non-empty string",
             %{}
           )}

        true ->
          {:ok, %{title: title, success_conditions: success_conditions}}
      end
    end
  end

  defp check_goal(_) do
    {:error, type_error("goal", "map")}
  end

  defp check_capability(value) when is_map(value) do
    with {:ok, id} <- map_field(value, "id", :any, value),
         {:ok, contract_version} <- map_field(value, "contract_version", :any, value),
         {:ok, provenance_list} <- map_field(value, "method_provenance", :any, value) do
      cond do
        not is_binary(id) or id != @accepted_capability_id ->
          {:error,
           Error.new(
             :precondition,
             :unsupported_capability,
             "the capability id is not in the accepted Wave 3 set",
             %{accepted: [@accepted_capability_id], actual: id}
           )}

        not is_binary(contract_version) or byte_size(contract_version) == 0 ->
          {:error, empty_identifier_error("capability.contract_version")}

        byte_size(contract_version) > @max_identifier_bytes ->
          {:error,
           limit_error(
             "capability.contract_version",
             @max_identifier_bytes,
             byte_size(contract_version)
           )}

        not is_list(provenance_list) ->
          {:error,
           Error.new(
             :precondition,
             :invalid_method_provenance,
             "capability.method_provenance must be a list",
             %{}
           )}

        length(provenance_list) > @max_list_items ->
          {:error,
           limit_error("capability.method_provenance", @max_list_items, length(provenance_list))}

        true ->
          case check_method_provenance_list(provenance_list) do
            :ok ->
              {:ok,
               %{id: id, contract_version: contract_version, method_provenance: provenance_list}}

            {:error, _} = err ->
              err
          end
      end
    end
  end

  defp check_capability(_) do
    {:error, type_error("capability", "map")}
  end

  defp check_method_provenance_list(list) do
    Enum.reduce_while(list, :ok, fn entry, acc ->
      case acc do
        :ok -> check_method_provenance_entry(entry)
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp check_method_provenance_entry(entry) when is_binary(entry) do
    cond do
      byte_size(entry) == 0 ->
        {:halt, empty_identifier_error("method_provenance")}

      byte_size(entry) > @max_identifier_bytes ->
        {:halt, limit_error("method_provenance", @max_identifier_bytes, byte_size(entry))}

      has_disallowed_control?(entry) ->
        {:halt, control_byte_error("method_provenance")}

      true ->
        {:cont, :ok}
    end
  end

  defp check_method_provenance_entry(_) do
    {:halt,
     {:error,
      Error.new(
        :precondition,
        :invalid_method_provenance_entry,
        "each method_provenance entry must be a non-empty string",
        %{}
      )}}
  end

  defp check_project_state(value) when is_map(value) do
    with {:ok, repository} <- map_field(value, "repository", :any, value),
         {:ok, base_commit} <- map_field(value, "base_commit", :any, value),
         {:ok, workspace_state_digest} <- map_field(value, "workspace_state_digest", :any, value) do
      cond do
        not is_binary(repository) or byte_size(repository) == 0 ->
          {:error, empty_identifier_error("project_state.repository")}

        byte_size(repository) > @max_identifier_bytes ->
          {:error,
           limit_error("project_state.repository", @max_identifier_bytes, byte_size(repository))}

        has_disallowed_control?(repository) ->
          {:error, control_byte_error("project_state.repository")}

        not is_binary(base_commit) or not valid_commit_sha?(base_commit) ->
          {:error,
           Error.new(
             :precondition,
             :invalid_base_commit,
             "project_state.base_commit must be a 40-character lowercase SHA",
             %{value: base_commit}
           )}

        not is_binary(workspace_state_digest) or byte_size(workspace_state_digest) == 0 ->
          {:error, empty_identifier_error("project_state.workspace_state_digest")}

        byte_size(workspace_state_digest) > @max_identifier_bytes ->
          {:error,
           limit_error(
             "project_state.workspace_state_digest",
             @max_identifier_bytes,
             byte_size(workspace_state_digest)
           )}

        true ->
          {:ok,
           %{
             repository: repository,
             base_commit: base_commit,
             workspace_state_digest: workspace_state_digest
           }}
      end
    end
  end

  defp check_project_state(_) do
    {:error, type_error("project_state", "map")}
  end

  defp valid_commit_sha?(value) when is_binary(value) do
    String.match?(value, ~r/^[0-9a-f]{40}$/)
  end

  defp check_scope(value) when is_map(value) do
    with {:ok, included} <- map_field(value, "included", :any, value),
         {:ok, excluded} <- map_field(value, "excluded", :any, value) do
      with {:ok, included} <- check_string_list("scope.included", included),
           {:ok, excluded} <- check_string_list("scope.excluded", excluded) do
        {:ok, %{included: included, excluded: excluded}}
      end
    end
  end

  defp check_scope(_) do
    {:error, type_error("scope", "map")}
  end

  defp check_constraints(value) when is_map(value) do
    with {:ok, must} <- map_field(value, "must", :any, value),
         {:ok, must_not} <- map_field(value, "must_not", :any, value) do
      with {:ok, must} <- check_string_list("constraints.must", must),
           {:ok, must_not} <- check_string_list("constraints.must_not", must_not) do
        {:ok, %{must: must, must_not: must_not}}
      end
    end
  end

  defp check_constraints(_) do
    {:error, type_error("constraints", "map")}
  end

  defp check_string_list(field, value) when is_list(value) do
    cond do
      length(value) > @max_list_items ->
        {:error, limit_error(field, @max_list_items, length(value))}

      not Enum.all?(value, &(is_binary(&1) and byte_size(&1) > 0)) ->
        {:error,
         Error.new(
           :precondition,
           :invalid_list_entry,
           "every entry must be a non-empty string",
           %{field: field}
         )}

      true ->
        {:ok, value}
    end
  end

  defp check_string_list(field, _) do
    {:error,
     Error.new(
       :precondition,
       :wrong_type,
       "field must be a list",
       %{field: field}
     )}
  end

  defp check_proof_obligations(value) when is_list(value) do
    cond do
      length(value) > @max_list_items ->
        {:error, limit_error("proof_obligations", @max_list_items, length(value))}

      true ->
        Enum.reduce_while(value, {:ok, []}, fn entry, acc ->
          case acc do
            {:ok, items} ->
              case check_proof_obligation_entry(entry) do
                {:ok, item} -> {:cont, {:ok, [item | items]}}
                {:error, _} = err -> {:halt, err}
              end

            {:error, _} = err ->
              {:halt, err}
          end
        end)
        |> case do
          {:ok, items} -> {:ok, Enum.reverse(items)}
          {:error, _} = err -> err
        end
    end
  end

  defp check_proof_obligations(_) do
    {:error, type_error("proof_obligations", "list")}
  end

  defp check_proof_obligation_entry(%{"id" => id, "kind" => kind, "requirement" => requirement})
       when is_binary(id) and is_binary(kind) and is_binary(requirement) do
    cond do
      byte_size(id) == 0 ->
        {:error, empty_identifier_error("proof_obligations.id")}

      byte_size(id) > @max_identifier_bytes ->
        {:error, limit_error("proof_obligations.id", @max_identifier_bytes, byte_size(id))}

      byte_size(kind) == 0 ->
        {:error, empty_identifier_error("proof_obligations.kind")}

      byte_size(requirement) == 0 ->
        {:error, empty_identifier_error("proof_obligations.requirement")}

      byte_size(requirement) > @max_text_bytes ->
        {:error,
         limit_error("proof_obligations.requirement", @max_text_bytes, byte_size(requirement))}

      true ->
        {:ok, %{id: id, kind: kind, requirement: requirement}}
    end
  end

  defp check_proof_obligation_entry(_) do
    {:error,
     Error.new(
       :precondition,
       :invalid_proof_obligation,
       "each proof_obligation must have id, kind, and requirement",
       %{}
     )}
  end

  defp check_authority_requests(value) when is_list(value) do
    cond do
      length(value) > @max_list_items ->
        {:error, limit_error("authority_requests", @max_list_items, length(value))}

      true ->
        Enum.reduce_while(value, {:ok, []}, fn entry, acc ->
          case acc do
            {:ok, items} ->
              case check_authority_request_entry(entry) do
                {:ok, item} -> {:cont, {:ok, [item | items]}}
                {:error, _} = err -> {:halt, err}
              end

            {:error, _} = err ->
              {:halt, err}
          end
        end)
        |> case do
          {:ok, items} -> {:ok, Enum.reverse(items)}
          {:error, _} = err -> err
        end
    end
  end

  defp check_authority_requests(_) do
    {:error, type_error("authority_requests", "list")}
  end

  defp check_authority_request_entry(%{"capability" => capability, "scope" => scope})
       when is_binary(capability) and is_binary(scope) do
    cond do
      byte_size(capability) == 0 ->
        {:error, empty_identifier_error("authority_requests.capability")}

      byte_size(capability) > @max_identifier_bytes ->
        {:error,
         limit_error(
           "authority_requests.capability",
           @max_identifier_bytes,
           byte_size(capability)
         )}

      byte_size(scope) == 0 ->
        {:error, empty_identifier_error("authority_requests.scope")}

      byte_size(scope) > @max_identifier_bytes ->
        {:error, limit_error("authority_requests.scope", @max_identifier_bytes, byte_size(scope))}

      true ->
        {:ok, %{capability: capability, scope: scope}}
    end
  end

  defp check_authority_request_entry(_) do
    {:error,
     Error.new(
       :precondition,
       :invalid_authority_request,
       "each authority_request must have capability and scope",
       %{}
     )}
  end

  defp check_context_refs(value) when is_list(value) do
    cond do
      length(value) > @max_list_items ->
        {:error, limit_error("context_refs", @max_list_items, length(value))}

      not Enum.all?(value, &(is_binary(&1) and byte_size(&1) > 0)) ->
        {:error,
         Error.new(
           :precondition,
           :invalid_context_ref,
           "every context_ref must be a non-empty string",
           %{}
         )}

      true ->
        {:ok, value}
    end
  end

  defp check_context_refs(_) do
    {:error, type_error("context_refs", "list")}
  end

  defp map_field(map, key, _expected, _parent) do
    case Map.fetch(map, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, missing_field_error(key)}
    end
  end

  defp missing_field_error(field) do
    Error.new(
      :precondition,
      :missing_field,
      "work envelope field is required",
      %{field: field}
    )
  end

  defp empty_identifier_error(field) do
    Error.new(
      :precondition,
      :empty_text,
      "field must be a non-empty binary",
      %{field: field}
    )
  end

  defp limit_error(field, max, actual) do
    Error.new(
      :precondition,
      :limit_exceeded,
      "field exceeds the accepted byte bound",
      %{field: field, max: max, actual: actual}
    )
  end

  defp control_byte_error(field) do
    Error.new(
      :precondition,
      :disallowed_control_byte,
      "field contains a NUL or disallowed control byte",
      %{field: field}
    )
  end

  defp type_error(field, expected) do
    Error.new(
      :precondition,
      :wrong_type,
      "field has the wrong type",
      %{field: field, expected: expected}
    )
  end

  defp has_disallowed_control?(value) when is_binary(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.any?(&disallowed_control?/1)
  end

  defp disallowed_control?(byte) when byte < 0x20, do: true
  defp disallowed_control?(0x7F), do: true
  defp disallowed_control?(_), do: false

  # The accepted maximum canonical request size is the same bound the
  # Evidence and Artifact record requests use (65,536 bytes); the Work
  # Envelope intake never accepts larger canonical requests. Tests and
  # supervisors may consult this constant to size their request fixtures.
  @doc "Maximum accepted canonical Work Envelope request bytes."
  @spec max_request_bytes() :: pos_integer()
  def max_request_bytes, do: @max_request_bytes
end
