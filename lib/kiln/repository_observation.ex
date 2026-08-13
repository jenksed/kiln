defmodule Kiln.RepositoryObservation do
  @moduledoc """
  Read-only repository state observation for the Wave 3 wedge.

  `Kiln.RepositoryObservation` observes the target repository the Work
  Envelope names and produces a Kiln-owned state digest plus the
  producer's `input_state` reference. It performs **no mutation**: no
  write to the repository, no commit, no push, no checkout, no branch
  creation, and no filesystem change outside the observed path. It is
  the read-only observation step that runs *before* any authority
  decision is bound to the Work Envelope.

  ## Observed facts

    * `current_commit` — the resolved HEAD commit SHA where knowable.
    * `repository_state_digest` — a deterministic Kiln-owned SHA-256
      digest over the observed fileset manifest. The algorithm is
      deterministic and bound to the Kiln binary; it is **not** claimed
      to be identical to the producer's `workspace_state_digest`.
    * `observed_at` — an RFC 3339 timestamp recorded at observation time.
    * `head_resolved` — `true` when `current_commit` could be resolved
      from the repository root; `false` when the repository was absent
      or unreadable.

  The supervisor retains both the producer's `input_state` (passed
  through unchanged from the Work Envelope) and Kiln's independently
  observed `repository_state_digest`. It compares only the facts whose
  equivalence the contracts actually define (the base_commit SHA) and
  preserves uncertainty everywhere else. The supervisor never
  substitutes one digest for the other.
  """

  alias Kiln.Store.Error

  @schema "kiln.repository_observation/v1"

  @type outcome :: {:ok, t()} | {:error, Error.t()}
  @type repository_state :: %{repository: String.t(), files: [file_entry()]}
  @type file_entry :: %{
          path: String.t(),
          mode: String.t(),
          size: non_neg_integer(),
          digest: String.t()
        }

  @enforce_keys [
    :repository,
    :current_commit,
    :repository_state_digest,
    :input_state_digest,
    :observed_at,
    :head_resolved
  ]

  defstruct [
    :repository,
    :current_commit,
    :repository_state_digest,
    :input_state_digest,
    :observed_at,
    :head_resolved
  ]

  @type t :: %__MODULE__{
          repository: String.t(),
          current_commit: String.t() | nil,
          repository_state_digest: String.t(),
          input_state_digest: String.t(),
          observed_at: String.t(),
          head_resolved: boolean()
        }

  @doc "The accepted repository-observation schema identifier."
  @spec schema() :: String.t()
  def schema, do: @schema

  @doc """
  Observe the target repository under `repository_root`.

  `repository_root` is the path the Work Envelope `project_state.repository`
  names. `input_state_digest` is the producer's
  `workspace_state_digest`, retained untouched so the supervisor can
  preserve uncertainty between the two algorithms.

  The function performs no write. It opens the repository in
  `--shared` read-only mode via `git` when available, computes a
  Kiln-owned digest over the file manifest, and records the result.
  A missing repository or absent HEAD returns an observation with
  `head_resolved: false` and `current_commit: nil`; the digest still
  reflects the absent-tree manifest so the supervisor can preserve
  the absence.
  """
  @spec observe(String.t(), String.t(), keyword()) :: outcome()
  def observe(repository_root, input_state_digest, opts \\ [])
      when is_binary(repository_root) and is_binary(input_state_digest) do
    now = Keyword.get(opts, :now, default_now())
    git = Keyword.get(opts, :git, "git")

    cond do
      not File.regular?(git) and not executable?(git) ->
        {:error,
         Error.new(
           :precondition,
           :git_unavailable,
           "git executable was not found on the path",
           %{path: git}
         )}

      true ->
        manifest = build_manifest(repository_root)
        current_commit = resolve_head(repository_root, git)
        digest = digest_manifest(repository_root, manifest)

        observation = %__MODULE__{
          repository: repository_root,
          current_commit: current_commit,
          repository_state_digest: digest,
          input_state_digest: input_state_digest,
          observed_at: now,
          head_resolved: current_commit != nil
        }

        {:ok, observation}
    end
  end

  @doc """
  The canonical request digest bound to the observation schema.

  Two observations with identical facts produce the same digest; the
  digest is bound to the `kiln.repository_observation/v1` schema so
  future schema migrations do not silently collide.
  """
  @spec request_digest(t()) :: String.t()
  def request_digest(%__MODULE__{} = observation) do
    payload = %{
      "schema" => @schema,
      "repository" => observation.repository,
      "current_commit" => observation.current_commit,
      "repository_state_digest" => observation.repository_state_digest,
      "input_state_digest" => observation.input_state_digest,
      "observed_at" => observation.observed_at,
      "head_resolved" => observation.head_resolved
    }

    :sha256
    |> :crypto.hash([@schema, "\n", Kiln.Store.Canonical.encode(payload)])
    |> Base.encode16(case: :lower)
    |> (fn hex -> "sha256:" <> hex end).()
  end

  # -- helpers --

  defp executable?(path) when is_binary(path) do
    case resolve_executable(path) do
      {:ok, resolved} ->
        case File.stat(resolved) do
          {:ok, %File.Stat{mode: mode}} -> Bitwise.band(mode, 0o111) != 0
          _ -> false
        end

      :error ->
        false
    end
  end

  defp executable?(_), do: false

  defp resolve_executable(path) do
    cond do
      String.contains?(path, "/") ->
        {:ok, path}

      true ->
        case System.find_executable(path) do
          nil -> :error
          resolved -> {:ok, resolved}
        end
    end
  end

  defp build_manifest(root) do
    cond do
      not File.exists?(root) ->
        []

      true ->
        Path.wildcard(Path.join([root, "**"]))
        |> Enum.filter(&File.regular?/1)
        |> Enum.map(fn path ->
          rel = Path.relative_to(path, root)
          bytes = File.read!(path)
          digest = :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

          %{
            path: rel,
            mode: mode_string(path),
            size: byte_size(bytes),
            digest: "sha256:" <> digest
          }
        end)
        |> Enum.sort_by(& &1.path)
    end
  end

  defp mode_string(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mode: mode}} -> Integer.to_string(mode, 8)
      _ -> "0"
    end
  end

  defp resolve_head(root, git) do
    case System.cmd(git, ["-C", root, "rev-parse", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} ->
        trimmed = String.trim(sha)

        if String.match?(trimmed, ~r/^[0-9a-f]{40}$/), do: trimmed, else: nil

      _ ->
        nil
    end
  catch
    _kind, _reason -> nil
  end

  defp digest_manifest(root, manifest) do
    payload = %{
      "schema" => @schema,
      "repository" => root,
      "files" => manifest
    }

    :sha256
    |> :crypto.hash(Kiln.Store.Canonical.encode(payload))
    |> Base.encode16(case: :lower)
    |> (fn hex -> "sha256:" <> hex end).()
  end

  defp default_now do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
end
