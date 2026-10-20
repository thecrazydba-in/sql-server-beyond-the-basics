/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 04 — Tail-Log Backup | Step 4 of 5: Fix and Verify (tail first, then restore)
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* ---------------------------------------------------------------
   Run 02_Investigate.sql first. Close any other query windows that
   are connected to CrazyDBA_Lab04 (backup with NORECOVERY and restore
   need exclusive access). Press F5 to run the whole script.

   SSMS alternative: right-click Databases > Restore Database...
   Options page > "Take tail-log backup before restore".
--------------------------------------------------------------- */
SET NOCOUNT ON;
USE master;
GO

/* Step 4.1 — Back up the tail WITH NORECOVERY (Slide 3).
   NORECOVERY captures the log records that are not in any backup yet
   and leaves the database in the RESTORING state, so nothing can
   change after the tail-log backup.
   EXPECTED: "BACKUP LOG successfully processed ..." in Messages.
   (Damaged database? Microsoft Learn: try WITH CONTINUE_AFTER_ERROR.
    Not part of this lab.)                                                 */
ALTER DATABASE CrazyDBA_Lab04 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO
BACKUP LOG CrazyDBA_Lab04
    TO DISK = N'CrazyDBA_Lab04_Tail.trn'
    WITH NORECOVERY, INIT, FORMAT, CHECKSUM;
GO

/* Step 4.2 — Confirm the database is now waiting for a restore.
   EXPECTED: state_desc = RESTORING                                        */
SELECT name, state_desc
FROM sys.databases
WHERE name = N'CrazyDBA_Lab04';
GO

/* Step 4.3 — Restore in order, tail last (Slide 7).
   No WITH REPLACE is needed: the tail is safe, so SQL Server no longer
   raises Msg 3159.                                                        */
RESTORE DATABASE CrazyDBA_Lab04
    FROM DISK = N'CrazyDBA_Lab04_Full.bak'
    WITH NORECOVERY;
GO
RESTORE LOG CrazyDBA_Lab04
    FROM DISK = N'CrazyDBA_Lab04_Log1.trn'
    WITH NORECOVERY;
GO
RESTORE LOG CrazyDBA_Lab04
    FROM DISK = N'CrazyDBA_Lab04_Tail.trn'
    WITH RECOVERY;
GO
ALTER DATABASE CrazyDBA_Lab04 SET MULTI_USER;
GO

/* Step 4.4 — Verify (Slides 6 and 7).
   EXPECTED: state_desc = ONLINE
             Full = 1000, Log1 = 500, Tail = 100, TotalRows = 1600
   Compare: CrazyDBA_Lab04_NoTail (no tail) = 1500.                        */
SELECT name, state_desc, user_access_desc
FROM sys.databases
WHERE name IN (N'CrazyDBA_Lab04', N'CrazyDBA_Lab04_NoTail');

SELECT Phase, COUNT(*) AS OrderRows
FROM CrazyDBA_Lab04.dbo.Orders
GROUP BY Phase
ORDER BY MIN(OrderID);

SELECT N'With tail'    AS RestoreType, COUNT(*) AS TotalRows FROM CrazyDBA_Lab04.dbo.Orders
UNION ALL
SELECT N'Without tail' AS RestoreType, COUNT(*) AS TotalRows FROM CrazyDBA_Lab04_NoTail.dbo.Orders;
GO

/* Step 4.5 — The tail-log backup in msdb.
   EXPECTED newest row: type = L, physical_device_name ends with
   CrazyDBA_Lab04_Tail.trn                                                 */
SELECT TOP (3)
       bs.type,
       bs.backup_finish_date,
       bmf.physical_device_name
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf
     ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = N'CrazyDBA_Lab04'
ORDER BY bs.backup_set_id DESC;
GO

USE master;
GO
