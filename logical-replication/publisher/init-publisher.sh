#!/bin/bash
set -e

# Copy your custom configs into the data directory
cp /etc/postgresql/postgresql.conf /var/lib/postgresql/data/postgresql.conf
cp /etc/postgresql/pg_hba.conf /var/lib/postgresql/data/pg_hba.conf

# Make sure permissions are correct
chown postgres:postgres /var/lib/postgresql/data/postgresql.conf /var/lib/postgresql/data/pg_hba.conf

# Create replication user if not exists, create table, grant privileges, and create publication
psql -U postgres -d "$POSTGRES_DB"  <<-EOSQL
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'replicator') THEN
            CREATE ROLE replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD '123456';
        END IF;
    END
    \$\$;

    -- Create the replication table if it doesn't exist
    CREATE TABLE IF NOT EXISTS test_replication (
        id SERIAL PRIMARY KEY,
        note TEXT
    );

    -- Grant privileges to replicator
    GRANT ALL PRIVILEGES ON TABLE test_replication TO replicator;

    -- Create publication if it doesn't exist
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'main_pub') THEN
            CREATE PUBLICATION main_pub FOR TABLE test_replication;
        END IF;
    END
    \$\$;
EOSQL