CREATE TABLE wms_pl_inv_cnt_plan_cycle (
    id VARCHAR(36) NOT NULL,
    whId BIGINT NOT NULL,
    planId VARCHAR(36) NOT NULL,
    seqId VARCHAR(36) NOT NULL,
    cycleId VARCHAR(36) NOT NULL,
    sequence INT NOT NULL,
    cycleCount INT NOT NULL DEFAULT "0",
    plInvCntSessionId VARCHAR(36),
    plInvCntSessionCreatedAt DATETIME
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
