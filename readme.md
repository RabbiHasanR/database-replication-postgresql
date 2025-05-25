# Testing master and replicas working fine
### On replica, run:
```sql
SELECT * FROM pg_stat_wal_receiver;
```
If this returns a row, streaming is active.
If it's empty, streaming is not active!

### On master, check:

```sql
SELECT * FROM pg_stat_replication;
```
If this returns a row, a replica is connected.


### for test replica work when insert or create table in master
```sql
CREATE TABLE replication_test (id serial PRIMARY KEY, note text);
INSERT INTO replication_test (note) VALUES ('hello from master');
```

## get inside db container 
```sh
docker exec -it <container name> psql -U postgres -d <db name>
```

### Confirm Asynchronous Mode
When you check pg_stat_replication on the master, look for the column sync_state:
If it says async, your replication is asynchronous.
If it says sync, it's synchronous.

## check async mood in master db
```sql
SELECT application_name, state, sync_state
FROM pg_stat_replication;
```