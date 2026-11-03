/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 10 — Statistics: Checking the Modification Counter | Step 5 of 5: Cleanup
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* Drops the lab database. No server settings were changed by this lab. */

USE master;
GO

IF DB_ID(N'CrazyDBA_Lab10') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab10 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab10;
END;
GO
