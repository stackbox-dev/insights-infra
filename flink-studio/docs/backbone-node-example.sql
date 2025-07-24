-- ============================================================================
-- BACKBONE NODE TOPIC EXAMPLE
-- Topic: sbx-uat.backbone.public.node
-- Format: Avro with Confluent Schema Registry
-- ============================================================================

-- Create the backbone nodes table
CREATE TABLE backbone_nodes (
    id BIGINT,
    parentId BIGINT,
    `group` STRING,           -- Using backticks because 'group' is a reserved keyword
    code STRING,
    name STRING,
    type STRING,
    data STRING,              -- JSON data stored as string (can be parsed with JSON functions)
    createdAt TIMESTAMP(3),   -- Timestamp with millisecond precision
    updatedAt TIMESTAMP(3),   
    active BOOLEAN,
    hasLocations BOOLEAN,
    platform STRING,          -- Nullable field
    is_deleted BOOLEAN,       -- Nullable field
    -- Add computed columns for stream processing
    proc_time AS PROCTIME(),  -- Processing time for temporal operations
    event_time AS CASE 
        WHEN updatedAt > createdAt THEN updatedAt 
        ELSE createdAt 
    END,                      -- Use the latest timestamp as event time
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'sbx-uat.backbone.public.node',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required clientId="unused" clientSecret="unused";',
    'properties.sasl.login.callback.handler.class' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginCallbackHandler',
    'properties.sasl.oauthbearer.token.endpoint.url' = 'http://localhost:14293',
    'properties.group.id' = 'flink-backbone-analysis',
    'scan.startup.mode' = 'earliest-offset',  -- Start from earliest for complete data analysis
    'format' = 'avro'
    'avro-confluent.url' = 'http://cp-schema-registry:8081'
);

-- ============================================================================
-- BASIC QUERIES
-- ============================================================================

-- Check if table was created successfully
SHOW TABLES;

-- View table schema
DESCRIBE backbone_nodes;

-- Sample recent data (limit to avoid overwhelming output)
SELECT id, name, type, `group`, active, createdAt, updatedAt 
FROM backbone_nodes 
LIMIT 10;

-- ============================================================================
-- ANALYTICAL QUERIES
-- ============================================================================

-- 1. INVENTORY OVERVIEW: Count nodes by type and group
SELECT 
    type,
    `group`,
    COUNT(*) as total_nodes,
    COUNT(CASE WHEN active = true THEN 1 END) as active_nodes,
    COUNT(CASE WHEN hasLocations = true THEN 1 END) as nodes_with_locations,
    COUNT(CASE WHEN is_deleted = true THEN 1 END) as deleted_nodes
FROM backbone_nodes
GROUP BY type, `group`
ORDER BY total_nodes DESC;

-- 2. PLATFORM DISTRIBUTION: Analyze nodes by platform
SELECT 
    COALESCE(platform, 'Unknown') as platform,
    COUNT(*) as node_count,
    COUNT(DISTINCT type) as unique_types,
    COUNT(DISTINCT `group`) as unique_groups
FROM backbone_nodes
WHERE active = true AND (is_deleted IS NULL OR is_deleted = false)
GROUP BY platform
ORDER BY node_count DESC;

-- 3. RECENT ACTIVITY: Find recently created or updated nodes
SELECT 
    id,
    name,
    code,
    type,
    `group`,
    platform,
    createdAt,
    updatedAt,
    CASE 
        WHEN updatedAt > createdAt THEN 'Updated'
        ELSE 'Created'
    END as activity_type
FROM backbone_nodes
WHERE event_time > CURRENT_TIMESTAMP - INTERVAL '24' HOUR
ORDER BY event_time DESC
LIMIT 50;

-- 4. HIERARCHY ANALYSIS: Find parent-child relationships
SELECT 
    p.id as parent_id,
    p.name as parent_name,
    p.type as parent_type,
    COUNT(c.id) as child_count,
    COUNT(CASE WHEN c.active = true THEN 1 END) as active_children
