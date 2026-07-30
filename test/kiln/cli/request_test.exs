defmodule Kiln.CLI.RequestTest do
  use ExUnit.Case, async: true

  alias Kiln.CLI.Request

  test "parses the start command with all required options" do
    assert {:ok, request} =
             Request.parse([
               "--kiln-home",
               "/tmp/kiln-cli-test",
               "--format",
               "json",
               "start",
               "--repo",
               "/tmp/example",
               "--objective",
               "Fix one defect",
               "--criterion",
               "Test passes",
               "--constraint",
               "No new dependencies",
               "--exclude",
               "No provider"
             ])

    assert request.command == :start
    assert request.format == :json
    assert request.kiln_home == "/tmp/kiln-cli-test"
    assert request.options["repo"] == "/tmp/example"
    assert request.options["objective"] == "Fix one defect"
    assert request.options["criterion"] == ["Test passes"]
    assert request.options["constraint"] == ["No new dependencies"]
    assert request.options["exclude"] == ["No provider"]
  end

  test "parses equals-separated flag values" do
    assert {:ok, request} =
             Request.parse([
               "--kiln-home=/tmp/kiln-cli-test",
               "--format=text",
               "status"
             ])

    assert request.kiln_home == "/tmp/kiln-cli-test"
    assert request.format == :text
    assert request.command == :status
  end

  test "preserves repeated criteria in argv order" do
    assert {:ok, request} =
             Request.parse([
               "--kiln-home=/tmp/x",
               "start",
               "--repo=/tmp/repo",
               "--objective=Fix it",
               "--criterion=first",
               "--criterion=second"
             ])

    assert request.options["criterion"] == ["first", "second"]
  end

  test "rejects flags that are not authorized for the command" do
    assert {:error, error} = Request.parse(["--kiln-home=/tmp/x", "status", "--reason=nope"])
    assert error.message =~ "unknown flag for status"
  end

  test "rejects missing start inputs during parsing" do
    assert {:error, error} = Request.parse(["--kiln-home=/tmp/x", "start", "--repo=/tmp/repo"])
    assert error.message =~ "--objective is required"
  end

  test "marks the help request when only --help is given" do
    assert {:ok, request} = Request.parse(["--help"])
    assert request.show_help == true
    assert request.command == nil
  end

  test "marks the version request when only --version is given" do
    assert {:ok, request} = Request.parse(["--version"])
    assert request.show_version == true
    assert request.command == nil
  end

  test "rejects unknown commands with a structured USAGE_ERROR" do
    assert {:error, error} = Request.parse(["--kiln-home=/tmp/x", "patch.inspect"])
    assert error.code == "USAGE_ERROR"
    assert error.class == "usage"
    assert error.message =~ "unsupported command"
  end

  test "rejects unknown flags before the command with a structured USAGE_ERROR" do
    assert {:error, error} = Request.parse(["--kiln-home=/tmp/x", "--bogus", "status"])
    assert error.code == "USAGE_ERROR"
    assert error.message =~ "unknown flag"
  end

  test "treats --kiln-home with no value as a missing required command" do
    assert {:error, error} = Request.parse(["--kiln-home"])
    assert error.message =~ "--kiln-home requires a path value"
  end

  test "rejects --kiln-home whose next value happens to look like a command" do
    assert {:error, error} = Request.parse(["--kiln-home", "status"])
    assert error.message =~ "a command is required"
  end

  test "rejects --format with an unsupported value" do
    assert {:error, error} =
             Request.parse(["--kiln-home=/tmp/x", "--format=xml", "status"])

    assert error.message =~ "--format must be text or json"
  end

  test "requires a command unless --help or --version is requested" do
    assert {:error, error} = Request.parse(["--kiln-home=/tmp/x"])
    assert error.message =~ "a command is required"
  end
end
