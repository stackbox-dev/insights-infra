-- ClickHouse Materialized View for WMS Workstation Events Enriched
-- Enriches workstation_events_staging with dimension data
-- Only enriches with handling_units, storage_bin, storage_bin_master

CREATE MATERIALIZED VIEW IF NOT EXISTS wms_workstation_events_enriched_mv
ENGINE = ReplacingMergeTree(event_timestamp)
PARTITION BY toYYYYMM(event_timestamp)  
ORDER BY (wh_id, event_timestamp, event_source_id, event_type)
AS
SELECT
    -- Core fields from basic events
    we.event_type,
    we.event_source_id,
    we.event_timestamp,
    we.wh_id,
    we.sku_id,
    we.hu_id,
    we.hu_code,
    we.batch_id,
    we.user_id,
    we.task_id,
    we.session_id,
    we.bin_id,
    we.primary_quantity,
    we.secondary_quantity,
    we.tertiary_quantity,
    we.price,
    we.status_or_bucket,
    we.reason,
    we.sub_reason,
    
    -- Handling Unit enrichment (based on hu_id)
    hu.code AS hu_enriched_code,
    hu.kindId AS hu_kind_id,
    hu.sessionId AS hu_session_id,
    hu.taskId AS hu_task_id,
    hu.storageId AS hu_storage_id,
    hu.outerHuId AS hu_outer_hu_id,
    hu.state AS hu_state,
    hu.attrs AS hu_attrs,
    hu.lockTaskId AS hu_lock_task_id,
    hu.effectiveStorageId AS hu_effective_storage_id,
    hu.createdAt AS hu_created_at,
    hu.updatedAt AS hu_updated_at,
    
    -- Storage Bin enrichment (based on bin_id)
    sb.code AS bin_code,
    sb.createdAt AS bin_created_at,
    sb.updatedAt AS bin_updated_at,
    
    -- Storage Bin Master enrichment (based on bin_code)
    sbm.bin_description,
    sbm.bin_status,
    sbm.bin_hu_id,
    sbm.multi_sku,
    sbm.multi_batch,
    sbm.picking_position,
    sbm.putaway_position,
    sbm.rank AS bin_rank,
    sbm.aisle,
    sbm.bay,
    sbm.level,
    sbm.position AS bin_position,
    sbm.depth,
    sbm.bin_type_code,
    sbm.zone_id,
    sbm.zone_code,
    sbm.zone_description,
    sbm.area_id,
    sbm.area_code,
    sbm.area_description,
    sbm.x1,
    sbm.y1,
    sbm.max_volume_in_cc,
    sbm.max_weight_in_kg,
    sbm.pallet_capacity,
    
    -- System fields
    we.is_snapshot,
    we.event_time
FROM wms_workstation_events_staging we
-- Handling Unit enrichment
LEFT JOIN wms_handling_units hu ON we.hu_id = hu.id
-- Storage Bin enrichment  
LEFT JOIN wms_storage_bins sb ON we.bin_id = sb.id
-- Storage Bin Master enrichment
LEFT JOIN wms_storage_bin_master sbm ON sb.id = sbm.bin_id;