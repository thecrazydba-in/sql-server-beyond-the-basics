# Lab 05 — Max Server Memory: Why the Default Needs Changing

**DBA Toolkit (read-along)** · The CrazyDBA — SQL Server: Beyond the Basics

Watch the video: [YouTube](VIDEO_URL) · [Instagram](VIDEO_URL)

## What you'll learn

- Why the default `max server memory (MB)` of 2147483647 is no practical cap.
- How to read `value_in_use` and the low-memory signals Windows and SQL Server report.
- How to set a safe starting cap (75% → 49152 MB on a dedicated 64 GB server) and roll it back.

## Requirements and permissions

- SQL Server 2019 or 2022 on Windows, SSMS 20 or later. Free with SQL Server Developer Edition.
- `01_Check.sql`: **read-only** (SELECT statements only).
  - `sys.configurations`: public role (SQL Server 2022: `VIEW SERVER PERFORMANCE STATE`).
  - `sys.dm_os_sys_info`, `sys.dm_os_sys_memory`, `sys.dm_os_process_memory`, `sys.dm_os_performance_counters`: `VIEW SERVER STATE` (SQL Server 2022: `VIEW SERVER PERFORMANCE STATE`).
- `02_Fix_Template.sql`: changing the setting needs `ALTER SETTINGS` (held by `sysadmin` and `serveradmin`).
- Linux is not covered: SQL Server on Linux uses `memory.memorylimitmb` instead.

## How to run 01_Check.sql

1. Open `01_Check.sql` in SSMS, connected to the instance you want to check.
2. Press **F5**. Five result grids appear (Q1–Q5).
3. Run it again at **peak time**: memory pressure rarely shows on a quiet server.

## How to read the results

The "expected" values below are for the example server in the video: a dedicated Windows server with **64 GB (65536 MB)** RAM, `max server memory (MB)` never changed, under memory pressure. Your server will show its own values.

| Query | Slide | What to look at | Example server |
|---|---|---|---|
| Q1 `sys.configurations` | 4 | `value_in_use` of `max server memory (MB)` | `2147483647` = default, never changed |
| Q2 `sys.dm_os_sys_info` | 7 | `ram_gb_rounded_up`, `starting_point_75pct_mb`, `sql_memory_model_desc` | `64`, `49152`, `LOCK_PAGES` means Lock Pages in Memory is in use |
| Q3 `sys.dm_os_sys_memory` + `sys.dm_os_process_memory` | 5 | `system_memory_state_desc`, `process_physical_memory_low` | `Available physical memory is low`, `1` |
| Q4 `sys.dm_os_process_memory` | 6 | `memory_utilization_percentage` | No official threshold: compare with your baseline |
| Q5 `sys.dm_os_performance_counters` | 2 | `Target Server Memory (KB)`, `Total Server Memory (KB)` | No official ratio: record at peak, before and after |

Notes:

- **Q1:** 2147483647 MB is about 2 PB, far more than any real server, so it is no practical cap.
- **Q2:** `starting_point_75pct_mb` is 75% of installed RAM. Microsoft recommends 75% of the memory **not used by other processes**, so it is only a starting point for a dedicated server. Subtract other instances and applications on a shared server.
- **Q3:** `process_physical_memory_low = 1` means SQL Server is responding to a low physical memory notification.
- **Q4:** `memory_utilization_percentage` is the percentage of committed memory that is in the working set. A drop well below its usual level means part of SQL Server's memory is no longer in RAM.
- **Also check** the error log for message **17890** ("A significant part of sql server process memory has been paged out."): SSMS → Management → SQL Server Logs → Current → Filter.

## When and how to use 02_Fix_Template.sql

Use it when Q1 shows the default (or a value that leaves Windows too little room) and Q3/Q4 or error 17890 show memory pressure.

1. **STEP 0** (runs on F5, read-only): save the original values.
2. Choose `<YourValueMB>`: 75% of the memory not used by other processes. Dedicated 64 GB server: **49152 MB**.
3. **STEP 1** (commented out on purpose): replace the placeholder, select the lines and run them deliberately. Takes effect immediately, **no restart needed**.
4. **STEP 2**: run `01_Check.sql` again and monitor at peak, then adjust.
5. **STEP 3** (commented out): roll back to the original value from STEP 0 if needed.

Review and test on a non-production instance first. If you use Lock Pages in Memory, Microsoft strongly recommends setting a cap.

## SQL Server 2019 notes

- Same setting, same default (2147483647) and same sp_configure commands.
- Since SQL Server 2019, Setup on Windows recommends a `max server memory (MB)` value during installation. It can be skipped, so check every server.
- SQL Server 2019 uses `VIEW SERVER STATE` for the DMVs; SQL Server 2022 uses `VIEW SERVER PERFORMANCE STATE`.

## Microsoft Learn

- [Server memory configuration options](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/server-memory-server-configuration-options)
- [sys.dm_os_sys_memory](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-sys-memory-transact-sql)
- [sys.dm_os_process_memory](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-process-memory-transact-sql)
- [sys.dm_os_sys_info](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-sys-info-transact-sql)
- [SQL Server Memory Manager object](https://learn.microsoft.com/en-us/sql/relational-databases/performance-monitor/sql-server-memory-manager-object)
- [sp_configure](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-configure-transact-sql)

---

[← Back to the repository](https://github.com/thecrazydba-in/sql-server-beyond-the-basics)
