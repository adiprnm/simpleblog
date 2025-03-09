# frozen_string_literal: true

require_relative './database'

db = create_database_connection
db.execute <<-SQL
  INSERT INTO pages (id, title, slug, content, 'state', 'published_at')
  VALUES (1, 'Home', 'home', 'Welcome!\n\nHappy blogging!', 'published', datetime('now'))
  ON CONFLICT DO NOTHING;
SQL

db.execute <<-SQL
  INSERT INTO navlinks (id, name, position, url) VALUES (1, 'Home', 1, '/') ON CONFLICT DO NOTHING;
SQL
db.execute <<-SQL
  INSERT INTO navlinks (id, name, position, url) VALUES (2, 'Blog', 2, '/blog') ON CONFLICT DO NOTHING;
SQL

db.execute <<-SQL
  INSERT INTO settings (id, key, value) VALUES (1, 'site.title', "My Blog") ON CONFLICT DO NOTHING;
SQL
db.execute <<-SQL
  INSERT INTO settings (id, key, value) VALUES (2, 'site.description', "Small blog is awesome!")
  ON CONFLICT DO NOTHING;
SQL
db.execute <<-SQL
  INSERT INTO settings (id, key, value) VALUES (3, 'site.twitter.username', "john_doe")
  ON CONFLICT DO NOTHING;
SQL
db.execute <<-SQL
  INSERT INTO settings (id, key, value) VALUES (4, 'site.text.footer', 'Written by human. Grab the [RSS Feed](/feed.xml)')
  ON CONFLICT DO NOTHING;
SQL
db.execute <<-SQL
  INSERT INTO settings (id, key, value) VALUES (5, 'site.og_image', null)
  ON CONFLICT DO NOTHING;
SQL

db.close
