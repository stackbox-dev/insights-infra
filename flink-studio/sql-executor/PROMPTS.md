# Prompts to make ETL SQL scripts

- This is the schema registry url "http://cp-schema-registry.kafka.api.staging.stackbox.internal/". In the file the same is referred to as "http://cp-schema-registry.kafka"(dont' change it). Main job of yours is to check all the DDLs match the avro schemas of the source topics. Call the schema registry and get the schemas. Ensurnig the primary keys are also adhering to key avro schemas. Confirm with me before many any changes.
