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