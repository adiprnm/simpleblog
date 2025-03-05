#!/bin/bash

echo "Removing database..."
rm storage/db.sqlite3
echo "Creating database..."
ruby ddl.rb
echo "Adding predefined data to database..."
ruby predefined_data.rb
echo "Done! You're ready to go!"
