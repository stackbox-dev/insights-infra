-- Create a replication user for Razum
CREATE USER debezium WITH REPLICATION ENCRYPTED PASSWORD '<your_password>';
GRANT USAGE ON SCHEMA public TO debezium;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO debezium;

-- Verify the replication slots and publications:
SELECT * FROM pg_replication_slots;
SELECT * FROM pg_publication;

CREATE PUBLICATION razum_publication
FOR TABLE 
public.retailer_activity,
public.market_activity;
