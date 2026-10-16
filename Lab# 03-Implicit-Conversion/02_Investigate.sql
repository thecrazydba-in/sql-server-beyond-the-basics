/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 03 — Implicit Conversion | Step 3 of 5: Investigate
   Requires: SQL Server 2019+ (or 2022) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE CrazyDBA_Lab03;
GO

/* EVIDENCE 1 — the plan XML (video Slide 4).
   Ctrl + M on, run the batch below.
   Right-click the plan → Show Execution Plan XML... → search for PlanAffectingConvert.

   EXPECTED (inside <Warnings>):
     <PlanAffectingConvert ConvertIssue="Seek Plan"
       Expression="CONVERT_IMPLICIT(nvarchar(20),[c].[AccountNumber],0)=[@Acct]" />
   You may also see a second line with ConvertIssue="Cardinality Estimate".

   EVIDENCE 2 — rows read (video Slide 5).
   Click the Index Scan operator, press F4 (Properties).
   EXPECTED: Number of Rows Read = 100000
             Actual Number of Rows (for All Executions) = 1 */
EXEC sp_executesql
  N'SELECT c.CustomerID FROM dbo.Customers AS c
    WHERE c.AccountNumber = @Acct',
  N'@Acct nvarchar(20)',
  @Acct = N'AW00012345';
GO

/* EVIDENCE 3 — find plan-affecting conversions in the plan cache, for this lab database only.
   No Ctrl + M needed.
   EXPECTED: at least one row with ConvertIssue = Seek Plan and
             Expression = CONVERT_IMPLICIT(nvarchar(20),[c].[AccountNumber],0)=[@Acct]
   (A Cardinality Estimate row may also appear.) */
WITH XMLNAMESPACES (DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT  w.n.value(N'@ConvertIssue', N'nvarchar(128)') AS ConvertIssue,
        w.n.value(N'@Expression',   N'nvarchar(4000)') AS Expression,
        cp.usecounts                                    AS UseCounts,
        st.text                                         AS QueryText
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle)  AS st
CROSS APPLY qp.query_plan.nodes(N'//PlanAffectingConvert') AS w(n)
WHERE qp.dbid = DB_ID(N'CrazyDBA_Lab03')
  AND st.text NOT LIKE N'%dm_exec_cached_plans%';
GO
