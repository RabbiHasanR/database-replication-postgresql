#!/bin/bash
set -e

# Start Postgres in the background
docker-entrypoint.sh postgres &

# Wait for local Postgres to be ready
until psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c '\q' 2>/dev/null; do
  echo "Waiting for local PostgreSQL to be ready..."
  sleep 2
done

# Create the replicated table if it doesn't exist
psql -U postgres -d "$POSTGRES_DB"  <<'EOSQL'
CREATE TABLE IF NOT EXISTS test_replication (
    id SERIAL PRIMARY KEY,
    note TEXT
);
EOSQL

echo "Subscriber table created (if not exists)."

# Wait for publisher to be ready
PUBLISHER_HOST=${PUBLISHER_HOST:-publisher}
until pg_isready -h "$PUBLISHER_HOST" -p 5432; do
  echo "Waiting for publisher at $PUBLISHER_HOST..."
  sleep 2
done

# Create the subscription if it doesn't already exist
EXISTING_SUBSCRIPTION=$(psql -U postgres -tAc "SELECT 1 FROM pg_subscription WHERE subname = 'sub1'")
if [ "$EXISTING_SUBSCRIPTION" != "1" ]; then
  psql -U postgres -d "$POSTGRES_DB" -c "
    CREATE SUBSCRIPTION sub1
      CONNECTION 'host=$PUBLISHER_HOST port=5432 user=$REPLICATOR_USER password=$REPLICATOR_PASSWORD dbname=$POSTGRES_DB'
      PUBLICATION main_pub;
  "
  echo "Logical replication subscription created."
else
  echo "Subscription 'sub1' already exists, skipping creation."
fi

# Keep container running by waiting on postgres process
wait
