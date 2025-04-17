-- This SQL script creates a publication for the specified tables in the PostgreSQL database.
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
public.storage_position;

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

