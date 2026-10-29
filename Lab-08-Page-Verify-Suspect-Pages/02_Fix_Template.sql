/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 08 — Page Verify CHECKSUM and msdb.dbo.suspect_pages | Read-along 2 of 2: Fix template (CHECKSUM + suspect_pages housekeeping)
   Requires: SQL Server 2019+ (or 2022), SSMS,
             permission ALTER on the database (STEP 1, STEP 3);
             db_owner in msdb or sysadmin (STEP 4)
   Run on a test instance only. Review and test on a non-production instance first.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* ================================================================
   SAFETY: every change below is inside a comment block, so pressing F5
   on this file runs ONLY the STEP 0 queries (read-only).
   To apply a change: replace the <placeholders>, select the lines of
   that step (without the comment markers) and run that selection on
   purpose.
   ================================================================ */

SET NOCOUNT ON;
USE master;
GO

/* ---------------------------------------------------------------
   STEP 0 — Save the ORIGINAL values first (read-only).
   Copy both results into your change ticket.
   - Result 1: page_verify_option_desc per database (needed for STEP 3).
   - Result 2: suspect_pages rows that STEP 4 would archive.
   EXPECTED on the example server in the video (Example values):
           SalesDB   TORN_PAGE_DETECTION
   --------------------------------------------------------------- */
SELECT  d.name,
        d.state_desc,
        d.page_verify_option_desc
FROM    sys.databases AS d
WHERE   d.source_database_id IS NULL
  AND   (d.page_verify_option_desc <> N'CHECKSUM'
         OR d.page_verify_option_desc IS NULL)
ORDER BY d.name;
GO

SELECT  DB_NAME(sp.database_id) AS database_name,
        sp.file_id,
        sp.page_id,
        sp.event_type,
        sp.error_count,
        sp.last_update_date
FROM    msdb.dbo.suspect_pages AS sp
WHERE   sp.event_type IN (4, 5, 7)
ORDER BY sp.last_update_date;
GO

/* ---------------------------------------------------------------
   STEP 1 — Switch a database to PAGE_VERIFY CHECKSUM.   (Slide 7, [1])
   (COMMENTED OUT ON PURPOSE)
   - Microsoft Learn: PAGE_VERIFY can be set without taking the database
     offline, locking the database, or otherwise impeding concurrency.
   - The change does NOT checksum existing pages immediately. Each page
     gets a checksum the next time it is written. Until then, old pages
     keep their old protection (or none), so the database can contain a
     mix of protection types for a while.
   - Microsoft also recommends CHECKSUM for tempdb.
   - Example from the video: <YourDatabase> = SalesDB.

ALTER DATABASE [<YourDatabase>] SET PAGE_VERIFY CHECKSUM;   -- e.g. SalesDB
   --------------------------------------------------------------- */

/* ---------------------------------------------------------------
   STEP 2 — Verify.
   Run 01_Check.sql again:
   - Q1: <YourDatabase> no longer appears (page_verify_option_desc is
     CHECKSUM). EXPECTED: SalesDB gone from the result.
   - Q7: take your full backups WITH CHECKSUM so every backup verifies
     the page checksums it finds (Episode 23).
   - Run DBCC CHECKDB regularly: it checks the integrity of all objects
     in the database, so it can find damage on pages your workload
     rarely reads (Episode 20).
   --------------------------------------------------------------- */

/* ---------------------------------------------------------------
   STEP 3 — Roll back (only if needed).  (COMMENTED OUT ON PURPOSE)
   Microsoft recommends CHECKSUM; rolling back removes that protection
   for pages written from now on. Use the ORIGINAL value from STEP 0:
   TORN_PAGE_DETECTION or NONE.

ALTER DATABASE [<YourDatabase>] SET PAGE_VERIFY <OriginalValue>;   -- from STEP 0
   --------------------------------------------------------------- */

/* ---------------------------------------------------------------
   STEP 4 — suspect_pages housekeeping.   (Slide 7, [2])
   (COMMENTED OUT ON PURPOSE)
   Why: msdb.dbo.suspect_pages keeps at most 1,000 rows. When it is
   full, new errors are not logged. Microsoft recommends periodically
   deleting or archiving rows that are restored (4) or repaired (5), or
   rows with an old last_update_date. Deallocated by DBCC = 7.
   NEVER delete open rows (event_type 1, 2, 3) you have not resolved.
   Needs: db_owner in msdb or sysadmin.
   <YourDBADatabase> = a database you use for DBA history (not msdb).

-- 4a. First run only: create the archive table (same columns + archive time).
SELECT TOP (0) sp.*, CAST(NULL AS datetime) AS archived_at
INTO   [<YourDBADatabase>].dbo.suspect_pages_archive
FROM   msdb.dbo.suspect_pages AS sp;

-- 4b. Archive, then delete the fixed rows, in one transaction.
BEGIN TRANSACTION;

INSERT INTO [<YourDBADatabase>].dbo.suspect_pages_archive
       (database_id, file_id, page_id, event_type, error_count, last_update_date, archived_at)
SELECT  sp.database_id, sp.file_id, sp.page_id, sp.event_type,
        sp.error_count, sp.last_update_date, GETDATE()
FROM    msdb.dbo.suspect_pages AS sp
WHERE   sp.event_type IN (4, 5, 7);

DELETE FROM msdb.dbo.suspect_pages
WHERE  event_type IN (4, 5, 7);

COMMIT TRANSACTION;

-- 4c. Verify: Q4 in 01_Check.sql shows fixed_rows_can_archive = 0.
   --------------------------------------------------------------- */

/* ---------------------------------------------------------------
   IF Q3 SHOWED OPEN ROWS — respond, safest first.   (Slide 7, [3] and [4])
   No commands here on purpose: every case is different.
   1. Read the full 823/824 message in the error log (file, offset, page).
   2. Run DBCC CHECKDB on that database (and on the other databases on
      the same volume, Q6). HEAVY: plan it, it checks every object.
      Do NOT start with a REPAIR option (Episode 20).
   3. Investigate the I/O path with your storage team: Windows event
      logs, disks, firmware, drivers, filter drivers (for example
      antivirus scanning database files).
   4. Restore the damage from a known clean backup. Page restore
      (RESTORE DATABASE ... PAGE = 'file:page') needs the FULL or
      BULK_LOGGED recovery model and a read/write filegroup; online page
      restore is an Enterprise edition feature. Follow Microsoft Learn
      "Restore Pages (SQL Server)" step by step, including the tail-log
      backup (Episode 04).
   5. After a restore, SQL Server marks the row as restored
      (event_type 4); archive it later with STEP 4.
   --------------------------------------------------------------- */
