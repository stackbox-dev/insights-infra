CREATE TABLE wms_wave_olg_invoice_line (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    wavePreviewId VARCHAR(36) NOT NULL,
    waveOlgBinId VARCHAR(36) NOT NULL,
    invoiceId VARCHAR(36) NOT NULL,
    lineId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    qty INT NOT NULL,
    crateId VARCHAR(36),
    crateTypeId VARCHAR(36),
    fulfillmentType STRING,
    lineFulfillmentType STRING,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    lmTripId VARCHAR(36),
    mmTripId VARCHAR(36)
)
ENGINE=OLAP
PRIMARY KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('MONTH', sessionCreatedAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
