# Logical Replication Example

This directory demonstrates how to set up **PostgreSQL Logical Replication** using Bash scripts, configuration files, Docker, Docker Compose, and custom Dockerfiles for both publisher (master) and subscriber (replica) nodes.

---

## Overview

**Logical Replication** in PostgreSQL enables fine-grained, table-level replication using a publication/subscription model. Unlike streaming replication, logical replication lets you replicate specific tables and is suitable for upgrades, partial data sharing, and heterogeneous environments.

> **This example uses a one-publisher, one-subscriber approach:**  
> You will find one publisher container and one subscriber container defined in the Docker Compose setup. This reflects a practical scenario where multiple subscribers receive changes from the same publication, supporting scalability and flexible data distribution.

Publisher and subscribers are launched as separate containers, built from their own Dockerfiles, and orchestrated with Docker Compose. Initialization and configuration are automated using Bash scripts and mounted configuration files.

---

## Publisher Directory: File Explanations

The `publisher/` directory contains everything needed to build and initialize the publisher (master) PostgreSQL node for logical replication.

### `Dockerfile`
- **Purpose:**  
  Builds a custom PostgreSQL image for the publisher server.
- **Why it's written this way:**  
  - Uses the official `postgres` image for reliability.
  - Copies in the custom `postgresql.conf` and `pg_hba.conf` to enable logical replication and access control.
  - Copies and sets the `init-publisher.sh` script as the entrypoint or startup command, for automated initialization.
- **How it works:**  
  When you build the image, it includes all configs and the init script, so the container is ready for logical replication when launched.

### `postgresql.conf`
- **Purpose:**  
  Main PostgreSQL configuration file, tailored for logical replication.
- **Why it's written this way:**  
  - Sets `wal_level = logical` to enable logical replication.
  - Configures `max_replication_slots` and `max_wal_senders` for supporting multiple subscribers.
  - Uses `listen_addresses = '*'` for network accessibility.
- **How it works:**  
  The publisher starts with these settings, ready to accept logical replication connections and stream changes to subscribers.

### `pg_hba.conf`
- **Purpose:**  
  Controls which users and hosts can connect (host-based authentication).
- **Why it's written this way:**  
  - Allows the replication user to connect from the subscribers' network.
  - Uses `md5` authentication for password protection.
- **How it works:**  
  Ensures subscribers can connect over Docker network and authenticate for logical replication.

### `init-publisher.sh`
- **Purpose:**  
  Bash script to initialize the publisher on container startup.
- **Why it's written this way:**  
  - Automates creation of the replication user and the publication.
  - creates test tables
- **How it works:**  
  When the publisher container starts, this script runs, setting up logical replication and making the process repeatable and container-friendly.

---

## Subscriber Directory: File Explanations

The `subscriber/` directory contains all files necessary to build and initialize a PostgreSQL subscriber (replica) node for logical replication. For setups with multiple subscribers, each subscriber can use this same structure with minor adjustments (such as container name or subscription name).

### `Dockerfile`
- **Purpose:**  
  Builds a custom PostgreSQL image for the subscriber server.
- **Why it's written this way:**  
  - Uses the official `postgres` image as base.
  - Copies the `init-subscriber.sh` script for automated setup.
- **How it works:**  
  Ensures every subscriber container is built with all configs and logic for initialization—no manual config required at runtime.

### `init-subscriber.sh`
- **Purpose:**  
  Bash script to automate initialization of the subscriber PostgreSQL instance.
- **Why it's written this way:**  
  - Waits for the publisher to become available.
  - Creates the required tables to match the publisher’s schema.
  - Creates the subscription to the publisher’s publication.
- **How it works:**  
  The script runs on container startup, sets up the schema, creates the subscription, and starts streaming changes from the publisher.

---

## Docker Compose File Explanation

The `docker-compose.yml` file orchestrates the entire setup. Here’s how it works and why it’s written this way:

- **Defines Three Services:**  
  - `publisher`: The PostgreSQL master node, built from `publisher/Dockerfile`.
  - `subscriber1`: Two PostgreSQL subscriber nodes, both built from `subscriber/Dockerfile`.

- **Build Contexts:**  
  Each service uses its corresponding subdirectory as the build context, ensuring the correct Dockerfile and files are used.

- **Service Names as Hostnames:**  
  Docker Compose provides service names (`publisher`, `subscriber1`) as internal DNS hostnames, so subscribers can reliably connect to the publisher.

- **Environment Variables:**  
  Set environment variables for PostgreSQL passwords and user configuration.

- **Volumes:**  
  mount volumes for data persistence.

- **Network:**  
  By default, all containers are on the same Docker Compose bridge network, allowing direct communication.

**How it works:**  
When you run `docker compose up --build`, Docker Compose:
1. Builds each image using the correct Dockerfile and context.
2. Starts the publisher first, running its initialization logic.
3. Starts both subscribers, which wait for the publisher to be ready, create their schemas, and establish logical subscriptions.
4. All containers remain running, with the subscribers receiving replicated changes from the publisher.

---

## How to Use

1. **Clone this repository and enter the `logical-replication/` directory.**

2. **Ensure Docker and Docker Compose are installed on your system.**

3. **Build and run the containers:**
    ```sh
    docker compose up --build
    ```
    or (older Compose versions)
    ```sh
    docker-compose up --build
    ```

4. **Test replication:**
    - Insert data into the publisher:
      ```sh
      docker exec -it publisher psql -U postgres -c "INSERT INTO test_replication(note) VALUES('Hello from publisher');"
      ```
    - Check data on the subscribers:
      ```sh
      docker exec -it subscriber1 psql -U postgres -c "SELECT * FROM test_replication;"
      docker exec -it subscriber2 psql -U postgres -c "SELECT * FROM test_replication;"
      ```

---

## Notes

- Only DML operations (INSERT, UPDATE, DELETE) are replicated; DDL (schema changes) are **not**.
- Publisher and subscribers can be different PostgreSQL major versions (version 10+).
- For production, use secure credentials, monitoring, and robust error handling.

---

## File Structure Example

```
logical-replication/
├── docker-compose.yml
├── publisher/
│   ├── Dockerfile.pub
│   ├── postgresql.conf
│   ├── pg_hba.conf
│   └── init-publisher.sh
├── subscriber-one/
│   ├── Dockerfile.sub
│   └── init-subscriber.sh
└── README.md
```

---

## Further Resources

- [PostgreSQL Logical Replication Docs](https://www.postgresql.org/docs/current/logical-replication.html)
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---