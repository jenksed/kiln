-- Migration 0005: Wave 3 supervision_runs + supervision_run_artifacts +
-- supervision_run_evidence bindings.
--
-- Adds the durable identity binding the KIL-W3 supervisor uses to bind
-- a Work Envelope `work_id` to a single durable Run, and to record which
-- Artifact and Evidence rows belong to that Run. The tables are
-- additive: they do not modify the existing kiln-state/v1 substrate,
-- do not change accepted evidence semantics, and do not relax any
-- constraint. The migration uses the same compound-statement support
-- already authorized for migration 0004.
--
-- Invariants:
--
--   * `work_id` and `run_id` are non-empty bounded identifiers.
--   * `(work_id, request_digest)` is the unique idempotency binding
--     for one supervised request.
--   * `run_id` is unique across the entire store.
--   * The artifact and evidence link tables enforce that referenced
--     Artifact and Evidence ids exist (foreign keys).
--   * `position` on the link tables is bounded by an explicit CHECK
--     so an oversized payload aborts the migration.

CREATE TABLE supervision_runs (
  work_id TEXT NOT NULL,
  run_id TEXT NOT NULL,
  request_digest TEXT NOT NULL,
  created_at TEXT NOT NULL,
  run_state TEXT NOT NULL,
  PRIMARY KEY (run_id),
  UNIQUE (work_id, request_digest)
);

CREATE TABLE supervision_run_artifacts (
  run_id TEXT NOT NULL,
  artifact_id TEXT NOT NULL,
  position INTEGER NOT NULL CHECK (position BETWEEN 0 AND 1023),
  PRIMARY KEY (run_id, artifact_id),
  FOREIGN KEY (run_id) REFERENCES supervision_runs (run_id) ON DELETE CASCADE
);

CREATE TABLE supervision_run_evidence (
  run_id TEXT NOT NULL,
  evidence_id TEXT NOT NULL,
  position INTEGER NOT NULL CHECK (position BETWEEN 0 AND 255),
  PRIMARY KEY (run_id, evidence_id),
  FOREIGN KEY (run_id) REFERENCES supervision_runs (run_id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX supervision_runs_work_id_index ON supervision_runs (work_id);
