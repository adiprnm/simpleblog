# frozen_string_literal: true

require_relative './database'

def migrate!
  db = create_database_connection
  db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS posts (
    id INTEGER PRIMARY KEY,
    title TEXT,
    slug TEXT UNIQUE,
    state TEXT,
    published_at TIMESTAMP,
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
  SQL

  db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS pages (
    id INTEGER PRIMARY KEY,
    title TEXT,
    slug TEXT UNIQUE,
    state TEXT,
    published_at TIMESTAMP,
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
  SQL

  db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS navlinks (
    id INTEGER PRIMARY KEY,
    name TEXT,
    position INTEGER,
    url TEXT
  );
  SQL

  db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS settings (
    id INTEGER PRIMARY KEY,
    key TEXT,
    value TEXT
  );
  SQL

  db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS visits (
    id INTEGER PRIMARY KEY,
    entry_id INTEGER,
    entry_type TEXT,
    browser TEXT,
    device TEXT,
    country TEXT,
    referer TEXT,
    visit_hash TEXT,
    date DATE,
    entry_name TEXT,
    entry_path TEXT,
    visitor_id TEXT,
    UNIQUE(visit_hash)
  )
  SQL

  db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS tags (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    taggable_type TEXT,
    taggable_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(name, taggable_type, taggable_id)
  );
  SQL

  db.close
end

migrate!
