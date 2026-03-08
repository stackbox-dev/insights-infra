CREATE TABLE wms_pl_inv_cnt_plan_seq (
    id VARCHAR(36) NOT NULL,
    whId BIGINT NOT NULL,
    planId VARCHAR(36) NOT NULL,
    areaId VARCHAR(36) NOT NULL,
    zoneIds JSON,
    sequence INT NOT NULL
)
ENGINE=OLAP
PRIMARY KEY(id)
DISTRIBUTED BY HASH(id) BUCKETS 16
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
