/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 06 — Wait Statistics: Take a Delta | Step 2 of 5: Reproduce
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* HOW THIS LAB USES TWO QUERY WINDOWS
   Window 1 = THIS script. It shows the cumulative view, then holds a lock
              on OrderID 42 for 60 seconds (the "incident").
   Window 2 = 02_Investigate.sql. Open it in a NEW query window (Ctrl + N,
              or File > Open) and press F5 within 30 seconds of starting this
              script. It runs the blocked read and measures the delta.
   Run this whole script with F5. */

SET NOCOUNT ON;
USE CrazyDBA_Lab06;
GO

/* ---------------------------------------------------------------
   STEP 2.1 — THE PROBLEM VIEW: cumulative totals (Slides 1 and 2).
   sys.dm_os_wait_stats only adds a wait when it completes, and the
   counters only go up until a restart or DBCC SQLPERF CLEAR.
   Permission: VIEW SERVER STATE (SQL Server 2019) or
               VIEW SERVER PERFORMANCE STATE (SQL Server 2022).
   EXPECTED: first result = when the counters started (sqlserver_start_time).
             second result = your top 5 waits since then (idle waits skipped).
             Your values are your own; they mix everything since startup.
   --------------------------------------------------------------- */
SELECT si.sqlserver_start_time,
       DATEDIFF(HOUR, si.sqlserver_start_time, SYSDATETIME()) AS hours_of_history
FROM sys.dm_os_sys_info AS si;

SELECT TOP (5)
       ws.wait_type,
       ws.waiting_tasks_count,
       ws.wait_time_ms / 1000 AS wait_s
FROM sys.dm_os_wait_stats AS ws
WHERE NOT EXISTS (SELECT 1
                  FROM dbo.IgnoredWait AS iw
                  WHERE ws.wait_type COLLATE DATABASE_DEFAULT LIKE iw.wait_type_pattern)
ORDER BY ws.wait_time_ms DESC;
GO

/* ---------------------------------------------------------------
   STEP 2.2 — THE INCIDENT: hold an exclusive lock on OrderID 42.
   The UPDATE takes an exclusive (X) lock on the row and keeps it
   until the transaction ends, 60 seconds later.
   NOW: switch to Window 2 and run 02_Investigate.sql (F5) within
        30 seconds. Its read of OrderID 42 waits for a Shared lock.
   EXPECTED here: the query runs for about 60 seconds, then
        "Lock released: transaction rolled back." in the Messages tab.
   If you cancel this script, run  IF @@TRANCOUNT > 0 ROLLBACK;
   in this window, or the lock stays held.
   --------------------------------------------------------------- */
BEGIN TRANSACTION;

UPDATE dbo.Orders
SET    Status = N'Held'
WHERE  OrderID = 42;

WAITFOR DELAY '00:01:00';   -- 60 seconds: start Window 2 now

ROLLBACK TRANSACTION;       -- nothing changes in dbo.Orders

PRINT N'Lock released: transaction rolled back.';
GO
