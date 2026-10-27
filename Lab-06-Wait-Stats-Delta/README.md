# Lab 06 — Wait Statistics: Take a Delta Instead of Reading Cumulative Totals



## What you'll learn

- Why `sys.dm_os_wait_stats` shows totals since startup, not what is happening now.
- How to take two snapshots and subtract them to see only the waits inside a window.
- How a 20-second blocking incident shows up clearly in a delta: `LCK_M_S | 1 | 20`.

## Requirements

- SQL Server 2019 or 2022 (any edition; free with SQL Server Developer Edition), SSMS 20+.
- A **test instance**. The lab creates its own database `CrazyDBA_Lab06` and changes no server settings.
- Permissions: `CREATE DATABASE`, plus `VIEW SERVER STATE` (SQL Server 2019) or `VIEW SERVER PERFORMANCE STATE` (SQL Server 2022) to read the wait-statistics DMVs. A sysadmin login on your test instance covers all of it.
- **Two query windows** for steps 2 and 3 (Window 1 holds a lock, Window 2 gets blocked).

## Steps

| Step | Script | Where | What happens | Slides |
|---|---|---|---|---|
| 1 | `00_Setup.sql` | any window | Creates `CrazyDBA_Lab06`: `dbo.Orders` (1000 rows), `dbo.IgnoredWait` (44 idle/background waits), `dbo.WaitsBefore`, `dbo.WaitsAfter`. | — |
| 2 | `01_Reproduce.sql` | **Window 1** | Shows the cumulative view since `sqlserver_start_time`, then holds an exclusive lock on `OrderID = 42` for 60 seconds. | 1, 2 |
| 3 | `02_Investigate.sql` | **Window 2**, start within 30 s of step 2 | Snapshot 1 → blocked read (20 s, `SET LOCK_TIMEOUT 20000`) → snapshot 2 → delta. | 3, 4, 5, 6 |
| 4 | `03_Fix_and_Verify.sql` | any window, after Window 1 finishes | Creates `dbo.usp_WaitDelta @Seconds`, measures a quiet 30-second window, and shows the cumulative total still remembers the incident. | 7 |
| 5 | `04_Cleanup.sql` | any window | Drops `CrazyDBA_Lab06`. | — |

Run every script with **F5**. Open Window 2 with **Ctrl + N** (or File > Open > `02_Investigate.sql`).

## Expected results

| Script / step | Expected |
|---|---|
| `00_Setup.sql` verification | `orders_rows = 1000`, `ignored_waits = 44`, `before_rows = 0`, `after_rows = 0`, `rcsi_on = 0`, `compat_level = 150` |
| `01_Reproduce.sql` 2.1 | Your own `sqlserver_start_time` and top 5 waits since then (values differ on every server) |
| `01_Reproduce.sql` 2.2 | Runs about 60 seconds, then `Lock released: transaction rolled back.` |
| `02_Investigate.sql` 3.2 | After about 20 seconds: `Blocked for 20 seconds: Msg 1222 - Lock request time out period exceeded.` |
| `02_Investigate.sql` 3.4 (delta, Slide 5) | Top row: `wait_type = LCK_M_S`, `tasks = 1`, `wait_s = 20` |
| `02_Investigate.sql` 3.5 (cumulative) | `LCK_M_S` with `waiting_tasks_count` ≥ 1 and `wait_s` ≥ 20 (includes all lock waits since startup) |
| `02_Investigate.sql` 3.6 (session) | `LCK_M_S`, `waiting_tasks_count = 1`, `wait_s = 20` |
| `03_Fix_and_Verify.sql` 4.2 | Quiet window: no `LCK_M_S` row with `wait_s` above 0 |
| `03_Fix_and_Verify.sql` 4.3 | Cumulative `LCK_M_S` still ≥ 1 task and ≥ 20 s: nothing was cleared |
| `04_Cleanup.sql` | `lab_database_exists = 0` |

Notes:
- `wait_s` uses integer division (`/ 1000`). Timer resolution can occasionally make the lock wait show as 19 or 21 instead of 20.
- On a busy instance, waits from other sessions also appear in the delta. That is what a delta is for: everything that waited inside the window. The lab's `LCK_M_S` row should still be easy to find.
- If an unfamiliar background wait ranks above `LCK_M_S`, look it up in the [sys.dm_os_wait_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-wait-stats-transact-sql) documentation. If it is documented as idle or internal, add it to `dbo.IgnoredWait`.
- If step 3.2 prints `Not blocked`, Window 1 was not holding the lock. Run `01_Reproduce.sql` again and start `02_Investigate.sql` within 30 seconds.

## Why the snapshot skips some waits

`dbo.IgnoredWait` holds 44 wait types that only measure idle time or background tasks waiting for work:

- the **Idle** and **User Wait** categories from [sys.query_store_wait_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-wait-stats-transact-sql) (for example `SLEEP_%`, `LAZYWRITER_SLEEP`, `XE_TIMER_EVENT`, `WAITFOR`),
- waits that `sys.dm_os_wait_stats` documents as *Internal use only* (for example `DIRTY_PAGE_POLL`, `SP_SERVER_DIAGNOSTICS_SLEEP`),
- background tasks documented as waiting for work (for example `KSOURCE_WAKEUP`, `DISPATCHER_QUEUE_SEMAPHORE`).

They grow even on an idle server, so they would push real waits off the top of the list.

## SQL Server 2019 notes

- Everything in this lab runs on SQL Server 2019 (compatibility level 150 is set on purpose).
- Permission: SQL Server 2019 uses `VIEW SERVER STATE`; SQL Server 2022 uses the more granular `VIEW SERVER PERFORMANCE STATE` for these DMVs.
- `sys.dm_exec_session_wait_stats` exists since SQL Server 2016.

## Don't clear the counters as a first step

`DBCC SQLPERF ('sys.dm_os_wait_stats', CLEAR);` resets the counters for the **whole instance** (it needs `ALTER SERVER STATE`). Anyone else's baseline or monitoring tool loses its history. A delta gives you the same "fresh start" without touching anything. This lab never runs it.

## Cleanup

Run `04_Cleanup.sql`. It drops `CrazyDBA_Lab06`. No server settings were changed. The 20-second `LCK_M_S` wait stays in the cumulative totals until the next restart, which is harmless.

---

Back to the repository: [sql-server-beyond-the-basics](https://github.com/thecrazydba-in/sql-server-beyond-the-basics)
