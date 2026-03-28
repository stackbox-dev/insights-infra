-- Fair Resource Usage: Restrict resource usage for readonly user
-- This file enforces quotas and limits ONLY for the 'readonly' user

-- =============================================================================
-- QUOTA: Limit resource consumption for readonly user
-- =============================================================================

-- Drop existing quota if it exists
DROP QUOTA IF EXISTS readonly_quota;

-- Create quota for readonly user with reasonable limits
CREATE QUOTA readonly_quota
    FOR INTERVAL 1 hour MAX queries = 1000, errors = 100, execution_time = 3600
    FOR INTERVAL 1 day MAX queries = 10000, errors = 500, execution_time = 36000
    TO readonly;

-- =============================================================================
-- SETTINGS PROFILE: Control query limits for readonly user
-- =============================================================================

-- Drop existing settings profile if it exists
DROP SETTINGS PROFILE IF EXISTS readonly_profile;

-- Profile for readonly user: 10GB memory max, 30 seconds max execution time
CREATE SETTINGS PROFILE readonly_profile SETTINGS
    max_memory_usage = 10000000000,              -- 10 GB max memory per query
    max_execution_time = 30,                     -- 30 seconds max execution time
    max_concurrent_queries_for_user = 20         -- Max 20 concurrent queries
    TO readonly;

-- =============================================================================
-- MONITORING QUERIES
-- =============================================================================

-- Check current quota usage for readonly user
-- SELECT * FROM system.quota_usage WHERE user_name = 'readonly';

-- Check active queries by readonly user
-- SELECT user, query, memory_usage, elapsed
-- FROM system.processes
-- WHERE user = 'readonly';

-- Check query statistics for readonly user
-- SELECT
--     count() AS queries,
--     sum(read_rows) AS total_read_rows,
--     sum(read_bytes) AS total_read_bytes,
--     sum(memory_usage) AS total_memory,
--     avg(query_duration_ms) AS avg_duration_ms,
--     max(query_duration_ms) AS max_duration_ms
-- FROM system.query_log
-- WHERE event_time >= now() - INTERVAL 1 HOUR
--   AND type = 'QueryFinish'
--   AND user = 'readonly';

-- =============================================================================
-- NOTES
-- =============================================================================

-- 1. Only the 'readonly' user has enforced quotas and resource limits
-- 2. All other users have no restrictions
-- 3. Max 10GB memory per query for readonly user
-- 4. Max 30 seconds execution time per query for readonly user
-- 5. Monitor system.quota_usage and system.query_log for readonly user activity
