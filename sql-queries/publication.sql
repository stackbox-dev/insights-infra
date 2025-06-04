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

-- This SQL script creates a publication for the specified tables in the PostgreSQL database.
CREATE PUBLICATION dbz_publication
FOR TABLE 
public.table_name1,
public.table_name2,
public.table_name3;

-- Query to check the tables in the publication
SELECT 
    p.pubname AS publication_name,
    n.nspname AS schema_name,
    c.relname AS table_name
FROM 
    pg_publication p
JOIN 
    pg_publication_rel pr ON p.oid = pr.prpubid
JOIN 
    pg_class c ON c.oid = pr.prrelid
JOIN 
    pg_namespace n ON n.oid = c.relnamespace
WHERE 
    p.pubname = 'dbz_publication';

-- Add new tables to the existing publication
ALTER PUBLICATION dbz_publication 
ADD TABLE public.new_table_name1, public.new_table_name2;
