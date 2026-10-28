# Lab 07 — Orphaned Users After a Restore: Finding and Fixing Them

Watch the video: [YouTube](VIDEO_URL) · [Instagram](VIDEO_URL)

## What you'll learn

- Why a restored database can lock out a login that "exists": users find their login by **SID**, not by name.
- How to list orphaned users with one query against `sys.database_principals` and `sys.server_principals`.
- How to fix both kinds of orphan without dropping anything: `ALTER USER ... WITH LOGIN` and `CREATE LOGIN ... SID =`.

## Requirements

- SQL Server 2019 or 2022 (free with SQL Server Developer Edition), SSMS 20+.
- A **test instance**. The lab creates the database `CrazyDBA_Lab07` and two lab-only SQL Server logins, `CrazyDBA_App07` and `CrazyDBA_Rpt07`. It changes no server settings. `04_Cleanup.sql` removes everything.
- sysadmin on the test instance (the lab uses `CREATE DATABASE`, `ALTER ANY LOGIN`, `BACKUP`/`RESTORE`, `IMPERSONATE` on the lab logins, and `CONTROL` on the lab database).
- Write access for SQL Server to its default backup directory (the lab writes one small file, `CrazyDBA_Lab07.bak`, there).
- The passwords in the scripts are lab-only values. Never reuse them.

## How the lab fakes a "new server" on one instance

`01_Reproduce.sql` backs up the database, then drops the database **and both logins**, like a fresh server that has never seen them. It creates `CrazyDBA_App07` again by name (SQL Server gives it a new SID) and restores the backup. `CrazyDBA_Rpt07` is not created. Result: two orphaned users, each needing a different fix.

## Steps

| Step | Script | What happens | Slides |
|---|---|---|---|
| 1 | `00_Setup.sql` | "Old server": creates the two logins, `CrazyDBA_Lab07`, `dbo.Orders` (1000 rows), user `AppUser` (GRANT SELECT on `dbo.Orders`) and user `ReportUser` (member of `db_datareader`). | — |
| 2 | `01_Reproduce.sql` | Backup → drop database and logins → re-create `CrazyDBA_App07` by name → restore → read as `CrazyDBA_App07`: **Msg 916**. | 1, 2 |
| 3 | `02_Investigate.sql` | Shows the SID mismatch, runs the orphan check (**2 rows**), shows which login is missing and that the permissions are still in the database. | 2, 3, 4, 5 |
| 4 | `03_Fix_and_Verify.sql` | `ALTER USER AppUser WITH LOGIN = CrazyDBA_App07;`, creates `CrazyDBA_Rpt07` with `ReportUser`'s SID, reruns the check (**0 rows**), reads 1000 rows as each login, shows permissions were kept. | 6, 7 |
| 5 | `04_Cleanup.sql` | Shows the backup file path, drops the database and both logins, removes the lab's msdb backup history. | — |

Run every script with **F5**, in order, in one query window.

## Expected results

| Script / step | Expected |
|---|---|
| `00_Setup.sql` 1.7 | `orders_rows = 1000`, `mapped_users = 2`, `orphaned_users = 0`, `guest_connect = 0`, `compat_level = 150` |
| `01_Reproduce.sql` 2.1 | `BACKUP DATABASE successfully processed ...`, then one row with the full path of `CrazyDBA_Lab07.bak` |
| `01_Reproduce.sql` 2.4 | `RESTORE DATABASE successfully processed ...` |
| `01_Reproduce.sql` 2.5 | `orders_rows = 1000` |
| `01_Reproduce.sql` 2.6 (Slide 1) | `Msg 916 ... The server principal "CrazyDBA_App07" is not able to access the database "CrazyDBA_Lab07" under the current security context.` |
| `01_Reproduce.sql` last step | `current_login` = your own login |
| `02_Investigate.sql` 3.1 | 2 rows with two **different** `sid` values (random hex, differs on every machine) |
| `02_Investigate.sql` 3.2 (Slide 4) | `AppUser \| SQL_USER` and `ReportUser \| SQL_USER` |
| `02_Investigate.sql` 3.3 | `AppUser \| CrazyDBA_App07 \| login exists, different SID` and `ReportUser \| CrazyDBA_Rpt07 \| login missing` |
| `02_Investigate.sql` 3.4 | `AppUser \| SELECT \| GRANT \| Orders` and `db_datareader \| ReportUser` |
| `03_Fix_and_Verify.sql` 4.2 | `Created login CrazyDBA_Rpt07 with the SID of ReportUser.` |
| `03_Fix_and_Verify.sql` 4.3 | **0 rows** |
| `03_Fix_and_Verify.sql` 4.4 | `same_sid = 1` for both users |
| `03_Fix_and_Verify.sql` 4.5 | `app_rows = 1000`, `report_rows = 1000` |
| `03_Fix_and_Verify.sql` 4.6 | Same as 3.4: nothing was lost, nothing was re-granted |
| `04_Cleanup.sql` 5.5 | `lab_database_exists = 0`, `lab_logins = 0`, `history_rows = 0` |

