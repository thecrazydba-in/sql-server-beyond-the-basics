/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 09 — Autogrowth Settings and VLF Count | Step 1 of 5: Setup
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE master;
GO

/* ------------------------------------------------------------------
   STEP 1.1  Drop the lab database if it already exists (re-runnable).
   SSMS: run the whole script with F5.
   EXPECTED: no error. CrazyDBA_Lab09 is dropped if it was there.
------------------------------------------------------------------- */
IF DB_ID(N'CrazyDBA_Lab09') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab09 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab09;
END;
GO

/* ------------------------------------------------------------------
   STEP 1.2  Create CrazyDBA_Lab09 in the instance default folders.
   The log starts at 100 MB with a deliberately tiny autogrowth of
   1 MB (the setting this episode is about).
   Creating a 100 MB log uses the "64 MB up to 1 GB" rule: 8 VLFs.
   EXPECTED: database created, no error.
------------------------------------------------------------------- */
DECLARE @data nvarchar(512) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(512)),
        @log  nvarchar(512) = CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS nvarchar(512)),
        @sql  nvarchar(max);

IF RIGHT(@data, 1) NOT IN (N'\', N'/') SET @data += N'\';
IF RIGHT(@log, 1)  NOT IN (N'\', N'/') SET @log  += N'\';

SET @sql = N'CREATE DATABASE CrazyDBA_Lab09
ON PRIMARY
    (NAME = N''CrazyDBA_Lab09'',
     FILENAME = N''' + @data + N'CrazyDBA_Lab09.mdf'',
     SIZE = 64MB, FILEGROWTH = 64MB)
LOG ON
    (NAME = N''CrazyDBA_Lab09_log'',
     FILENAME = N''' + @log + N'CrazyDBA_Lab09_log.ldf'',
     SIZE = 100MB, FILEGROWTH = 1MB);';

EXEC sys.sp_executesql @sql;
GO

/* ------------------------------------------------------------------
   STEP 1.3  Database options, set explicitly.
   - Compatibility level: 160 on SQL Server 2022, 150 on SQL Server 2019
     (VLF behaviour does not depend on the compatibility level).
   - SIMPLE recovery: no backups needed in the lab; CHECKPOINT truncates.
   - Query Store OFF and AUTO_SHRINK OFF: nothing else writes to or
     resizes the log while you watch it.
   EXPECTED: no error.
------------------------------------------------------------------- */
DECLARE @compat nvarchar(3) =
    CASE WHEN CAST(SERVERPROPERTY('ProductMajorVersion') AS int) >= 16 THEN N'160' ELSE N'150' END;
DECLARE @sql nvarchar(400) =
    N'ALTER DATABASE CrazyDBA_Lab09 SET COMPATIBILITY_LEVEL = ' + @compat + N';';
EXEC sys.sp_executesql @sql;
GO

ALTER DATABASE CrazyDBA_Lab09 SET RECOVERY SIMPLE;
ALTER DATABASE CrazyDBA_Lab09 SET QUERY_STORE = OFF;
ALTER DATABASE CrazyDBA_Lab09 SET AUTO_SHRINK OFF;
GO

USE CrazyDBA_Lab09;
GO

/* ------------------------------------------------------------------
   STEP 1.4  Snapshot table + procedure.
   dbo.usp_LogSnapshot records the log size, the autogrowth setting
   and the VLF count at each step, so you can compare them at the end.
   EXPECTED: no error.
------------------------------------------------------------------- */
CREATE TABLE dbo.LogSnapshot
(
    snapshot_id       int IDENTITY(1, 1) NOT NULL CONSTRAINT PK_LogSnapshot PRIMARY KEY,
    label             varchar(40)  NOT NULL,
    log_size_mb       int          NOT NULL,
    growth_mb         int          NULL,      -- NULL when growth is a percentage
    is_percent_growth bit          NOT NULL,
    vlf_count         int          NOT NULL,
    captured_at       datetime2(0) NOT NULL CONSTRAINT DF_LogSnapshot_captured_at DEFAULT SYSDATETIME()
);
GO

CREATE OR ALTER PROCEDURE dbo.usp_LogSnapshot
    @label varchar(40)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT dbo.LogSnapshot (label, log_size_mb, growth_mb, is_percent_growth, vlf_count)
    SELECT @label,
           f.size / 128,                                   -- size is in 8 KB pages; 128 pages = 1 MB
           CASE WHEN f.is_percent_growth = 0 THEN f.growth / 128 END,
           f.is_percent_growth,
           (SELECT COUNT(*) FROM sys.dm_db_log_info(DB_ID()))
    FROM sys.database_files AS f
    WHERE f.type_desc = N'LOG';

    SELECT label, log_size_mb, growth_mb, is_percent_growth, vlf_count
    FROM dbo.LogSnapshot
    WHERE snapshot_id = SCOPE_IDENTITY();
END;
GO

/* ------------------------------------------------------------------
   STEP 1.5  Verification. Must match "Expected results" in README.md.
   EXPECTED (one row):
     label         | log_size_mb | growth_mb | is_percent_growth | vlf_count
     1 after setup | 100         | 1         | 0                 | 8
------------------------------------------------------------------- */
CHECKPOINT;
EXEC dbo.usp_LogSnapshot @label = '1 after setup';
GO
