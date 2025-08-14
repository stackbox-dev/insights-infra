-- ClickHouse OPTIMIZE FINAL Script
-- Run this script to optimize all tables in the sbx_uat database
-- This merges all parts and applies deduplication for ReplacingMergeTree tables

-- ========================================
-- Encarta Tables
-- ========================================
OPTIMIZE TABLE encarta_skus_master FINAL;
OPTIMIZE TABLE encarta_skus_overrides FINAL;

-- ========================================
-- WMS Commons Tables
-- ========================================
OPTIMIZE TABLE wms_handling_unit_kinds FINAL;
OPTIMIZE TABLE wms_handling_units FINAL;
OPTIMIZE TABLE wms_sessions FINAL;
OPTIMIZE TABLE wms_tasks FINAL;
OPTIMIZE TABLE wms_trips FINAL;
OPTIMIZE TABLE wms_trip_relations FINAL;
OPTIMIZE TABLE wms_workers FINAL;

-- ========================================
-- WMS Storage Tables
-- ========================================
OPTIMIZE TABLE wms_storage_area_sloc FINAL;
OPTIMIZE TABLE wms_storage_bin_master FINAL;
OPTIMIZE TABLE wms_storage_bin_dockdoor_master FINAL;

-- ========================================
-- WMS Inventory Tables
-- ========================================
OPTIMIZE TABLE wms_inventory_staging FINAL;
OPTIMIZE TABLE wms_inventory_events_enriched FINAL;
OPTIMIZE TABLE wms_inventory_hourly_position FINAL;
OPTIMIZE TABLE wms_inventory_weekly_snapshot FINAL;

-- ========================================
-- WMS Pick-Drop Tables
-- ========================================
OPTIMIZE TABLE wms_pick_drop_staging FINAL;
OPTIMIZE TABLE wms_pick_drop_enriched FINAL;

-- ========================================
-- WMS Workstation Events Tables
-- ========================================
OPTIMIZE TABLE wms_workstation_events_staging FINAL;

-- ========================================
-- Note: OPTIMIZE FINAL forces merge of all parts in the table
-- This is resource-intensive and should be run during low-traffic periods
-- For production, consider using partition-level optimization:
-- OPTIMIZE TABLE table_name PARTITION partition_id FINAL;
-- ========================================