Notes:
- The lab triggers the symptom with `EXECUTE AS LOGIN`, so it shows **Msg 916**. A real application that names the database in its connection string usually fails at connect time instead, with error 4060 ("Cannot open database ... requested by the login. The login failed.") and a login-failed message. Same cause.
- If `DROP LOGIN` reports that the login is currently logged in, a query window is still impersonating it: run `REVERT;` in that window (or close it) and rerun the script.
- If the backup fails with an "operating system error", SQL Server cannot write to its default backup directory. Fix the folder permissions on your test machine, or change `N'CrazyDBA_Lab07.bak'` in `01_Reproduce.sql` (both places) to a full path SQL Server can write to.

## Why the check filters on `'INSTANCE'`

`authentication_type_desc = 'INSTANCE'` keeps the check to database users that are based on **SQL Server logins**, which is the case Microsoft Learn's check covers. Windows users show `WINDOWS`, and their SID comes from Windows, not from `CREATE LOGIN`. Review those separately if you move databases between domains.

## Which fix when

| Situation | Fix | What changes |
|---|---|---|
| Login exists, different SID (`AppUser`) | `ALTER USER AppUser WITH LOGIN = CrazyDBA_App07;` | The user's SID is replaced by the login's SID. The user keeps its name and permissions. Needs `CONTROL` on the database. |
| Login missing (`ReportUser`) | `CREATE LOGIN ... WITH PASSWORD = ..., SID = <the user's SID>;` | A new login that already matches the user. Nothing changes inside the database. Needs `ALTER ANY LOGIN`. |
| Old scripts using `sp_change_users_login` | Replace with `ALTER USER ... WITH LOGIN` | `sp_change_users_login` is deprecated. |

Prevention: before a migration, transfer SQL Server logins **with their SIDs** (Microsoft's article [Transfer logins and passwords between instances of SQL Server](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/security/transfer-logins-passwords-between-instances)). For databases that move often, contained database users cannot become orphaned.

## SQL Server 2019 notes

- Everything in this lab runs on SQL Server 2019 (compatibility level 150 is set on purpose). The orphan check, `ALTER USER ... WITH LOGIN` and `CREATE LOGIN ... SID` behave the same on 2019 and 2022.

## Cleanup

Run `04_Cleanup.sql`. It shows the path of `CrazyDBA_Lab07.bak`, drops `CrazyDBA_Lab07`, drops `CrazyDBA_App07` and `CrazyDBA_Rpt07`, and removes the msdb backup/restore history for `CrazyDBA_Lab07` only. Then **delete `CrazyDBA_Lab07.bak` by hand** from the folder shown in step 5.1. No server settings were changed.

## Microsoft Learn

- [Troubleshoot orphaned users (SQL Server)](https://learn.microsoft.com/en-us/sql/sql-server/failover-clusters/troubleshoot-orphaned-users-sql-server)
- [ALTER USER](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-user-transact-sql) · [CREATE LOGIN](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-login-transact-sql) · [sys.database_principals](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-principals-transact-sql)

---

Back to the repository: [sql-server-beyond-the-basics](https://github.com/thecrazydba-in/sql-server-beyond-the-basics)
