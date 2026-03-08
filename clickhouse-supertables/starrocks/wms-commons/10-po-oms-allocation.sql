CREATE TABLE wms_po_oms_allocation (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    uom STRING NOT NULL DEFAULT '',
    batch STRING NOT NULL DEFAULT '',
    poNo STRING,
    omsAllocationLineId VARCHAR(36),
    invoiceLineId VARCHAR(36),
    obSessionId VARCHAR(36)
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
