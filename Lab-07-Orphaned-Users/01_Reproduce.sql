/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 07 — Orphaned Users After a Restore | Step 2 of 5: Reproduce
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* This script moves CrazyDBA_Lab07 to a "NEW SERVER" without a second instance:
   back up -> drop the database and both logins (the new server has none)
   -> create only CrazyDBA_App07 again, by name (new SID) -> restore.
   Video: Slides 1 and 2. SSMS: press F5 (takes a few seconds).
   Close Object Explorer windows or queries that use CrazyDBA_Lab07 first. */

SET NOCOUNT ON;
USE master;
GO

/* ---------------------------------------------------------------
   STEP 2.1 — OLD SERVER: back up the database.
   File name only, no path: SQL Server writes it to the instance's
   default backup directory. COPY_ONLY keeps it out of any backup chain.
   EXPECTED (Messages tab): "BACKUP DATABASE successfully processed ..."
   --------------------------------------------------------------- */
BACKUP DATABASE CrazyDBA_Lab07
    TO DISK = N'CrazyDBA_Lab07.bak'
    WITH COPY_ONLY, INIT;
GO

/* Where did the file go? (You delete it by hand after 04_Cleanup.sql.)
   EXPECTED: one row with the full path ending in CrazyDBA_Lab07.bak */
SELECT TOP (1) bmf.physical_device_name AS backup_file
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = N'CrazyDBA_Lab07'
ORDER BY bs.backup_finish_date DESC;
GO

/* ---------------------------------------------------------------
   STEP 2.2 — Become the NEW SERVER: the database and both logins are gone.
   --------------------------------------------------------------- */
ALTER DATABASE CrazyDBA_Lab07 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE CrazyDBA_Lab07;
GO
DROP LOGIN CrazyDBA_App07;
DROP LOGIN CrazyDBA_Rpt07;
GO

/* ---------------------------------------------------------------
   STEP 2.3 — On the "new server", someone creates the app login again:
   same name, same password, but no SID option, so SQL Server assigns
   a NEW SID (Slide 2). CrazyDBA_Rpt07 is NOT created: that login is missing.
   --------------------------------------------------------------- */
CREATE LOGIN CrazyDBA_App07 WITH PASSWORD = N'CrazyLab07#App';
GO

/* ---------------------------------------------------------------
   STEP 2.4 — Restore the backup on the "new server".
   File name only: read from the default backup directory.
   EXPECTED (Messages tab): "RESTORE DATABASE successfully processed ..."
   --------------------------------------------------------------- */
RESTORE DATABASE CrazyDBA_Lab07
    FROM DISK = N'CrazyDBA_Lab07.bak'
    WITH RECOVERY;
GO

/* ---------------------------------------------------------------
   STEP 2.5 — The data arrived (Slide 1, card a).
   EXPECTED: orders_rows = 1000
   --------------------------------------------------------------- */
SELECT COUNT(*) AS orders_rows
FROM CrazyDBA_Lab07.dbo.Orders;
GO

/* ---------------------------------------------------------------
   STEP 2.6 — THE SYMPTOM (Slide 1, card c): act as the app login.
   EXECUTE AS LOGIN switches this session to CrazyDBA_App07
   (you need IMPERSONATE on the login; sysadmin has it).
   EXPECTED (Messages tab, red):
     Msg 916 ... The server principal "CrazyDBA_App07" is not able to access
     the database "CrazyDBA_Lab07" under the current security context.
   The login exists and the user AppUser exists, but they no longer match.
   --------------------------------------------------------------- */
EXECUTE AS LOGIN = N'CrazyDBA_App07';
SELECT COUNT(*) AS app_rows
FROM CrazyDBA_Lab07.dbo.Orders;
GO

/* Switch back to your own login (always runs, even after the error).
   EXPECTED: current_login = your own login name, not CrazyDBA_App07 */
IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;
SELECT SUSER_SNAME() AS current_login;
GO
