defmodule Kiln.ArtifactTest do
  use ExUnit.Case, async: true

  alias Kiln.Artifact
  alias Kiln.Store.Canonical

  @valid_artifact_id "01920080-0000-7000-8000-000000000001"
  @valid_session_id "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  @valid_run_id "run_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

  defp base_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        artifact_id: @valid_artifact_id,
        session_id: @valid_session_id,
        run_id: @valid_run_id,
        owner_kind: :session,
        owner_id: @valid_session_id,
        producer_kind: :user,
        producer_id: "user:local",
        kind: :output,
        media_type: "application/octet-stream",
        encoding: :binary,
        content_digest: "sha256:" <> String.duplicate("a", 64),
        byte_size: 5,
        content_location: "sha256/aa/" <> String.duplicate("a", 62),
        trust: :user_supplied,
        sensitivity: :project,
        retention_class: :session,
        completeness: :complete,
        recorded_at: "2026-08-10T12:00:00Z",
        idempotency_key: "idem_" <> String.duplicate("b", 12)
      },
      overrides
    )
  end

  test "accepts a fully valid artifact and stamps the schema" do
    assert {:ok, artifact} = Artifact.new(base_attrs())
    assert artifact.schema == "kiln.artifact/v1"
    assert artifact.artifact_id == @valid_artifact_id
    assert artifact.creator_operation_id == nil
    assert artifact.repository_state_digest == nil
    assert artifact.host_profile_digest == nil
  end

  test "request_digest is deterministic for identical canonical bytes" do
    attrs1 = base_attrs(%{idempotency_key: "idem_" <> String.duplicate("c", 12)})
    attrs2 = base_attrs(%{idempotency_key: "idem_" <> String.duplicate("c", 12)})

    {:ok, artifact1} = Artifact.new(attrs1)
    {:ok, artifact2} = Artifact.new(attrs2)

    assert Artifact.request_digest(artifact1) == Artifact.request_digest(artifact2)
    assert Artifact.request_digest(artifact1) =~ ~r/^[0-9a-f]{64}$/
  end

  test "different content_digest produces a different request_digest" do
    {:ok, a} = Artifact.new(base_attrs())
    {:ok, b} = Artifact.new(base_attrs(%{content_digest: "sha256:" <> String.duplicate("d", 64)}))
    refute Artifact.request_digest(a) == Artifact.request_digest(b)
  end

  test "rejects every disallowed owner_kind vocabulary" do
    for bad <- [:bogus, :team, :org, ""] do
      assert {:error, %{class: :precondition, code: :invalid_vocabulary}} =
               Artifact.new(base_attrs(%{owner_kind: bad}))
    end
  end

  test "rejects every disallowed producer_kind vocabulary" do
    for bad <- [:wizard, :external, "command"] do
      assert {:error, %{class: :precondition}} = Artifact.new(base_attrs(%{producer_kind: bad}))
    end
  end

  test "rejects every disallowed kind vocabulary" do
    for bad <- [:trace, :audit, "input"] do
      assert {:error, %{class: :precondition}} = Artifact.new(base_attrs(%{kind: bad}))
    end
  end

  test "rejects NUL and disallowed control bytes on every text identifier" do
    for field <- [:session_id, :run_id, :owner_id, :producer_id, :idempotency_key],
        byte <- [<<0>>, <<1>>, <<0x1F>>, <<0x7F>>] do
      attrs = base_attrs(Map.put(%{}, field, "abc" <> byte <> "def"))

      assert {:error, %{class: :precondition, code: :disallowed_control_byte}} =
               Artifact.new(attrs),
             "expected rejection for #{inspect(field)} containing control byte #{inspect(byte)}"
    end
  end

  test "rejects a content_location that starts with '/'" do
    attrs = base_attrs(%{content_location: "/absolute/path"})
    assert {:error, %{class: :precondition, code: :absolute_path}} = Artifact.new(attrs)
  end

  test "rejects a content_location that contains '..'" do
    attrs = base_attrs(%{content_location: "sha256/aa/../../etc/passwd"})
    assert {:error, %{class: :precondition, code: :path_escape}} = Artifact.new(attrs)
  end

  test "rejects byte_size outside [0, 16_777_216]" do
    assert {:error, %{code: :limit_exceeded}} =
             Artifact.new(base_attrs(%{byte_size: 16_777_217}))

    assert {:error, %{code: :limit_exceeded}} = Artifact.new(base_attrs(%{byte_size: -1}))
  end

  test "accepts byte_size at exactly 0 and at the maximum" do
    assert {:ok, _} = Artifact.new(base_attrs(%{byte_size: 0}))
    assert {:ok, _} = Artifact.new(base_attrs(%{byte_size: 16_777_216}))
  end

  test "rejects a content_digest that is not sha256 + 64 hex" do
    bad_digest = "md5:" <> String.duplicate("a", 32)

    assert {:error, %{class: :precondition, code: :malformed_content_digest}} =
             Artifact.new(base_attrs(%{content_digest: bad_digest}))
  end

  test "rejects a malformed artifact_id" do
    attrs = base_attrs(%{artifact_id: "not-a-uuid"})

    assert {:error, %{class: :precondition, code: :malformed_uuid_v7}} = Artifact.new(attrs)
  end

  test "rejects a missing required field" do
    attrs = Map.delete(base_attrs(), :artifact_id)
    assert {:error, %{class: :precondition, code: :missing_field}} = Artifact.new(attrs)
  end

  test "canonical map round-trips through the Canonical encoder" do
    {:ok, artifact} = Artifact.new(base_attrs())

    map =
      artifact
      |> Artifact.canonical_map()
      |> stringify_for_canonical()

    assert is_binary(Canonical.encode(map))
  end

  defp stringify_for_canonical(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {k, stringify_for_canonical(v)} end)
  end

  defp stringify_for_canonical(value) when is_list(value),
    do: Enum.map(value, &stringify_for_canonical/1)

  defp stringify_for_canonical(value)
       when is_atom(value) and value not in [nil, true, false],
       do: Atom.to_string(value)

  defp stringify_for_canonical(value), do: value

  test "uuid_v7? recognizes canonical UUIDv7 strings" do
    assert Artifact.uuid_v7?("01920080-0000-7000-8000-000000000001")
    refute Artifact.uuid_v7?("01920080-0000-4000-8000-000000000001")
    refute Artifact.uuid_v7?("not-a-uuid")
    refute Artifact.uuid_v7?(nil)
    refute Artifact.uuid_v7?("")
  end
end