FROM backbone_nodes p
LEFT JOIN backbone_nodes c ON p.id = c.parentId
WHERE p.active = true
GROUP BY p.id, p.name, p.type
HAVING COUNT(c.id) > 0
ORDER BY child_count DESC;

-- 5. DATA CONTENT ANALYSIS: Parse JSON data field (if needed)
-- Note: This requires JSON functions which may vary by Flink version
SELECT 
    id,
    name,
    type,
    data,
    -- JSON_VALUE(data, '$.key') as extracted_value,  -- Uncomment if you need to parse JSON
    LENGTH(data) as data_size
FROM backbone_nodes
WHERE data != '{}' AND data IS NOT NULL
LIMIT 20;

-- ============================================================================
-- STREAMING QUERIES (Real-time monitoring)
-- ============================================================================

-- 6. REAL-TIME CHANGE MONITORING: Track changes by minute
SELECT 
    `group`,
    type,
    COUNT(*) as changes_per_minute,
    COUNT(CASE WHEN updatedAt > createdAt THEN 1 END) as updates,
    COUNT(CASE WHEN updatedAt = createdAt THEN 1 END) as creates,
    TUMBLE_START(event_time, INTERVAL '1' MINUTE) as window_start,
    TUMBLE_END(event_time, INTERVAL '1' MINUTE) as window_end
FROM backbone_nodes
GROUP BY 
    `group`,
    type,
    TUMBLE(event_time, INTERVAL '1' MINUTE);

-- 7. ACTIVE NODE MONITORING: Real-time count of active nodes
SELECT 
    type,
    COUNT(*) as active_node_count,
    HOP_START(event_time, INTERVAL '30' SECOND, INTERVAL '5' MINUTE) as window_start
FROM backbone_nodes
WHERE active = true AND (is_deleted IS NULL OR is_deleted = false)
GROUP BY 
    type,
    HOP(event_time, INTERVAL '30' SECOND, INTERVAL '5' MINUTE);

-- ============================================================================
-- DATA QUALITY CHECKS
-- ============================================================================

-- 8. CHECK FOR MISSING OR INVALID DATA
SELECT 
    'Missing Name' as issue,
    COUNT(*) as count
FROM backbone_nodes 
WHERE name IS NULL OR name = ''
UNION ALL
SELECT 
    'Missing Code' as issue,
    COUNT(*) as count
FROM backbone_nodes 
WHERE code IS NULL OR code = ''
UNION ALL
SELECT 
    'Invalid Parent Reference' as issue,
    COUNT(*) as count
FROM backbone_nodes n1
WHERE parentId IS NOT NULL 
  AND NOT EXISTS (
    SELECT 1 FROM backbone_nodes n2 WHERE n2.id = n1.parentId
  );

-- 9. FIND POTENTIAL DUPLICATES
SELECT 
    code,
    COUNT(*) as duplicate_count,
    STRING_AGG(CAST(id AS STRING), ', ') as duplicate_ids
FROM backbone_nodes
WHERE code IS NOT NULL
GROUP BY code
HAVING COUNT(*) > 1;

-- ============================================================================
-- CLEANUP QUERIES
-- ============================================================================

-- Drop table if needed (use with caution!)
-- DROP TABLE IF EXISTS backbone_nodes;

-- ============================================================================
-- NOTES:
-- 1. The 'group' field is quoted with backticks because it's a SQL reserved word
-- 2. Timestamps are automatically converted from Avro long (millis) to TIMESTAMP(3)
-- 3. The data field contains JSON but is treated as STRING - use JSON functions to parse
-- 4. Nullable fields (platform, is_deleted) may contain NULL values
-- 5. Use WATERMARK for time-based operations in streaming queries
-- 6. Adjust the schema registry URL to match your environment
-- ============================================================================
