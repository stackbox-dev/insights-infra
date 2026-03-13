CREATE TABLE wms_storage_bin_dockdoor_master (
    wh_id BIGINT NOT NULL,
    bin_code STRING NOT NULL,
    dockdoor_code STRING NOT NULL,
    bin_id STRING NULL,
    dockdoor_id STRING NULL,
    dockdoor_description STRING NULL,
    usage STRING NULL,
    active BOOLEAN NULL,
    dock_handling_unit STRING NULL,
    multi_trip BOOLEAN NULL,
    max_queue BIGINT NULL,
    allow_inbound BOOLEAN NULL,
    allow_outbound BOOLEAN NULL,
    allow_returns BOOLEAN NULL,
    dockdoor_status STRING NULL,
    incompatible_vehicle_types STRING NULL,
    incompatible_load_types STRING NULL,
    dockdoor_x_coordinate DOUBLE NULL,
    dockdoor_y_coordinate DOUBLE NULL,
    dockdoor_position_active BOOLEAN NULL,
    bin_created_at DATETIME NULL,
    bin_updated_at DATETIME NULL,
    dockdoor_created_at DATETIME NULL,
    dockdoor_updated_at DATETIME NULL
)
ENGINE=OLAP
PRIMARY KEY(wh_id, bin_code, dockdoor_code)
DISTRIBUTED BY HASH(wh_id) BUCKETS 2
ORDER BY (wh_id, bin_code, dockdoor_code)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
