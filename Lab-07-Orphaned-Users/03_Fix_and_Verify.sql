/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 07 — Orphaned Users After a Restore | Step 4 of 5: Fix and Verify
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* Run after 02_Investigate.sql. Video: Slides 6 and 7. SSMS: press F5.
   Targeted fixes only: no user is dropped, no permission is re-granted. */

SET NOCOUNT ON;
USE CrazyDBA_Lab07;
GO

/* ---------------------------------------------------------------
   STEP 4.1 — FIX 1: the login EXISTS, but with a different SID (Slide 6).
   ALTER USER ... WITH LOGIN copies the login's SID into the user.
   The user keeps its name (AppUser) and all its permissions.
   Needs CONTROL permission on the database.
   This is the exact code from Slide 6.
   EXPECTED: "Commands completed successfully."
   --------------------------------------------------------------- */
USE CrazyDBA_Lab07;
ALTER USER AppUser
    WITH LOGIN = CrazyDBA_App07;
GO

/* ---------------------------------------------------------------
   STEP 4.2 — FIX 2: the login is MISSING (Slide 7, row [2]).
   Create it with the SID the user already has, so the existing user
   matches it without any change inside the database.
   CREATE LOGIN only accepts a literal SID, so the statement is built
   from the user's SID (CONVERT style 1 gives the '0x...' form).
   Needs ALTER ANY LOGIN. Lab-only password.
   EXPECTED: "Created login CrazyDBA_Rpt07 with the SID of ReportUser."
   --------------------------------------------------------------- */
USE master;
GO

DECLARE @sid varbinary(85);
DECLARE @sql nvarchar(max);

SELECT @sid = dp.sid
FROM CrazyDBA_Lab07.sys.database_principals AS dp
WHERE dp.name = N'ReportUser';

IF @sid IS NULL
    PRINT N'ReportUser not found: run 00_Setup.sql and 01_Reproduce.sql first.';
ELSE IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'CrazyDBA_Rpt07')
    PRINT N'Login CrazyDBA_Rpt07 already exists: nothing to create.';
ELSE
BEGIN
    SET @sql = N'CREATE LOGIN CrazyDBA_Rpt07 WITH PASSWORD = N''CrazyLab07#Rpt'', SID = '
             + CONVERT(nvarchar(200), CONVERT(varchar(200), @sid, 1)) + N';';
    EXEC sys.sp_executesql @sql;
    PRINT N'Created login CrazyDBA_Rpt07 with the SID of ReportUser.';
END;
GO

/* ---------------------------------------------------------------
   STEP 4.3 — VERIFY 1: rerun the orphan check (Slide 7, row [3]).
   EXPECTED: 0 rows (empty grid with the headers user_name | type_desc)
   --------------------------------------------------------------- */
USE CrazyDBA_Lab07;
GO

SELECT dp.name AS user_name, dp.type_desc
FROM sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp ON sp.sid = dp.sid
WHERE sp.sid IS NULL
  AND dp.authentication_type_desc = 'INSTANCE'
ORDER BY dp.name;
GO

/* ---------------------------------------------------------------
   STEP 4.4 — VERIFY 2: each user now has the same SID as its login.
   EXPECTED (2 rows):
     AppUser    | CrazyDBA_App07 | same_sid = 1
     ReportUser | CrazyDBA_Rpt07 | same_sid = 1
   --------------------------------------------------------------- */
SELECT dp.name AS user_name,
       sp.name AS login_name,
       CASE WHEN dp.sid = sp.sid THEN 1 ELSE 0 END AS same_sid
FROM sys.database_principals AS dp
JOIN sys.server_principals   AS sp
  ON sp.name COLLATE DATABASE_DEFAULT
     = CASE dp.name WHEN N'AppUser'    THEN N'CrazyDBA_App07'
                    WHEN N'ReportUser' THEN N'CrazyDBA_Rpt07' END
WHERE dp.name IN (N'AppUser', N'ReportUser')
ORDER BY dp.name;
GO

/* ---------------------------------------------------------------
   STEP 4.5 — VERIFY 3: read dbo.Orders as each login (Slide 7, row [4]).
   Run from master, like an application that connects and then reads.
   EXPECTED: app_rows = 1000, then report_rows = 1000
   --------------------------------------------------------------- */
USE master;
GO

EXECUTE AS LOGIN = N'CrazyDBA_App07';
SELECT COUNT(*) AS app_rows FROM CrazyDBA_Lab07.dbo.Orders;
REVERT;
GO

EXECUTE AS LOGIN = N'CrazyDBA_Rpt07';
SELECT COUNT(*) AS report_rows FROM CrazyDBA_Lab07.dbo.Orders;
REVERT;
GO

/* Safety net: make sure you are yourself again.
   EXPECTED: current_login = your own login name */
IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;
SELECT SUSER_SNAME() AS current_login;
GO

/* ---------------------------------------------------------------
   STEP 4.6 — VERIFY 4: permissions were kept, nothing was re-granted.
   EXPECTED, first grid:  AppUser | SELECT | GRANT | Orders
   EXPECTED, second grid: db_datareader | ReportUser
   (Identical to STEP 3.4 in 02_Investigate.sql.)
   --------------------------------------------------------------- */
USE CrazyDBA_Lab07;
GO

SELECT dp.name           AS user_name,
       p.permission_name,
       p.state_desc,
       OBJECT_NAME(p.major_id) AS object_name
FROM sys.database_permissions AS p
JOIN sys.database_principals  AS dp ON dp.principal_id = p.grantee_principal_id
WHERE dp.name IN (N'AppUser', N'ReportUser')
  AND p.class = 1
ORDER BY dp.name;

SELECT r.name AS role_name,
       m.name AS member_name
FROM sys.database_role_members AS rm
JOIN sys.database_principals   AS r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals   AS m ON m.principal_id = rm.member_principal_id
WHERE m.name IN (N'AppUser', N'ReportUser')
ORDER BY r.name;
GO
