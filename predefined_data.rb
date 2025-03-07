# frozen_string_literal: true

require_relative './database'

db = create_database_connection
db.execute <<-SQL
  INSERT INTO pages (id, title, slug, content, 'state', 'published_at')
  VALUES (1, 'Home', 'home', 'Welcome!\n\nHappy blogging!', 'published', datetime('now'))
  ON CONFLICT DO UPDATE SET published_at = datetime('now') WHERE id = excluded.id;
SQL

db.execute <<-SQL
  INSERT INTO pages (id, title, slug, content, 'state', 'published_at')
  VALUES (2, "Example Page", 'example-page', 'This is an example page', 'published', datetime('now'))
  ON CONFLICT DO UPDATE SET published_at = datetime('now') WHERE id = excluded.id;
SQL

db.execute <<-SQL
  INSERT INTO posts (id, title, slug, content, 'state', 'published_at')
  VALUES (1, "Hello World!", 'hello-world', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur et venenatis mi. Duis accumsan quam ac nulla sagittis interdum. Mauris aliquet facilisis sapien, eget luctus turpis vehicula ac. Integer porttitor ex at risus pretium rutrum. Suspendisse euismod mi in dolor fringilla, nec lacinia enim euismod. Donec quis sagittis eros, sit amet dignissim lectus. Pellentesque id lacinia sem. Vestibulum tellus ipsum, venenatis nec tortor at, pretium egestas ex. Maecenas vitae pretium mi. Etiam nec augue et quam semper consectetur vel vel tortor.', 'published', datetime('now'))
  ON CONFLICT DO UPDATE SET published_at = datetime('now') WHERE id = excluded.id;
SQL

db.execute <<-SQL
  INSERT INTO navlinks (id, name, position, url) VALUES (1, 'Home', 1, '/') ON CONFLICT DO NOTHING;
SQL
db.execute <<-SQL
  INSERT INTO navlinks (id, name, position, url) VALUES (2, 'Blog', 2, '/blog') ON CONFLICT DO NOTHING;
SQL
db.execute <<-SQL
  INSERT INTO navlinks (id, name, position, url) VALUES (3, 'Example Page', 2, '/example-page') ON CONFLICT DO NOTHING;
SQL

db.execute <<-SQL
  INSERT INTO settings (id, key, value) VALUES (1, 'site.title', "Lorem Ipsum") ON CONFLICT DO NOTHING;
SQL

db.close
