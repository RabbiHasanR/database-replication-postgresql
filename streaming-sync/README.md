# Streaming Synchronous Replication Example

This directory demonstrates how to set up **PostgreSQL Streaming Synchronous Replication** using Bash scripts, configuration files, Docker, Docker Compose, and custom Dockerfiles for both primary and replica nodes.

---

## Overview

**Streaming Synchronous Replication** allows a standby (replica) PostgreSQL server to continuously receive WAL (Write-Ahead Log) changes from a primary (master) server, but unlike asynchronous replication, the primary **waits for at least one replica** to confirm receipt of the transaction before it is considered committed. This ensures zero data loss on failover, at the cost of a slight increase in transaction latency.

> **This example uses a one-master, two-replica approach:**  
> You will find one primary container and two replica containers defined in the Docker Compose setup.

Both primary and replica are launched as separate containers, built from their own Dockerfiles, and orchestrated with Docker Compose. Initialization and configuration are automated using Bash scripts and mounted configuration files.

---

## Primary Directory: File Explanations

The `primary/` directory contains everything needed to build and initialize the primary (master) PostgreSQL node for synchronous replication.

### `Dockerfile`
- **Purpose:**  
  Builds a custom PostgreSQL image for the primary server.
- **Why it's written this way:**  
  - Starts from the official `postgres` image for stability and compatibility.
  - Copies in the custom `postgresql.conf` and `pg_hba.conf` to configure replication-specific settings and access control.
  - Copies and sets the `init-primary.sh` script as the entrypoint or startup command, ensuring initialization is automated when the container starts.
- **How it works:**  
  When you build the image, it includes all custom configs and the init script, so when the container is launched, it is ready for synchronous replication—with no manual setup required.

### `postgresql.conf`
- **Purpose:**  
  Main PostgreSQL configuration file, tailored for synchronous replication.
- **Why it's written this way:**  
  - Sets `wal_level = replica` to enable WAL sending for physical replication.
  - Configures `max_wal_senders` and `wal_keep_size` for concurrent replication streams and WAL retention.
  - Uses `listen_addresses = '*'` so the container can accept connections from other hosts (the replica).
  - Sets `synchronous_commit = on` to enforce synchronous replication.
  - Sets `synchronous_standby_names` to specify which replicas must acknowledge before commit.
- **How it works:**  
  The primary PostgreSQL server starts with these settings, making it ready to accept replication connections and will only confirm transactions when the configured standby acknowledges receipt.

### `pg_hba.conf`
- **Purpose:**  
  Controls which users and hosts can connect (host-based authentication).
- **Why it's written this way:**  
  - Explicitly allows the `replicator` user to connect from the replica container's network.
  - Uses `md5` authentication for password protection.
- **How it works:**  
  Ensures the replica server can connect over the Docker network and authenticate for replication.

### `init-primary.sh`
- **Purpose:**  
  Bash script to initialize the primary Postgres instance on container startup.
- **Why it's written this way:**  
  - Automates database initialization, creation of the replication user, and ensures all configs are placed correctly.
- **How it works:**  
  When the primary container starts, this script runs automatically, setting up everything for streaming synchronous replication. It makes the process repeatable and container-friendly.

---

## Replica Directory: File Explanations

The `replica/` directory contains all files necessary to build and initialize a PostgreSQL replica (standby) node for streaming synchronous replication. For multi-replica setups, each replica can reuse this same structure with minor changes (such as container name or application name).

**The following explains the purpose and logic of each file in the replica directory:**

### `Dockerfile`
- **Purpose:**  
  Builds a custom PostgreSQL image for the replica server.
- **Why it's written this way:**  
  - Uses the official `postgres` image as base.
  - Copies `postgresql.conf` and `pg_hba.conf` for correct replica configuration and authentication.
  - Copies the `init-replica.sh` script for automated setup.
- **How it works:**  
  Ensures every time a replica container is built, it includes all the necessary configs and logic for initialization—no manual config is required at runtime.

### `postgresql.conf`
- **Purpose:**  
  Main PostgreSQL configuration file for running as a replica.
- **Why it's written this way:**  
  - `hot_standby = on` enables read-only queries on the replica.
  - Does not set `wal_level` or `max_wal_senders` (not required for replica).
  - Includes `primary_conninfo`  to instruct the replica how to connect to the primary for streaming WAL.
  - Optionally, sets `application_name` to match `synchronous_standby_names` on the primary.
- **How it works:**  
  Starts PostgreSQL in standby mode and ensures it can connect to the primary for streaming replication and synchronous acknowledgment.

