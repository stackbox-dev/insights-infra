-- ClickHouse table for Node Closure
-- Source: public.node_closure

CREATE TABLE IF NOT EXISTS backbone_node_closure
(
    parentId Int64 DEFAULT 0,
    childId Int64 DEFAULT 0,
    distance Int16 DEFAULT 0
)
ENGINE = ReplacingMergeTree()
PARTITION BY tuple()
ORDER BY (parentId, childId)
SETTINGS index_granularity = 8192;