# Lab 10 — Statistics: Checking the Modification Counter



## What you'll learn
- Why SQL Server counts data changes instead of updating statistics right away.
- How the auto-update threshold scales with table size, and how to calculate it.
- How to read `modification_counter` and the histogram's last step, then fix just the statistic that is behind.

## Requirements
- SQL Server 2019 or 2022 (Developer Edition is free), SSMS.
- A test instance. The lab creates and drops its own database, `CrazyDBA_Lab10`. No server settings are changed.
- About 1 minute for setup (1,000,000 rows).

## Steps
| Step | Script | What it does | Slides |
|---|---|---|---|
| 1 | `00_Setup.sql` | Creates `dbo.Orders` with 1,000,000 rows for 2025 and two indexes with fresh statistics | — |
| 2 | `01_Reproduce.sql` | Inserts 30,000 rows for January 2026, runs a query, shows the statistics were not refreshed | 1–3 |
| 3 | `02_Investigate.sql` | Reads `modification_counter`, calculates the threshold, checks the histogram's last step, compares estimates (Ctrl + M) | 3–6 |
| 4 | `03_Fix_and_Verify.sql` | `UPDATE STATISTICS dbo.Orders IX_Orders_OrderDate WITH FULLSCAN` and verifies the result | 7 |
| 5 | `04_Cleanup.sql` | Drops `CrazyDBA_Lab10` | — |

## Expected results
| Check | After 01_Reproduce | After 03_Fix_and_Verify |
|---|---|---|
| `rows` (IX_Orders_OrderDate) | 1000000 | 1030000 |
| `modification_counter` (IX_Orders_OrderDate) | 30000 | 0 |
| `modification_counter` (PK_Orders) | 30000 | 30000 (not updated: targeted fix) |
| Changed | 3.00 % | — |
| Dynamic threshold, CEILING(SQRT(1000 × rows)) | 31623 | — |
| Histogram last step `range_high_key` | 2025-12-31 | 2026-01-30 |
| Histogram last step `equal_rows` | 2739 | 1000 |
| Actual rows, `OrderDate >= '20260101'` | 30000 | 30000 |

The estimated row count for January 2026 before the fix is not listed: no histogram step covers those dates, so the value is an extrapolation that depends on the cardinality estimator version.

## SQL Server 2019 notes
- The lab runs unchanged on SQL Server 2019 and 2022 (it uses compatibility level 150).
- The dynamic threshold `MIN(500 + 0.20 × n, SQRT(1000 × n))` applies from compatibility level 130 (SQL Server 2016). Lower levels use 500 + 20% of the rows.
- `sys.dm_db_stats_histogram` needs SQL Server 2016 SP1 CU2 or later; `DBCC SHOW_STATISTICS ... WITH HISTOGRAM` works everywhere.

## Cleanup
Run `04_Cleanup.sql`. It drops `CrazyDBA_Lab10`; nothing else was changed.

---
[← Back to all labs](https://github.com/thecrazydba-in/sql-server-beyond-the-basics)
