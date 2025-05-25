#!/bin/bash
set -e

# Wait for PostgreSQL to be ready in this container
until pg_isready -h localhost -p 5432; do
  echo "Waiting for local PostgreSQL..."
  sleep 2
done

# Create the replicated table if it doesn't exist
psql -U postgres <<'EOSQL'
CREATE TABLE IF NOT EXISTS test_replication (
    id SERIAL PRIMARY KEY,
    note TEXT
);
EOSQL

echo "Subscriber table created (if not exists)."

# Wait for publisher to be ready (adjust PUBLISHER_HOST as needed)
PUBLISHER_HOST=${PUBLISHER_HOST:-publisher}
until pg_isready -h "$PUBLISHER_HOST" -p 5432; do
  echo "Waiting for publisher at $PUBLISHER_HOST..."
  sleep 2
done

# Create the subscription if it doesn't already exist
psql -U postgres <<EOSQL
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT 1 FROM pg_subscription WHERE subname = 'my_sub') THEN
     CREATE SUBSCRIPTION my_sub
       CONNECTION 'host=$PUBLISHER_HOST port=5432 user=replicator password=123456 dbname=pubdb'
       PUBLICATION my_pub;
   END IF;
END
\$\$;
EOSQL

echo "Logical replication subscription created (if not exists)."

# Done