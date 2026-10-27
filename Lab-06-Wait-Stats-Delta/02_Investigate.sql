/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 06 — Wait Statistics: Take a Delta | Step 3 of 5: Investigate
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* RUN THIS IN WINDOW 2, while 01_Reproduce.sql is still running in Window 1
   (start it within 30 seconds of starting 01_Reproduce.sql). Press F5.
   It takes about 20 seconds: the read in STEP 3.2 is blocked on purpose.
   Permission: VIEW SERVER STATE (SQL Server 2019) or
               VIEW SERVER PERFORMANCE STATE (SQL Server 2022). */

SET NOCOUNT ON;
USE CrazyDBA_Lab06;
GO

/* ---------------------------------------------------------------
   STEP 3.1 — SNAPSHOT 1: copy sys.dm_os_wait_stats into dbo.WaitsBefore,
   skipping the waits listed in dbo.IgnoredWait (Slides 3, 4 and 7).
   EXPECTED: no result set; dbo.WaitsBefore now holds one row per wait type.
   --------------------------------------------------------------- */
TRUNCATE TABLE dbo.WaitsBefore;

INSERT INTO dbo.WaitsBefore (wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms)
SELECT ws.wait_type, ws.waiting_tasks_count, ws.wait_time_ms, ws.signal_wait_time_ms
FROM sys.dm_os_wait_stats AS ws
WHERE NOT EXISTS (SELECT 1
                  FROM dbo.IgnoredWait AS iw
                  WHERE ws.wait_type COLLATE DATABASE_DEFAULT LIKE iw.wait_type_pattern);
GO

/* ---------------------------------------------------------------
   STEP 3.2 — THE BLOCKED READ (the problem happening inside the window).
   Under READ COMMITTED (RCSI OFF), this read needs a Shared (S) lock on
   OrderID 42. Window 1 holds an exclusive (X) lock on it, so the read
   waits on LCK_M_S. SET LOCK_TIMEOUT 20000 stops the wait after
   20 seconds, so the wait is the same length on every machine.
   EXPECTED (Messages tab), after about 20 seconds:
     "Blocked for 20 seconds: Msg 1222 - Lock request time out period exceeded."
   If you see "Not blocked" instead, Window 1 was not holding the lock:
   start 01_Reproduce.sql, then run this script again within 30 seconds.
   --------------------------------------------------------------- */
SET LOCK_TIMEOUT 20000;   -- milliseconds

BEGIN TRY
    SELECT OrderID, Status
    FROM dbo.Orders
    WHERE OrderID = 42;

    PRINT N'Not blocked: start 01_Reproduce.sql in Window 1 first, then rerun this script.';
END TRY
BEGIN CATCH
    PRINT N'Blocked for 20 seconds: Msg ' + CAST(ERROR_NUMBER() AS nvarchar(10))
        + N' - ' + ERROR_MESSAGE();
END CATCH;

SET LOCK_TIMEOUT -1;      -- back to the default: wait without a time-out
GO

/* ---------------------------------------------------------------
   STEP 3.3 — SNAPSHOT 2: same copy into dbo.WaitsAfter.
   The lock wait has completed (it timed out), so it is now counted.
   --------------------------------------------------------------- */
TRUNCATE TABLE dbo.WaitsAfter;

INSERT INTO dbo.WaitsAfter (wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms)
SELECT ws.wait_type, ws.waiting_tasks_count, ws.wait_time_ms, ws.signal_wait_time_ms
FROM sys.dm_os_wait_stats AS ws
WHERE NOT EXISTS (SELECT 1
                  FROM dbo.IgnoredWait AS iw
                  WHERE ws.wait_type COLLATE DATABASE_DEFAULT LIKE iw.wait_type_pattern);
GO

/* ---------------------------------------------------------------
   STEP 3.4 — THE DELTA: subtract Before from After (Slides 4 and 5).
   This is the exact query shown on Slide 4.
   EXPECTED top row:  wait_type = LCK_M_S | tasks = 1 | wait_s = 20
   Other rows are small waits from this window (usually 0 seconds).
   On a busy instance, other sessions' waits can also appear: that is
   the point of a delta — it shows everything that waited in the window.
   --------------------------------------------------------------- */
SELECT TOP (5) a.wait_type,
  a.waiting_tasks_count - b.waiting_tasks_count AS tasks,
  (a.wait_time_ms - b.wait_time_ms) / 1000 AS wait_s
FROM dbo.WaitsAfter AS a
JOIN dbo.WaitsBefore AS b ON b.wait_type = a.wait_type
ORDER BY wait_s DESC;
GO

/* ---------------------------------------------------------------
   STEP 3.5 — COMPARE: the same wait in the cumulative view.
   EXPECTED: LCK_M_S waiting_tasks_count of 1 or more and wait_s of 20 or
   more: it includes every lock wait since sqlserver_start_time, not just
   the 20 seconds you created. Compare its rank with STEP 2.1.
   --------------------------------------------------------------- */
SELECT ws.wait_type,
       ws.waiting_tasks_count,
       ws.wait_time_ms / 1000 AS wait_s
FROM sys.dm_os_wait_stats AS ws
WHERE ws.wait_type = N'LCK_M_S';
GO

/* ---------------------------------------------------------------
   STEP 3.6 — CROSS-CHECK: this session's own waits (Slide 5 tip).
   sys.dm_exec_session_wait_stats (SQL Server 2016+) resets when the
   session opens, so it shows only waits from this query window.
   EXPECTED: LCK_M_S | waiting_tasks_count = 1 | wait_s = 20
   (2 and 40 if you ran this script twice in the same window).
   --------------------------------------------------------------- */
SELECT sws.wait_type,
       sws.waiting_tasks_count,
       sws.wait_time_ms / 1000 AS wait_s
FROM sys.dm_exec_session_wait_stats AS sws
WHERE sws.session_id = @@SPID
  AND sws.wait_type = N'LCK_M_S';
GO
