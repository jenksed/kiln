-- P1-S02-T01 Artifact provenance metadata for kiln-state/v1.
-- Forward-only. The applied checksum of this file is immutable once recorded.
--
-- This migration stores Artifact METADATA only. Content bytes live below
-- $KILN_HOME/artifacts/sha256/<first-two-hex>/<remaining-hex> and never in
-- SQLite (P1-S02-T01-R01). content_location holds a relative path below the
-- accepted Artifact root; an absolute or traversing path is rejected here and
-- by application validation.
--
-- artifact_id and content_digest are distinct identities (P1-S02-T01-R02).
-- Identical bytes may share one content-addressed blob while separate Artifact
-- records preserve different owners, producers, bindings, sensitivity, or
-- retention. content_digest is therefore deliberately NOT unique.
--
-- Byte bounds use length(CAST(value AS BLOB)) so multibyte UTF-8 input cannot
-- bypass a byte limit by being measured in code points (P1-S02-T01-R08).
-- NUL and control-byte rejection is owned by application validation; this
-- schema enforces the byte-size, scalar-length, vocabulary, digest-shape, and
-- relative-location bounds required at the direct-SQL boundary.

CREATE TABLE artifacts (
  artifact_id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  run_id TEXT NOT NULL,
  creator_operation_id TEXT,
  owner_kind TEXT NOT NULL,
  owner_id TEXT NOT NULL,
  producer_kind TEXT NOT NULL,
  producer_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  media_type TEXT NOT NULL,
  encoding TEXT NOT NULL,
  content_digest TEXT NOT NULL,
  byte_size INTEGER NOT NULL,
  content_location TEXT NOT NULL,
  repository_state_digest TEXT,
  host_profile_digest TEXT,
  trust TEXT NOT NULL,
  sensitivity TEXT NOT NULL,
  retention_class TEXT NOT NULL,
  completeness TEXT NOT NULL,
  recorded_at TEXT NOT NULL,
  artifact_schema TEXT NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  request_digest TEXT NOT NULL,

  CHECK (owner_kind IN ('project', 'session', 'run')),
  CHECK (producer_kind IN ('command', 'provider', 'pack', 'patch', 'repository', 'user', 'deterministic_service')),
  CHECK (kind IN ('input', 'output', 'report', 'log', 'snapshot', 'patch', 'diff', 'summary', 'other')),
  CHECK (encoding IN ('binary', 'utf_8', 'utf_8_bom')),
  CHECK (trust IN ('kiln_generated', 'registered_command_output', 'provider_output', 'user_supplied', 'repository_observation')),
  CHECK (sensitivity IN ('public', 'project', 'sensitive', 'secret', 'unknown')),
  CHECK (retention_class IN ('run', 'session', 'project', 'audit', 'release', 'policy_controlled')),
  CHECK (completeness IN ('complete', 'partial', 'truncated', 'missing', 'unknown')),
  CHECK (artifact_schema = 'kiln.artifact/v1'),

  CHECK (typeof(byte_size) = 'integer'),
  CHECK (byte_size BETWEEN 0 AND 16777216),

  CHECK (length(content_digest) = 71),
  CHECK (substr(content_digest, 1, 7) = 'sha256:'),
  CHECK (substr(content_digest, 8) GLOB '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*'),
  CHECK (length(request_digest) = 64),
  CHECK (request_digest GLOB '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*'),
  CHECK (repository_state_digest IS NULL OR length(repository_state_digest) > 0),
  CHECK (host_profile_digest IS NULL OR length(host_profile_digest) > 0),

  CHECK (length(artifact_id) = 36),
  CHECK (creator_operation_id IS NULL OR length(creator_operation_id) = 36),
  CHECK (length(CAST(session_id AS BLOB)) BETWEEN 1 AND 256),
  CHECK (length(CAST(run_id AS BLOB)) BETWEEN 1 AND 256),
  CHECK (length(CAST(owner_id AS BLOB)) BETWEEN 1 AND 256),
  CHECK (length(CAST(producer_id AS BLOB)) BETWEEN 1 AND 256),
  CHECK (length(CAST(media_type AS BLOB)) BETWEEN 1 AND 255),
  CHECK (length(CAST(idempotency_key AS BLOB)) BETWEEN 1 AND 256),
  CHECK (length(CAST(recorded_at AS BLOB)) BETWEEN 1 AND 64),

  -- Relative location below the accepted Artifact root only.
  CHECK (length(CAST(content_location AS BLOB)) BETWEEN 1 AND 128),
  CHECK (substr(content_location, 1, 1) <> '/'),
  CHECK (instr(content_location, '..') = 0)
);

-- Exact lookups exercised by T01: content-addressed reuse, owner scoping, and
-- producer provenance. The idempotency_key UNIQUE constraint supplies its own
-- index.
CREATE INDEX artifacts_content_digest_idx ON artifacts (content_digest);
CREATE INDEX artifacts_owner_idx ON artifacts (owner_kind, owner_id);
CREATE INDEX artifacts_producer_idx ON artifacts (producer_kind, producer_id);
