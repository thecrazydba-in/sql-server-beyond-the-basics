# Lab 04 — Tail-Log Backup: Capturing the Last Transactions Before a Restore

Watch the video: [YouTube](VIDEO_URL) · [Instagram](VIDEO_URL)

## What you'll learn

- Why your last backup is not your last transaction: the **tail of the log** holds work that no backup contains yet.
- How SQL Server protects the tail (**Msg 3159**) and how `sys.dm_db_log_stats` shows log written since the last log backup.
- How to back up the tail `WITH NORECOVERY` and restore in the right order, so nothing is lost.

## Requirements

- SQL Server 2019 or 2022 (Developer Edition is fine). **Free with SQL Server Developer Edition.**
- SSMS 20 or later.
- A **test instance only**. The lab creates and drops its own databases: `CrazyDBA_Lab04` and `CrazyDBA_Lab04_NoTail`.
- Permissions: `sysadmin` on the test instance is simplest (the lab creates, backs up, restores and drops databases).
- About 200 MB of free disk space (data, log and backup files).
- Backup files are written to the instance's **default backup directory** (only a file name is used in each `DISK` clause). Find it with:
  ```sql
  SELECT SERVERPROPERTY('InstanceDefaultBackupPath');
  ```

## Steps

Close any other query windows connected to `CrazyDBA_Lab04` before Steps 3 and 4 (restores need exclusive access). Every script ends with `USE master;`.

| Step | Script | What happens | Slides |
|---|---|---|---|
| 1 | `00_Setup.sql` | Creates `CrazyDBA_Lab04` (FULL recovery), loads 1,000 rows, takes a full backup, adds 500 rows, takes a log backup. | 1 |
| 2 | `01_Reproduce.sql` | Adds 100 rows after the last log backup: the tail. | 1, 2 |
| 3 | `02_Investigate.sql` | `sys.dm_db_log_stats`, msdb backup history, the Msg 3159 restore attempt, and a side restore without the tail. | 4, 5, 6 |
| 4 | `03_Fix_and_Verify.sql` | `BACKUP LOG … WITH NORECOVERY`, then restore Full → Log1 → Tail, and verify. | 3, 6, 7 |
| 5 | `04_Cleanup.sql` | Drops both lab databases and their msdb backup history. | — |

Press **F5** to run each script. In Step 3 the red **Msg 3159** error is expected.

## Expected results

| Check | Expected |
|---|---|
| After `00_Setup.sql` | `recovery_model_desc` = FULL · Full = 1000 · Log1 = 500 · TotalRows = **1500** |
| After `01_Reproduce.sql` | Full = 1000 · Log1 = 500 · Tail = 100 · TotalRows = **1600** |
| `sys.dm_db_log_stats` | `recovery_model` = FULL · `log_since_last_log_backup_mb` above 0 (exact value varies) |
| Restore without tail-log backup | **Msg 3159**: `The tail of the log for the database "CrazyDBA_Lab04" has not been backed up. …` then Msg 3013. Database stays ONLINE with 1600 rows. |
| `CrazyDBA_Lab04_NoTail` (Full + Log1 only) | TotalRows = **1500** — 100 rows lost |
| After `BACKUP LOG … WITH NORECOVERY` | `state_desc` = RESTORING |
| After restore Full → Log1 → Tail | `state_desc` = ONLINE · Tail = 100 · TotalRows = **1600** — nothing lost |

Backup files created: `CrazyDBA_Lab04_Full.bak`, `CrazyDBA_Lab04_Log1.trn`, `CrazyDBA_Lab04_Tail.trn`.

## Key T-SQL

```sql
-- 1. Tail first: capture the unbacked log and put the database in RESTORING
BACKUP LOG CrazyDBA_Lab04
    TO DISK = N'CrazyDBA_Lab04_Tail.trn'
    WITH NORECOVERY;

-- 2. Restore in order, tail last
RESTORE DATABASE CrazyDBA_Lab04 FROM DISK = N'CrazyDBA_Lab04_Full.bak' WITH NORECOVERY;
RESTORE LOG      CrazyDBA_Lab04 FROM DISK = N'CrazyDBA_Lab04_Log1.trn' WITH NORECOVERY;
RESTORE LOG      CrazyDBA_Lab04 FROM DISK = N'CrazyDBA_Lab04_Tail.trn' WITH RECOVERY;
```

SSMS alternative: right-click **Databases** › **Restore Database…** › **Options** page › **Take tail-log backup before restore**.

Good to know:

- Tail-log backups apply to the **FULL** and **BULK_LOGGED** recovery models.
- `WITH REPLACE` (or `STOPAT`) skips the tail-log check and overwrites the log: the tail is lost.
- Damaged database? Microsoft Learn: try the tail-log backup `WITH CONTINUE_AFTER_ERROR`. `NO_TRUNCATE` is equivalent to `COPY_ONLY` + `CONTINUE_AFTER_ERROR`. (Not part of this lab: a damaged database cannot be built safely here.)
- In production scripts, always give a full path in `TO DISK` / `FROM DISK`.

## SQL Server 2019 notes

- The lab runs unchanged on SQL Server 2019 and 2022 (compatibility level 150 is set on purpose).
- `sys.dm_db_log_stats` needs `VIEW SERVER STATE` on SQL Server 2019, and `VIEW SERVER PERFORMANCE STATE` on SQL Server 2022.
- `SERVERPROPERTY('InstanceDefaultBackupPath')` is available from SQL Server 2019.

## Cleanup

Run `04_Cleanup.sql`. It drops `CrazyDBA_Lab04` and `CrazyDBA_Lab04_NoTail` and removes their msdb backup history. No server settings are changed by this lab. The three backup files stay in your default backup directory: delete them manually.

## Microsoft Learn

- [Tail-log backups (SQL Server)](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/tail-log-backups-sql-server)
- [MSSQLSERVER_3159](https://learn.microsoft.com/en-us/sql/relational-databases/errors-events/mssqlserver-3159-database-engine-error)
- [BACKUP (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/backup-transact-sql)
- [sys.dm_db_log_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-log-stats-transact-sql)
- [Restore a database backup using SSMS](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/restore-a-database-backup-using-ssms)

---

[← Back to SQL Server — Beyond the Basics](https://github.com/thecrazydba-in/sql-server-beyond-the-basics)
