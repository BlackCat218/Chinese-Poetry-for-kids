CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE content_status AS ENUM ('draft', 'in_review', 'published', 'archived');
CREATE TYPE content_source AS ENUM ('manual', 'workbook_import', 'trusted_reference');
CREATE TYPE media_kind AS ENUM ('image', 'audio');
CREATE TYPE user_role AS ENUM ('learner', 'parent', 'editor', 'admin');

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE,
  display_name TEXT NOT NULL,
  role user_role NOT NULL DEFAULT 'learner',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE dynasties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  start_year INTEGER,
  end_year INTEGER,
  description TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE authors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  dynasty_id UUID REFERENCES dynasties(id),
  biography TEXT,
  portrait_asset_url TEXT,
  UNIQUE (name, dynasty_id)
);

CREATE TABLE poems (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  author_id UUID REFERENCES authors(id),
  dynasty_id UUID REFERENCES dynasties(id),
  body TEXT NOT NULL,
  pinyin_lines JSONB NOT NULL DEFAULT '[]'::jsonb,
  translation TEXT,
  brief_analysis TEXT,
  detailed_analysis TEXT,
  creation_background TEXT,
  source_reference TEXT,
  source_kind content_source NOT NULL DEFAULT 'manual',
  source_confidence NUMERIC(3,2),
  status content_status NOT NULL DEFAULT 'draft',
  difficulty SMALLINT CHECK (difficulty BETWEEN 1 AND 5),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (jsonb_typeof(pinyin_lines) = 'array')
);

CREATE TABLE media_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kind media_kind NOT NULL,
  storage_key TEXT NOT NULL UNIQUE,
  public_url TEXT NOT NULL,
  alt_text TEXT,
  attribution TEXT,
  copyright_status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE poem_media (
  poem_id UUID NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
  media_id UUID NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
  purpose TEXT NOT NULL CHECK (purpose IN ('cover', 'detail_background', 'audio_reading')),
  sort_order SMALLINT NOT NULL DEFAULT 0,
  PRIMARY KEY (poem_id, media_id)
);

CREATE TABLE category_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  multiple_allowed BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type_id UUID NOT NULL REFERENCES category_types(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  UNIQUE (type_id, code)
);

CREATE TABLE poem_categories (
  poem_id UUID NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (poem_id, category_id)
);

CREATE TABLE historical_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  start_year INTEGER NOT NULL,
  end_year INTEGER,
  volume TEXT NOT NULL CHECK (volume IN ('early', 'late')),
  summary TEXT NOT NULL,
  sort_order INTEGER NOT NULL
);

CREATE TABLE event_poems (
  event_id UUID NOT NULL REFERENCES historical_events(id) ON DELETE CASCADE,
  poem_id UUID NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
  note TEXT,
  PRIMARY KEY (event_id, poem_id)
);

CREATE TABLE literary_schools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  cover_asset_url TEXT
);

CREATE TABLE literary_school_authors (
  school_id UUID NOT NULL REFERENCES literary_schools(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
  PRIMARY KEY (school_id, author_id)
);

CREATE TABLE literary_school_poems (
  school_id UUID NOT NULL REFERENCES literary_schools(id) ON DELETE CASCADE,
  poem_id UUID NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
  PRIMARY KEY (school_id, poem_id)
);

CREATE TABLE quiz_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poem_id UUID NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
  prompt TEXT NOT NULL,
  explanation TEXT,
  difficulty SMALLINT NOT NULL DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 5),
  status content_status NOT NULL DEFAULT 'draft',
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE quiz_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id UUID NOT NULL REFERENCES quiz_questions(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  is_correct BOOLEAN NOT NULL DEFAULT false,
  sort_order SMALLINT NOT NULL DEFAULT 0
);

CREATE TABLE user_poem_progress (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  poem_id UUID NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
  view_count INTEGER NOT NULL DEFAULT 0,
  quiz_attempt_count INTEGER NOT NULL DEFAULT 0,
  quiz_correct_count INTEGER NOT NULL DEFAULT 0,
  completed_at TIMESTAMPTZ,
  familiarity_score SMALLINT NOT NULL DEFAULT 0 CHECK (familiarity_score BETWEEN 0 AND 100),
  first_opened_at TIMESTAMPTZ,
  last_opened_at TIMESTAMPTZ,
  PRIMARY KEY (user_id, poem_id)
);

CREATE TABLE learning_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  poem_id UUID REFERENCES poems(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('open_poem', 'start_quiz', 'answer_quiz', 'complete_poem', 'add_bookshelf')),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_bookshelf_items (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  poem_id UUID NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  note TEXT,
  PRIMARY KEY (user_id, poem_id)
);

CREATE INDEX poems_status_idx ON poems(status);
CREATE INDEX poems_author_idx ON poems(author_id);
CREATE INDEX categories_type_idx ON categories(type_id, sort_order);
CREATE INDEX progress_last_opened_idx ON user_poem_progress(user_id, last_opened_at DESC);
CREATE INDEX learning_events_user_created_idx ON learning_events(user_id, created_at DESC);