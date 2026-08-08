-- P1-S02-T01: typed Evidence records table.
--
-- One row per Evidence construction. evidence_id is the canonical
-- lowercase hex SHA-256 digest over the canonical bytes of the Evidence
-- struct (schema-bound; see Kiln.Evidence.canonical_digest/1). The UNIQUE
-- PRIMARY KEY enforces idempotent re-recording: a second insert with
-- identical canonical bytes yields a SQLite UNIQUE-constraint rejection,
-- not a silent duplicate row. The protected-failure-matrix fixture
-- `replay_attack` depends on this property.
--
-- artifact_id is nullable: an Evidence row may reference a produced
-- Artifact (e.g., a Command's stdout/stderr captured into content) or
-- carry only the producer identification without an Artifact.
--
-- Bounded vocabulary columns (method, freshness_class, completeness_class,
-- producer_kind) are validated in Kiln.Evidence.new/1 and in
-- Kiln.Evidence.Freshness/Completeness.
--
-- kiln-state/v1 is preserved.

CREATE TABLE evidence_records (
  evidence_id            TEXT    PRIMARY KEY,
  subject_id             TEXT    NOT NULL,
  subject_kind           TEXT    NOT NULL,
  subject_state_digest   TEXT    NOT NULL,
  producer_kind          TEXT    NOT NULL,
  producer_id            TEXT    NOT NULL,
  method                 TEXT    NOT NULL,
  freshness_class        TEXT    NOT NULL,
  freshness_ttl_seconds  INTEGER,
  completeness_class     TEXT    NOT NULL,
  observed_at            TEXT    NOT NULL,
  recorded_at            TEXT    NOT NULL,
  artifact_id            TEXT    REFERENCES artifacts (artifact_id),
  schema                 TEXT    NOT NULL,
  CHECK (freshness_class <> 'transient' OR freshness_ttl_seconds IS NOT NULL),
  CHECK (freshness_class =  'durable'  OR freshness_ttl_seconds IS NOT NULL)
);

CREATE INDEX evidence_records_subject  ON evidence_records (subject_id, recorded_at);
CREATE INDEX evidence_records_producer ON evidence_records (producer_kind, producer_id);
CREATE INDEX evidence_records_method   ON evidence_records (method, recorded_at);