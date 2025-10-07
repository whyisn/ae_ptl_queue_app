-- 00_schema.sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TYPE user_role AS ENUM ('AE','PTL','ADMIN');
CREATE TYPE request_status AS ENUM ('draft','waiting_review','revision_requested','approved','rejected');

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role user_role NOT NULL DEFAULT 'AE',
  name text NOT NULL,
  email text UNIQUE NOT NULL,
  phone text,
  created_at timestamptz DEFAULT now(),
  last_login_at timestamptz,
  is_active boolean DEFAULT true
);

CREATE TABLE IF NOT EXISTS requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ae_id uuid NOT NULL REFERENCES users(id),
  applicant_name text NOT NULL,
  external_id text,
  status request_status NOT NULL DEFAULT 'draft',
  ptl_note_last text,
  enqueued_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  closed_at timestamptz
);

CREATE TABLE IF NOT EXISTS request_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
  url text NOT NULL,
  type text CHECK (type IN ('image','video')) NOT NULL,
  caption text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS request_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id),
  role_snapshot user_role NOT NULL,
  note text,
  action text CHECK (action IN ('submit','ask_revision','approve','reject','add_media')) NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_requests_status_enqueued ON requests(status, enqueued_at);
CREATE INDEX IF NOT EXISTS idx_requests_ae_created ON requests(ae_id, created_at);

-- queue_position (dinamis)
CREATE OR REPLACE FUNCTION queue_position(req_id uuid)
RETURNS int AS $$
  WITH mine AS (SELECT enqueued_at, id FROM requests WHERE id = req_id),
  waiting AS (SELECT enqueued_at, id FROM requests WHERE status = 'waiting_review')
  SELECT 1 + COUNT(*) FROM waiting w, mine m
  WHERE (w.enqueued_at < m.enqueued_at)
     OR (w.enqueued_at = m.enqueued_at AND w.id < m.id);
$$ LANGUAGE sql STABLE;
