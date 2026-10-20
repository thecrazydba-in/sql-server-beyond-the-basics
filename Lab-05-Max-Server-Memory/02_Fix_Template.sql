/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 05 — Max Server Memory | Read-along 2 of 2: Fix template (set a cap)
   Requires: SQL Server 2019+ (or 2022), SSMS,
             permission ALTER SETTINGS (held by sysadmin and serveradmin)
   Run on a test instance only. Review and test on a non-production instance first.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* ================================================================
   SAFETY: the change below is inside a comment block, so pressing F5
   on this file runs ONLY the STEP 0 query (read-only).
   To apply the change: replace <YourValueMB>, select the STEP 1 lines
   (without the comment markers) and run that selection on purpose.
   ================================================================ */

SET NOCOUNT ON;
USE master;
GO

/* ---------------------------------------------------------------
   STEP 0 — Save the ORIGINAL values first (read-only).
   Copy the result into your change ticket. You need value_in_use
   of 'max server memory (MB)' for the rollback in STEP 3.
   EXPECTED on the example server: 2147483647 (the default).
   --------------------------------------------------------------- */
SELECT  c.name,
        CAST(c.value        AS bigint) AS value,
        CAST(c.value_in_use AS bigint) AS value_in_use
FROM    sys.configurations AS c
WHERE   c.name IN (N'max server memory (MB)', N'show advanced options')
ORDER BY c.name;
GO

/* ---------------------------------------------------------------
   CHOOSING <YourValueMB>
   - Microsoft recommends starting at 75% of the memory NOT used by
     other processes, including other instances.
   - Dedicated 64 GB server (65536 MB):  65536 x 0.75 = 49152 MB.
   - Shared server: first subtract what other instances, agents and
     applications need, then take 75% of the rest.
   - Microsoft also documents a more detailed method that reserves
     memory for thread stacks and other needs; it gives a somewhat
     lower value. Either way: start there, monitor at peak, adjust.
   - Minimum allowed value: 128 MB. Never set it close to that.
   --------------------------------------------------------------- */

/* ---------------------------------------------------------------
   STEP 1 — Set the cap.  (COMMENTED OUT ON PURPOSE)
   Takes effect immediately, no restart needed.
   When the new target is below what SQL Server has committed, its
   memory manager tries to shrink towards it: prefer a quiet period.

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'max server memory (MB)', <YourValueMB>;   -- e.g. 49152
RECONFIGURE;

-- Microsoft recommends using 'show advanced options' only temporarily.
-- If STEP 0 showed show advanced options = 0, switch it back:
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
   --------------------------------------------------------------- */

/* ---------------------------------------------------------------
   STEP 2 — Verify.
   Run 01_Check.sql again:
   - Q1: value and value_in_use both show <YourValueMB> (e.g. 49152).
   - Q3 at the next peak: system_memory_state_desc should no longer
     report "Available physical memory is low" because of SQL Server,
     and process_physical_memory_low should be 0.
     (Other applications can still cause low memory; check them too.)
   - Error log: no new 17890 messages.
   --------------------------------------------------------------- */

/* ---------------------------------------------------------------
   STEP 3 — Roll back (only if needed).  (COMMENTED OUT ON PURPOSE)
   Use the ORIGINAL value you saved in STEP 0
   (2147483647 if the setting was never changed).

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'max server memory (MB)', <OriginalValueMB>;   -- from STEP 0
RECONFIGURE;
EXEC sp_configure 'show advanced options', 0;   -- only if it was 0 in STEP 0
RECONFIGURE;
   --------------------------------------------------------------- */
