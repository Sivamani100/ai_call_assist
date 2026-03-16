-- ─── TABLE: call_logs ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS call_logs (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  exotel_call_sid     TEXT UNIQUE,
  caller_number       TEXT NOT NULL,
  caller_name         TEXT,
  caller_relationship TEXT DEFAULT 'unknown',
  is_known_contact    BOOLEAN DEFAULT false,
  call_start_time     TIMESTAMPTZ DEFAULT NOW(),
  call_duration_sec   INTEGER DEFAULT 0,
  call_type           TEXT DEFAULT 'routine',
    -- values: spam | event | routine | important | urgent
  ai_summary          TEXT,
  full_transcript     JSONB,
    -- array of {"speaker": "caller"|"assistant", "text": "..."}
  key_details         TEXT[],
  urgency_level       TEXT DEFAULT 'low',
    -- values: low | medium | high | urgent
  action_needed       TEXT,
  recommended_response TEXT,
  deadline            TEXT,
  should_call_back    BOOLEAN DEFAULT false,
  status              TEXT DEFAULT 'new',
    -- values: new | read | replied | blocked | done
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ─── TABLE: fcm_tokens ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fcm_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fcm_token   TEXT UNIQUE NOT NULL,
  device_id   TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─── TABLE: contacts ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS contacts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone       TEXT UNIQUE NOT NULL,  -- E.164: +919876543210
  name        TEXT NOT NULL,
  is_vip      BOOLEAN DEFAULT false,
  notes       TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─── TABLE: settings ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS settings (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key        TEXT UNIQUE NOT NULL,
  value      TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO settings (key, value) VALUES
  ('ai_mode', 'false'),
  ('owner_name', 'Siva'),
  ('exotel_number', '+918047123456'),
  ('ai_personality', 'professional')
ON CONFLICT (key) DO NOTHING;

-- ─── INDEXES ────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_call_logs_status   ON call_logs(status);
CREATE INDEX IF NOT EXISTS idx_call_logs_created  ON call_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_logs_urgency  ON call_logs(urgency_level);
CREATE INDEX IF NOT EXISTS idx_contacts_phone     ON contacts(phone);

-- ─── REALTIME ───────────────────────────────────────────────────────
-- Flutter app gets live updates the moment a call log is saved
ALTER PUBLICATION supabase_realtime ADD TABLE call_logs;
