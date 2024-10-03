To set up PostgreSQL replication with Docker on a Windows system where you have a primary database and two replicas, you can follow these steps. This setup will allow your application to read and write to the primary database, and the replicas will replicate data from the primary. You will also be able to temporarily disconnect a replica for development purposes.

Here’s a step-by-step guide to achieve this:

### 1. **Set Up Docker and Docker Compose**

Ensure Docker and Docker Compose are installed on your Windows system. You can download them from the [Docker website](https://www.docker.com/products/docker-desktop).

### 2. **Create Docker Compose File**

Create a `docker-compose.yml` file to define your PostgreSQL containers. This file will define three PostgreSQL instances: one primary and two replicas.

```yaml
version: '3.9'

services:
  postgres_primary:
    image: postgres:14
    container_name: postgres_primary
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: mysecretpassword
    volumes:
      - postgres_primary_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - postgres_network

  postgres_replica1:
    image: postgres:14
    container_name: postgres_replica1
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: mysecretpassword
    volumes:
      - postgres_replica1_data:/var/lib/postgresql/data
    networks:
      - postgres_network

  postgres_replica2:
    image: postgres:14
    container_name: postgres_replica2
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: mysecretpassword
    volumes:
      - postgres_replica2_data:/var/lib/postgresql/data
    networks:
      - postgres_network

volumes:
  postgres_primary_data:
    driver: local
  postgres_replica1_data:
    driver: local
  postgres_replica2_data:
    driver: local

networks:
  postgres_network:
    driver: bridge
```

### 3. **Configure Replication**

Create a directory for configuration files and add a `init-replica.sh` script that configures replication on the replicas.

#### `init-replica.sh`

```bash
#!/bin/bash
set -e

# Configure replication on primary
psql -U postgres -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_password';"
psql -U postgres -c "ALTER SYSTEM SET wal_level = replica;"
psql -U postgres -c "ALTER SYSTEM SET max_wal_senders = 3;"
psql -U postgres -c "ALTER SYSTEM SET wal_keep_size = 16MB;"
psql -U postgres -c "SELECT pg_reload_conf();"

# Configure replica
echo "primary_conninfo = 'host=postgres_primary port=5432 user=replicator password=replicator_password'" >> /var/lib/postgresql/data/postgresql.conf
echo "standby_mode = on" >> /var/lib/postgresql/data/recovery.conf
pg_basebackup -h postgres_primary -U replicator -D /var/lib/postgresql/data -Fp -Xs -P -R
```

#### Adding the Script to Docker Containers

Modify the `docker-compose.yml` to include the initialization script and run it in the replica containers. You can use the `Dockerfile` to copy the script and run it.

For each replica service, add:

```yaml
    build:
      context: .
      dockerfile: Dockerfile.replica
```

#### `Dockerfile.replica`

```Dockerfile
FROM postgres:14

COPY init-replica.sh /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/init-replica.sh
```

### 4. **Run Docker Compose**

Run Docker Compose to start the PostgreSQL containers:

```sh
docker-compose up -d
```

### 5. **Connect to Primary and Test Replication**

1. **Connect to Primary:**

   Use `psql` or any database client to connect to `postgres_primary` at `localhost:5432`.

2. **Check Replication:**

   Verify that replication is working by connecting to the replicas and checking if they are receiving data from the primary.

   ```sh
   docker exec -it postgres_replica1 psql -U postgres -c "SELECT * FROM pg_stat_replication;"
   ```

### 6. **Temporarily Disconnect a Replica**

To disconnect a replica for development:

1. **Stop Replica Container:**

   ```sh
   docker stop postgres_replica1
   ```

2. **Reconnect Replica:**

   Once your development work is done, you can start the replica again:

   ```sh
   docker start postgres_replica1
   ```

### 7. **Clean Up**

When you’re finished with development or testing:

1. **Remove Replica Data (if needed):**

   If you need to reset a replica, you might want to remove its data volume:

   ```sh
   docker-compose down -v
   ```

2. **Recreate Containers:**

   Recreate containers to apply any configuration changes:

   ```sh
   docker-compose up -d
   ```

### Summary

- **Primary Database**: Handles read and write operations.
- **Replicas**: Replicate data from the primary and can be temporarily disconnected for development.
- **Volumes**: Ensure data persistence and isolation for each database instance.
- **Docker Compose**: Simplifies the setup and management of multiple containers.

This setup allows you to have a functional PostgreSQL replication environment with the flexibility to manage your replicas as needed.



To set up your PostgreSQL replication with an initial database state from a dump, you need to follow these steps:

1. **Copy the Dump File to the Primary Database Container**
2. **Restore the Dump into the Primary Database**
3. **Ensure the Replication Configuration**
4. **Start the Replica Containers**

Here’s how to handle each step:

### 1. **Copy the Dump File to the Primary Database Container**

First, ensure that you have the PostgreSQL dump file (e.g., `initial_dump.sql`) ready. You can use `docker cp` to copy the dump file into the running primary PostgreSQL container.

```sh
docker cp /path/to/initial_dump.sql postgres_primary:/initial_dump.sql
```

### 2. **Restore the Dump into the Primary Database**

After copying the dump file, you need to restore it into your primary PostgreSQL database. Connect to the container and use `psql` to restore the dump.

```sh
docker exec -it postgres_primary bash
psql -U postgres -f /initial_dump.sql
```

This will restore the dump into the `postgres` database or any other database specified in the dump file.

### 3. **Ensure the Replication Configuration**

Make sure that your primary PostgreSQL is configured correctly for replication. This should be done either in the `postgresql.conf` file or using SQL commands. 

For your replication setup to work, ensure these settings are in place:

- **`wal_level`** should be set to `replica`
- **`max_wal_senders`** should be set to a value greater than the number of replicas
- **`wal_keep_size`** should be set to ensure that enough WAL logs are retained

You can set these by connecting to the primary PostgreSQL container and running:

```sh
docker exec -it postgres_primary psql -U postgres -c "ALTER SYSTEM SET wal_level = replica;"
docker exec -it postgres_primary psql -U postgres -c "ALTER SYSTEM SET max_wal_senders = 3;"
docker exec -it postgres_primary psql -U postgres -c "ALTER SYSTEM SET wal_keep_size = 16MB;"
docker exec -it postgres_primary psql -U postgres -c "SELECT pg_reload_conf();"
```

### 4. **Configure Replicas**

If you haven’t already, make sure your replica configurations are set up. Here’s a summary of the steps you should follow:

- **Primary Configuration**:
  Ensure that `pg_hba.conf` allows replication connections from replicas.

  ```sh
  # Add to pg_hba.conf on the primary
  host replication replicator <replica-ip>/32 md5
  ```

- **Replica Initialization**:
  Make sure the replicas are correctly initialized. They should copy data from the primary and be configured to start in replication mode.

Here's an example of a script that should run when initializing the replica (usually placed in the Dockerfile):

#### `init-replica.sh`

```bash
#!/bin/bash
set -e

# Wait for primary to be available
until pg_isready -h postgres_primary -p 5432 -U postgres; do
  echo "Waiting for primary to be ready..."
  sleep 2
done

# Ensure replication role exists on primary
psql -U postgres -h postgres_primary -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_password';"

# Initialize the replica from the primary
pg_basebackup -h postgres_primary -U replicator -D /var/lib/postgresql/data -Fp -Xs -P -R
```

Ensure the script is executable and included in your Dockerfile as shown previously.

### 5. **Restart Containers**

Once you have everything set up, restart your containers:

```sh
docker-compose down
docker-compose up -d
```

### Summary

1. **Copy the dump file** into the primary PostgreSQL container.
2. **Restore the dump** using `psql`.
3. **Ensure replication configuration** is correct on the primary.
4. **Initialize and start replicas** to start replicating from the primary.

By following these steps, you will have your PostgreSQL setup with an initial dump and replication configured properly.


### Restore the dummy dB
```
pg_restore -U postgres -d postgres /dummy.sql
```

To incorporate the dump file located at `D:\Workplace\CMPFO\postgre-distribution\dummy.sql` into your PostgreSQL setup using Docker, follow these steps:

### Step-by-Step Guide

#### 1. **Prepare Your Docker Setup**

Ensure your Docker Compose setup is ready, as described previously.

#### 2. **Copy the Dump File to the Primary Database Container**

1. **Ensure Your Containers Are Running:**

   Make sure your Docker containers are up and running:

   ```sh
   docker-compose up -d
   ```

2. **Copy the Dump File to the Primary Container:**

   Use the `docker cp` command to copy your dump file from your local filesystem to the primary PostgreSQL container:

   ```sh
   docker cp "D:\Workplace\CMPFO\postgre-distribution\dummy.sql" postgres_primary:/dummy.sql
   ```

   Note: The Windows path should be in quotes to handle backslashes correctly.

#### 3. **Restore the Dump into the Primary Database**

1. **Connect to the Primary Container:**

   Start a shell session in the primary PostgreSQL container:

   ```sh
   docker exec -it postgres_primary bash
   ```

2. **Restore the Dump File:**

   Use `psql` to restore the database from the dump file. Run:

   ```sh
   psql -U postgres -f /dummy.sql

   ```

   if error
   ```
   docker exec -it postgres_primary psql -U postgres
   CREATE ROLE readonly;
   CREATE ROLE readonly LOGIN; # hopefully not need

   pg_restore -U postgres -d postgres /dummy.sql


   ```

   This command will execute the SQL commands from `dummy.sql` and restore your database.

#### 4. **Verify Replication**

1. **Create Some Test Data in the Primary:**

   To ensure replication is working, you can create some additional test data:

   ```sh
   docker exec -it postgres_primary psql -U postgres -c "CREATE TABLE test_table (id SERIAL PRIMARY KEY, data TEXT);"
   docker exec -it postgres_primary psql -U postgres -c "INSERT INTO test_table (data) VALUES ('Test data');"
   ```

2. **Check Replication on the Replicas:**

   Verify if the test data is replicated to the replica containers:

   ```sh
   docker exec -it postgres_replica1 psql -U postgres -c "SELECT * FROM test_table;"
   docker exec -it postgres_replica2 psql -U postgres -c "SELECT * FROM test_table;"
   ```

   You should see the data you inserted into the primary database.

#### 5. **Disconnect and Reconnect Replicas**

1. **Temporarily Disconnect a Replica:**

   To disconnect a replica for development purposes:

   ```sh
   docker stop postgres_replica1
   ```

2. **Reconnect the Replica:**

   To reconnect:

   ```sh
   docker start postgres_replica1
   ```

   When you restart the replica, it should resync with the primary.

#### 6. **Clean Up**

1. **Remove Volumes (if needed):**

   If you need to reset your setup:

   ```sh
   docker-compose down -v
   ```

2. **Recreate Containers:**

   Recreate containers if you made changes:

   ```sh
   docker-compose up -d
   ```



