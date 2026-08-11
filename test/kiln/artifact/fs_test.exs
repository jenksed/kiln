defmodule Kiln.Artifact.FSTest do
  use ExUnit.Case, async: true

  alias Kiln.Artifact.FS

  setup do
    base = Path.join(System.tmp_dir!(), "kiln-art-fs-#{System.unique_integer([:positive])}")
    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)
    {:ok, base: base}
  end

  describe "ensure_root/1" do
    test "creates the directory if missing and accepts a real directory", %{base: base} do
      target = Path.join(base, "artifacts")
      assert :ok = FS.ensure_root(target)
      assert File.dir?(target)
    end

    test "rejects a path whose final component is a regular file", %{base: base} do
      blocker = Path.join(base, "blocker")
      File.write!(blocker, "")

      assert {:error, %{class: :integrity, code: :artifact_root_not_directory}} =
               FS.ensure_root(blocker)
    end

    test "rejects an Artifact root that is itself a symlink", %{base: base} do
      real = Path.join(base, "real")
      File.mkdir_p!(real)
      symlinked = Path.join(base, "symlinked")
      File.ln_s!(real, symlinked)

      assert {:error, %{class: :integrity, code: :artifact_root_symlink}} =
               FS.ensure_root(symlinked)
    end
  end

  describe "content_location/1 and final_path/2" do
    test "deterministically splits the digest into first-two + remaining" do
      digest = "sha256:ab" <> String.duplicate("c", 62)
      assert FS.content_location(digest) == "sha256/ab/" <> String.duplicate("c", 62)
    end

    test "combines root and relative location to an absolute final path" do
      assert FS.final_path("/tmp/k", "sha256/ab/cd") == "/tmp/k/sha256/ab/cd"
    end

    test "stage_pair places the staging file in the same directory as the final" do
      {stage, final} = FS.stage_pair("/tmp/k", "sha256/ab/cd", "idem_x")

      assert Path.dirname(stage) == Path.dirname(final)
      assert Path.basename(stage) =~ "cd-"
      assert Path.basename(stage) =~ ".kiln-stage-"
    end
  end

  describe "stage_write/2 and verify_staged/3" do
    test "writes bytes, fsyncs, and verifies size and digest on reopen", %{base: base} do
      stage = Path.join(base, "stage")
      bytes = "kiln artifact bytes"

      :ok = FS.stage_write(stage, bytes)

      digest = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

      assert {:ok, %{size: 19, digest: "sha256:" <> _}} =
               FS.verify_staged(stage, byte_size(bytes), "sha256:" <> digest)
    end

    test "rejects a staged file whose size differs from `expected_size`", %{base: base} do
      stage = Path.join(base, "stage")
      File.write!(stage, "abcd")

      assert {:error, %{class: :integrity, code: :artifact_size_mismatch}} =
               FS.verify_staged(stage, 99, "sha256:" <> String.duplicate("a", 64))
    end

    test "rejects a staged file whose digest differs from `expected_digest`", %{base: base} do
      stage = Path.join(base, "stage")
      File.write!(stage, "abcd")

      assert {:error, %{class: :integrity, code: :artifact_digest_mismatch}} =
               FS.verify_staged(stage, 4, "sha256:" <> String.duplicate("z", 64))
    end

    test "returns integrity when the staging file is missing", %{base: base} do
      stage = Path.join(base, "missing")

      assert {:error, %{class: :integrity}} =
               FS.verify_staged(stage, 0, "sha256:" <> String.duplicate("a", 64))
    end
  end

  describe "publish/2" do
    test "atomically places the staged bytes at the final path", %{base: base} do
      stage = Path.join(base, "stage")
      final = Path.join(base, "final")
      File.write!(stage, "kiln")

      assert :ok = FS.publish(stage, final)
      refute File.exists?(stage)
      assert File.read!(final) == "kiln"
    end

    test "treats an existing destination with identical bytes as success", %{base: base} do
      stage = Path.join(base, "stage")
      final = Path.join(base, "final")
      File.write!(stage, "kiln")
      File.write!(final, "kiln")

      assert :ok = FS.publish(stage, final)
    end
  end

  describe "rehash_existing/1" do
    test "reports size and digest for a real regular file", %{base: base} do
      path = Path.join(base, "blob")
      File.write!(path, "kiln")

      assert {:ok, %{size: 4, digest: "sha256:" <> _}} = FS.rehash_existing(path)
    end

    test "reports integrity when the file is missing", %{base: base} do
      path = Path.join(base, "missing")
      assert {:error, %{class: :integrity, code: :artifact_missing}} = FS.rehash_existing(path)
    end

    test "reports integrity when the path is a directory", %{base: base} do
      assert {:error, %{class: :integrity, code: :leaf_is_directory}} = FS.rehash_existing(base)
    end
  end

  describe "cleanup_stage/1" do
    test "removes a leftover staging file", %{base: base} do
      stage = Path.join(base, "stage")
      File.write!(stage, "leftover")

      assert :ok = FS.cleanup_stage(stage)
      refute File.exists?(stage)
    end

    test "is idempotent when the staging file is already gone" do
      assert :ok = FS.cleanup_stage("/nonexistent/kiln-stage-xxx")
    end
  end
end
