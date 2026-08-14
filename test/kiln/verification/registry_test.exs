defmodule Kiln.Verification.RegistryTest do
  use ExUnit.Case, async: true

  alias Kiln.Verification.{Change, Registry}
  alias Kiln.WorkEnvelope

  @sha String.duplicate("a", 40)

  test "accepts only an exact registered command and rejects a shell escape" do
    repository = "/tmp/loadout"
    command = command("loadout.test", "npm", ["test"], ["proof-loadout.test"])

    assert {:ok, registered} = Registry.validate(command, repository, @sha)
    assert registered.id == "loadout.test"

    injected = %{command | "executable" => "sh", "argv" => ["-c", "touch /tmp/pwned"]}

    assert {:error, {:command_registration_mismatch, "loadout.test"}} =
             Registry.validate(injected, repository, @sha)

    assert {:error, {:unregistered_command, "loadout.shell"}} =
             Registry.validate(%{command | "command_id" => "loadout.shell"}, repository, @sha)
  end

  test "verification projection is content, authority, and obligation bound" do
    repository = "/tmp/loadout"

    obligations = [
      %{
        "id" => "patch-hygiene",
        "kind" => "verification",
        "requirement" => "patch is clean",
        "required_commands" => ["repo.diff-check"]
      }
    ]

    change = %{
      "schema" => "loadout/verification-change/v0",
      "method" => %{
        "id" => "verify-change/proof-obligation",
        "version" => "1.0.0",
        "implementation_digest" =>
          "sha256:7528513f16863330a8f69a4c554fec0e37a22de7994465e99962532bc6ea1690",
        "selection_result_digest" => "sha256:" <> String.duplicate("b", 64),
        "arsenal_commit" => String.duplicate("c", 40),
        "status" => "evaluated-winner"
      },
      "change" => %{
        "repository" => repository,
        "repository_profile" => "loadout",
        "base_state" => %{"ref" => "main", "commit" => @sha},
        "current_state" => %{
          "commit" => @sha,
          "workspace_state_digest" => "sha256:" <> String.duplicate("d", 64)
        },
        "changed_files" => ["src/cli.ts"],
        "patch_digest" => "sha256:" <> String.duplicate("e", 64),
        "workspace_state" => %{"clean" => false, "status_entries" => [" M src/cli.ts"]}
      },
      "affected_surfaces" => ["cli-composition"],
      "claims_at_risk" => ["built CLI composes"],
      "proof_obligations" => obligations,
      "selected_verification" => [
        command("repo.diff-check", "git", ["diff", "--check", @sha, "--"], [
          "patch-hygiene"
        ])
      ],
      "skipped_verification" => [],
      "unknowns" => []
    }

    digest = Change.digest(change)

    envelope_attrs = %{
      "schema" => "engineering-system/work-envelope/v0",
      "work_id" => "wave6-test",
      "producer" => %{"product" => "loadout", "version" => "0.1.0"},
      "goal" => %{"title" => "Verify this change", "success_conditions" => ["truth"]},
      "capability" => %{
        "id" => "verify-change",
        "contract_version" => "0.1.0",
        "method_provenance" => ["verify-change/proof-obligation@1.0.0"]
      },
      "project_state" => %{
        "repository" => repository,
        "base_commit" => @sha,
        "workspace_state_digest" => "sha256:" <> String.duplicate("d", 64)
      },
      "scope" => %{"included" => ["src/cli.ts"], "excluded" => []},
      "constraints" => %{"must" => ["exact"], "must_not" => ["shell"]},
      "context_refs" => ["loadout/verification-change/v0:" <> digest],
      "proof_obligations" => [Map.drop(hd(obligations), ["required_commands"])],
      "authority_requests" => [
        %{"capability" => "git.read", "scope" => repository},
        %{"capability" => "verification.run:repo.diff-check", "scope" => repository}
      ]
    }

    assert {:ok, envelope} = WorkEnvelope.new(envelope_attrs)
    assert {:ok, validated} = Change.validate(change, envelope)
    assert validated.digest == digest

    assert {:error, :verification_change_binding_mismatch} =
             Change.validate(
               put_in(change, ["change", "patch_digest"], "sha256:" <> String.duplicate("f", 64)),
               envelope
             )
  end

  test "binding remains strict: an arbitrary other implementation_digest fails with VERIFICATION_CHANGE_BINDING_MISMATCH" do
    repository = "/tmp/loadout"

    obligations = [
      %{
        "id" => "patch-hygiene",
        "kind" => "verification",
        "requirement" => "patch is clean",
        "required_commands" => ["repo.diff-check"]
      }
    ]

    base_change = %{
      "schema" => "loadout/verification-change/v0",
      "method" => %{
        "id" => "verify-change/proof-obligation",
        "version" => "1.0.0",
        "implementation_digest" =>
          "sha256:7528513f16863330a8f69a4c554fec0e37a22de7994465e99962532bc6ea1690",
        "selection_result_digest" => "sha256:" <> String.duplicate("b", 64),
        "arsenal_commit" => String.duplicate("c", 40),
        "status" => "evaluated-winner"
      },
      "change" => %{
        "repository" => repository,
        "repository_profile" => "loadout",
        "base_state" => %{"ref" => "main", "commit" => @sha},
        "current_state" => %{
          "commit" => @sha,
          "workspace_state_digest" => "sha256:" <> String.duplicate("d", 64)
        },
        "changed_files" => ["src/cli.ts"],
        "patch_digest" => "sha256:" <> String.duplicate("e", 64),
        "workspace_state" => %{"clean" => false, "status_entries" => [" M src/cli.ts"]}
      },
      "affected_surfaces" => ["cli-composition"],
      "claims_at_risk" => ["built CLI composes"],
      "proof_obligations" => obligations,
      "selected_verification" => [
        command("repo.diff-check", "git", ["diff", "--check", @sha, "--"], [
          "patch-hygiene"
        ])
      ],
      "skipped_verification" => [],
      "unknowns" => []
    }

    digest = Change.digest(base_change)
    envelope_attrs = base_envelope(repository, obligations, digest)

    assert {:ok, envelope} = WorkEnvelope.new(envelope_attrs)
    assert {:ok, _validated} = Change.validate(base_change, envelope)

    wrong_digest_1 = "sha256:" <> String.duplicate("0", 64)
    wrong_digest_2 = "sha256:ec329afbb1e6337b8af2edd2a9614a1a034c91e1f3946d757ba1f9970dde5b84"

    for wrong <- [wrong_digest_1, wrong_digest_2] do
      tampered = put_in(base_change, ["method", "implementation_digest"], wrong)
      tampered_digest = Change.digest(tampered)
      tampered_envelope_attrs = base_envelope(repository, obligations, tampered_digest)

      assert {:ok, tampered_envelope} = WorkEnvelope.new(tampered_envelope_attrs)

      assert {:error, :verification_change_binding_mismatch} =
               Change.validate(tampered, tampered_envelope),
             "expected binding mismatch for implementation_digest=#{wrong}"
    end
  end

  defp base_envelope(repository, obligations, digest) do
    %{
      "schema" => "engineering-system/work-envelope/v0",
      "work_id" => "wave6-binding-strict",
      "producer" => %{"product" => "loadout", "version" => "0.1.0"},
      "goal" => %{"title" => "Verify this change", "success_conditions" => ["truth"]},
      "capability" => %{
        "id" => "verify-change",
        "contract_version" => "0.1.0",
        "method_provenance" => ["verify-change/proof-obligation@1.0.0"]
      },
      "project_state" => %{
        "repository" => repository,
        "base_commit" => @sha,
        "workspace_state_digest" => "sha256:" <> String.duplicate("d", 64)
      },
      "scope" => %{"included" => ["src/cli.ts"], "excluded" => []},
      "constraints" => %{"must" => ["exact"], "must_not" => ["shell"]},
      "context_refs" => ["loadout/verification-change/v0:" <> digest],
      "proof_obligations" => [Map.drop(hd(obligations), ["required_commands"])],
      "authority_requests" => [
        %{"capability" => "git.read", "scope" => repository},
        %{"capability" => "verification.run:repo.diff-check", "scope" => repository}
      ]
    }
  end

  defp command(id, executable, argv, proves) do
    %{
      "command_id" => id,
      "executable" => executable,
      "argv" => argv,
      "working_directory" => ".",
      "timeout_ms" => 30_000,
      "environment_policy" => "minimal-toolchain-path",
      "network_policy" => "not-required",
      "mutation_expectation" => "none",
      "proves" => proves,
      "rationale" => "test"
    }
  end
end
