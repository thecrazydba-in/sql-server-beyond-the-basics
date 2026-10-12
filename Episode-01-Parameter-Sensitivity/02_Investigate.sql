/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 01 — Parameter Sensitivity | Step 3 of 5: Investigate
   Requires: SQL Server 2019+ (2022 for the optional steps in 03) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE CrazyDBA_Lab01;
GO

/* Run 01_Reproduce.sql first. Keep Ctrl + M (Include Actual Execution Plan) ON. */

/* ---------------------------------------------------------------
   Evidence 1 (video Slide 4): estimated vs actual rows.
   Run the slow call again; the cached 'SmallTown' plan is reused.
   EXPECTED on the Execution plan tab:
     Index Seek (NonClustered) [Orders].[IX_Orders_City]
       500000 of 200 (250000%)
     Key Lookup (Clustered) [Orders].[PK_Orders]
       Click it, press F4: Number of Executions = 500000
   --------------------------------------------------------------- */
EXEC dbo.GetOrdersByCity @City = N'MetroCity';
GO

/* ---------------------------------------------------------------
   Evidence 2 (video Slide 5): compiled vs runtime value.
   In the plan from the call above:
     Right-click the plan > Show Execution Plan XML...
     Search for ParameterList.
   EXPECTED (exactly):
     <ParameterList>
       <ColumnReference Column="@City"
         ParameterDataType="nvarchar(50)"
         ParameterCompiledValue="N'SmallTown'"
         ParameterRuntimeValue="N'MetroCity'" />
     </ParameterList>
   Same values in the GUI: click SELECT, press F4, expand Parameter List.
   (In the XML everything is on one line; it is wrapped here for reading.)
   --------------------------------------------------------------- */

/* ---------------------------------------------------------------
   Evidence 3: the cached plan shows ONLY the compiled value.
   Requires VIEW SERVER STATE (2019) or VIEW SERVER PERFORMANCE STATE (2022).
   EXPECTED:
     execution_count: 3 if you ran 01 once and this script once
     max_logical_reads: thousands of times larger than min_logical_reads
     query_plan (click it): ParameterCompiledValue="N'SmallTown'" and
       NO ParameterRuntimeValue. That is why you need an actual plan.
   --------------------------------------------------------------- */
SELECT ps.execution_count,
       ps.min_logical_reads,
       ps.max_logical_reads,
       qp.query_plan
FROM sys.dm_exec_procedure_stats AS ps
CROSS APPLY sys.dm_exec_query_plan(ps.plan_handle) AS qp
WHERE ps.database_id = DB_ID()
  AND ps.object_id = OBJECT_ID(N'dbo.GetOrdersByCity');
GO
