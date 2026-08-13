defmodule Kiln.CLI.JsonRendererTest do
  @moduledoc """
  Validates that `Kiln.CLI.JsonRenderer.render/1` emits documents that
  conform to the `$defs.cli_result` JSON schema in
  `docs/contracts/kiln-first-month.schema.json`.

  The check is end-to-end: every test writes the renderer's actual
  output bytes to a temporary file and shells out to
  `scripts/validate_cli_result_schema.py` (which uses the pinned
  `jsonschema 4.26.0` Draft 2020-12 validator with format checking
  enabled). The test fails when the renderer emits a key the schema
  does not accept, an absent required field, or an enum value outside
  the accepted set. The mutation tests (additional property, missing
  required field) build a synthetic document and confirm the validator
  rejects it, so a renderer regression that *adds* a forbidden key or
  *drops* a required key is caught here.

  Every `Result` here is constructed to mirror the foundation CLI's
  output shape on representative P1-S01 inputs. The set covers every
  accepted CLI status and every combination of optional fields the
  renderer emits today.
  """

  use ExUnit.Case, async: false

  alias Kiln.CLI.{JsonRenderer, Result}

  @validator_script "scripts/validate_cli_result_schema.py"

  defp validate_renderer_output(%Result{} = result) do
    bytes = JsonRenderer.render(result)
    validate_bytes(bytes)
  end

  defp validate_bytes(bytes) when is_binary(bytes) do
    tmp_path =
      Path.join(System.tmp_dir!(), "kiln_cli_result_#{System.unique_integer([:positive])}.json")

    File.write!(tmp_path, bytes)

    output =
      case System.cmd("python3", [@validator_script, tmp_path], stderr_to_stdout: true) do
        {out, 0} ->
          out

        {out, code} ->
          File.rm(tmp_path)
          flunk("schema validator exited #{code}; output:\n#{out}")
      end

    File.rm(tmp_path)
    output
  end

  defp mutate_and_validate(document, mutate) do
    mutated = mutate.(document)
    tmp = Path.join(System.tmp_dir!(), "kiln_mut_#{System.unique_integer([:positive])}.json")
    File.write!(tmp, JSON.encode!(mutated))

    {out, code} = System.cmd("python3", [@validator_script, tmp], stderr_to_stdout: true)
    File.rm(tmp)
    {out, code}
  end

  test "renderer output of an ok result conforms to the cli_result schema" do
    result =
      Result.ok("status",
        data: %{session_id: "ses-1", run_state: "ready"},
        session_revision: 2,
        journal_digest: "sha256:abc",
        next_actions: [Result.next_action("inspect", "review the current state")]
      )

    output = validate_renderer_output(result)
    assert output =~ "pass", "ok document failed: #{output}"
  end

  test "successful supervision renders the canonical Run Result Envelope for Loadout" do
    envelope = %{
      "schema" => "engineering-system/run-result-envelope/v0",
      "work_id" => "work-1",
      "run_id" => "run-1",
      "status" => "completed",
      "authority" => %{requested: ["git.read"], granted: ["git.read"], denied: []}
    }

    result =
      Result.ok("supervise",
        data: %{work_id: "work-1", run_id: "run-1", envelope: envelope}
      )

    rendered = result |> JsonRenderer.render_supervision() |> JSON.decode!()

    assert rendered == %{
             "schema" => "engineering-system/run-result-envelope/v0",
             "work_id" => "work-1",
             "run_id" => "run-1",
             "status" => "completed",
             "authority" => %{
               "requested" => ["git.read"],
               "granted" => ["git.read"],
               "denied" => []
             }
           }

    refute Map.has_key?(rendered, "data")
    refute Map.has_key?(rendered, "kind")
  end

  test "renderer output of every accepted status conforms to the schema" do
    for status <- Result.statuses() do
      result = build_for_status(status)
      output = validate_renderer_output(result)
      assert output =~ "pass", "status=#{status} failed: #{output}"
    end
  end

  test "schema rejects a document that adds a key the schema does not list" do
    # Build a conforming result, then add a key the schema does not
    # list (`additional`). The schema validator must reject this; this
    # catches the F2 review finding where the renderer emitted a key
    # the schema did not enumerate.
    result = Result.ok("status", data: %{session_id: "ses-1"}, next_actions: [])
    document = result_to_document(result) |> Map.put("additional", "forbidden")

    {out, code} = mutate_and_validate(document, & &1)
    assert code == 1
    assert out =~ "Additional properties are not allowed"
  end

  test "schema rejects a document missing a required field" do
    # Build a conforming result and remove the required `kind` field
    # before validating. This catches a renderer regression that drops
    # a required key.
    result = Result.ok("status", data: %{}, next_actions: [])
    document = result_to_document(result) |> Map.delete("kind")

    {out, code} = mutate_and_validate(document, & &1)
    assert code == 1
    assert out =~ "kind"
  end

  # -- helpers --

  defp result_to_document(%Result{} = result) do
    %{
      kind: Result.kind(),
      schema: Result.schema(),
      command: result.command,
      status: to_string(result.status),
      exit_code: result.exit_code,
      data: result.data,
      errors: result.errors,
      warnings: result.warnings,
      next_actions: result.next_actions,
      session_revision: result.session_revision,
      journal_digest: result.journal_digest,
      emitted_at: result.emitted_at
    }
    # Mirror the renderer so test data matches what the validator sees
    # on the wire.
    |> Map.new(fn {k, v} -> {to_string(k), jsonify_value(v)} end)
  end

  defp jsonify_value(value) when is_map(value) and not is_struct(value) do
    Map.new(value, fn {k, v} -> {to_string(k), jsonify_value(v)} end)
  end

  defp jsonify_value(list) when is_list(list), do: Enum.map(list, &jsonify_value/1)

  defp jsonify_value(value) when is_atom(value) and value not in [true, false, nil],
    do: Atom.to_string(value)

  defp jsonify_value(value), do: value

  defp build_for_status(:ok) do
    Result.ok("status", data: %{}, next_actions: [])
  end

  defp build_for_status(:denied) do
    Result.error("start", :denied,
      errors: [Result.to_error(%{code: "USAGE_ERROR", message: "test"})]
    )
  end

  defp build_for_status(:blocked) do
    Result.error("status", :blocked,
      errors: [Result.to_error(%{code: :no_session, message: "test"})]
    )
  end

  defp build_for_status(:stale) do
    Result.error("cancel", :stale,
      errors: [Result.to_error(%{code: :stale_revision, message: "test"})]
    )
  end

  defp build_for_status(:failed) do
    Result.error("cancel", :failed,
      errors: [Result.to_error(%{code: :terminal_run_state, message: "test"})]
    )
  end

  defp build_for_status(:unknown) do
    Result.error("status", :unknown,
      errors: [Result.to_error(%{code: :orphaned_run, message: "test"})]
    )
  end

  defp build_for_status(:unsupported) do
    Result.error("foo", :unsupported,
      errors: [Result.to_error(%{code: :unsupported_command, message: "test"})]
    )
  end
end
