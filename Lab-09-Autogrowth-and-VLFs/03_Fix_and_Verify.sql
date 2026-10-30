/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 09 — Autogrowth Settings and VLF Count | Step 4 of 5: Fix and Verify
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE CrazyDBA_Lab09;
GO

/* ------------------------------------------------------------------
   STEP 4.1  [1] Fix the setting first (Slide 7, row 1).
   Safe and targeted: it changes only how THIS log grows from now on.
   Use a fixed size in MB, not a percentage. 64 MB is the lab value
   (and the default for new databases since SQL Server 2016).
   Size the increment for YOUR workload: big enough to avoid frequent
   growths. Microsoft Learn advises not to go above 1,024 MB for logs.
   SQL Server 2022: log growths up to 64 MB can use instant file
   initialization (if it is enabled for the service account).
   EXPECTED: growth_mb = 64, is_percent_growth = 0
------------------------------------------------------------------- */
ALTER DATABASE CrazyDBA_Lab09
    MODIFY FILE (NAME = N'CrazyDBA_Lab09_log', FILEGROWTH = 64MB);
GO

SELECT name,
       size / 128   AS size_mb,
       growth / 128 AS growth_mb,
       is_percent_growth
FROM sys.database_files
WHERE type_desc = N'LOG';
GO

/* ------------------------------------------------------------------
   STEP 4.2  [2] + [3] Shrink the log ONCE (Slide 7, rows 2 and 3).
   On a real server: quiet window, a valid restorable backup first.
   - FULL recovery: take a log backup first so VLFs become inactive.
   - SIMPLE recovery (this lab): a CHECKPOINT does the same job.
   The shrink removes inactive VLFs from the end of the file. The
   500 small VLFs sit after the original 100 MB, so a target of 100 MB
   removes them.
   SSMS: run, then check the Results tab of the SELECT below.
   EXPECTED: size_mb = 100, vlf_count = 8.
   If size_mb is still higher, the active log has moved past the first
   100 MB: run CHECKPOINT and this DBCC SHRINKFILE once more.
------------------------------------------------------------------- */
CHECKPOINT;
DBCC SHRINKFILE (N'CrazyDBA_Lab09_log', 100) WITH NO_INFOMSGS;
GO

SELECT (SELECT size / 128 FROM sys.database_files WHERE type_desc = N'LOG') AS size_mb,
       (SELECT COUNT(*) FROM sys.dm_db_log_info(DB_ID()))                    AS vlf_count;
GO

/* ------------------------------------------------------------------
   STEP 4.3  [3] Grow the log back to 600 MB in ONE step
   and [4] count the VLFs this one growth added (Slide 7, row 4).
   The growth is 500 MB: more than 1/8 of the current size and between
   64 MB and 1 GB, so SQL Server creates 8 VLFs (2019 and 2022 alike).
   EXPECTED:
     vlfs_before | vlfs_after | vlfs_added_by_one_500_mb_step
     8           | 16         | 8
   Compare: the same 500 MB added in 1 MB steps (01) created 500 VLFs.
------------------------------------------------------------------- */
DECLARE @before int = (SELECT COUNT(*) FROM sys.dm_db_log_info(DB_ID()));

ALTER DATABASE CrazyDBA_Lab09
    MODIFY FILE (NAME = N'CrazyDBA_Lab09_log', SIZE = 600MB);

DECLARE @after int = (SELECT COUNT(*) FROM sys.dm_db_log_info(DB_ID()));

SELECT @before          AS vlfs_before,
       @after           AS vlfs_after,
       @after - @before AS vlfs_added_by_one_500_mb_step;
GO

/* ------------------------------------------------------------------
   STEP 4.4  Verify: same log size, new setting, far fewer VLFs.
   EXPECTED (latest snapshot):
     label        | log_size_mb | growth_mb | is_percent_growth | vlf_count
     3 after fix  | 600         | 64        | 0                 | 16
   Then the full history: 100/1/8 -> 600/1/508 -> 600/64/16.
------------------------------------------------------------------- */
EXEC dbo.usp_LogSnapshot @label = '3 after fix';
GO

SELECT label, log_size_mb, growth_mb, is_percent_growth, vlf_count
FROM dbo.LogSnapshot
ORDER BY snapshot_id;
GO

/* ------------------------------------------------------------------
   On your own servers: shrinking is a one-time repair, not a job.
   Fix the growth setting first; schedule the shrink-and-regrow only
   where the VLF count is really high for the log size, and size the
   log close to what the workload needs so it rarely has to grow.
------------------------------------------------------------------- */
