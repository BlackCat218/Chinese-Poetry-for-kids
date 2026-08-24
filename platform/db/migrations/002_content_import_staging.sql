CREATE TABLE content_import_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_file TEXT NOT NULL,
  source_checksum TEXT,
  status TEXT NOT NULL CHECK (status IN ('uploaded', 'validated', 'reviewing', 'completed', 'failed')) DEFAULT 'uploaded',
  imported_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);

CREATE TABLE staged_poems (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  import_job_id UUID NOT NULL REFERENCES content_import_jobs(id) ON DELETE CASCADE,
  source_row_number INTEGER NOT NULL,
  raw_record JSONB NOT NULL,
  title TEXT,
  dynasty_name TEXT,
  author_name TEXT,
  body TEXT,
  validation_errors JSONB NOT NULL DEFAULT '[]'::jsonb,
  review_status TEXT NOT NULL CHECK (review_status IN ('pending', 'approved', 'rejected', 'merged')) DEFAULT 'pending',
  merged_poem_id UUID REFERENCES poems(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  reviewer_id UUID REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE (import_job_id, source_row_number)
);

CREATE INDEX staged_poems_review_idx ON staged_poems(import_job_id, review_status);