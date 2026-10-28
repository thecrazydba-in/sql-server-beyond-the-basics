/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 07 — Orphaned Users After a Restore | Step 1 of 5: Setup
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* This script plays the "OLD SERVER": a database with two working users.
   It creates two lab-only SQL Server logins (CrazyDBA_App07, CrazyDBA_Rpt07)
   and the lab database CrazyDBA_Lab07. 04_Cleanup.sql removes all of them.
   Permissions needed: sysadmin on your TEST instance (CREATE DATABASE,
   ALTER ANY LOGIN, BACKUP/RESTORE and IMPERSONATE are used in this lab).
   The passwords below are lab-only values. Never reuse them anywhere.
   SSMS: open the script and press F5. */

SET NOCOUNT ON;
USE master;
GO

/* ---------------------------------------------------------------
   STEP 1.1 — Drop the lab database if it exists (re-runnable).
   --------------------------------------------------------------- */
IF DB_ID(N'CrazyDBA_Lab07') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab07 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab07;
END;
GO

/* ---------------------------------------------------------------
   STEP 1.2 — Drop the two lab logins if they exist (re-runnable).
   Only these two lab-owned names are touched.
   If DROP LOGIN fails with "currently logged in", close any query
   window that is still impersonating the login (run REVERT; there)
   and run this script again.
   --------------------------------------------------------------- */
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'CrazyDBA_App07')
    DROP LOGIN CrazyDBA_App07;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'CrazyDBA_Rpt07')
    DROP LOGIN CrazyDBA_Rpt07;
GO

/* ---------------------------------------------------------------
   STEP 1.3 — Create the two SQL Server authentication logins.
   SQL Server assigns each one a new SID automatically (no SID option).
   That SID is what the database users will store.
   --------------------------------------------------------------- */
CREATE LOGIN CrazyDBA_App07 WITH PASSWORD = N'CrazyLab07#App';
CREATE LOGIN CrazyDBA_Rpt07 WITH PASSWORD = N'CrazyLab07#Rpt';
GO

/* ---------------------------------------------------------------
   STEP 1.4 — Create the lab database.
   Compatibility level 150 so the lab runs unchanged on SQL Server 2019
   and 2022 (nothing here depends on level 160).
   --------------------------------------------------------------- */
CREATE DATABASE CrazyDBA_Lab07;
GO
ALTER DATABASE CrazyDBA_Lab07 SET COMPATIBILITY_LEVEL = 150;
GO

USE CrazyDBA_Lab07;
GO

/* guest is disabled by default in new databases. The lab makes sure:
   with guest enabled, a login without a user could still get in as guest
   and the Msg 916 symptom in 01_Reproduce.sql would not appear. */
REVOKE CONNECT FROM guest;
GO

/* ---------------------------------------------------------------
   STEP 1.5 — dbo.Orders: 1000 deterministic rows (OrderID 1 to 1000).
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
       CASE WHEN rn % 4 = 0 THEN N'Shipped' ELSE N'Open' END,
       CAST(10 + (rn % 50) AS decimal(10,2))
FROM n;
GO

/* ---------------------------------------------------------------
   STEP 1.6 — Two database users, each mapped to its login.
   AppUser    -> login CrazyDBA_App07, explicit GRANT SELECT on dbo.Orders
   ReportUser -> login CrazyDBA_Rpt07, member of db_datareader
   Each user stores its login's SID in this database.
   --------------------------------------------------------------- */
CREATE USER AppUser FOR LOGIN CrazyDBA_App07;
GRANT SELECT ON dbo.Orders TO AppUser;

CREATE USER ReportUser FOR LOGIN CrazyDBA_Rpt07;
ALTER ROLE db_datareader ADD MEMBER ReportUser;
GO

/* ---------------------------------------------------------------
   STEP 1.7 — Verification.
   EXPECTED (one row):
   orders_rows = 1000 | mapped_users = 2 | orphaned_users = 0
   | guest_connect = 0 | compat_level = 150
   --------------------------------------------------------------- */
SELECT
    (SELECT COUNT(*) FROM dbo.Orders) AS orders_rows,
    (SELECT COUNT(*)
     FROM sys.database_principals AS dp
     JOIN sys.server_principals AS sp ON sp.sid = dp.sid
     WHERE dp.name IN (N'AppUser', N'ReportUser'))          AS mapped_users,
    (SELECT COUNT(*)
     FROM sys.database_principals AS dp
     LEFT JOIN sys.server_principals AS sp ON sp.sid = dp.sid
     WHERE sp.sid IS NULL
       AND dp.authentication_type_desc = 'INSTANCE')        AS orphaned_users,
    (SELECT COUNT(*)
     FROM sys.database_permissions AS p
     WHERE p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'guest')
       AND p.permission_name = N'CONNECT'
       AND p.state IN ('G', 'W'))                            AS guest_connect,
    d.compatibility_level                                    AS compat_level
FROM sys.databases AS d
WHERE d.name = N'CrazyDBA_Lab07';
GO
