CREATE TABLE IF NOT EXISTS sbx_uat_backbone.node
(
    "id" Int64,
    "parentId" Int64,
    "group" String,
    "code" String,
    "name" String,
    "type" LowCardinality(String),
    "data" String,
    "createdAt" DateTime64(3, 'UTC'),
    "updatedAt" DateTime64(3, 'UTC'),
    "active" Bool,
    "hasLocations" Bool,
    "platform" String DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_backbone.node_closure
(
    "parentId" Int64,
    "childId" Int64,
    "distance" Int16
)
ENGINE = ReplacingMergeTree()
ORDER BY (childId);