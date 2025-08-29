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
public.ord,
public.line,
public.ord_state,
public.line_state,
public.allocation_line,
public.inv,
public.inv_line,
public.shipment_input,
public.shipment_output,
public.wms_dock_line,
public.allocation_run(id, created_at, active, node_id);
