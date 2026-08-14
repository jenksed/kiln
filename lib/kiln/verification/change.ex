defmodule Kiln.Verification.Change do
  @moduledoc "Validation boundary for `loadout/verification-change/v0`."

  alias Kiln.Verification.Registry

  @schema "loadout/verification-change/v0"
  @method "verify-change/proof-obligation"
  # Trust transition authorized by the project owner:
  #   old: sha256:ec329afbb1e6337b8af2edd2a9614a1a034c91e1f3946d757ba1f9970dde5b84 (Wave 6 verify-change/proof-obligation@1.0.0)
  #   new: sha256:13a137f778a479f01d1b90ab9640dceed893a824a06fc386f4df925164a4c0e9 (Wave 6R combined, 10 general heuristics)
  #   evidence: Arsenal evaluation on 22 dev trials shows false_READY=0; Loadout port: 159/159 tests pass
  #   authorization: Owner decision recorded in engineering-system/program/wave-6/FINAL-VERDICT.md
  @implementation_digest "sha256:13a137f778a479f01d1b90ab9640dceed893a824a06fc386f4df925164a4c0e9"

  @spec validate(map(), Kiln.WorkEnvelope.t()) :: {:ok, map()} | {:error, term()}
  def validate(attrs, envelope) when is_map(attrs) do
    change = attrs["change"] || %{}
    method = attrs["method"] || %{}
    selected = attrs["selected_verification"]
    obligations = attrs["proof_obligations"]
    digest = digest(attrs)

    with true <- attrs["schema"] == @schema,
         true <- method["id"] == @method,
         true <- method["implementation_digest"] == @implementation_digest,
         true <- change["repository"] == envelope.project_state.repository,
         true <- get_in(change, ["current_state", "commit"]) == envelope.project_state.base_commit,
         true <-
           get_in(change, ["current_state", "workspace_state_digest"]) ==
             envelope.project_state.workspace_state_digest,
         true <- valid_digest?(change["patch_digest"]),
         true <- is_list(obligations) and obligations != [],
         true <- is_list(selected) and selected != [],
         true <- context_bound?(envelope.context_refs, digest),
         true <- obligations_bound?(obligations, envelope.proof_obligations),
         {:ok, commands} <-
           validate_commands(selected, change["repository"], envelope.project_state.base_commit),
         true <- command_authority_bound?(commands, envelope.authority_requests),
         true <- command_proofs_bound?(commands, obligations) do
      {:ok,
       %{
         attrs: attrs,
         digest: digest,
         repository: change["repository"],
         patch_digest: change["patch_digest"],
         obligations: obligations,
         commands: commands,
         unknowns: Enum.map(attrs["unknowns"] || [], &to_string/1)
       }}
    else
      {:error, _} = error -> error
      false -> {:error, :verification_change_binding_mismatch}
      _ -> {:error, :invalid_verification_change}
    end
  end

  def validate(_attrs, _envelope), do: {:error, :invalid_verification_change}

  def digest(attrs) do
    "sha256:" <>
      (:crypto.hash(:sha256, Kiln.Store.Canonical.encode(attrs))
       |> Base.encode16(case: :lower))
  end

  defp context_bound?(refs, digest),
    do: refs == [@schema <> ":" <> digest]

  defp obligations_bound?(obligations, envelope_obligations) do
    from_change = Enum.map(obligations, &Map.take(&1, ["id", "kind", "requirement"]))

    from_envelope =
      Enum.map(envelope_obligations, fn item ->
        %{"id" => item.id, "kind" => item.kind, "requirement" => item.requirement}
      end)

    from_change == from_envelope and unique_non_empty_ids?(from_change)
  end

  defp validate_commands(selected, repository, base_commit) do
    Enum.reduce_while(selected, {:ok, []}, fn command, {:ok, acc} ->
      case Registry.validate(command, repository, base_commit) do
        {:ok, validated} -> {:cont, {:ok, acc ++ [validated]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp command_authority_bound?(commands, authority_requests) do
    expected =
      ["git.read" | Enum.map(commands, &("verification.run:" <> &1.id))]
      |> Enum.sort()

    actual =
      authority_requests
      |> Enum.map(&(&1["capability"] || &1[:capability]))
      |> Enum.sort()

    expected == actual
  end

  defp command_proofs_bound?(commands, obligations) do
    obligation_ids = MapSet.new(obligations, & &1["id"])

    Enum.all?(commands, fn command ->
      Enum.all?(command.proves, &MapSet.member?(obligation_ids, &1))
    end) and
      Enum.all?(obligations, fn obligation ->
        required = obligation["required_commands"] || []

        Enum.all?(required, fn command_id ->
          Enum.any?(commands, &(&1.id == command_id and obligation["id"] in &1.proves))
        end)
      end)
  end

  defp unique_non_empty_ids?(items) do
    ids = Enum.map(items, & &1["id"])
    Enum.all?(ids, &(is_binary(&1) and &1 != "")) and length(ids) == length(Enum.uniq(ids))
  end

  defp valid_digest?("sha256:" <> hex), do: String.match?(hex, ~r/^[0-9a-f]{64}$/)
  defp valid_digest?(_), do: false
end