### `init-replica.sh`
- **Purpose:**  
  Bash script to automate initialization of the replica PostgreSQL instance on container startup.
- **Why it's written this way:**  
  - Waits for the primary server to become available (using `pg_isready` or similar).
  - Runs `pg_basebackup` to copy the initial database state from the primary.
  - Sets up `standby.signal` for PostgreSQL 12+ to enter standby/replica mode.
  - Starts PostgreSQL in replica mode.
- **How it works:**  
  When the replica container starts, this script waits for the primary, clones its data with `pg_basebackup`, configures standby mode, and starts PostgreSQL as a synchronous replica. This automation makes adding more replicas easy—just reuse the same files.

---

## Docker Compose File Explanation

The `docker-compose.yml` file orchestrates the entire setup. Here’s how it works and why it’s written this way:

- **Defines Two Services:**  
  - `primary`: The PostgreSQL master node, built from `primary/Dockerfile`.
  - `replica1`: The PostgreSQL standby node, built from `replica-one/Dockerfile`.
  - `replica2`: The PostgreSQL standby node, built from `replica-two/Dockerfile`.

- **Build Contexts:**  
  Each service uses its corresponding subdirectory as the build context, ensuring the correct Dockerfile and files are used.

- **Service Names as Hostnames:**  
  Docker Compose automatically provides service names (`primary`, `replica1`, `replica2`) as internal DNS hostnames, so the replica can reliably connect to the primary.

- **Environment Variables:**  
  Set environment variables for PostgreSQL passwords and user configuration, ensuring repeatable and secure deployments.

- **Volumes:**  
  mount volumes for data persistence.

- **Network:**  
  By default, both containers are on the same Docker Compose bridge network, allowing direct communication.

**How it works:**  
When you run `docker compose up --build`, Docker Compose:
1. Builds each image using the correct Dockerfile and context.
2. Starts the primary first, running its initialization logic.
3. Starts the replica, which waits for the primary to be ready, then clones its data and enters streaming synchronous replication mode.
4. Both containers remain running, with the replica streaming WAL changes from the primary and sending acknowledgments for synchronous commit.

---

## How to Use

1. **Clone this repository and enter the `streaming-sync/` directory.**

2. **Ensure Docker and Docker Compose are installed on your system.**

3. **Build and run the containers:**
    ```sh
    docker compose up --build
    ```
    or (older Compose versions)
    ```sh
    docker-compose up --build
    ```

4. **Verify master-slave replication status:**
    - On the primary, check replication state:
      ```sh
      docker exec -it primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"
      ```
    - On each replica, check recovery status:
      ```sh
      docker exec -it replica1 psql -U postgres -c "SELECT * FROM pg_stat_wal_receiver;"
      docker exec -it replica2 psql -U postgres -c "SELECT * FROM pg_stat_wal_receiver;"
      ```
    - *(Note: use `pg_stat_replication` on the primary and `pg_stat_wal_receiver` on replicas to check streaming replication health.if these query return row then
    replication working.)*

5. **Test replication:**
    - Create the test table in the primary before inserting data:
      ```sh
      docker exec -it primary psql -U postgres -c "CREATE TABLE test_replication(id SERIAL PRIMARY KEY, note TEXT);"
      ```
    - Insert data into the primary:
      ```sh
      docker exec -it primary psql -U postgres -c "INSERT INTO test_replication(note) VALUES('Hello from primary');"
      ```
    - Check data on the replica1:
      ```sh
      docker exec -it replica1 psql -U postgres -c "SELECT * FROM test_replication;"
      ```
    - Check data on the replica2:
      ```sh
      docker exec -it replica2 psql -U postgres -c "SELECT * FROM test_replication;"
      ```

---

## Notes

- This setup is for demonstration and learning purposes. For production, use secure credentials, monitoring, and proper failover handling.
- Requires PostgreSQL 12 or newer.
- The containers communicate using Docker Compose's default network; use service names (`primary`, `replica`) as hostnames.

---

## File Structure Example

```
streaming-sync/
├── docker-compose.yml
├── primary/
│   ├── Dockerfile.primary
│   ├── postgresql.conf
│   ├── pg_hba.conf
│   └── init-primary.sh
├── replica-one/
│   ├── Dockerfile.replica
│   ├── postgresql.conf
│   └── init-replica.sh
── replica-two/
│   ├── Dockerfile.replica
│   ├── postgresql.conf
│   └── init-replica.sh
└── README.md
```

---

## Further Resources

- [PostgreSQL Streaming Replication Docs](https://www.postgresql.org/docs/current/warm-standby.html)
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---