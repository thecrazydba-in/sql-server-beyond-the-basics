/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 09 — Autogrowth Settings and VLF Count | Step 2 of 5: Reproduce
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE CrazyDBA_Lab09;
GO

/* ------------------------------------------------------------------
   STEP 2.1  Safety check: start from a fresh 100 MB log.
   If you already ran this script, run 00_Setup.sql again first.
   If the check fails, SET NOEXEC ON skips the rest of this script
   (the last batch switches it off again).
   EXPECTED: no message. (An error saying "Run 00_Setup.sql again"
   means the log is not 100 MB: run 00_Setup.sql, then this script.)
------------------------------------------------------------------- */
IF (SELECT size / 128 FROM sys.database_files WHERE type_desc = N'LOG') <> 100
BEGIN
    RAISERROR (N'The log is not 100 MB. Run 00_Setup.sql again, then this script.', 16, 1);
    SET NOEXEC ON;
END;
GO

/* ------------------------------------------------------------------
   STEP 2.2  Grow the log 1 MB at a time, 500 times: 100 MB -> 600 MB.
   Slides 1 and 2.

   Why a loop instead of a real workload?
   - Under a real workload, a log with FILEGROWTH = 1MB grows by exactly
     1 MB each time it runs out of space. How many times depends on how
     much log your workload writes, so the result would differ per machine.
   - This loop makes the SAME 500 growths of 1 MB on purpose, so every
     viewer gets the same numbers. Manual growth and autogrowth follow the
     same VLF rule (Microsoft Learn: transaction log architecture guide).

   VLF rule for each step: 1 MB is less than 1/8 of the current log
   size (at least 100 MB / 8 = 12.5 MB), so each growth adds exactly
   1 VLF, on SQL Server 2019 and 2022 alike.

   SSMS: press F5 and watch the Messages tab (progress every 100 MB).
   On a slow disk this step can take a while: every growth is written
   out before it can be used.
   EXPECTED: messages "Log size now 200 MB" ... "Log size now 600 MB".
------------------------------------------------------------------- */
DECLARE @mb  int = 101,
        @sql nvarchar(400),
        @msg nvarchar(100);

WHILE @mb <= 600
BEGIN
    SET @sql = N'ALTER DATABASE CrazyDBA_Lab09 MODIFY FILE (NAME = N''CrazyDBA_Lab09_log'', SIZE = '
             + CAST(@mb AS nvarchar(10)) + N'MB);';
    EXEC sys.sp_executesql @sql;

    IF @mb % 100 = 0
    BEGIN
        SET @msg = N'Log size now ' + CAST(@mb AS nvarchar(10)) + N' MB';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END;

    SET @mb += 1;
END;
GO

/* ------------------------------------------------------------------
   STEP 2.3  Snapshot after the 500 growths.
   EXPECTED (one row):
     label                | log_size_mb | growth_mb | is_percent_growth | vlf_count
     2 after 500 growths  | 600         | 1         | 0                 | 508
   508 = 8 VLFs from creating the 100 MB log + 500 VLFs from the growths.
------------------------------------------------------------------- */
EXEC dbo.usp_LogSnapshot @label = '2 after 500 growths';
GO

/* Always switch NOEXEC off again (see STEP 2.1). */
SET NOEXEC OFF;
GO
