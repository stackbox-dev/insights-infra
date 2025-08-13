-- ClickHouse table for WMS Storage Bin Dockdoor Master
-- Maps storage bins to dock doors for inbound/outbound logistics and staging
-- Source: sbx_uat.wms.public.storage_bin_dockdoor_master

CREATE TABLE IF NOT EXISTS wms_storage_bin_dockdoor_master
(
    -- Core Identifiers (Composite Primary Key)
    wh_id Int64,
    bin_code String,
    dockdoor_code String,
    
    -- Bin and Dockdoor IDs
    bin_id String DEFAULT '',
    dockdoor_id String DEFAULT '',
    
    -- Dock Door Configuration
    dockdoor_description String DEFAULT '',
    usage String DEFAULT '',  -- INBOUND/OUTBOUND/BOTH
    active Bool DEFAULT false,
    dock_handling_unit String DEFAULT '',
    multi_trip Bool DEFAULT false,
    
    -- Dock Door Capabilities
    max_queue Int64 DEFAULT 0,
    allow_inbound Bool DEFAULT false,
    allow_outbound Bool DEFAULT false,
    allow_returns Bool DEFAULT false,
    dockdoor_status String DEFAULT '',
    
    -- Compatibility Constraints
    incompatible_vehicle_types String DEFAULT '',  -- List as String
    incompatible_load_types String DEFAULT '',  -- List as String
    
    -- Position Information
    dockdoor_x_coordinate Float64 DEFAULT 0,
    dockdoor_y_coordinate Float64 DEFAULT 0,
    dockdoor_position_active Bool DEFAULT false,
    
    -- System Fields
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    is_snapshot Bool DEFAULT false,
    event_time DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(event_time)
ORDER BY (wh_id, bin_code, dockdoor_code)
SETTINGS index_granularity = 8192
COMMENT 'Storage bin to dock door mapping for staging area management and logistics operations';