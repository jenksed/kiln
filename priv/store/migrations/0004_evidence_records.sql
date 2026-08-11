-- P1-S02-T01 immutable Evidence records for kiln-state/v1.
-- Forward-only. The applied checksum of this file is immutable once recorded.
--
-- Evidence carries a required first-month result: pass | fail | blocked |
-- unknown (P1-S02-T01-R05). That vocabulary is NOT the generic v0 Claim
-- relation vocabulary; Claim relations remain a separate later association.
--
-- Freshness is state-based only. The four accepted rules are the complete
-- vocabulary and there is no TTL column, so a direct SQL statement naming a
-- TTL attribute fails because no such column exists (P1-S02-T01-R09).
--
-- Artifact association is plural and lives in evidence_artifacts, not in a
-- singular foreign-key column or caller-ordered JSON. Warnings live in
-- evidence_warnings. Both child tables carry position bounds and byte bounds.
--
-- Byte bounds use length(CAST(value AS BLOB)) so multibyte UTF-8 input cannot
-- bypass a byte limit by being measured in code points (P1-S02-T01-R08).

CREATE TABLE evidence_records (
  evidence_id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  run_id TEXT NOT NULL,
  criterion_id TEXT NOT NULL,
  criterion_revision TEXT NOT NULL,
  subject_id TEXT NOT NULL,
  subject_kind TEXT NOT NULL,
  subject_state_digest TEXT NOT NULL,
  producer_kind TEXT NOT NULL,
  producer_id TEXT NOT NULL,
  method TEXT NOT NULL,
  result TEXT NOT NULL,
  repository_state_digest TEXT NOT NULL,
  patch_id TEXT,
  patch_digest TEXT,
  patch_result_digest TEXT,
  host_profile_digest TEXT,
  command_registration_digest TEXT,
  command_result_id TEXT,
  evaluator_digest TEXT NOT NULL,
  observation_digest TEXT NOT NULL,
  completeness TEXT NOT NULL,
  freshness_rule TEXT NOT NULL,
  observed_at TEXT NOT NULL,
  recorded_at TEXT NOT NULL,
  rationale TEXT,
  evidence_schema TEXT NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  request_digest TEXT NOT NULL,
  record_digest TEXT NOT NULL,

  CHECK (result IN ('pass', 'fail', 'blocked', 'unknown')),
  CHECK (method IN ('registered_command', 'repository_observation', 'deterministic_validator', 'user_observation')),
  CHECK (subject_kind IN ('session', 'run', 'operation', 'patch', 'command', 'artifact', 'evidence', 'repository')),
  CHECK (producer_kind IN ('command', 'provider', 'pack', 'patch', 'repository', 'user', 'deterministic_service')),
  CHECK (completeness IN ('complete', 'partial', 'truncated', 'missing', 'unknown')),
  CHECK (evidence_schema = 'kiln.evidence/v1'),

  -- The complete accepted freshness vocabulary. No time_bound, no TTL.
  CHECK (freshness_rule IN (
    'same_repository_state',
    'same_patch_and_repository_state',
    'same_command_registration_and_repository_state',
    'manual_same_repository_state'
  )),

  -- A pass or fail claim requires complete observation content. A truthful
  -- blocked or unknown record may commit with non-complete content.
  CHECK (result NOT IN ('pass', 'fail') OR completeness = 'complete'),

  -- Patch identity, digest, and result digest are all null or all non-null.
  CHECK (
    (patch_id IS NULL AND patch_digest IS NULL AND patch_result_digest IS NULL)
    OR (patch_id IS NOT NULL AND patch_digest IS NOT NULL AND patch_result_digest IS NOT NULL)
  ),

  -- Registered-Command Evidence requires Command registration, Command result,
  -- and host-profile bindings.
  CHECK (
    method <> 'registered_command'
    OR (command_registration_digest IS NOT NULL
        AND command_result_id IS NOT NULL
        AND host_profile_digest IS NOT NULL)
  ),

  CHECK (length(evidence_id) = 36),
  CHECK (length(record_digest) = 64),
  CHECK (record_digest GLOB '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*'),
  CHECK (length(request_digest) = 64),
  CHECK (request_digest GLOB '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*'),
  CHECK (length(subject_state_digest) > 0),
  CHECK (length(repository_state_digest) > 0),
  CHECK (length(evaluator_digest) > 0),
  CHECK (length(observation_digest) > 0),
  CHECK (patch_digest IS NULL OR length(patch_digest) > 0),
  CHECK (patch_result_digest IS NULL OR length(patch_result_digest) > 0),
  CHECK (host_profile_digest IS NULL OR length(host_profile_digest) > 0),
  CHECK (command_registration_digest IS NULL OR length(command_registration_digest) > 0),

  CHECK (length(CAST(session_id AS BLOB)) BETWEEN 1 AND 256),
  CHECK (length(CAST(run_id AS BLOB)) BETWEEN 1 AND 256),
  CHECK (length(CAST(criterion_id AS BLOB)) BETWEEN 1 AND 256),
  CHECK (length(CAST(criterion_revision AS BLOB)) BETWEEN 1 AND 64),
  CHECK (length(CAST(subject_id AS BLOB)) BETWEEN 1 AND 256),
  CHECK (length(CAST(producer_id AS BLOB)) BETWEEN 1 AND 256),
  CHECK (command_result_id IS NULL OR length(CAST(command_result_id AS BLOB)) BETWEEN 1 AND 256),
  CHECK (patch_id IS NULL OR length(CAST(patch_id AS BLOB)) BETWEEN 1 AND 256),
  CHECK (length(CAST(idempotency_key AS BLOB)) BETWEEN 1 AND 256),
  CHECK (rationale IS NULL OR length(CAST(rationale AS BLOB)) <= 8192),
  CHECK (length(CAST(observed_at AS BLOB)) BETWEEN 1 AND 64),
  CHECK (length(CAST(recorded_at AS BLOB)) BETWEEN 1 AND 64)
);

