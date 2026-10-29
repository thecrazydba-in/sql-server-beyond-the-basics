/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 08 — Page Verify CHECKSUM and msdb.dbo.suspect_pages | Read-along 1 of 2: Check page verify settings and suspect pages
   Requires: SQL Server 2019+ (or 2022), SSMS,
             permission VIEW ANY DATABASE (granted to public by default),
             read access to msdb, and for Q5/Q6 CREATE DATABASE,
             ALTER ANY DATABASE or VIEW ANY DEFINITION (sys.master_files).
   01_Check.sql is read-only. It contains SELECT statements only.
   Run it on a test instance first, then on your own servers.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE master;
GO

/* ---------------------------------------------------------------
   Q1 — Which databases do NOT use PAGE_VERIFY CHECKSUM?   (Slide 4)
   Shows : every database whose page verify option is not CHECKSUM.
   Needs : VIEW ANY DATABASE (public has it by default).
   SSMS  : press F5 (or select this query and press F5).
   EXPECTED on the example server in the video (Example values):
           name      page_verify_option_desc
           SalesDB   TORN_PAGE_DETECTION
   READ  : TORN_PAGE_DETECTION = 2 bits per 512-byte sector, a minimal
           subset of CHECKSUM protection.
           NONE = no checksum or torn-page check on read at all.
           Both usually come from databases upgraded from very old
           versions: an upgrade keeps the old setting.
           Include tempdb: on upgraded instances it can still be NONE.
           An EMPTY result = every online database uses CHECKSUM.
           Note: databases that are not online can show NULL here and
           are skipped by this filter. Q2 lists them.
   --------------------------------------------------------------- */
SELECT name, page_verify_option_desc
FROM sys.databases
WHERE page_verify_option_desc
  <> N'CHECKSUM';
GO

/* ---------------------------------------------------------------
   Q2 — All databases, with state and a hint   (Slides 3 and 4)
   Shows : every database (database snapshots excluded), its state and
           its page verify option, non-CHECKSUM databases first.
   Needs : VIEW ANY DATABASE (public has it by default).
   READ  : page_verify_option_desc NULL = the database is not online
           (or AUTO_CLOSE closed it): check it again when it is online.
   --------------------------------------------------------------- */
SELECT  d.name,
        d.database_id,
        d.state_desc,
        d.page_verify_option_desc,
        CASE
            WHEN d.page_verify_option_desc IS NULL      THEN N'Not online: check again later'
            WHEN d.page_verify_option_desc = N'CHECKSUM' THEN N'OK'
            ELSE N'Change to CHECKSUM (02_Fix_Template.sql)'
        END AS action_hint
FROM    sys.databases AS d
WHERE   d.source_database_id IS NULL
ORDER BY CASE WHEN d.page_verify_option_desc = N'CHECKSUM' THEN 1 ELSE 0 END,
         d.name;
GO

/* ---------------------------------------------------------------
   Q3 — Open suspect pages: 823/824 errors, bad checksums, torn pages   (Slide 5)
   Shows : pages SQL Server recorded as suspect (event_type 1, 2, 3).
   Needs : access to msdb (anyone with access to msdb can read it).
   EXPECTED on the example server in the video (Example values):
           database_name  file_id  page_id  event_type  error_count
           OrdersDB       1        2856     2           1
           (the slide shows the first four columns)
   READ  : event_type 1 = an 823 error that causes a suspect page (such as
                          a disk error) or an 824 error other than a bad
                          checksum or torn page (such as a bad page ID)
           event_type 2 = Bad checksum
           event_type 3 = Torn page
           Page notation file_id:page_id, e.g. (1:2856).
           An EMPTY result is what you want.
           Microsoft documents that rows can also come from transient
           errors (for example a disconnected cable), so a row is a
           SUSPECT page: confirm with DBCC CHECKDB (see README).
           database_name NULL = you cannot see that database.
   --------------------------------------------------------------- */
SELECT  DB_NAME(sp.database_id) AS database_name,
        sp.file_id,
        sp.page_id,
        sp.event_type,
        sp.error_count,
        sp.last_update_date,
        CASE sp.event_type
            WHEN 1 THEN N'823 error or other 824 error (e.g. bad page ID)'
            WHEN 2 THEN N'Bad checksum'
            WHEN 3 THEN N'Torn page'
        END AS event_desc
FROM    msdb.dbo.suspect_pages AS sp
WHERE   sp.event_type IN (1, 2, 3)
ORDER BY sp.last_update_date DESC;
GO

/* ---------------------------------------------------------------
   Q4 — How full is suspect_pages?   (Slide 5 tip)
   Shows : total rows against the documented 1,000-row limit, split into
           open rows (1, 2, 3) and fixed rows (4, 5, 7).
   Needs : access to msdb.
   READ  : The table is limited to 1,000 rows. When it is full, NEW
           ERRORS ARE NOT LOGGED. Microsoft recommends periodically
           deleting or archiving rows that are restored (4), repaired (5)
           or have an old last_update_date. Deallocated by DBCC = 7.
           fixed_rows_can_archive > 0: see STEP 4 in 02_Fix_Template.sql.
           There is no official "warning" level below 1,000: watch the
           trend. A sudden increase in rows usually points to an I/O
           subsystem problem (Microsoft Learn).
   --------------------------------------------------------------- */
