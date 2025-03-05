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

  db.close
end

migrate!
