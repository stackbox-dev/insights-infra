**Deploy the connector:**
   ```bash
   curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" -d @sql-queries/encarta/connectors/debezium-postgres.json
   ```

   To update the connector:

   ```bash
   curl -X PUT http://localhost:8083/connectors/postgres-source-sbx-uat-encarta/config \
        -H "Content-Type: application/json" \
        -d @sql-queries/encarta/connectors/debezium-postgres-update.json
   ```

   To restart the connector:
   ```bash
   curl -X POST http://localhost:8083/connectors/postgres-source-sbx-uat-encarta/restart
   ```

   To delete the connector:

   ```bash
   curl -X DELETE http://localhost:8083/connectors/postgres-source-sbx-uat-encarta
   ```
---


**Deploy the connector:**
   ```bash
   curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" -d @sql-queries/encarta/connectors/clickhouse-sink.json
   ```

   To update the connector:

   ```bash
   curl -X PUT http://localhost:8083/connectors/clickhouse-connect-sbx-uat-encarta/config \
        -H "Content-Type: application/json" \
        -d @sql-queries/encarta/connectors/clickhouse-sink-update.json
   ```

   To restart the connector:
   ```bash
   curl -X POST http://localhost:8083/connectors/clickhouse-connect-sbx-uat-encarta/restart
   ```


   To delete the connector:

   ```bash
   curl -X DELETE http://localhost:8083/connectors/clickhouse-connect-sbx-uat-encarta
   ```