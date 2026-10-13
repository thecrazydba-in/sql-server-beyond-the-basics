# Lab 02 — Estimated vs Actual Rows: Identifying One Cardinality Mismatch

**The CrazyDBA — SQL Server: Beyond the Basics**

Watch the video: [YouTube](VIDEO_URL) · [Instagram](VIDEO_URL)

## What you'll learn

- How to read "actual of estimated" row counts in an actual execution plan.
- Why you must check **Number of Executions** before calling something a mismatch.
- How to find the **first** operator where the estimate goes wrong (the origin), and prove the cause.

## Requirements

- SQL Server 2019 or later, Developer Edition (SQL Server 2022 recommended; the video uses 2022).
- SSMS 18.5 or later (for the property names used below).
- About 1 GB of free disk space. Run on a **test instance only**.

## Steps

| Step | Script | Video | What you do |
|---|---|---|---|
| 1 | `00_Setup.sql` | — | Creates `CrazyDBA_Lab02`, `dbo.Orders` (1,250,000 rows) and `dbo.Customers` (200,000 rows). Ends with a verification query. |
| 2 | `01_Reproduce.sql` | Slides 1–3 | Press **Ctrl + M**, run the query, and see `1245620 of 1000 (124562%)` on the Index Seek. |
| 3 | `02_Investigate.sql` | Slides 3–6 | Confirm in Properties (**F4**), check Number of Executions, find the origin, and see *why* the estimate is 1,000. |
| 4 | `03_Fix_and_Verify.sql` | Slide 7 | Test one targeted option at a time and verify that the estimate matches the actual rows. |
| 5 | `04_Cleanup.sql` | — | Drops the lab database. |

## Expected results

| Check | Expected value |
|---|---|
| Total orders | 1,250,000 |
| Orders with `Status = N'Shipped'` | 1,245,620 |
| Distinct statuses | 1,250 |
| Average rows per status (the estimate) | 1,000 |
| Customers | 200,000 |
| Index Seek label in `01_Reproduce.sql` | `1245620 of 1000 (124562%)` |
| Index Seek → Actual Number of Rows for All Executions | 1245620 |
| Index Seek → Estimated Number of Rows Per Execution | 1000 |
| Index Seek → Number of Executions | 1 |
| Clustered Index Seek on Customers → Number of Executions | 1245620 (its per-execution estimate of 1 is correct) |
| After `OPTION (RECOMPILE)` | Estimate matches actual: `1245620 of 1245620 (100%)` |

**Why 1,000?** The query filters on a local variable. When the batch compiles, the variable's value is unknown, so the optimizer uses the average from the statistics density vector: 1,250,000 rows × (1 / 1,250) = 1,000. The real value, `N'Shipped'`, has 1,245,620 rows.

Exact plan shapes can vary with hardware and cumulative updates. The **row counts** above are fixed by the data.

## SQL Server 2019 notes

- The lab runs on 2019 at compatibility level 150 (setup picks the level automatically). The estimates and row counts are the same.
- Cardinality estimation (CE) feedback, mentioned on Slide 7, exists only in SQL Server 2022 and later (compatibility level 160 + Query Store). It doesn't apply to this lab's local-variable case, and the lab keeps Query Store off.

## Lab design notes

- `BATCH_MODE_ON_ROWSTORE = OFF` is set for this database only, so the join stays a row-mode Nested Loops as in the video (no Adaptive Join).
- `OPTION (MAXDOP 1)` keeps the plan serial and identical on every machine.
- Results go into variables so SSMS doesn't have to display 1.2 million rows.
- No server-level settings are changed. Cleanup drops the database and everything in it.

## Cleanup

Run `04_Cleanup.sql`. Expected: `LabDatabaseRemoved = 1`.

---

[← Back to all labs](https://github.com/thecrazydba-in/sql-server-beyond-the-basics)
