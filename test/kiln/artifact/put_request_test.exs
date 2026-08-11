defmodule Kiln.Artifact.PutRequestTest do
  use ExUnit.Case, async: true

  alias Kiln.Artifact.PutRequest

  defp base_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        artifact_id: "01920080-0000-7000-8000-000000000001",
        idempotency_key: "idem_put_request",
        recorded_at: "2026-08-10T12:00:00Z",
        bytes: "hello",
        metadata: %{
          session_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          run_id: "run_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          owner_kind: :session,
          owner_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          producer_kind: :user,
          producer_id: "user:local",
          kind: :output,
          media_type: "application/octet-stream",
          encoding: :binary,
          trust: :user_supplied,
          sensitivity: :project,
          retention_class: :session,
          completeness: :complete
        }
      },
      overrides
    )
  end

  test "accepts a well-formed request" do
    assert {:ok, request} = PutRequest.new(base_attrs())
    assert request.artifact_id == "01920080-0000-7000-8000-000000000001"
    assert request.bytes == "hello"
    assert request.metadata.owner_kind == :session
  end

  test "rejects a missing required field" do
    attrs = Map.delete(base_attrs(), :bytes)
    assert {:error, %{class: :precondition, code: :missing_field}} = PutRequest.new(attrs)
  end

  test "rejects bytes that exceed the artifact byte bound" do
    huge = :binary.copy(<<0>>, 16_777_217)

    assert {:error, %{class: :precondition, code: :limit_exceeded}} =
             PutRequest.new(base_attrs(%{bytes: huge}))
  end

  test "accepts bytes at exactly the maximum" do
    huge = :binary.copy(<<0>>, 16_777_216)
    assert {:ok, _} = PutRequest.new(base_attrs(%{bytes: huge}))
  end

  test "rejects bytes that are not a binary" do
    assert {:error, %{class: :precondition, code: :wrong_type}} =
             PutRequest.new(base_attrs(%{bytes: [:not_a_binary]}))
  end

  test "rejects a malformed artifact_id" do
    attrs = base_attrs(%{artifact_id: "not-a-uuid"})

    assert {:error, %{class: :precondition, code: :malformed_uuid_v7}} =
             PutRequest.new(attrs)
  end

  test "rejects an empty or oversized idempotency_key" do
    assert {:error, %{class: :precondition, code: :empty_idempotency_key}} =
             PutRequest.new(base_attrs(%{idempotency_key: ""}))

    big = :binary.copy(<<0x41>>, 257)

    assert {:error, %{class: :precondition, code: :limit_exceeded}} =
             PutRequest.new(base_attrs(%{idempotency_key: big}))
  end

  test "rejects a NUL or control byte inside idempotency_key" do
    assert {:error, %{class: :precondition, code: :disallowed_control_byte}} =
             PutRequest.new(base_attrs(%{idempotency_key: "abc" <> <<0>> <> "def"}))
  end

  test "rejects an empty recorded_at" do
    assert {:error, %{class: :precondition, code: :empty_recorded_at}} =
             PutRequest.new(base_attrs(%{recorded_at: ""}))
  end

  test "rejects a NUL or control byte inside recorded_at" do
    assert {:error, %{class: :precondition, code: :disallowed_control_byte}} =
             PutRequest.new(base_attrs(%{recorded_at: "abc" <> <<1>> <> "def"}))
  end
end
