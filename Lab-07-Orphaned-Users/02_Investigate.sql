/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 07 — Orphaned Users After a Restore | Step 3 of 5: Investigate
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* Run after 01_Reproduce.sql. Read-only: nothing is changed here.
   Video: Slides 2, 3 and 4. SSMS: press F5, then read each result grid
   (Results tab) from top to bottom. */

SET NOCOUNT ON;
USE CrazyDBA_Lab07;
GO

/* ---------------------------------------------------------------
   STEP 3.1 — Same name, different SID (Slide 2).
   The database user stores a SID. The server login has its own SID.
   EXPECTED: 2 rows. The two sid values are DIFFERENT.
   (The hex values are random and differ on every machine.)
   --------------------------------------------------------------- */
SELECT N'database user AppUser'       AS principal, dp.sid
FROM sys.database_principals AS dp
WHERE dp.name = N'AppUser'
UNION ALL
SELECT N'server login CrazyDBA_App07' AS principal, sp.sid
FROM sys.server_principals AS sp
WHERE sp.name = N'CrazyDBA_App07';
GO

/* ---------------------------------------------------------------
   STEP 3.2 — THE ORPHAN CHECK (Slides 3 and 4).
   Users whose SID matches no server login. authentication_type_desc
   = 'INSTANCE' keeps the check to users based on SQL Server logins.
   This is the exact code from Slide 3.
   EXPECTED (2 rows, Slide 4):
     user_name  | type_desc
     AppUser    | SQL_USER
     ReportUser | SQL_USER
   --------------------------------------------------------------- */
SELECT dp.name AS user_name, dp.type_desc
FROM sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp ON sp.sid = dp.sid
WHERE sp.sid IS NULL
  AND dp.authentication_type_desc = 'INSTANCE'
ORDER BY dp.name;
GO

/* ---------------------------------------------------------------
   STEP 3.3 — Which fix does each orphan need? (Slide 4 tip, Slide 7)
   In this lab each user belongs to a known login (in real life: your
   documentation, or the login with the same name).
   EXPECTED (2 rows):
     AppUser    | CrazyDBA_App07 | login exists, different SID
     ReportUser | CrazyDBA_Rpt07 | login missing
   --------------------------------------------------------------- */
SELECT v.user_name,
       v.login_name,
       CASE WHEN sp.principal_id IS NULL
            THEN N'login missing'
            ELSE N'login exists, different SID'
       END AS status
FROM (VALUES (N'AppUser',    N'CrazyDBA_App07'),
             (N'ReportUser', N'CrazyDBA_Rpt07')) AS v (user_name, login_name)
LEFT JOIN sys.server_principals AS sp
       ON sp.name COLLATE DATABASE_DEFAULT = v.login_name
ORDER BY v.user_name;
GO

/* ---------------------------------------------------------------
   STEP 3.4 — The permissions are still inside the database (Slide 5).
   They belong to the database users, so the restore kept them.
   That is why you REMAP the users instead of dropping them.
   EXPECTED, first grid (1 row):
     AppUser | SELECT | GRANT | Orders
   EXPECTED, second grid (1 row):
     db_datareader | ReportUser
   --------------------------------------------------------------- */
SELECT dp.name           AS user_name,
       p.permission_name,
       p.state_desc,
       OBJECT_NAME(p.major_id) AS object_name
FROM sys.database_permissions AS p
JOIN sys.database_principals  AS dp ON dp.principal_id = p.grantee_principal_id
WHERE dp.name IN (N'AppUser', N'ReportUser')
  AND p.class = 1          -- object-level permissions only
ORDER BY dp.name;

SELECT r.name AS role_name,
       m.name AS member_name
FROM sys.database_role_members AS rm
JOIN sys.database_principals   AS r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals   AS m ON m.principal_id = rm.member_principal_id
WHERE m.name IN (N'AppUser', N'ReportUser')
ORDER BY r.name;
GO
