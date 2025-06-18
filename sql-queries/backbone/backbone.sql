CREATE TABLE IF NOT EXISTS sbx_uat.backbone_node
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
    "platform" String DEFAULT 0,
    is_deleted Bool DEFAULT 0,
    deleted_at DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat.backbone_node_closure
(
    "parentId" Int64,
    "childId" Int64,
    "distance" Int16,
    is_deleted Bool DEFAULT 0,
    deleted_at DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree()
ORDER BY (childId);