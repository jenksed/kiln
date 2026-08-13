-- Migration 0006: Persist supervisor input bindings on supervision_runs.
--
-- The Wave 3 supervisor rebuilds a Run Result Envelope from durable facts
-- after process death. Migration 0005 bound (work_id, run_id) to a single
-- durable Run but did not persist the producer's input bindings
-- (project_state.base_commit, project_state.workspace_state_digest) or
-- the requested proof_obligations list. Without those, the post-restart
-- projection can read the immutable Artifact substrate but cannot return
-- the producer's input_state or identify which proof obligations were
-- requested.
--
-- This migration adds three TEXT columns to supervision_runs so the
-- supervisor can rebuild the input_state and the set of requested proof
-- obligations from durable SQL without fabricating placeholders:
--
--   * base_commit — the producer's submitted base commit SHA.
--   * workspace_state_digest — the producer's workspace state digest.
--   * proof_obligation_ids — JSON-encoded list of obligation ids the
--     Work Envelope declared.
--
-- The migration is additive. No existing column is modified, no
-- constraint is relaxed, and no existing row is destroyed. The default
-- for each new column is an empty value so this migration can apply to
-- stores created by the previous schema without raising; the supervisor
-- treats empty values as `unknown` during reconstruction, matching the
-- existing "incomplete durable facts" vocabulary. The supervisor itself
-- never persists an empty value for a new supervision: any successful
-- `resolve_run_id` write after this migration must include all three
-- values, so empty defaults only describe rows written before the
-- fix landed.

ALTER TABLE supervision_runs
  ADD COLUMN base_commit TEXT NOT NULL DEFAULT '';

ALTER TABLE supervision_runs
  ADD COLUMN workspace_state_digest TEXT NOT NULL DEFAULT '';

ALTER TABLE supervision_runs
  ADD COLUMN proof_obligation_ids TEXT NOT NULL DEFAULT '[]';