/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 09 — Autogrowth Settings and VLF Count | Step 3 of 5: Investigate
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Permission for sys.dm_db_log_info: VIEW SERVER STATE (SQL Server 2019),
   VIEW DATABASE PERFORMANCE STATE on the database (SQL Server 2022).
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE CrazyDBA_Lab09;
GO

/* ------------------------------------------------------------------
   STEP 3.1  Evidence 1: the autogrowth setting. Slide 4.
   sys.database_files stores size and growth in 8 KB pages
   (128 pages = 1 MB). If is_percent_growth = 1, growth is a
   percentage instead, and growth_mb below would be meaningless.
   SSMS: select the query, press F5, read the Results tab.
   (The same setting is visible in SSMS under right-click the
   database > Properties > Files.)
   EXPECTED (one row):
     name               | size_mb | growth_mb | is_percent_growth
     CrazyDBA_Lab09_log | 600     | 1         | 0
------------------------------------------------------------------- */
SELECT name,
       size / 128   AS size_mb,
       growth / 128 AS growth_mb,
       is_percent_growth
FROM sys.database_files
WHERE type_desc = N'LOG';
GO

/* ------------------------------------------------------------------
   STEP 3.2  Evidence 2: count the VLFs. Slide 5.
   sys.dm_db_log_info returns one row per VLF
   (SQL Server 2016 SP2 and later; it replaces DBCC LOGINFO).
   EXPECTED: vlf_count = 508
------------------------------------------------------------------- */
SELECT COUNT(*) AS vlf_count
FROM sys.dm_db_log_info(DB_ID());
GO

/* ------------------------------------------------------------------
   STEP 3.3  Where do the 508 VLFs come from? (lab detail, not on a slide)
   vlf_size_mb is rounded to two decimals.
   EXPECTED:
     - 500 VLFs with vlf_size_mb = 1   -> one per 1 MB growth
     - 8 more VLFs of about 12.5 MB    -> from creating the 100 MB log
       (they may show as one or two size groups, because the first
        VLF can be slightly smaller: the file starts with a header page)
------------------------------------------------------------------- */
SELECT vlf_size_mb,
       COUNT(*) AS vlfs
FROM sys.dm_db_log_info(DB_ID())
GROUP BY vlf_size_mb
ORDER BY vlf_size_mb;
GO

/* ------------------------------------------------------------------
   STEP 3.4  Is the active log near the start of the file?
   A log shrink removes only inactive VLFs from the END of the file,
   so check where the last active VLF sits before shrinking (03).
   EXPECTED: last_active_vlf_position is 8 or lower
   (the active log is still inside the original 100 MB).
------------------------------------------------------------------- */
WITH v AS
(
    SELECT ROW_NUMBER() OVER (ORDER BY vlf_begin_offset) AS position,
           vlf_active
    FROM sys.dm_db_log_info(DB_ID())
)
SELECT COUNT(*)                                             AS vlf_count,
       SUM(CASE WHEN vlf_active = 1 THEN 1 ELSE 0 END)      AS active_vlfs,
       MAX(CASE WHEN vlf_active = 1 THEN position END)      AS last_active_vlf_position
FROM v;
GO

/* ------------------------------------------------------------------
   STEP 3.5  Optional: VLF count for every online database on the
   instance. Read-only. Use it on your own test instance to compare.
   There is no single official "bad" number. Microsoft Learn suggests
   keeping the total at a reasonable level, up to several thousand at
   most, and lists slow startup and restore symptoms once counts reach
   the several-hundred-thousand range. Compare against your log size
   and against your own baseline.
   EXPECTED: CrazyDBA_Lab09 shows vlf_count = 508.
------------------------------------------------------------------- */
SELECT d.name,
       COUNT(*) AS vlf_count
FROM sys.databases AS d
CROSS APPLY sys.dm_db_log_info(d.database_id) AS l
WHERE d.state_desc = N'ONLINE'
GROUP BY d.name
ORDER BY vlf_count DESC;
GO
