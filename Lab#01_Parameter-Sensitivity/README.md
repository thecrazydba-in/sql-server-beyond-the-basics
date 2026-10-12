# Lab 01 — Parameter Sensitivity: Compiled vs Runtime Values

**The CrazyDBA · SQL Server — Beyond the Basics**

Watch the video: [YouTube](https://www.youtube.com/@learnwithcrazydba) · [Instagram](https://www.instagram.com/learnwiththecrazydba/)

## What you'll learn

1. Why SQL Server reuses a plan that was compiled for the first parameter value.
2. How to spot the problem in an actual plan: `500000 of 200 (250000%)`.
3. How to prove it with `ParameterCompiledValue` vs `ParameterRuntimeValue`, then test one targeted fix.

## Requirements

- SQL Server 2019 or later, Developer Edition (free). SQL Server 2022 is the series baseline; Options C and D in step 4 need SQL Server 2022 or later.
- SQL Server Management Studio (SSMS) 18 or later, so the "actual of estimated" row counts appear under each operator.
- A **test instance only**. The lab creates its own database, `CrazyDBA_Lab01`, and changes no server-level settings.
- A little free disk space: the lab database is small (well under 1 GB).
- For `02_Investigate.sql`, Evidence 3: VIEW SERVER STATE (2019) or VIEW SERVER PERFORMANCE STATE (2022).

## Steps

| Step | Script | What it does | Video slide |
|---|---|---|---|
| 1 | `00_Setup.sql` | Creates `CrazyDBA_Lab01`, table `dbo.Orders` (500,200 rows), index `IX_Orders_City`, procedure `dbo.GetOrdersByCity`. | Slide 1 |
| 2 | `01_Reproduce.sql` | Press **Ctrl + M** first. Runs `'SmallTown'` (plan compiled and cached), then `'MetroCity'` (same plan reused). | Slides 2, 3, 4 |
| 3 | `02_Investigate.sql` | Evidence 1: actual vs estimated rows. Evidence 2: compiled vs runtime value in the plan XML. Evidence 3: the cached plan has only the compiled value. | Slides 4, 5, 6 |
| 4 | `03_Fix_and_Verify.sql` | Option A `OPTION (RECOMPILE)`, Option B `OPTIMIZE FOR`, Option C Query Store hint (2022+), Option D PSP optimization (2022+, experiment). | Slide 7 |
| 5 | `04_Cleanup.sql` | Drops `CrazyDBA_Lab01`. | — |

Tip: in SSMS, *Query > Query Options > Results > Grid > Discard results after execution* stops SSMS from drawing 500,000 rows in the grid. The actual plan is still captured.

## Expected results

| Check | Expected |
|---|---|
| Rows per city (end of `00_Setup.sql`) | `SmallTown` = 200, `MetroCity` = 500000 |
| Histogram of `IX_Orders_City` | `MetroCity` equal_rows = 500000, `SmallTown` equal_rows = 200 |
| `01`, first call `N'SmallTown'` | Index Seek (NonClustered) `[Orders].[IX_Orders_City]` + Key Lookup (Clustered) `[Orders].[PK_Orders]`, under Nested Loops (Inner Join). Seek shows `200 of 200 (100%)`. |
| `01`, second call `N'MetroCity'` | Same plan. Index Seek shows `500000 of 200 (250000%)`. Key Lookup Number of Executions = 500000. |
| Plan XML, Parameter List | `ParameterDataType="nvarchar(50)"`, `ParameterCompiledValue="N'SmallTown'"`, `ParameterRuntimeValue="N'MetroCity'"` |
| Cached plan (`sys.dm_exec_query_plan`) | `ParameterCompiledValue="N'SmallTown'"` only, no runtime value |
| Option A, `N'MetroCity'` | Clustered Index Scan `[Orders].[PK_Orders]`, `500000 of 500000 (100%)` |

## SQL Server 2019 notes

- `00_Setup.sql` sets compatibility level **150** on SQL Server 2019 and **160** on SQL Server 2022 or later.
- Steps 1–3 and Options A and B work the same on 2019 and 2022.
- Option C (Query Store hints) and Option D (Parameter Sensitive Plan optimization) need SQL Server 2022 or later. On 2019, the script prints a message and skips them.
- On SQL Server 2022, `00_Setup.sql` turns PSP optimization **off** for this database so the classic problem reproduces exactly as in the video. Option D turns it on as an experiment, then off again. PSP *may* create separate plans for the two cities; whether it does depends on its internal checks.
- Your plans may include a Parallelism operator for the scan in Option A, depending on your MAXDOP and cost threshold for parallelism. The plan shape otherwise stays the same.

## Cleanup

Run `04_Cleanup.sql`. It drops `CrazyDBA_Lab01`. The lab changed no server-level settings, so nothing else needs to be restored.

---

[Back to all labs](../README.md) · [The CrazyDBA on GitHub](https://github.com/thecrazydba-in/sql-server-beyond-the-basics)
