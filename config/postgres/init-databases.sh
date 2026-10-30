#!/bin/bash
set -e

# Create application databases if they don't exist
for db in n8n litellm langfuse openwebui; do
    if ! psql -U "$POSTGRES_USER" -tc "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -q 1; then
        echo "Creating database: $db"
        psql -U "$POSTGRES_USER" -tc "CREATE DATABASE \"$db\""
    else
        echo "Database already exists: $db"
    fi
done

echo "Database initialization complete."
