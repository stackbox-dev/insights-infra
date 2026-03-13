CREATE TABLE wms_ira_session_progress (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    bins INT NOT NULL DEFAULT "0",
    binsCovered INT NOT NULL DEFAULT "0",
    accurateBins INT NOT NULL DEFAULT "0",
    plannedBins INT NOT NULL DEFAULT "0",
    plannedBinsCovered INT NOT NULL DEFAULT "0",
    plannedAccurateBins INT NOT NULL DEFAULT "0",
    linesCovered INT NOT NULL DEFAULT "0",
    missingHUs INT NOT NULL DEFAULT "0",
    excessHUs INT NOT NULL DEFAULT "0",
    missingUOMs JSON,
    excessUOMs JSON,
    recordLines JSON,
    finalRecordLines JSON,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00"
)
ENGINE=OLAP
PRIMARY KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('DAY', sessionCreatedAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
