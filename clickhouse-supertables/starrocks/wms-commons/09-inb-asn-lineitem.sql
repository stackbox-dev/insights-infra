CREATE TABLE wms_inb_asn_lineitem (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    asnId VARCHAR(36) NOT NULL,
    asnNo STRING,
    vehicleNo STRING,
    poNo STRING,
    shipmentDate DATE,
    skuId VARCHAR(36) NOT NULL,
    uom STRING NOT NULL DEFAULT '',
    batch STRING NOT NULL DEFAULT '',
    price STRING,
    qty INT NOT NULL,
    vendor STRING,
    deliveryNo STRING,
    priority INT NOT NULL DEFAULT "0",
    lineCode STRING,
    extraFields JSON,
    bucket STRING,
    active BOOLEAN NOT NULL DEFAULT "true",
    asnType STRING,
    huWeight DOUBLE,
    huNumber STRING,
    huKind STRING,
    huCode STRING,
    vehicleType STRING,
    transporterCode STRING
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
