**Deploy the connector:**
   ```bash
   curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" -d @sql-queries/wms/connectors/debezium-postgres.json
   ```

   To update the connector:

   ```bash
   curl -X PUT http://localhost:8083/connectors/postgres-source/config \
        -H "Content-Type: application/json" \
        -d @sql-queries/wms/connectors/debezium-postgres-update.json
   ```

   To restart the connector:
   ```bash
   curl -X POST http://localhost:8083/connectors/postgres-source/restart
   ```

   To delete the connector:

   ```bash
   curl -X DELETE http://localhost:8083/connectors/postgres-source
   ```
---


**Deploy the connector:**
   ```bash
   curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" -d @sql-queries/wms/connectors/clickhouse-sink.json
   ```

   To update the connector:

   ```bash
   curl -X PUT http://localhost:8083/connectors/clickhouse-connect/config \
        -H "Content-Type: application/json" \
        -d @sql-queries/wms/connectors/clickhouse-sink-update.json
   ```

   To restart the connector:
   ```bash
   curl -X POST http://localhost:8083/connectors/clickhouse-connect/restart
   ```

   To delete the connector:

   ```bash
   curl -X DELETE http://localhost:8083/connectors/clickhouse-connect
   ```
