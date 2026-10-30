# Lab 09 — Autogrowth Settings and VLF Count

**The CrazyDBA — SQL Server: Beyond the Basics**

Watch the video: [YouTube](VIDEO_URL) · [Instagram](VIDEO_URL)

## What you'll learn

- Why every transaction log growth adds virtual log files (VLFs), and how the growth size decides how many.
- How to read a log's autogrowth setting in `sys.database_files` and count its VLFs with `sys.dm_db_log_info`.
- How to fix it safely: correct the setting first, then shrink once and grow back in one step.

## Requirements

- SQL Server 2019 or 2022 (baseline: SQL Server 2022). Free with SQL Server Developer Edition.
- SSMS 20 or later.
- A **test instance** you are allowed to change. The lab creates its own database `CrazyDBA_Lab09` and changes no server settings.
- About 700 MB of free disk space for the lab log and data file while the lab runs.
- Permission: `sysadmin` on the test instance is simplest. `sys.dm_db_log_info` needs `VIEW SERVER STATE` (SQL Server 2019) or `VIEW DATABASE PERFORMANCE STATE` on the database (SQL Server 2022).

## Steps

| Step | Script | What happens | Slides |
|---|---|---|---|
| 1 | `00_Setup.sql` | Creates `CrazyDBA_Lab09` with a 100 MB log and `FILEGROWTH = 1MB`, SIMPLE recovery, plus a snapshot table and procedure. | 1, 2 |
| 2 | `01_Reproduce.sql` | Grows the log 1 MB at a time, 500 times (100 MB → 600 MB). | 1, 2, 3 |
| 3 | `02_Investigate.sql` | Reads the autogrowth setting, counts the VLFs, shows where they come from. | 4, 5 |
| 4 | `03_Fix_and_Verify.sql` | Sets `FILEGROWTH = 64MB`, shrinks the log once, grows it back to 600 MB in one step, recounts. | 7 |
| 5 | `04_Cleanup.sql` | Drops `CrazyDBA_Lab09`. | — |

Run each script top to bottom with **F5** and read the **Results** and **Messages** tabs. Every step has an `EXPECTED:` comment.

**Why `01_Reproduce.sql` uses a loop:** a log with `FILEGROWTH = 1MB` grows by exactly 1 MB each time a workload runs out of log space, but how many times depends on how much log your workload writes. The loop makes the same 500 growths of 1 MB on every machine, so your numbers match the video. Manual growth and autogrowth follow the same VLF rule.

## How many VLFs does one growth create?

From Microsoft Learn (SQL Server 2014 and later; checked top to bottom):

| Growth G (current log size S) | SQL Server 2022 | SQL Server 2019 |
|---|---|---|
| G less than 1/8 of S | 1 VLF | 1 VLF |
| otherwise, G up to 64 MB | 1 VLF | 4 VLFs if under 64 MB |
| otherwise, G from 64 MB up to 1 GB | 8 VLFs | 8 VLFs |
| otherwise, G larger than 1 GB | 16 VLFs | 16 VLFs |

In this lab every 1 MB growth is under 1/8 of the log (at least 12.5 MB), so each adds **1 VLF** on both versions.

## Expected results

| Moment | log_size_mb | growth_mb | is_percent_growth | vlf_count |
|---|---|---|---|---|
| After `00_Setup.sql` | 100 | 1 | 0 | 8 |
| After `01_Reproduce.sql` (500 growths of 1 MB) | 600 | 1 | 0 | **508** |
| After `03_Fix_and_Verify.sql` | 600 | 64 | 0 | 16 |

- `02_Investigate.sql` STEP 3.1: `CrazyDBA_Lab09_log | 600 | 1 | 0` (Slide 4).
- `02_Investigate.sql` STEP 3.2: `vlf_count = 508` = 8 from creating the 100 MB log + 500 from the growths (Slide 5).
- `03_Fix_and_Verify.sql` STEP 4.2: after the shrink, `size_mb = 100`, `vlf_count = 8`.
- `03_Fix_and_Verify.sql` STEP 4.3: the one-step growth of 500 MB adds **8 VLFs** (the same 500 MB in 1 MB steps added 500) (Slide 7).

If the shrink in STEP 4.2 stops above 100 MB, the active log has moved past the original 100 MB: run `CHECKPOINT` and the `DBCC SHRINKFILE` line once more. The "8 VLFs added" result in STEP 4.3 does not depend on where the shrink stops.

## How to read the numbers on your own servers

- There is no official "magic" VLF number. Microsoft Learn suggests keeping the total at a reasonable level, up to several thousand at most, and lists symptoms (very slow recovery at startup, slow restores and attaches, replication/CDC latency) once counts reach the several-hundred-thousand range. Compare the count with the log size and with your own baseline.
- Many VLFs can slow database startup, log backups and restores, and Always On redo. SQL Server can log error 9017 when a restored database has an excessive number of VLFs.
- Prefer a fixed growth in MB over a percentage: a percentage grows by an ever larger amount.
- Fix order: (1) set a sensible fixed `FILEGROWTH` in MB; (2) in a quiet window, with a valid restorable backup, take a log backup (FULL recovery) or `CHECKPOINT` (SIMPLE); (3) shrink the log once and grow it to the size the workload needs in one or a few planned steps; (4) recount. Shrinking is a one-time repair, never a scheduled job.

## SQL Server 2019 notes

- VLFs per growth: for a growth that is **not** under 1/8 of the log, SQL Server 2019 creates **4** VLFs when the growth is under 64 MB (SQL Server 2022 creates 1 for growths up to 64 MB). All growths in this lab avoid that case, so 2019 shows the same numbers: 8 → 508 → 16.
- Permission for `sys.dm_db_log_info`: `VIEW SERVER STATE` (2019) instead of `VIEW DATABASE PERFORMANCE STATE` (2022).
- Instant file initialization never applies to log growth before SQL Server 2022. From SQL Server 2022, log growths up to 64 MB can use it.
- The lab sets compatibility level 150 on SQL Server 2019 and 160 on SQL Server 2022 automatically. VLF behaviour does not depend on it.

## Cleanup

Run `04_Cleanup.sql`. It drops `CrazyDBA_Lab09` (and its files). No server settings were changed.

## Microsoft Learn

- [Transaction log architecture: virtual log files](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-log-architecture-and-management-guide)
- [Manage the size of the transaction log file](https://learn.microsoft.com/en-us/sql/relational-databases/logs/manage-the-size-of-the-transaction-log-file)
- [sys.dm_db_log_info](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-log-info-transact-sql)
- [sys.database_files](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-files-transact-sql)
- [ALTER DATABASE file and filegroup options](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-file-and-filegroup-options)
- [DBCC SHRINKFILE](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-shrinkfile-transact-sql)

---

[← Back to the repository](https://github.com/thecrazydba-in/sql-server-beyond-the-basics)
