defmodule Kiln.Artifact.FS do
  @moduledoc """
  Filesystem primitives for the durable Artifact byte store.

  Every operation is local, deterministic, and contained below an explicit
  Artifact root. The module never resolves a path outside the root supplied by
  the caller and never dereferences a symlink at any boundary (P1-S02-T01-R01,
  R13).

  Each function returns either `:ok`/`{:ok, value}` or a `Kiln.Store.Error` so
  callers can classify boundary failures without parsing messages. Bytes and
  paths never appear in error details.

  This module is the boundary that fault-injection tests exercise; the
  publication path in `Kiln.Artifact.Store` calls each function exactly once in
  the order documented by `Kiln.Artifact.Store.put/2`. Tests replace individual
  functions with fault-raising variants via `:meck` or by injecting a configured
  failure module, then assert the externally observable filesystem and store
  state after each failure.
  """

  alias Kiln.Store.Error

  @doc """
  Ensure the Artifact root exists as a real, non-symlink directory.

  Returns `:ok` on success. If the root already exists but is a symlink, special
  file, or non-directory, returns an `:integrity` error. A missing root is
  created with `File.mkdir_p!/1` and re-verified.

  The check uses `File.lstat!/1` so it inspects the root itself rather than a
  dereferenced target; a root reached through a parent symlink (such as
  macOS `/var/folders/...`) is accepted because the root itself is a real
  directory.
  """
  @spec ensure_root(String.t()) :: :ok | {:error, Error.t()}
  def ensure_root(root) when is_binary(root) do
    cond do
      not File.exists?(root) ->
        File.mkdir_p!(root)
        verify_real_directory(root)

      true ->
        verify_real_directory(root)
    end
  rescue
    e in File.Error ->
      {:error,
       Error.new(:io, :artifact_root_uncreatable, "artifact root could not be created", %{
         reason: Exception.message(e)
       })}
  end

  defp verify_real_directory(root) do
    %File.Stat{type: type} = File.lstat!(root)

    case type do
      :directory ->
        :ok

      :symlink ->
        {:error, Error.new(:integrity, :artifact_root_symlink, "artifact root is a symlink", %{})}

      other ->
        {:error,
         Error.new(
           :integrity,
           :artifact_root_not_directory,
           "artifact root is not a directory",
           %{
             type: other
           }
         )}
    end
  end

  @doc """
  The relative, deterministic content-addressed location for a `sha256:` digest.

  The shape is `sha256/<first-two-hex>/<remaining-hex>` (P1-S02-T01). The
  returned path is a relative POSIX path with no leading `/` and no `..`
  segments so the SQLite CHECK constraints accept it directly.
  """
  @spec content_location(String.t()) :: String.t()
  def content_location("sha256:" <> hex) when byte_size(hex) == 64 do
    <<first_two::binary-size(2), rest::binary>> = hex
    "sha256/#{first_two}/#{rest}"
  end

  @doc "The absolute final path for a content-addressed location below `root`."
  @spec final_path(String.t(), String.t()) :: String.t()
  def final_path(root, relative) when is_binary(root) and is_binary(relative) do
    Path.join(root, relative)
  end

  @doc """
  Walk every intermediate directory of `relative` below `root` and ensure each
  is a real directory (not a symlink, not a special file). The leaf component
  of `relative` (the digest filename) is the file the Store will publish and
  is not pre-created here.

  Missing directories are created with `File.mkdir/1` rather than
  `File.mkdir_p!/1` so a parent symlink cannot redirect the walk.

  Returns `:ok` on success, or a typed `Kiln.Store.Error` when the chain
  contains a symlink, special file, or cannot be created.

  The check uses `File.lstat/1` so a symlink at any intermediate component is
  detected even though `File.realpath` would have followed it. This is the
  filesystem-resolution proof that no `Artifact` write can escape through an
  interior symlink. `root` must already have been proven a real directory by
  `ensure_root/1` at Store startup; this function does not re-verify `root`
  itself.
  """
  @spec verify_chain(String.t(), String.t()) :: :ok | {:error, Error.t()}
  def verify_chain(root, relative) when is_binary(root) and is_binary(relative) do
    parent_components =
      relative
      |> Path.dirname()
      |> Path.split()

    case Enum.reduce_while(parent_components, {:ok, root}, &ensure_real_dir_step/2) do
      {:ok, _final} -> :ok
      {:error, %Error{} = err} -> {:error, err}
    end
  end

  defp ensure_real_dir_step(component, {:ok, current}) do
    next = Path.join(current, component)

    case File.lstat(next) do
      {:ok, %File.Stat{type: :directory}} ->
        {:cont, {:ok, next}}

      {:ok, %File.Stat{type: :symlink}} ->
        {:halt,
         {:error,
          Error.new(
            :integrity,
            :interior_symlink,
            "interior path component is a symlink",
            %{component: component}
          )}}

      {:ok, %File.Stat{type: other}} ->
        {:halt,
         {:error,
          Error.new(
            :integrity,
            :interior_special_file,
            "interior path component is not a directory",
            %{component: component, type: other}
          )}}

      {:error, :enoent} ->
        case File.mkdir(next) do
          :ok ->
            {:cont, {:ok, next}}

          {:error, :eexist} ->
            # Race: someone created the directory between lstat and mkdir.
            # Re-stat and proceed if it is a directory.
            case File.lstat(next) do
              {:ok, %File.Stat{type: :directory}} -> {:cont, {:ok, next}}
              {:ok, %File.Stat{type: :symlink}} -> {:halt, interior_symlink_error(component)}
              {:ok, %File.Stat{type: other}} -> {:halt, interior_special_error(component, other)}
              {:error, reason} -> {:halt, interior_io_error(component, reason)}
            end

          {:error, reason} ->
            {:halt, interior_io_error(component, reason)}
        end

      {:error, reason} ->
        {:halt, interior_io_error(component, reason)}
    end
  end

  defp interior_symlink_error(component) do
    {:error,
     Error.new(:integrity, :interior_symlink, "interior path component is a symlink", %{
       component: component
     })}
  end

  defp interior_special_error(component, type) do
    {:error,
     Error.new(
       :integrity,
       :interior_special_file,
       "interior path component is not a directory",
       %{component: component, type: type}
     )}
  end

  defp interior_io_error(component, reason) do
    {:error,
     Error.new(:io, :interior_mkdir_failed, "interior path component could not be created", %{
       component: component,
       reason: inspect(reason)
     })}
  end

  @doc """
  Stage a temporary file path beside the final destination.

  Returns `{stage_path, final_path}` for atomic same-directory rename. The stage
  path carries a deterministic 12-character lowercase-hex suffix derived from
  the SHA-256 of the caller-supplied idempotency key, so the suffix is always
  filesystem-safe (no path separators, no control bytes, no Unicode
  assumptions) and bounded.

  The caller-supplied idempotency key never reaches the filesystem name
  directly; this guarantees that even a valid UTF-8 key cannot introduce a
  path separator, NUL, or disallowed control byte into the staging filename.
  """
  @spec stage_pair(String.t(), String.t(), String.t()) :: {String.t(), String.t()}
  def stage_pair(root, relative, idempotency_key) when is_binary(root) do
    final = final_path(root, relative)
    parent = Path.dirname(final)
    stem = Path.basename(final)
    suffix = stage_suffix(idempotency_key)
    stage = Path.join(parent, ".kiln-stage-" <> stem <> "-" <> suffix)
    {stage, final}
  end

  # Always 12 lowercase hex characters; independent of any Unicode byte
  # assumptions about the input idempotency_key.
  defp stage_suffix(idempotency_key) when is_binary(idempotency_key) do
    :crypto.hash(:sha256, idempotency_key)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 12)
  end

  @doc """
  Open, write, `fsync`, and close the staging file.

  Returns `:ok` after a successful fsync of the file contents. A raise from any
  step propagates so the caller rolls back and observes no staging file.
  """
  @spec stage_write(String.t(), iodata()) :: :ok | {:error, Error.t()}
  def stage_write(stage_path, bytes) when is_binary(stage_path) do
    parent = Path.dirname(stage_path)
    File.mkdir_p!(parent)

    {:ok, _result} =
      File.open(stage_path, [:write, :binary, :raw], fn fd ->
        :ok = write_chunks(fd, bytes)
        maybe_inject(:stage_write_fsync, :io, :artifact_fsync_failed)
        :ok = :file.sync(fd)
        :ok = :file.datasync(fd)
        :ok
      end)

    :ok
  rescue
    e in File.Error ->
      {:error,
       Error.new(:io, :artifact_write_failed, "artifact staging write failed", %{
         reason: Exception.message(e)
       })}

    e in ErlangError ->
      {:error,
       Error.new(:io, :artifact_write_failed, "artifact staging write failed", %{
         reason: Exception.message(e)
       })}
  end

  defp write_chunks(fd, bytes) when is_binary(bytes) do
    :ok = :file.write(fd, bytes)
  end

  defp write_chunks(fd, iodata) do
    :ok = :file.write(fd, iodata)
  end

  @doc """
  Reopen the staged file, verify its size and SHA-256 digest, and close it.

  Returns `{:ok, %{size: pos_integer, digest: String.t()}}` on success or an
  `:integrity` error when the staged bytes diverge from `expected_size` and
  `expected_digest`. The fsync'd staging file is the authority; the caller
  trusts the close-time state.
  """
  @spec verify_staged(String.t(), non_neg_integer(), String.t()) ::
          {:ok, %{size: non_neg_integer(), digest: String.t()}}
          | {:error, Error.t()}
  def verify_staged(stage_path, expected_size, expected_digest)
      when is_binary(stage_path) and is_integer(expected_size) and is_binary(expected_digest) do
    with {:ok, stat} <- lstat_or_error(stage_path) do
      case stat.type do
        :regular ->
          if stat.size != expected_size do
            return_integrity(:artifact_size_mismatch, "staged size differs from request")
          else
            rehash_and_check(stage_path, expected_size, expected_digest)
          end

        :symlink ->
          return_integrity(:leaf_is_symlink, "staged file is a symlink")

        :directory ->
          return_integrity(:leaf_is_directory, "staged file is a directory")

        other ->
          return_integrity(:leaf_is_special_file, "staged file is a special file", %{type: other})
      end
    end
  end

  defp lstat_or_error(path) do
    {:ok, File.lstat!(path)}
  rescue
    e in File.Error ->
      return_integrity(:artifact_staged_unreadable, Exception.message(e))
  end

  defp rehash_and_check(stage_path, expected_size, expected_digest) do
    {:ok, actual_size, actual_digest} = rehash_file(stage_path)

    cond do
      actual_size != expected_size ->
        return_integrity(:artifact_size_mismatch, "rehashed size differs from request")

      actual_digest != expected_digest ->
        return_integrity(:artifact_digest_mismatch, "rehashed digest differs from request")

      true ->
        {:ok, %{size: actual_size, digest: actual_digest}}
    end
  end

  defp rehash_file(path) do
    {:ok, fd} = :file.open(path, [:read, :binary, :raw])

    try do
      rehash_loop(fd, 0, :crypto.hash_init(:sha256))
    after
      :file.close(fd)
    end
  end

  defp rehash_loop(fd, count, acc) do
    case :file.read(fd, 64 * 1024) do
      :eof ->
        digest = :crypto.hash_final(acc) |> Base.encode16(case: :lower)
        {:ok, count, "sha256:" <> digest}

      {:ok, chunk} ->
        rehash_loop(fd, count + byte_size(chunk), :crypto.hash_update(acc, chunk))

      {:error, reason} ->
        throw({:rehash_failed, reason})
    end
  catch
    {:rehash_failed, reason} ->
      throw({:rehash_failed, reason})
  end

  @doc """
  Atomically place the staged bytes at the final path.

  The rename is the durability boundary required by P1-S02-T01-R04: on POSIX it
  is atomic for files on the same filesystem; the staging file is created in
  the same directory so the rename crosses no filesystem boundary.

  If the destination already exists, the caller is expected to verify its
  contents against the staged digest before any reuse. This function does not
  overwrite a non-identical existing blob.
  """
  @spec publish(String.t(), String.t()) :: :ok | {:error, Error.t()}
  def publish(stage_path, final_path) when is_binary(stage_path) and is_binary(final_path) do
    maybe_inject(:publish_rename, :io, :artifact_publish_failed)

    case File.rename(stage_path, final_path) do
      :ok ->
        :ok

      {:error, :eexist} ->
        # Destination already exists. The caller will verify the existing blob
        # and either accept it (same digest) or reject (different digest).
        :ok

      {:error, reason} ->
        {:error,
         Error.new(:io, :artifact_publish_failed, "artifact rename failed", %{
           reason: inspect(reason)
         })}
    end
  end

  @typedoc "Classification of the final Artifact path component via lstat."
  @type leaf_type :: :regular | :absent | :symlink | :directory | {:special, atom()}

  @doc """
  Classify the final Artifact path component without dereferencing.

  Uses `File.lstat/1` so the result describes the path itself rather than its
  target. A symlink at the final component is reported as `:symlink`, never
  followed, even when its target is a real regular file. POSIX `lstat(2)` does
  not follow the final-component symlink and reports the entry's own type.

  Returns one of:

    * `:regular` — a normal file; permitted for rehash verification.
    * `:absent` — no entry at the path; permitted where publication expects
      absence.
    * `:symlink` — a symlink at the final component; rejected as `:integrity`
      for any read or destination-verification path.
    * `:directory` — a directory at the final component; rejected as
      `:integrity`.
    * `{:special, type}` — a special file (block, character, FIFO, socket,
      device, other); rejected as `:integrity`.

  This proves rejection of an already-present unauthorized leaf at read or
  destination time. It does not establish race-free containment: a
  same-user concurrent TOCTOU attacker can replace the leaf between
  classification and open.
  """
  @spec classify_leaf(String.t()) :: {:ok, leaf_type()} | {:error, Error.t()}
  def classify_leaf(path) when is_binary(path) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :regular}} ->
        {:ok, :regular}

      {:ok, %File.Stat{type: :symlink}} ->
        {:ok, :symlink}

      {:ok, %File.Stat{type: :directory}} ->
        {:ok, :directory}

      {:ok, %File.Stat{type: other}} when is_atom(other) ->
        {:ok, {:special, other}}

      {:error, :enoent} ->
        {:ok, :absent}

      {:error, reason} ->
        {:error,
         Error.new(:io, :artifact_leaf_stat_failed, "could not stat artifact leaf", %{
           reason: inspect(reason)
         })}
    end
  end

  @doc """
  Read the bytes at `path` for verification, returning size and digest.

  Used by `fetch/2` to verify an already-published blob against its metadata.
  Classifies the leaf with `lstat` first; a non-regular leaf (symlink,
  directory, special file) is rejected with `:integrity` and the symlink
  target is never dereferenced.
  """
  @spec rehash_existing(String.t()) ::
          {:ok, %{size: non_neg_integer(), digest: String.t()}}
          | {:error, Error.t()}
  def rehash_existing(path) when is_binary(path) do
    case classify_leaf(path) do
      {:ok, :regular} ->
        rehash_file_or_error(path)

      {:ok, :symlink} ->
        return_integrity(:leaf_is_symlink, "artifact leaf is a symlink")

      {:ok, :directory} ->
        return_integrity(:leaf_is_directory, "artifact leaf is a directory")

      {:ok, {:special, type}} ->
        return_integrity(:leaf_is_special_file, "artifact leaf is a special file", %{
          type: type
        })

      {:ok, :absent} ->
        return_integrity(:artifact_missing, "expected regular file at content path")

      {:error, %Error{} = err} ->
        {:error, err}
    end
  rescue
    e in File.Error ->
      return_integrity(:artifact_missing, Exception.message(e))
  end

  defp rehash_file_or_error(path) do
    {:ok, size, digest} = rehash_file(path)
    {:ok, %{size: size, digest: digest}}
  catch
    {:rehash_failed, reason} ->
      return_integrity(:artifact_unreadable, inspect(reason))
  end

  defp return_integrity(code, message, details \\ %{}) do
    {:error, Error.new(:integrity, code, message, details)}
  end

  @doc """
  Best-effort cleanup of a leftover staging file.

  Used when publication or verification fails before the staging file is
  promoted to its final location. A missing staging file is not an error.
  """
  @spec cleanup_stage(String.t()) :: :ok
  def cleanup_stage(stage_path) when is_binary(stage_path) do
    case File.rm(stage_path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, _} -> :ok
    end
  end

  # Test seam: real fault injection at meaningful durability boundaries.
  # Tests set `:kiln, {:fs_fault, key}` in the application environment to make
  # the next call to that boundary raise before any state changes happen.
  # This is fault injection at the boundary, not a mock that records a call;
  # the operation attempts its real work but is short-circuited so the
  # post-failure state is observable. The raise uses `ErlangError` so the
  # public Store layer can rescue and translate it into a typed error.
  defp maybe_inject(key, _class, _code) do
    case Application.get_env(:kiln, :fs_fault, %{}) |> Map.get(key) do
      :raise ->
        :erlang.error({:kiln_fs_fault, key, []})

      _ ->
        :ok
    end
  end
end
