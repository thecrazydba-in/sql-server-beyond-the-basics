/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 01 — Parameter Sensitivity | Step 4 of 5: Fix and Verify
   Requires: SQL Server 2019+ (2022 for Options C and D) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE CrazyDBA_Lab01;
GO

/* Keep Ctrl + M (Include Actual Execution Plan) ON for the whole script.
   Each option is tested on its own. Every option starts with a cache
   clear for THIS database only. */

/* ===============================================================
   OPTION A (video Slide 7): OPTION (RECOMPILE) on the statement.
   A fresh plan for every execution. Costs some CPU per call.
   =============================================================== */
CREATE OR ALTER PROCEDURE dbo.GetOrdersByCity
    @City nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT OrderID, OrderDate, Total
    FROM dbo.Orders
    WHERE City = @City
    OPTION (RECOMPILE);
END;
GO

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

/* EXPECTED: Index Seek (NonClustered) + Key Lookup, 200 of 200 (100%) */
EXEC dbo.GetOrdersByCity @City = N'SmallTown';
GO

/* EXPECTED: Clustered Index Scan [Orders].[PK_Orders], 500000 of 500000 (100%).
   No Key Lookup. Depending on your MAXDOP and cost threshold for
   parallelism, you may also see a Parallelism (Gather Streams) operator. */
EXEC dbo.GetOrdersByCity @City = N'MetroCity';
GO

/* ===============================================================
   OPTION B (video Slide 7): OPTIMIZE FOR a chosen value.
   The plan is always built for 'MetroCity'. Trade-off: 'SmallTown'
   now scans the whole table to return 200 rows.
   =============================================================== */
CREATE OR ALTER PROCEDURE dbo.GetOrdersByCity
    @City nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT OrderID, OrderDate, Total
    FROM dbo.Orders
    WHERE City = @City
    OPTION (OPTIMIZE FOR (@City = N'MetroCity'));
END;
GO

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

/* EXPECTED: Clustered Index Scan for BOTH calls (plan built for 'MetroCity').
   'SmallTown': the scan reads all 500,200 rows to return 200. */
EXEC dbo.GetOrdersByCity @City = N'SmallTown';
GO
EXEC dbo.GetOrdersByCity @City = N'MetroCity';
GO

/* ===============================================================
   Restore the ORIGINAL procedure (no hint) for Options C and D.
   =============================================================== */
CREATE OR ALTER PROCEDURE dbo.GetOrdersByCity
    @City nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT OrderID, OrderDate, Total
    FROM dbo.Orders
    WHERE City = @City;
END;
GO

/* ===============================================================
   OPTION C (video Slide 7) — SQL Server 2022 and later only.
   Query Store hint: add OPTION(RECOMPILE) WITHOUT changing the code.
   On SQL Server 2019 this block prints a message and does nothing.
   =============================================================== */
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- Run the original statement once so Query Store captures it.
EXEC dbo.GetOrdersByCity @City = N'SmallTown';
GO

IF CAST(SERVERPROPERTY('ProductMajorVersion') AS int) < 16
BEGIN
    PRINT 'Option C skipped: Query Store hints need SQL Server 2022 or later.';
END
ELSE
BEGIN
    EXEC (N'
        DECLARE @query_id bigint =
        (
            SELECT TOP (1) q.query_id
            FROM sys.query_store_query AS q
            INNER JOIN sys.query_store_query_text AS qt
                ON q.query_text_id = qt.query_text_id
            WHERE q.object_id = OBJECT_ID(N''dbo.GetOrdersByCity'')
              AND qt.query_sql_text NOT LIKE N''%OPTION%''
            ORDER BY q.query_id DESC
        );

        IF @query_id IS NULL
            PRINT ''Query not found in Query Store. Run Option C again.'';
        ELSE
        BEGIN
            EXEC sys.sp_query_store_set_hints
                 @query_id = @query_id,
                 @query_hints = N''OPTION(RECOMPILE)'';

            -- EXPECTED: one row, query_hint_text = OPTION(RECOMPILE),
            --           query_hint_failure_count = 0
            SELECT query_id, query_hint_text, query_hint_failure_count
            FROM sys.query_store_query_hints
            WHERE query_id = @query_id;
        END;
    ');
END;
GO

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

/* EXPECTED on SQL Server 2022+: same plans as Option A
   (SmallTown: Index Seek + Key Lookup, MetroCity: Clustered Index Scan),
   although the procedure code has no hint.
   On SQL Server 2019: the original problem (no hint was applied). */
EXEC dbo.GetOrdersByCity @City = N'SmallTown';
GO
EXEC dbo.GetOrdersByCity @City = N'MetroCity';
GO

-- Remove the Query Store hint again (SQL Server 2022+).
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS int) >= 16
BEGIN
    EXEC (N'
        DECLARE @query_id bigint;
        DECLARE hints CURSOR LOCAL FAST_FORWARD FOR
            SELECT h.query_id
            FROM sys.query_store_query_hints AS h
            INNER JOIN sys.query_store_query AS q
                ON h.query_id = q.query_id
            WHERE q.object_id = OBJECT_ID(N''dbo.GetOrdersByCity'');
        OPEN hints;
        FETCH NEXT FROM hints INTO @query_id;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC sys.sp_query_store_clear_hints @query_id = @query_id;
            FETCH NEXT FROM hints INTO @query_id;
        END;
        CLOSE hints;
        DEALLOCATE hints;
    ');
END;
GO

/* ===============================================================
   OPTION D (video Slide 7 tip card) — SQL Server 2022 and later only.
   Parameter Sensitive Plan (PSP) optimization, compatibility level 160.
   PSP MAY create separate plan variants for 'SmallTown' and 'MetroCity'.
   Whether it does depends on its internal skew and boundary checks,
   so treat this as an experiment, not a guaranteed result.
   =============================================================== */
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS int) < 16
    PRINT 'Option D skipped: PSP optimization needs SQL Server 2022 or later.';
ELSE
    EXEC (N'ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON;');
GO

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

EXEC dbo.GetOrdersByCity @City = N'SmallTown';
GO
EXEC dbo.GetOrdersByCity @City = N'MetroCity';
GO

/* EXPECTED if PSP was used: rows in sys.query_store_query_variant for this
   procedure, and in the actual plan XML the statement text ends with
   "option (PLAN PER VALUE(...))".
   EXPECTED if PSP was skipped: no rows, and both calls behave as in 01. */
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS int) >= 16
    EXEC (N'
        SELECT v.query_variant_query_id, v.parent_query_id, v.dispatcher_plan_id
        FROM sys.query_store_query_variant AS v
        INNER JOIN sys.query_store_query AS q
            ON v.parent_query_id = q.query_id
        WHERE q.object_id = OBJECT_ID(N''dbo.GetOrdersByCity'');
    ');
GO

-- Put PSP back OFF so 01_Reproduce.sql reproduces the problem again.
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS int) >= 16
    EXEC (N'ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = OFF;');
GO
