#!/bin/bash -e

# Ensure the app has the correct permissions
chown -R nobody:nogroup /app

if [ "${1}" == "bundle" ] && [ "${2}" == "exec" ] && [ "${3}" == "puma" ]; then
  if [ ! -f storage/db.sqlite3 ]; then
    echo "Creating database..."
    touch storage/db.sqlite3
  fi

  ruby ddl.rb
  ruby predefined_data.rb
fi
# Execute the given command
exec "$@"
