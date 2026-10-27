/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 06 — Wait Statistics: Take a Delta | Step 1 of 5: Setup
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE master;
GO

/* ---------------------------------------------------------------
   STEP 1.1 — Drop and recreate the lab database (re-runnable).
   SSMS: press F5 to run the whole script.
   --------------------------------------------------------------- */
IF DB_ID(N'CrazyDBA_Lab06') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab06 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab06;
END;
GO

CREATE DATABASE CrazyDBA_Lab06;
GO

/* Compatibility level 150 so the lab runs unchanged on SQL Server 2019 and 2022.
   Nothing in this lab depends on level 160.
   READ_COMMITTED_SNAPSHOT is set OFF explicitly: the lab needs a reader that
   waits for a Shared lock (LCK_M_S). With RCSI ON, the reader would not block. */
ALTER DATABASE CrazyDBA_Lab06 SET COMPATIBILITY_LEVEL = 150;
ALTER DATABASE CrazyDBA_Lab06 SET READ_COMMITTED_SNAPSHOT OFF;
ALTER DATABASE CrazyDBA_Lab06 SET ALLOW_SNAPSHOT_ISOLATION OFF;
GO

USE CrazyDBA_Lab06;
GO

/* ---------------------------------------------------------------
   STEP 1.2 — dbo.Orders: 1000 deterministic rows (OrderID 1 to 1000).
   Row 42 is the row that gets blocked in 01_Reproduce.sql.
   --------------------------------------------------------------- */
CREATE TABLE dbo.Orders
(
    OrderID    int           NOT NULL,
    Customer   nvarchar(20)  NOT NULL,
    Status     nvarchar(10)  NOT NULL,
    Amount     decimal(10,2) NOT NULL,
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderID)
);
GO

WITH n AS
(
    SELECT TOP (1000)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_columns AS a
    CROSS JOIN sys.all_columns AS b
)
INSERT INTO dbo.Orders (OrderID, Customer, Status, Amount)
SELECT rn,
       N'Customer' + RIGHT(N'000' + CAST(rn % 100 AS nvarchar(3)), 3),
       N'Open',
       CAST(10 + (rn % 50) AS decimal(10,2))
FROM n;
GO

/* ---------------------------------------------------------------
   STEP 1.3 — dbo.IgnoredWait: waits the snapshots skip (44 rows).
   Sources (Microsoft Learn):
   - "Idle" and "User Wait" wait categories in sys.query_store_wait_stats.
   - Waits that sys.dm_os_wait_stats documents as "Internal use only",
     or as background tasks waiting for work.
   Patterns are used with LIKE ('SLEEP_%' covers all SLEEP_ waits).
   You can add your own rows later; the lab expects 44.
   --------------------------------------------------------------- */
CREATE TABLE dbo.IgnoredWait
(
    wait_type_pattern nvarchar(60)  NOT NULL,
    reason            nvarchar(60)  NOT NULL,
    CONSTRAINT PK_IgnoredWait PRIMARY KEY CLUSTERED (wait_type_pattern)
);
GO