SELECT  COUNT(*)                                                    AS total_rows,
        1000                                                        AS documented_row_limit,
        ISNULL(SUM(CASE WHEN sp.event_type IN (1, 2, 3) THEN 1 ELSE 0 END), 0) AS open_suspect_rows,
        ISNULL(SUM(CASE WHEN sp.event_type IN (4, 5, 7) THEN 1 ELSE 0 END), 0) AS fixed_rows_can_archive,
        MIN(sp.last_update_date)                                    AS oldest_update,
        MAX(sp.last_update_date)                                    AS newest_update
FROM    msdb.dbo.suspect_pages AS sp;
GO

/* ---------------------------------------------------------------
   Q5 — Which physical file holds each open suspect page?   (Slide 6)
   Shows : the data file behind every open suspect page.
   Needs : access to msdb, plus CREATE DATABASE, ALTER ANY DATABASE or
           VIEW ANY DEFINITION to see rows in sys.master_files.
   READ  : The file path tells you which volume to investigate.
           Error 824 usually points to the I/O path: disks, firmware,
           drivers, filter drivers (for example antivirus).
   --------------------------------------------------------------- */
SELECT  DB_NAME(sp.database_id) AS database_name,
        sp.file_id,
        sp.page_id,
        sp.event_type,
        mf.type_desc,
        mf.physical_name
FROM    msdb.dbo.suspect_pages AS sp
LEFT JOIN sys.master_files     AS mf
       ON  mf.database_id = sp.database_id
       AND mf.file_id     = sp.file_id
WHERE   sp.event_type IN (1, 2, 3)
ORDER BY database_name, sp.file_id, sp.page_id;
GO

/* ---------------------------------------------------------------
   Q6 — Other database files on the same drive   (Slide 6)
   Shows : every database file whose path starts with the same drive
           (first 3 characters, e.g. D:\) as a file with an open suspect
           page.
   Needs : as Q5.
   READ  : Microsoft recommends checking the consistency of the databases
           on the same volume as the one reported in the 824 message.
           volume_hint is ONLY a hint: mount points and UNC paths share
           the first 3 characters, so confirm the real volume yourself.
           An EMPTY result = no open suspect pages (Q3 was empty).
   --------------------------------------------------------------- */
WITH affected AS (
    SELECT DISTINCT LEFT(mf.physical_name, 3) AS volume_hint
    FROM   msdb.dbo.suspect_pages AS sp
    JOIN   sys.master_files       AS mf
           ON  mf.database_id = sp.database_id
           AND mf.file_id     = sp.file_id
    WHERE  sp.event_type IN (1, 2, 3)
)
SELECT  a.volume_hint,
        DB_NAME(mf.database_id) AS database_name,
        mf.type_desc,
        mf.physical_name
FROM    sys.master_files AS mf
JOIN    affected         AS a
        ON LEFT(mf.physical_name, 3) = a.volume_hint
ORDER BY a.volume_hint, database_name, mf.type_desc;
GO

/* ---------------------------------------------------------------
   Q7 — Do your full backups verify page checksums?   (Slide 7)
   Shows : the latest full backup per database recorded in msdb, whether
           it was taken WITH CHECKSUM and whether damage was detected.
   Needs : read access to msdb.dbo.backupset.
   READ  : has_backup_checksums = 1: the backup verified the page checksums
           it found while reading (pages that have no checksum yet cannot
           be verified).
           is_damaged = 1: damage was detected and the backup was told to
           continue despite errors. Investigate at once.
           last_full_backup NULL = no full backup in msdb history
           (history may have been cleaned up).
           Episode 23 covers verifying backups in depth.
   --------------------------------------------------------------- */
WITH last_full AS (
    SELECT  bs.database_name,
            bs.backup_finish_date,
            bs.has_backup_checksums,
            bs.is_damaged,
            ROW_NUMBER() OVER (PARTITION BY bs.database_name
                               ORDER BY bs.backup_finish_date DESC) AS rn
    FROM    msdb.dbo.backupset AS bs
    WHERE   bs.type = 'D'
)
SELECT  d.name,
        lf.backup_finish_date AS last_full_backup,
        lf.has_backup_checksums,
        lf.is_damaged
FROM    sys.databases AS d
LEFT JOIN last_full   AS lf
       ON  lf.database_name COLLATE DATABASE_DEFAULT = d.name COLLATE DATABASE_DEFAULT
       AND lf.rn = 1
WHERE   d.database_id <> 2              -- tempdb cannot be backed up
  AND   d.source_database_id IS NULL    -- skip database snapshots
ORDER BY d.name;
GO

/* ---------------------------------------------------------------
   ALSO CHECK (no T-SQL needed)
   SSMS: Object Explorer > Management > SQL Server Logs > double-click
   "Current" > Filter... > "Message contains text": 824
   Error 824 starts with:
   "SQL Server detected a logical consistency-based I/O error"
   Also search for 823 and 825.
   Episode 13 shows how to get SQL Server Agent alerts for 823, 824, 825.
   --------------------------------------------------------------- */
