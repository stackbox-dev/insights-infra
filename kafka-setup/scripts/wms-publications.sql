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
public.handling_unit,
public.trip,
public.trip_relation,
public.inb_receive_item,
public.ob_load_item,
public.inb_palletization_item,
public.inb_serialization_item,
public.inb_qc_item_v2,
public.ira_bin_items,
public.ob_qa_lineitem,
public.handling_unit_kind,
public.handling_unit_quant_event,
public.handling_unit_event;