INSERT INTO dbo.IgnoredWait (wait_type_pattern, reason)
VALUES
 -- Query Store category "Idle" (12)
 (N'SLEEP_%',                                        N'Idle category'),
 (N'LAZYWRITER_SLEEP',                               N'Idle category'),
 (N'SQLTRACE_BUFFER_FLUSH',                          N'Idle category'),
 (N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',               N'Idle category'),
 (N'SQLTRACE_WAIT_ENTRIES',                          N'Idle category'),
 (N'FT_IFTS_SCHEDULER_IDLE_WAIT',                    N'Idle category'),
 (N'XE_DISPATCHER_WAIT',                             N'Idle category'),
 (N'REQUEST_FOR_DEADLOCK_SEARCH',                    N'Idle category'),
 (N'LOGMGR_QUEUE',                                   N'Idle category'),
 (N'ONDEMAND_TASK_QUEUE',                            N'Idle category'),
 (N'CHECKPOINT_QUEUE',                               N'Idle category'),
 (N'XE_TIMER_EVENT',                                 N'Idle category'),
 -- Query Store category "User Wait" (3)
 (N'WAITFOR',                                        N'User Wait category'),
 (N'WAIT_FOR_RESULTS',                               N'User Wait category'),
 (N'BROKER_RECEIVE_WAITFOR',                         N'User Wait category'),
 -- Documented as "Internal use only" (19)
 (N'DIRTY_PAGE_POLL',                                N'Internal use only'),
 (N'SP_SERVER_DIAGNOSTICS_SLEEP',                    N'Internal use only'),
 (N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',               N'Internal use only'),
 (N'QDS_ASYNC_QUEUE',                                N'Internal use only'),
 (N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', N'Internal use only'),
 (N'QDS_SHUTDOWN_QUEUE',                             N'Internal use only'),
 (N'SOS_WORK_DISPATCHER',                            N'Internal use only'),
 (N'XE_LIVE_TARGET_TVF',                             N'Internal use only'),
 (N'PWAIT_ALL_COMPONENTS_INITIALIZED',               N'Internal use only'),
 (N'PREEMPTIVE_XE_GETTARGETSTATE',                   N'Internal use only'),
 (N'HADR_NOTIFICATION_DEQUEUE',                      N'Internal use only'),
 (N'PARALLEL_REDO_DRAIN_WORKER',                     N'Internal use only'),
 (N'PARALLEL_REDO_LOG_CACHE',                        N'Internal use only'),
 (N'PARALLEL_REDO_TRAN_LIST',                        N'Internal use only'),
 (N'PARALLEL_REDO_WORKER_SYNC',                      N'Internal use only'),
 (N'PARALLEL_REDO_WORKER_WAIT_WORK',                 N'Internal use only'),
 (N'REDO_THREAD_PENDING_WORK',                       N'Internal use only'),
 (N'UCS_SESSION_REGISTRATION',                       N'Internal use only'),
 (N'VDI_CLIENT_OTHER',                               N'Internal use only'),
 -- Documented background tasks waiting for work (10)
 (N'KSOURCE_WAKEUP',                                 N'Background, waiting for work'),
 (N'BROKER_TRANSMITTER',                             N'Background, waiting for work'),
 (N'BROKER_TO_FLUSH',                                N'Background, waiting for work'),
 (N'BROKER_EVENTHANDLER',                            N'Background, waiting for work'),
 (N'DISPATCHER_QUEUE_SEMAPHORE',                     N'Background, waiting for work'),
 (N'HADR_WORK_QUEUE',                                N'Background, waiting for work'),
 (N'CLR_AUTO_EVENT',                                 N'Background, waiting for work'),
 (N'XE_BUFFERMGR_ALLPROCESSED_EVENT',                N'Background, waiting for work'),
 (N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',             N'Background, waiting for work'),
 (N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',                  N'Background, waiting for work');
GO

/* ---------------------------------------------------------------
   STEP 1.4 — Two snapshot tables with the same shape:
   dbo.WaitsBefore and dbo.WaitsAfter.
   --------------------------------------------------------------- */
CREATE TABLE dbo.WaitsBefore
(
    wait_type           nvarchar(60) NOT NULL,
    waiting_tasks_count bigint       NOT NULL,
    wait_time_ms        bigint       NOT NULL,
    signal_wait_time_ms bigint       NOT NULL,
    captured_at         datetime2(0) NOT NULL
        CONSTRAINT DF_WaitsBefore_captured_at DEFAULT (SYSDATETIME())
);
CREATE CLUSTERED INDEX CIX_WaitsBefore ON dbo.WaitsBefore (wait_type);

CREATE TABLE dbo.WaitsAfter
(
    wait_type           nvarchar(60) NOT NULL,
    waiting_tasks_count bigint       NOT NULL,
    wait_time_ms        bigint       NOT NULL,
    signal_wait_time_ms bigint       NOT NULL,
    captured_at         datetime2(0) NOT NULL
        CONSTRAINT DF_WaitsAfter_captured_at DEFAULT (SYSDATETIME())
);
CREATE CLUSTERED INDEX CIX_WaitsAfter ON dbo.WaitsAfter (wait_type);
GO

/* ---------------------------------------------------------------
   STEP 1.5 — Verification.
   EXPECTED (one row):
   orders_rows = 1000 | ignored_waits = 44 | before_rows = 0 | after_rows = 0
   | rcsi_on = 0 | compat_level = 150
   --------------------------------------------------------------- */
SELECT
    (SELECT COUNT(*) FROM dbo.Orders)      AS orders_rows,
    (SELECT COUNT(*) FROM dbo.IgnoredWait) AS ignored_waits,
    (SELECT COUNT(*) FROM dbo.WaitsBefore) AS before_rows,
    (SELECT COUNT(*) FROM dbo.WaitsAfter)  AS after_rows,
    d.is_read_committed_snapshot_on        AS rcsi_on,
    d.compatibility_level                  AS compat_level
FROM sys.databases AS d
WHERE d.name = N'CrazyDBA_Lab06';
GO
