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
public.skus, 
public.uoms,
public.products, 
public.sub_categories,
public.categories,
public.classifications,
public.node_overrides,
public.node_override_classifications,
public.eans,
public.product_classifications,
public.product_node_overrides,
public.product_node_override_classifications,
public.category_groups,
public.default_values,
public.sub_brands,
public.brands;