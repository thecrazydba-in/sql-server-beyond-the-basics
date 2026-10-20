/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 05 — Max Server Memory | Read-along 1 of 2: Check the setting and the memory signals
   Requires: SQL Server 2019+ (or 2022), SSMS,
             permission VIEW SERVER STATE (SQL Server 2022: VIEW SERVER PERFORMANCE STATE)
   01_Check.sql is read-only. It contains SELECT statements only.
   Run it on a test instance first, then on your own servers.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE master;
GO

/* ---------------------------------------------------------------
   Q1 — Is max server memory still at the default?   (Slide 4)
   Shows : the configured value and the value SQL Server is using now.
   Needs : public role (SQL Server 2022: VIEW SERVER PERFORMANCE STATE).
   SSMS  : press F5 (or select this query and press F5).
   EXPECTED on the example server (64 GB, never configured):
           name                    value       value_in_use
           max server memory (MB)  2147483647  2147483647
   READ  : 2147483647 = the default, the setting was never changed.
           If value and value_in_use differ, someone ran sp_configure
           but not RECONFIGURE yet.
   --------------------------------------------------------------- */
SELECT  c.name,
        CAST(c.value        AS bigint) AS value,
        CAST(c.value_in_use AS bigint) AS value_in_use
FROM    sys.configurations AS c
WHERE   c.name IN (N'max server memory (MB)', N'min server memory (MB)')
ORDER BY c.name;
GO

/* ---------------------------------------------------------------
   Q2 — How much RAM does this server have, and which memory model?   (Slide 7)
   Shows : physical memory, SQL Server's current and target memory,
           the memory model, and a 75% starting point.
   Needs : VIEW SERVER STATE (SQL Server 2022: VIEW SERVER PERFORMANCE STATE).
   EXPECTED on the example server: ram_gb_rounded_up = 64,
           starting_point_75pct_mb = 49152.
   READ  : starting_point_75pct_mb is 75% of the installed RAM
           (rounded up to whole GB, because Windows usually reports a little
           less than the installed amount). Microsoft recommends 75% of the
           memory NOT used by other processes, so this column is only a
           starting point for a DEDICATED server. Subtract memory used by
           other instances and applications on a shared server.
           sql_memory_model_desc = LOCK_PAGES means Lock Pages in Memory is
           in use: Microsoft strongly recommends setting a cap (Slide 6).
   --------------------------------------------------------------- */
SELECT  si.physical_memory_kb / 1024                              AS physical_memory_mb,
        CEILING(si.physical_memory_kb / 1048576.0)                AS ram_gb_rounded_up,
        CAST(CEILING(si.physical_memory_kb / 1048576.0) * 1024 * 0.75 AS int)
                                                                  AS starting_point_75pct_mb,
        si.committed_kb / 1024                                    AS committed_mb,
        si.committed_target_kb / 1024                             AS committed_target_mb,
        si.sql_memory_model_desc
FROM    sys.dm_os_sys_info AS si;
GO

/* ---------------------------------------------------------------
   Q3 — Is Windows signalling low memory, and is SQL Server responding?   (Slide 5)
   Shows : the Windows memory state and SQL Server's low-memory flag.
   Needs : VIEW SERVER STATE (SQL Server 2022: VIEW SERVER PERFORMANCE STATE).
   Run it at PEAK time; a quiet server usually shows no pressure.
   EXPECTED on the example server under pressure:
           system_memory_state_desc            process_physical_memory_low
           Available physical memory is low    1
   READ  : system_memory_state_desc has four documented values:
             Available physical memory is high
             Available physical memory is low
             Physical memory usage is steady
             Physical memory state is transitioning
           process_physical_memory_low = 1 means SQL Server is responding to
           a low physical memory notification.
   --------------------------------------------------------------- */
SELECT  sm.system_memory_state_desc,
        pm.process_physical_memory_low,
        sm.total_physical_memory_kb / 1024     AS total_physical_memory_mb,
        sm.available_physical_memory_kb / 1024 AS available_physical_memory_mb
FROM    sys.dm_os_sys_memory     AS sm
CROSS JOIN sys.dm_os_process_memory AS pm;
GO

/* ---------------------------------------------------------------
   Q4 — How much of SQL Server's memory is really in RAM?   (Slide 6)
   Shows : SQL Server's working set, locked pages and memory utilization.
   Needs : VIEW SERVER STATE (SQL Server 2022: VIEW SERVER PERFORMANCE STATE).
   READ  : memory_utilization_percentage = the percentage of committed
           memory that is in the working set. Microsoft documents no fixed
           threshold. Compare with your own baseline: a value that drops
           well below its usual level means part of SQL Server's memory is
           no longer in RAM (paged out).
           locked_page_allocations_kb > 0 means Lock Pages in Memory is in use.
   --------------------------------------------------------------- */
SELECT  pm.physical_memory_in_use_kb / 1024     AS physical_memory_in_use_mb,
        pm.locked_page_allocations_kb / 1024    AS locked_page_allocations_mb,
        pm.memory_utilization_percentage,
        pm.page_fault_count
FROM    sys.dm_os_process_memory AS pm;
GO

/* ---------------------------------------------------------------
   Q5 — Target vs Total Server Memory   (Slide 2)
   Shows : Memory Manager counters for this instance.
           Target Server Memory (KB) = the ideal amount the server can consume.
           Total Server Memory (KB)  = the amount the server has committed
                                       using the memory manager.
   Needs : VIEW SERVER STATE (SQL Server 2022: VIEW SERVER PERFORMANCE STATE).
   READ  : Microsoft documents no fixed ratio between the two. Record them
           at peak time, before and after you set a cap, and compare
           against your own baseline.
   --------------------------------------------------------------- */
SELECT  RTRIM(pc.counter_name)  AS counter_name,
        pc.cntr_value / 1024    AS value_mb
FROM    sys.dm_os_performance_counters AS pc
WHERE   pc.object_name LIKE N'%Memory Manager%'
  AND   pc.counter_name IN (N'Target Server Memory (KB)', N'Total Server Memory (KB)')
ORDER BY pc.counter_name;
GO

/* ---------------------------------------------------------------
   ALSO CHECK (no T-SQL needed)   (Slide 5 tip)
   SSMS: Object Explorer > Management > SQL Server Logs > double-click
   "Current" > Filter... > "Message contains text": 17890
   Error 17890 starts with:
   "A significant part of sql server process memory has been paged out."
   --------------------------------------------------------------- */