-- Plural Artifact association. Foreign keys guarantee every referenced
-- Artifact metadata row exists, so a dangling association cannot be created.
-- At most 32 unique Artifact IDs per Evidence record.
CREATE TABLE evidence_artifacts (
  evidence_id TEXT NOT NULL REFERENCES evidence_records (evidence_id),
  artifact_id TEXT NOT NULL REFERENCES artifacts (artifact_id),
  position INTEGER NOT NULL,
  PRIMARY KEY (evidence_id, artifact_id),
  UNIQUE (evidence_id, position),
  CHECK (typeof(position) = 'integer'),
  CHECK (position BETWEEN 0 AND 31)
);

CREATE INDEX evidence_artifacts_artifact_idx ON evidence_artifacts (artifact_id);

-- Bounded warnings. At most 64 items, 1,024 bytes per item, and an aborting
-- aggregate limit of 16,384 bytes enforced by the trigger below.
CREATE TABLE evidence_warnings (
  evidence_id TEXT NOT NULL REFERENCES evidence_records (evidence_id),
  position INTEGER NOT NULL,
  warning TEXT NOT NULL,
  PRIMARY KEY (evidence_id, position),
  CHECK (typeof(position) = 'integer'),
  CHECK (position BETWEEN 0 AND 63),
  CHECK (length(CAST(warning AS BLOB)) BETWEEN 1 AND 1024)
);

-- Aggregate warning-byte limit. A row-local CHECK cannot express a bound
-- across sibling rows, so this is enforced as an aborting trigger. Exactly
-- 16,384 aggregate bytes is accepted; 16,385 aborts the statement and rolls
-- back the enclosing transaction (P1-S02-T01-AC15).
CREATE TRIGGER evidence_warnings_aggregate_limit
BEFORE INSERT ON evidence_warnings
BEGIN
  SELECT RAISE(ABORT, 'evidence warnings exceed the 16384-byte aggregate limit')
  WHERE (
    SELECT COALESCE(SUM(length(CAST(warning AS BLOB))), 0)
    FROM evidence_warnings
    WHERE evidence_id = NEW.evidence_id
  ) + length(CAST(NEW.warning AS BLOB)) > 16384;
END;

-- Exact lookups exercised by T01: idempotency replay, criterion and composite
-- binding queries, Command-result binding, and producer provenance. The
-- idempotency_key UNIQUE constraint supplies its own index.
CREATE INDEX evidence_records_criterion_idx
  ON evidence_records (criterion_id, criterion_revision, subject_kind, subject_id, repository_state_digest);
CREATE INDEX evidence_records_command_result_idx ON evidence_records (command_result_id);
CREATE INDEX evidence_records_producer_idx ON evidence_records (producer_kind, producer_id);
