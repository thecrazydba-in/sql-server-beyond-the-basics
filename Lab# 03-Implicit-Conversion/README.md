# Lab 03 — Implicit Conversion: Finding the Warning Affecting an Indexed Column

Watch the video: [YouTube](VIDEO_URL) · [Instagram](VIDEO_URL)

## What you'll learn
- Why a varchar column compared to an nvarchar parameter gets converted on every row.
- How to spot the conversion warning on SELECT and `PlanAffectingConvert` in the plan XML.
- How to restore the index seek by matching the parameter type to the column.

## Requirements
- SQL Server 2019 or 2022 Developer Edition (free), SSMS 20+.
- A test instance. The lab creates and drops its own database, `CrazyDBA_Lab03`, and changes no server settings.

## Steps
| Step | Script | What it does | Video |
|---|---|---|---|
| 1 | `00_Setup.sql` | Creates `CrazyDBA_Lab03`, `dbo.Customers` (100,000 rows) and `IX_Customers_AccountNumber` | — |
| 2 | `01_Reproduce.sql` | Runs the query with an `nvarchar(20)` parameter (Ctrl + M on) | Slides 1–3 |
| 3 | `02_Investigate.sql` | Plan XML, Number of Rows Read, plan-cache search for `PlanAffectingConvert` | Slides 4–5 |
| 4 | `03_Fix_and_Verify.sql` | `varchar(20)` parameter, parameter CAST, and the column-CAST anti-pattern | Slides 6–7 |
| 5 | `04_Cleanup.sql` | Drops the lab database | — |

## Expected results
| Check | Expected |
|---|---|
| Setup: rows in `dbo.Customers` | 100000 |
| Setup: rows with `AccountNumber = 'AW00012345'` | 1 |
| Setup: column | `AccountNumber`, `varchar`, 20, `SQL_Latin1_General_CP1_CI_AS` |
| `nvarchar(20)` parameter: plan | Index Scan (NonClustered) on `[Customers].[IX_Customers_AccountNumber]`, warning on SELECT |
| `nvarchar(20)` parameter: plan XML | `ConvertIssue="Seek Plan"`, `Expression="CONVERT_IMPLICIT(nvarchar(20),[c].[AccountNumber],0)=[@Acct]"` |
| `nvarchar(20)` parameter: Number of Rows Read | 100000 (1 row returned, CustomerID 12345) |
| `varchar(20)` parameter: plan | Index Seek (NonClustered), no warning, Number of Rows Read = 1 |
| `CAST(column AS nvarchar(20))`: plan | Still Index Scan, Number of Rows Read = 100000 |

## SQL Server 2019 notes
- Same behaviour. `00_Setup.sql` sets compatibility level 150 on 2019 and 160 on 2022 automatically.
- The result depends on the **column collation**, not the version. With a Windows collation (e.g. `Latin1_General_CI_AS`), SQL Server can often still seek after the conversion. The lab sets `SQL_Latin1_General_CP1_CI_AS` on the column so you see the scan on any instance.

## Cleanup
Run `04_Cleanup.sql`. It drops `CrazyDBA_Lab03`. Nothing else was changed.

---
[Back to the repository](https://github.com/thecrazydba-in/sql-server-beyond-the-basics)
