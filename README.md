# PostgreSQL Replication Examples

This repository demonstrates three major PostgreSQL replication methods:
- **Streaming Asynchronous Replication**
- **Streaming Synchronous Replication**
- **Logical Replication (Publication/Subscription)**

---

## Overview

**Replication** in PostgreSQL is the process of copying and maintaining database objects (such as tables) across multiple databases in a distributed system. Replication is essential for high availability, fault tolerance, load balancing, and disaster recovery.

---

## What is Replication?

Replication ensures that changes made to a primary (master) database are also reflected in one or more replica (standby) databases. This enables:

- **High Availability:** Replica servers can take over if the primary fails.
- **Load Balancing:** Read traffic can be distributed across replicas.
- **Disaster Recovery:** Backups and failovers are easier to manage.

---

## Types of Replication in PostgreSQL

### 1. Streaming Replication (Physical Replication)
- **Asynchronous:** The primary does not wait for standby to confirm WAL (Write-Ahead Log) receipt. Some data loss is possible in failover.
- **Synchronous:** The primary waits for at least one standby to confirm WAL receipt before committing a transaction. No data loss in failover.

#### **Advantages:**
- **Real-time Replication:** Changes are sent to replicas almost immediately.
- **High Availability:** Enables quick failover to standby servers.
- **Read Scaling:** Replicas can serve read-only queries, spreading read load.
- **Disaster Recovery:** Maintains a near real-time copy for recovery.

#### **Disadvantages:**
- **Whole Database Only:** Replicates the entire database cluster, not individual tables.
- **Read-Only Standbys:** Standbys are read-only (except when promoted).
- **Version Compatibility:** Both primary and standby must use the same major PostgreSQL version.
- **Network Dependency:** Replication requires continuous network connectivity.
- **Storage Requirements:** Replicas require the same storage as the primary.

---

### 2. Logical Replication (Publication/Subscription)
- Replicates changes at the logical level (e.g., table rows).
- Allows selective replication (specific tables, not the whole database).
- Enables multi-master and cross-version replication.

#### **Advantages:**
- **Table-level Replication:** Replicate only specific tables.
- **Version Flexibility:** Can replicate between different PostgreSQL major versions.
- **Flexible Topologies:** Supports one-to-many, many-to-one, and bi-directional replication.
- **Minimized Downtime:** Easier upgrades and migrations.

#### **Disadvantages:**
- **Schema Management:** DDL (schema changes) are not replicated, only DML (data changes); schemas must be managed manually.
- **Initial Data Copy:** Initial table data copy may take time for large tables.
- **Potential Data Conflicts:** Care is needed with bi-directional or multi-master setups to prevent conflicts.
- **Performance Overhead:** Logical decoding can add CPU and I/O overhead.
- **Limited Data Types:** Some data types and operations may not be fully supported.

---

## Replication Setup: Directory Structure

- [`streaming-async/`](./streaming-async/): Streaming Asynchronous Replication setup
- [`streaming-sync/`](./streaming-sync/): Streaming Synchronous Replication setup
- [`logical-replication/`](./logical-replication/): Logical Replication (Publication/Subscription) setup

*Refer to each directory for full configuration examples and scripts.*

---

## Streaming Replication Setup (Async & Sync)

### Prerequisites

- PostgreSQL 10 or higher on both primary and standby
- Primary and standby servers must use the same major PostgreSQL version
- Network connectivity between primary and standby
- Sufficient disk space on both servers
- Superuser or sufficient privileges on both servers

### 1. Primary (Master) Server Configuration

**Edit `postgresql.conf`:**
```conf
listen_addresses = '*'
wal_level = replica
max_wal_senders = 10
wal_keep_size = 64
synchronous_commit = on  # For async, can be 'off' or 'local'
# For synchronous replication add:
# synchronous_standby_names = '2 (replica1, replica2)'
```

- `listen_addresses = '*'`: Accept connections from any IP.
- `wal_level = replica`: Enable WAL for replication.
- `max_wal_senders`: Max concurrent replication connections.
- `wal_keep_size`: Retain enough WAL files for standby catch-up.
- `synchronous_commit`: Set to `on` for sync, `off` or `local` for async.
- `synchronous_standby_names`: Names of synchronous standbys (for sync, see below).

**Edit `pg_hba.conf`:**
```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    replication     replicator      <replica_ip>/32         md5
```
Replace `<replica_ip>` with your replica server's IP.

