# Lab 08 — Page Verify CHECKSUM and msdb.dbo.suspect_pages

**DBA Toolkit (read-along)** · The CrazyDBA — SQL Server: Beyond the Basics


## What you'll learn

- How `PAGE_VERIFY CHECKSUM` lets SQL Server catch a damaged page on read (error 824), and why `TORN_PAGE_DETECTION` and `NONE` protect less.
- How to find databases without CHECKSUM and read `msdb.dbo.suspect_pages` (including its 1,000-row limit).
- How to switch to CHECKSUM safely, keep `suspect_pages` from filling up, and respond to a suspect page.

## Requirements and permissions

- SQL Server 2019 or 2022, SSMS 20 or later. Free with SQL Server Developer Edition.
- `01_Check.sql`: **read-only** (SELECT statements only). No `VIEW SERVER STATE` needed.
  - `sys.databases` (Q1, Q2, Q7): `VIEW ANY DATABASE`, which the **public** role has by default.
  - `msdb.dbo.suspect_pages` (Q3–Q6): anyone with access to `msdb` can read it.
  - `sys.master_files` (Q5, Q6): `CREATE DATABASE`, `ALTER ANY DATABASE` or `VIEW ANY DEFINITION`.
  - `msdb.dbo.backupset` (Q7): read access to `msdb`.
- `02_Fix_Template.sql`:
  - `ALTER DATABASE ... SET PAGE_VERIFY`: `ALTER` permission on the database.
  - Deleting rows from `suspect_pages`: `db_owner` in `msdb` or `sysadmin`.

## How to run 01_Check.sql

1. Open `01_Check.sql` in SSMS, connected to the instance you want to check.
2. Press **F5**. Seven result grids appear (Q1–Q7). Empty grids for Q1, Q3, Q5 and Q6 are good news.
3. Also search the error log for 823, 824 and 825: SSMS → Management → SQL Server Logs → Current → Filter.

## How to read the results

The "example" values below are the example server from the video. Your server shows its own values.

| Query | Slide | What to look at | Example server |
|---|---|---|---|
| Q1 `sys.databases` | 4 | Databases whose `page_verify_option_desc` is not `CHECKSUM` | `SalesDB` → `TORN_PAGE_DETECTION` |
| Q2 `sys.databases` | 3, 4 | All databases, state, `action_hint`; `NULL` = not online | `SalesDB` → `Change to CHECKSUM (02_Fix_Template.sql)` |
| Q3 `suspect_pages` (event_type 1, 2, 3) | 5 | Open suspect pages | `OrdersDB`, `file_id` 1, `page_id` 2856, `event_type` 2, `error_count` 1 |
| Q4 `suspect_pages` row count | 5 (tip) | `total_rows` against `documented_row_limit` 1000 | Fewer than 1,000; `fixed_rows_can_archive` > 0 means housekeeping is due |
| Q5 `suspect_pages` + `sys.master_files` | 6 | `physical_name` of the file behind each open row | The data file of `OrdersDB` |
| Q6 files on the same drive | 6 | Other databases on that drive (hint only) | Check them with DBCC CHECKDB |
| Q7 `msdb.dbo.backupset` | 7 | `has_backup_checksums`, `is_damaged` of the last full backup | `1` and `0` is what you want |

`event_type` values in `msdb.dbo.suspect_pages` (Microsoft Learn):

| event_type | Meaning |
|---|---|
| 1 | An 823 error that causes a suspect page (such as a disk error) or an 824 error other than a bad checksum or torn page (such as a bad page ID) |
| 2 | Bad checksum |
| 3 | Torn page |
| 4 | Restored (the page was restored after it was marked bad) |
| 5 | Repaired (DBCC repaired the page) |
| 7 | Deallocated by DBCC |

Notes:

- **How CHECKSUM works (Slides 1–2):** when a page is written to disk, SQL Server stores a checksum over the whole 8 KB page in the page header. When the page is read from disk, the checksum is recomputed and compared. A failed read is retried four times; if the retries fail, the command fails with **error 824**. Error 824 means Windows reported a successful read, but SQL Server found the page contents wrong.
- **TORN_PAGE_DETECTION (Slide 3)** stores a 2-bit pattern per 512-byte sector and gives only a minimal subset of CHECKSUM protection. **NONE** verifies nothing on read.
- **Upgrades keep the old setting:** databases upgraded from SQL Server 2000 keep `NONE` or `TORN_PAGE_DETECTION`. On upgraded instances `tempdb` can still be `NONE`. Microsoft recommends CHECKSUM for all of them, including `tempdb`.
- **A row in suspect_pages is a suspect, not a verdict:** rows can come from transient errors. Confirm with DBCC CHECKDB. A sudden increase in rows usually means a problem in the I/O subsystem.
- **1,000-row limit (Slide 5):** when the table is full, new errors are **not logged**. The DBA has to delete or archive old rows (STEP 4 in the template).
- **There is no official threshold** for "too many" rows: any open row (event_type 1, 2, 3) deserves investigation; for the row count, watch the trend.

## When and how to use 02_Fix_Template.sql

Use it when Q1 lists databases, or when Q4 shows rows that can be archived.

1. **STEP 0** (runs on F5, read-only): save the original page verify values and the rows STEP 4 would archive.
2. **STEP 1** (commented out on purpose): `ALTER DATABASE [<YourDatabase>] SET PAGE_VERIFY CHECKSUM;` (in the video: `SalesDB`). It runs online: no offline database, no database lock.
   **Existing pages get a checksum only when they are next written.** Until then they keep their old protection.
3. **STEP 2**: run `01_Check.sql` again; Q1 should no longer list the database. Take full backups `WITH CHECKSUM` (Episode 23) and run DBCC CHECKDB regularly (Episode 20).
4. **STEP 3** (commented out): roll back to the original value from STEP 0, only if really needed.
5. **STEP 4** (commented out): archive and delete restored (4), repaired (5) and deallocated (7) rows. Never delete open rows you have not resolved.

If Q3 shows open rows, follow the response section at the end of the template, safest first: read the error log, run DBCC CHECKDB (no repair as a first step), investigate the I/O path, and restore from a known clean backup. Page restore needs the full or bulk-logged recovery model; online page restore is an Enterprise edition feature.

Review and test on a non-production instance first.

## SQL Server 2019 notes

- Same `PAGE_VERIFY` options, same default (`CHECKSUM` for new databases), same `msdb.dbo.suspect_pages` table and `event_type` values.
- Same permissions for every query in this toolkit; none of them needs `VIEW SERVER STATE` or the newer SQL Server 2022 granular permissions.
- SSMS path to see the setting: right-click the database → **Properties** → **Options** → **Recovery** → **Page Verify**.

## Microsoft Learn

- [ALTER DATABASE SET options: PAGE_VERIFY](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-set-options#page_verify)
- [Memory management architecture guide: Error detection (torn page and checksum protection)](https://learn.microsoft.com/en-us/sql/relational-databases/memory-management-architecture-guide)
- [suspect_pages (Transact-SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/suspect-pages-transact-sql)
- [Manage the suspect_pages table](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/manage-the-suspect-pages-table-sql-server)
- [MSSQLSERVER_824](https://learn.microsoft.com/en-us/sql/relational-databases/errors-events/mssqlserver-824-database-engine-error)
- [Possible media errors during backup and restore (backup checksums)](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/possible-media-errors-during-backup-and-restore-sql-server)
- [Restore pages](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/restore-pages-sql-server)
- [sys.databases](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql)

---

[← Back to the repository](https://github.com/thecrazydba-in/sql-server-beyond-the-basics)
