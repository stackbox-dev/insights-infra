--- Create a replication user
CREATE USER debezium WITH REPLICATION ENCRYPTED PASSWORD '<your_password>';
GRANT USAGE ON SCHEMA public TO debezium;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO debezium;

--- Verify the replication slots and publications:
SELECT * FROM pg_replication_slots;
SELECT * FROM pg_publication;

CREATE PUBLICATION dbz_publication
FOR TABLE
public.storage_dockdoor_position,
public.storage_bin_dockdoor,
public.storage_dockdoor,
public.storage_bin,
public.storage_bin_type,
public.storage_zone,
public.storage_area_sloc,
public.storage_area,
public.storage_position,
public.storage_bin_fixed_mapping,
public.pd_drop_item,
public.pd_pick_item,
public.pd_pick_drop_mapping,
public.task,
public.session,
public.worker,
public.trip_relation,
public.inb_receive_item,
public.ob_load_item,
public.inb_palletization_item,
public.inb_serialization_item,
public.inb_qc_item_v2,
public.ira_bin_items,
public.ob_qa_lineitem,
public.handling_unit_kind,
public.po_oms_allocation,
public.inb_asn_lineitem,
public.inb_asn,
public.inb_grn_line,
public.seg_item,
public.seg_group,
public.seg_container,
public.wave_olg_invoice_line,
public.ob_chu,
public.ob_chu_line,
public.vehicle_event,
public.sbl_demand_packed,
public.sbl_demand,
public.bbulk_ptl_demand_packed,
public.ob_qc_chu,
public.yms_trip,
public.exception_bin,
public.exception_hu,
public.exception_manual_assignment,
public.ira_approval,
public.ira_bin_items_scanned_hu,
public.ira_discrepancies_config,
public.ira_manual_update,
public.ira_record,
public.ira_session_progress,
public.ira_session_sku,
public.ira_session_summary,
public.ira_task_bin,
public.ira_worker_update,
public.pl_inv_cnt_plan,
public.pl_inv_cnt_plan_cycle,
public.pl_inv_cnt_plan_seq,
public.pln_ira_cycle_plan,
public.pln_ira_cycle_step,
public.pln_ira_cycle_step_bin,
public.vehicle_event_trip,
public.mhe,
public.mhe_kind,
public.inb_grn,
public.vehicle_parking,
public.pd_provisional_item
public.worker_active_time
public.worker_productivity;