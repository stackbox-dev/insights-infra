CREATE TABLE wms_worker_device_session (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    workerId VARCHAR(36) NOT NULL,
    otp STRING,
    accessToken STRING,
    provisionedAt DATETIME,
    deviceId VARCHAR(36),
    expiredAt DATETIME,
    attrs JSON,
    expiryAt DATETIME
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
