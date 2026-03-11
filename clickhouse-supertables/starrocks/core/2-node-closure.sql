CREATE TABLE backbone_node_closure (
    parentId BIGINT NOT NULL,
    childId BIGINT NOT NULL,
    distance SMALLINT NOT NULL DEFAULT "0"
)
ENGINE=OLAP
PRIMARY KEY(parentId, childId)
DISTRIBUTED BY HASH(parentId)
ORDER BY (parentId, childId)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