**Create Replication User:**
```sql
CREATE ROLE replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD '123456';
```

---

### 2. Replica (Standby) Server Configuration

**Edit `postgresql.conf`:**
```conf
hot_standby = on
primary_conninfo = 'host=primary port=5432 user=replicator password=123456 application_name=replica1'
```
- `application_name` must be unique for each standby.

**Initialize the Standby:**
```sh
# Stop PostgreSQL if running
sudo systemctl stop postgresql

# Clear old data (CAUTION: this deletes all data!)
rm -rf /var/lib/postgresql/data/*

# Take a base backup from primary (run this on the replica)
PGPASSWORD=123456 pg_basebackup -h <primary_ip> -U replicator -D /var/lib/postgresql/data -Fp -Xs -P
```

For PostgreSQL 12+, create an empty `standby.signal` file after the backup:
```sh
touch /var/lib/postgresql/data/standby.signal
```

**Start PostgreSQL:**
```sh
sudo systemctl start postgresql
```

---

### 3. Asynchronous vs Synchronous Replication

#### Asynchronous Replication
- `synchronous_commit = off` (or omit)
- `synchronous_standby_names` is not set or is empty.
- The primary does NOT wait for the standby to confirm WAL receipt; possible data loss on failover.

#### Synchronous Replication
- `synchronous_commit = on`
- `synchronous_standby_names = '2 (replica1, replica2)'` (or as appropriate)
- The primary waits for acknowledgments from the specified standbys before confirming commit.

```conf
synchronous_standby_names = '2 (replica1, replica2)'
```

---

## Logical Replication (Publication/Subscription) Setup

See the [`logical-replication/`](./logical-replication/) directory for full examples.

### Prerequisites

- PostgreSQL 10 or higher on both publisher and subscriber
- Network connectivity between publisher and subscriber
- Matching table structure (schema) on both publisher and subscriber
- Superuser or sufficient privileges on both servers

---

### Step-by-Step Setup

#### 1. Configure the Publisher (Primary)

**Edit `postgresql.conf`:**
```conf
wal_level = logical
max_replication_slots = 10
max_wal_senders = 10
```
**Edit `pg_hba.conf`:**
```
host    replication     replicator      <subscriber_ip>/32      md5
host    all             replicator      <subscriber_ip>/32      md5
```
Replace `<subscriber_ip>` with the subscriber's IP.

**Create a replication user:**
```sql
CREATE ROLE replicator WITH LOGIN REPLICATION PASSWORD '123456';
```

---

#### 2. Create Publication on Publisher

**Create the table to replicate (if not exists):**
```sql
CREATE TABLE test_replication (
    id SERIAL PRIMARY KEY,
    note TEXT
);
```

**Create the publication:**
```sql
CREATE PUBLICATION main_pub FOR TABLE test_replication;
-- Or, to replicate all tables:
-- CREATE PUBLICATION main_pub FOR ALL TABLES;
```

---

#### 3. Configure the Subscriber (Secondary)

**Ensure table exists on subscriber with same schema:**
```sql
CREATE TABLE test_replication (
    id SERIAL PRIMARY KEY,
    note TEXT
);
```

**Create the subscription:**
```sql
CREATE SUBSCRIPTION sub1
  CONNECTION 'host=<publisher_ip> port=5432 dbname=<db_name> user=replicator password=123456'
  PUBLICATION main_pub;
```
Replace `<publisher_ip>` and `<db_name>` with your publisher's IP and database name.

---

## Notes and Tips

- Only DML (INSERT, UPDATE, DELETE) operations are replicated; DDL (schema changes) are not.
- Table structure must match on both publisher and subscriber.
- Use `SELECT * FROM pg_stat_replication;` on the primary to check streaming replication status.
- Use `SELECT * FROM pg_stat_subscription;` on the subscriber to check logical replication status.
- For detailed examples and scripts, see each method's respective directory.

---

## Support & Feedback

If you found this project helpful, please consider giving it a ⭐ star!  
Your feedback and encouragement motivate me to improve and share more open-source work.

---

## References

- [PostgreSQL High Availability, Load Balancing, and Replication](https://www.postgresql.org/docs/current/high-availability.html)
- [Logical Replication](https://www.postgresql.org/docs/current/logical-replication.html)
- [Streaming Replication](https://www.postgresql.org/docs/current/warm-standby.html)

---