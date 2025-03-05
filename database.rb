# frozen_string_literal: true

require 'sqlite3'

def create_database_connection(result_as_hash: true)
  path = 'storage/db.sqlite3'
  File.write(path, '') unless File.exist?(path)

  db = SQLite3::Database.new(path)
  db.results_as_hash = result_as_hash
  db
end
