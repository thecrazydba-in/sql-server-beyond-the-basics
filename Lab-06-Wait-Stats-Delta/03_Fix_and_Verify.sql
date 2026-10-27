/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 06 — Wait Statistics: Take a Delta | Step 4 of 5: Fix and Verify
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* THE FIX (Slide 7): make "snapshot, wait, compare" a routine instead of
   reading lifetime totals or clearing the counters.
   Run in any window AFTER 01_Reproduce.sql has finished
   (Window 1 shows "Lock released: transaction rolled back."). Press F5.
   Takes about 30 seconds (STEP 4.2 measures a 30-second window). */

SET NOCOUNT ON;
USE CrazyDBA_Lab06;
GO

/* ---------------------------------------------------------------
   STEP 4.1 — A reusable procedure: dbo.usp_WaitDelta @Seconds.
   [1] Snapshot sys.dm_os_wait_stats into dbo.WaitsBefore (idle waits skipped)
   [2] Wait @Seconds while the problem happens, then snapshot into dbo.WaitsAfter
   [3] Subtract and rank by wait time (same query as Slide 4)
   Nothing is cleared: the server-wide counters are only read.
   EXPECTED: "Commands completed successfully."
   --------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.usp_WaitDelta
    @Seconds int = 60
AS
BEGIN
    SET NOCOUNT ON;

    IF @Seconds IS NULL OR @Seconds < 1 OR @Seconds > 3600
    BEGIN
        RAISERROR(N'@Seconds must be between 1 and 3600.', 16, 1);
        RETURN;
    END;

    DECLARE @delay char(8) =
        CONVERT(char(8), DATEADD(SECOND, @Seconds, CAST('00:00:00' AS time(0))), 108);

    -- [1] Snapshot 1
    TRUNCATE TABLE dbo.WaitsBefore;
    INSERT INTO dbo.WaitsBefore (wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms)
    SELECT ws.wait_type, ws.waiting_tasks_count, ws.wait_time_ms, ws.signal_wait_time_ms
    FROM sys.dm_os_wait_stats AS ws
    WHERE NOT EXISTS (SELECT 1
                      FROM dbo.IgnoredWait AS iw
                      WHERE ws.wait_type COLLATE DATABASE_DEFAULT LIKE iw.wait_type_pattern);

    -- [2] The window (this WAITFOR itself is in dbo.IgnoredWait), then snapshot 2
    WAITFOR DELAY @delay;

    TRUNCATE TABLE dbo.WaitsAfter;
    INSERT INTO dbo.WaitsAfter (wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms)
    SELECT ws.wait_type, ws.waiting_tasks_count, ws.wait_time_ms, ws.signal_wait_time_ms
    FROM sys.dm_os_wait_stats AS ws
    WHERE NOT EXISTS (SELECT 1
                      FROM dbo.IgnoredWait AS iw
                      WHERE ws.wait_type COLLATE DATABASE_DEFAULT LIKE iw.wait_type_pattern);

    -- [3] The delta
    SELECT TOP (5) a.wait_type,
      a.waiting_tasks_count - b.waiting_tasks_count AS tasks,
      (a.wait_time_ms - b.wait_time_ms) / 1000 AS wait_s
    FROM dbo.WaitsAfter AS a
    JOIN dbo.WaitsBefore AS b ON b.wait_type = a.wait_type
    ORDER BY wait_s DESC;
END;
GO

/* ---------------------------------------------------------------
   STEP 4.2 — VERIFY 1: a quiet 30-second window.
   Nobody is blocked now, so the delta must NOT show LCK_M_S time.
   EXPECTED: no LCK_M_S row with wait_s above 0. On a quiet test
   instance most rows show wait_s = 0.
   --------------------------------------------------------------- */
EXEC dbo.usp_WaitDelta @Seconds = 30;
GO

/* ---------------------------------------------------------------
   STEP 4.3 — VERIFY 2: nothing was cleared.
   The cumulative view still contains the lock wait from 02_Investigate.sql.
   EXPECTED: LCK_M_S waiting_tasks_count of 1 or more, wait_s of 20 or more.
   Same window, two different answers: the delta says "quiet now",
   the lifetime total still remembers the incident (Slides 3 and 6).
   --------------------------------------------------------------- */
SELECT ws.wait_type,
       ws.waiting_tasks_count,
       ws.wait_time_ms / 1000 AS wait_s
FROM sys.dm_os_wait_stats AS ws
WHERE ws.wait_type = N'LCK_M_S';
GO

/* ---------------------------------------------------------------
   STEP 4.4 — OPTIONAL: catch the incident with the procedure.
   1. Window 1: run 01_Reproduce.sql again (F5).
   2. Window 2: run  EXEC dbo.usp_WaitDelta @Seconds = 45;
   3. Window 3 (Ctrl + N), within the 45 seconds, run:
        USE CrazyDBA_Lab06;
        SET LOCK_TIMEOUT 20000;
        SELECT OrderID, Status FROM dbo.Orders WHERE OrderID = 42;
      It ends with Msg 1222 after 20 seconds.
   EXPECTED in Window 2: top row LCK_M_S | tasks = 1 | wait_s = 20.

   BASELINE (Slide 7, row 4): on a real server, save snapshots on a
   schedule (for example a SQL Server Agent job every 15 minutes into a
   history table with a captured_at column) so you can compare any
   window with a normal day. Not created by this lab.
   --------------------------------------------------------------- */
