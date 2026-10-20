/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 04 — Tail-Log Backup | Step 1 of 5: Setup (database, data, full backup, log backup)
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* ---------------------------------------------------------------
   What this lab builds (Slide 1):
     Full backup  -> 1,000 rows   (CrazyDBA_Lab04_Full.bak)
     Log backup   -> 1,500 rows   (CrazyDBA_Lab04_Log1.trn)
     Tail         -> +100 rows    (added in 01_Reproduce.sql, in NO backup yet)

   Backup files: only a file name is given in every DISK clause, so
   SQL Server writes them to the instance's DEFAULT BACKUP DIRECTORY.
   Find it with: SELECT SERVERPROPERTY('InstanceDefaultBackupPath');
   (In production scripts, always give a full path.)

   How to run: open this file in SSMS and press F5 (Execute).
--------------------------------------------------------------- */
SET NOCOUNT ON;
USE master;
GO

/* Step 1.1 — Drop the lab databases safely (re-runnable).
   A database left in RESTORING state cannot be set to SINGLE_USER,
   so ALTER only runs when the database is ONLINE.                     */
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

/* Step 1.2 — Remove old msdb backup history for the lab databases only,
   so 02_Investigate.sql shows just this run.                           */
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'CrazyDBA_Lab04';
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'CrazyDBA_Lab04_NoTail';
GO

/* Step 1.3 — Create the database with fixed logical file names
   (CrazyDBA_Lab04 and CrazyDBA_Lab04_log) in the instance default
   data and log folders. 02_Investigate.sql uses these names in WITH MOVE. */
DECLARE @data nvarchar(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(260)),
        @log  nvarchar(260) = CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS nvarchar(260)),
        @sql  nvarchar(max);

IF RIGHT(@data, 1) NOT IN (N'\', N'/')
    SET @data += CASE WHEN CHARINDEX(N'/', @data) > 0 THEN N'/' ELSE N'\' END;
IF RIGHT(@log, 1) NOT IN (N'\', N'/')
    SET @log += CASE WHEN CHARINDEX(N'/', @log) > 0 THEN N'/' ELSE N'\' END;

SET @sql = N'CREATE DATABASE CrazyDBA_Lab04
ON PRIMARY (NAME = N''CrazyDBA_Lab04'',     FILENAME = N''' + @data + N'CrazyDBA_Lab04.mdf'',     SIZE = 64MB, FILEGROWTH = 64MB)
LOG ON     (NAME = N''CrazyDBA_Lab04_log'', FILENAME = N''' + @log  + N'CrazyDBA_Lab04_log.ldf'', SIZE = 64MB, FILEGROWTH = 64MB);';

EXEC sys.sp_executesql @sql;
GO

/* Step 1.4 — FULL recovery model: required for log backups and a tail.
   Compatibility level 150 so the lab runs on SQL Server 2019 and 2022
   (tail-log behaviour does not depend on the compatibility level).    */
ALTER DATABASE CrazyDBA_Lab04 SET RECOVERY FULL;
ALTER DATABASE CrazyDBA_Lab04 SET COMPATIBILITY_LEVEL = 150;
GO

/* Step 1.5 — Table and the first 1,000 rows (Phase = 'Full').         */
USE CrazyDBA_Lab04;
GO

CREATE TABLE dbo.Orders
(
    OrderID      int           NOT NULL CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerName nvarchar(50)  NOT NULL,
    Amount       decimal(10,2) NOT NULL,
    Phase        varchar(10)   NOT NULL   -- which backup should contain the row
);
GO

WITH n AS
(
    SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_columns AS a
    CROSS JOIN sys.all_columns AS b
)
INSERT dbo.Orders (OrderID, CustomerName, Amount, Phase)
SELECT n,
       N'Customer ' + CAST(n AS nvarchar(10)),
       CAST(10 + (n % 90) AS decimal(10,2)),
       'Full'
FROM n;
GO

/* Step 1.6 — Full backup (contains rows 1–1,000).
   EXPECTED: "BACKUP DATABASE successfully processed ..." in Messages.  */
USE master;
GO
BACKUP DATABASE CrazyDBA_Lab04
    TO DISK = N'CrazyDBA_Lab04_Full.bak'
    WITH INIT, FORMAT, CHECKSUM;
GO

/* Step 1.7 — 500 more rows (Phase = 'Log1'), then a log backup.
   After this, the backups cover rows 1–1,500.                           */
USE CrazyDBA_Lab04;
GO

WITH n AS
(
    SELECT TOP (500) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_columns AS a
    CROSS JOIN sys.all_columns AS b
)
INSERT dbo.Orders (OrderID, CustomerName, Amount, Phase)
SELECT 1000 + n,
       N'Customer ' + CAST(1000 + n AS nvarchar(10)),
       CAST(10 + ((1000 + n) % 90) AS decimal(10,2)),
       'Log1'
FROM n;
GO

USE master;
GO
BACKUP LOG CrazyDBA_Lab04
    TO DISK = N'CrazyDBA_Lab04_Log1.trn'
    WITH INIT, FORMAT, CHECKSUM;
GO

/* Step 1.8 — Verification.
   EXPECTED (must match README "Expected results"):
     recovery_model_desc = FULL
     Phase Full = 1000, Phase Log1 = 500, TotalRows = 1500              */
SELECT name, recovery_model_desc, state_desc
FROM sys.databases
WHERE name = N'CrazyDBA_Lab04';

SELECT Phase, COUNT(*) AS OrderRows
FROM CrazyDBA_Lab04.dbo.Orders
GROUP BY Phase
ORDER BY MIN(OrderID);

SELECT COUNT(*) AS TotalRows
FROM CrazyDBA_Lab04.dbo.Orders;
GO

/* Leave the session in master so this window does not hold a
   connection to CrazyDBA_Lab04 (restores need exclusive access). */
USE master;
GO
