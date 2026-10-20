/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 04 — Tail-Log Backup | Step 5 of 5: Cleanup
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* ---------------------------------------------------------------
   Drops both lab databases and their msdb backup history.
   No server settings were changed by this lab, so nothing else
   needs restoring. Press F5 to run.
--------------------------------------------------------------- */
SET NOCOUNT ON;
USE master;
GO

/* Step 5.1 — Drop the lab databases (works in ONLINE or RESTORING state). */
IF DB_ID(N'CrazyDBA_Lab04_NoTail') IS NOT NULL
BEGIN
    IF DATABASEPROPERTYEX(N'CrazyDBA_Lab04_NoTail', 'Status') = 'ONLINE'
        ALTER DATABASE CrazyDBA_Lab04_NoTail SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab04_NoTail;
END;
GO

IF DB_ID(N'CrazyDBA_Lab04') IS NOT NULL
BEGIN
    IF DATABASEPROPERTYEX(N'CrazyDBA_Lab04', 'Status') = 'ONLINE'
        ALTER DATABASE CrazyDBA_Lab04 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab04;
END;
GO

/* Step 5.2 — Remove the lab's backup history from msdb (lab databases only). */
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'CrazyDBA_Lab04';
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'CrazyDBA_Lab04_NoTail';
GO

/* Step 5.3 — The three backup files stay on disk. T-SQL in this lab does
   not delete files. Delete them yourself from this folder:
     CrazyDBA_Lab04_Full.bak, CrazyDBA_Lab04_Log1.trn, CrazyDBA_Lab04_Tail.trn
   EXPECTED: no rows for the lab databases; BackupFolder = your default
   backup directory.                                                      */
SELECT name
FROM sys.databases
WHERE name IN (N'CrazyDBA_Lab04', N'CrazyDBA_Lab04_NoTail');

SELECT SERVERPROPERTY('InstanceDefaultBackupPath') AS BackupFolder;
GO
