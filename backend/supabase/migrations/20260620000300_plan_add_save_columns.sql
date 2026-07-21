-- Add status and custom_title to plan table for "Save Trip" feature.
-- status: 'draft' (auto-saved on generate) | 'saved' (user explicitly saved)
ALTER TABLE plan ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'draft';
ALTER TABLE plan ADD COLUMN IF NOT EXISTS custom_title TEXT;

CREATE INDEX IF NOT EXISTS idx_plan_user_status ON plan(id_user, status);
