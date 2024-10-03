#!/bin/bash
set -e

# Wait for the primary to be ready
until pg_isready -h postgres_primary -p 5432 -U postgres; do
  echo "Waiting for primary to be ready..."
  sleep 2
done

# Create replication role on the primary (run this only once)
psql -U postgres -h postgres_primary -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_password';"

# Configure replication on primary if not already configured
# It's generally better to manage this directly on the primary server configuration
psql -U postgres -h postgres_primary -c "ALTER SYSTEM SET wal_level = replica;"
psql -U postgres -h postgres_primary -c "ALTER SYSTEM SET max_wal_senders = 3;"
psql -U postgres -h postgres_primary -c "ALTER SYSTEM SET wal_keep_size = 16MB;"
psql -U postgres -h postgres_primary -c "SELECT pg_reload_conf();"

# Configure the replica
echo "primary_conninfo = 'host=postgres_primary port=5432 user=replicator password=replicator_password'" >> /var/lib/postgresql/data/postgresql.conf
echo "standby.signal" > /var/lib/postgresql/data/standby.signal

# Perform base backup from primary to replica
pg_basebackup -h postgres_primary -U replicator -D /var/lib/postgresql/data -Fp -Xs -P -R


# # #!/bin/bash
# # set -e

# # # Configure replication on primary
# # psql -U postgres -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_password';"
# # psql -U postgres -c "ALTER SYSTEM SET wal_level = replica;"
# # psql -U postgres -c "ALTER SYSTEM SET max_wal_senders = 3;"
# # psql -U postgres -c "ALTER SYSTEM SET wal_keep_size = 16MB;"
# # psql -U postgres -c "SELECT pg_reload_conf();"

# # # Configure replica
# # echo "primary_conninfo = 'host=postgres_primary port=5432 user=replicator password=replicator_password'" >> /var/lib/postgresql/data/postgresql.conf
# # echo "standby_mode = on" >> /var/lib/postgresql/data/recovery.conf
# # pg_basebackup -h postgres_primary -U replicator -D /var/lib/postgresql/data -Fp -Xs -P -R



# #!/bin/bash
# set -e

# # Configure replication on primary
# psql -U postgres -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_password';"
# psql -U postgres -c "ALTER SYSTEM SET wal_level = replica;"
# psql -U postgres -c "ALTER SYSTEM SET max_wal_senders = 3;"
# psql -U postgres -c "ALTER SYSTEM SET wal_keep_size = 16MB;"
# psql -U postgres -c "SELECT pg_reload_conf();"

# # Configure replica
# # Wait for the primary to be ready
# until pg_isready -h postgres_primary -p 5432 -U replicator; do
#   echo "Waiting for primary to be ready..."
#   sleep 2
# done

# # Initialize the replica from the primary
# pg_basebackup -h postgres_primary -U replicator -D /var/lib/postgresql/data -Fp -Xs -P -R

# # Create a standby.signal file to indicate it's a standby
# touch /var/lib/postgresql/data/standby.signal
