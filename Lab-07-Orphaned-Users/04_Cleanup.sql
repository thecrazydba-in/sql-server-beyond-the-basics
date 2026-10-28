/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 07 — Orphaned Users After a Restore | Step 5 of 5: Cleanup
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* Removes everything the lab created: the database CrazyDBA_Lab07, the
   logins CrazyDBA_App07 and CrazyDBA_Rpt07, and the msdb backup/restore
   history for CrazyDBA_Lab07. No server settings were changed.
   T-SQL cannot safely delete files, so STEP 5.1 shows the path of the
   backup file: delete CrazyDBA_Lab07.bak there by hand. SSMS: press F5. */

SET NOCOUNT ON;
USE master;
GO

/* If this window is still impersonating a lab login, switch back. */
IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;
GO

/* ---------------------------------------------------------------
   STEP 5.1 — Note the backup file path BEFORE the history is removed.
   EXPECTED: the full path(s) ending in CrazyDBA_Lab07.bak
   (0 rows if 01_Reproduce.sql was never run).
   --------------------------------------------------------------- */
SELECT DISTINCT bmf.physical_device_name AS delete_this_file_by_hand
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = N'CrazyDBA_Lab07';
GO

/* ---------------------------------------------------------------
   STEP 5.2 — Drop the lab database (closes any open lab connections).
   --------------------------------------------------------------- */
IF DB_ID(N'CrazyDBA_Lab07') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab07 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab07;
END;
GO

/* ---------------------------------------------------------------
   STEP 5.3 — Drop the two lab logins (only these names).
   --------------------------------------------------------------- */
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'CrazyDBA_App07')
    DROP LOGIN CrazyDBA_App07;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'CrazyDBA_Rpt07')
    DROP LOGIN CrazyDBA_Rpt07;
GO

/* ---------------------------------------------------------------
   STEP 5.4 — Remove the backup/restore history of CrazyDBA_Lab07 only.
   sp_delete_database_backuphistory must run from msdb.
   --------------------------------------------------------------- */
USE msdb;
GO
EXEC dbo.sp_delete_database_backuphistory @database_name = N'CrazyDBA_Lab07';
GO

USE master;
GO

/* ---------------------------------------------------------------
   STEP 5.5 — Verify.
   EXPECTED: lab_database_exists = 0 | lab_logins = 0 | history_rows = 0
   Then delete CrazyDBA_Lab07.bak from the folder shown in STEP 5.1.
   --------------------------------------------------------------- */
SELECT
    CASE WHEN DB_ID(N'CrazyDBA_Lab07') IS NULL THEN 0 ELSE 1 END AS lab_database_exists,
    (SELECT COUNT(*) FROM sys.server_principals
     WHERE name IN (N'CrazyDBA_App07', N'CrazyDBA_Rpt07'))        AS lab_logins,
    (SELECT COUNT(*) FROM msdb.dbo.backupset
     WHERE database_name = N'CrazyDBA_Lab07')                     AS history_rows;
GO
