**Deploy the connector:**
   ```bash
   curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" -d @sql-queries/backbone/connectors/debezium-postgres.json
   ```

   To update the connector:

   ```bash
   curl -X PUT http://localhost:8083/connectors/postgres-source-sbx-uat-backbone/config \
        -H "Content-Type: application/json" \
        -d @sql-queries/backbone/connectors/debezium-postgres-update.json
   ```

   To restart the connector:
   ```bash
   curl -X POST http://localhost:8083/connectors/postgres-source-sbx-uat-backbone/restart
   ```

   To delete the connector:

   ```bash
   curl -X DELETE http://localhost:8083/connectors/postgres-source-sbx-uat-backbone
   ```
---


**Deploy the connector:**
   ```bash
   curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" -d @sql-queries/backbone/connectors/clickhouse-sink.json
   ```

   To update the connector:

   ```bash
   curl -X PUT http://localhost:8083/connectors/clickhouse-connect-sbx-uat-backbone/config \
        -H "Content-Type: application/json" \
        -d @sql-queries/backbone/connectors/clickhouse-sink-update.json
   ```

   To restart the connector:
   ```bash
   curl -X POST http://localhost:8083/connectors/clickhouse-connect-sbx-uat-backbone/restart
   ```


   To delete the connector:

   ```bash
   curl -X DELETE http://localhost:8083/connectors/clickhouse-connect-sbx-uat-backbone
   ```