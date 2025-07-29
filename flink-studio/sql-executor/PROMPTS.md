# Helpful prompts

- This is the schema registry url "http://cp-schema-registry.kafka.api.staging.stackbox.internal/". In the file the same is referred to as "http://cp-schema-registry.kafka"(dont' change it). Main job of yours is to check all the DDLs match the avro schemas of the source topics. Call the schema registry and get the schemas. Ensurnig the primary keys are also adhering to key avro schemas. Confirm with me before many any changes.

- run `./run_sql_executor.sh --json --sql "SHOW JOBS"` and stop each job using `./run_sql_executor.sh  --json --sql "STOP JOB <job-id>"`

- fix encarta-skus-master in the same vain as test-sql. dont change connector type. keep it upsert-kafka. only change WITH parameters.
- simplify table names. keep topic names as is.