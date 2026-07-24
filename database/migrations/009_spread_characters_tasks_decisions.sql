BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS uq_character_appearances_spread_character
  ON character_appearances (spread_id, character_id)
  WHERE spread_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_character_appearances_spread
  ON character_appearances (spread_id);

CREATE INDEX IF NOT EXISTS idx_tasks_spread_status_due
  ON tasks (spread_id, status, due_date)
  WHERE spread_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_decisions_spread_date
  ON decisions (spread_id, decision_date DESC, created_at DESC)
  WHERE spread_id IS NOT NULL;

COMMIT;
