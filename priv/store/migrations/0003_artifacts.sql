-- P1-S02-T01: content-addressed Artifact storage table.
--
-- One row per immutable Artifact. artifact_id is the lowercase hex SHA-256
-- digest over the canonical content bytes, prefixed with the "sha256:" scheme.
-- The content BLOB is stored inline so a single self-contained module can
-- round-trip an Artifact without an external filesystem layout.
--
-- Bounded vocabulary columns (content_kind, encoding, retention_class,
-- producer_kind) are validated in Kiln.Artifact.Store; SQLite is not a
-- vocabulary enforcement layer.
--
-- Indexes on producer_id and recorded_at support the bounded lookups used
-- by later tickets. The PRIMARY KEY is sufficient to enforce content
-- uniqueness (same bytes => same id; second insert is rejected by the
-- SQLite UNIQUE constraint, not silently overwritten).
--
-- kiln-state/v1 is preserved: this migration adds one table, no schema
-- format version bump, no other existing table is altered.

CREATE TABLE artifacts (
  artifact_id      TEXT    PRIMARY KEY,
  byte_size        INTEGER NOT NULL CHECK (byte_size >= 0),
  content_kind     TEXT    NOT NULL,
  encoding         TEXT    NOT NULL,
  media_type       TEXT    NOT NULL,
  retention_class  TEXT    NOT NULL,
  producer_kind    TEXT    NOT NULL,
  producer_id      TEXT    NOT NULL,
  recorded_at      TEXT    NOT NULL,
  source_digest    TEXT    NOT NULL,
  schema           TEXT    NOT NULL,
  content          BLOB    NOT NULL
);

CREATE INDEX artifacts_producer_id  ON artifacts (producer_id);
CREATE INDEX artifacts_recorded_at  ON artifacts (recorded_at);
CREATE INDEX artifacts_retention    ON artifacts (retention_class, recorded_at);