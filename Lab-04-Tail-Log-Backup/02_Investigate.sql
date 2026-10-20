/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 04 — Tail-Log Backup | Step 3 of 5: Investigate (the evidence)
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* ---------------------------------------------------------------
   Run 01_Reproduce.sql first. Close any other query windows that are
   connected to CrazyDBA_Lab04 (Step 3.3 needs exclusive access).
   Press F5 to run the whole script. The red error in Step 3.3 is
   EXPECTED: SSMS still runs the batches after it.
--------------------------------------------------------------- */
SET NOCOUNT ON;
USE CrazyDBA_Lab04;
GO

/* Step 3.1 — Evidence 1 (Slide 4): the log still holds unbacked work.
   sys.dm_db_log_stats needs VIEW SERVER PERFORMANCE STATE on SQL Server
   2022 (VIEW SERVER STATE on SQL Server 2019).
   EXPECTED:
     recovery_model               = FULL
     log_backup_time              = the time 00_Setup.sql took the log backup
     log_since_last_log_backup_mb = above 0 (log written since that backup:
                                    the tail). The exact value varies.     */
SELECT recovery_model,
       log_backup_time,
       log_since_last_log_backup_mb
FROM sys.dm_db_log_stats(DB_ID());
GO

/* Step 3.2 — Backup history in msdb (type D = full, L = log).
   EXPECTED: two rows, newest first: L (CrazyDBA_Lab04_Log1.trn),
   then D (CrazyDBA_Lab04_Full.bak). Nothing after the log backup.         */
SELECT TOP (5)
       bs.type,
       bs.backup_start_date,
       bs.backup_finish_date,
       bmf.physical_device_name
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf
     ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = N'CrazyDBA_Lab04'
ORDER BY bs.backup_set_id DESC;
GO

/* Step 3.3 — Evidence 2 (Slide 5): try to restore over the database
   WITHOUT a tail-log backup. SQL Server refuses.
   EXPECTED in Messages:
     Msg 3159 ... The tail of the log for the database "CrazyDBA_Lab04"
     has not been backed up. Use BACKUP LOG WITH NORECOVERY to back up the
     log if it contains work that you do not want to lose. Use the WITH
     REPLACE or WITH STOPAT clause of the RESTORE statement to just
     overwrite the contents of the log.
     followed by Msg 3013 (RESTORE DATABASE is terminating abnormally).
   The database is NOT changed. Do NOT add WITH REPLACE here: it would
   overwrite the log and lose the 100 tail rows.                           */
USE master;
GO
ALTER DATABASE CrazyDBA_Lab04 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO
RESTORE DATABASE CrazyDBA_Lab04
    FROM DISK = N'CrazyDBA_Lab04_Full.bak'
    WITH NORECOVERY;
GO
ALTER DATABASE CrazyDBA_Lab04 SET MULTI_USER;
GO

/* Step 3.4 — Confirm nothing changed.
   EXPECTED: state_desc = ONLINE, TotalRows = 1600.                       */
SELECT name, state_desc, user_access_desc
FROM sys.databases
WHERE name = N'CrazyDBA_Lab04';

SELECT COUNT(*) AS TotalRows
FROM CrazyDBA_Lab04.dbo.Orders;
GO

/* Step 3.5 — Why it matters (Slide 6): what the existing backups give you.
   Restore the full backup + Log1 into a SEPARATE database
   (CrazyDBA_Lab04_NoTail). The original database is not touched.
   EXPECTED: TotalRows = 1500 (Full = 1000, Log1 = 500, no Tail rows).
   100 rows are missing: exactly the tail.                                */
IF DB_ID(N'CrazyDBA_Lab04_NoTail') IS NOT NULL
BEGIN
    IF DATABASEPROPERTYEX(N'CrazyDBA_Lab04_NoTail', 'Status') = 'ONLINE'
        ALTER DATABASE CrazyDBA_Lab04_NoTail SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab04_NoTail;
END;
GO

DECLARE @data nvarchar(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(260)),
        @log  nvarchar(260) = CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS nvarchar(260)),
        @sql  nvarchar(max);

IF RIGHT(@data, 1) NOT IN (N'\', N'/')
    SET @data += CASE WHEN CHARINDEX(N'/', @data) > 0 THEN N'/' ELSE N'\' END;
IF RIGHT(@log, 1) NOT IN (N'\', N'/')
    SET @log += CASE WHEN CHARINDEX(N'/', @log) > 0 THEN N'/' ELSE N'\' END;

SET @sql = N'RESTORE DATABASE CrazyDBA_Lab04_NoTail
    FROM DISK = N''CrazyDBA_Lab04_Full.bak''
    WITH MOVE N''CrazyDBA_Lab04''     TO N''' + @data + N'CrazyDBA_Lab04_NoTail.mdf'',
         MOVE N''CrazyDBA_Lab04_log'' TO N''' + @log  + N'CrazyDBA_Lab04_NoTail_log.ldf'',
         NORECOVERY;';
EXEC sys.sp_executesql @sql;
GO

RESTORE LOG CrazyDBA_Lab04_NoTail
    FROM DISK = N'CrazyDBA_Lab04_Log1.trn'
    WITH RECOVERY;
GO

SELECT Phase, COUNT(*) AS OrderRows
FROM CrazyDBA_Lab04_NoTail.dbo.Orders
GROUP BY Phase
ORDER BY MIN(OrderID);

SELECT COUNT(*) AS TotalRows   -- EXPECTED: 1500
FROM CrazyDBA_Lab04_NoTail.dbo.Orders;
GO

USE master;
GO
