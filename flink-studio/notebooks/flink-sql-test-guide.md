# Zeppelin Flink SQL Test Notebook

This notebook demonstrates how to connect to Flink Session cluster and run SQL queries in Zeppelin using the native Flink interpreter.

## 1. Test Connection with Flink Stream SQL Interpreter

Use the `%flink.ssql` interpreter to run streaming SQL queries:

```sql
%flink.ssql
SELECT 'Hello from Flink Session Cluster!' as message;
```

## 2. Create a Test Table

```sql
%flink.ssql
CREATE TABLE test_table (
    id INT,
    name STRING,
    timestamp_col TIMESTAMP(3),
    WATERMARK FOR timestamp_col AS timestamp_col - INTERVAL '5' SECOND
) WITH (
    'connector' = 'datagen',
    'rows-per-second' = '1',
    'fields.id.min' = '1',
    'fields.id.max' = '100',
    'fields.name.length' = '10'
);
```

## 3. Query the Test Table

```sql
%flink.ssql
SELECT * FROM test_table LIMIT 10;
```

## 4. Use Flink Batch SQL Interpreter (Alternative)

You can also use the batch SQL interpreter for batch queries:

```sql
%flink.bsql
SHOW TABLES;
```

## 5. Check Flink Jobs

```sql
%flink.ssql
SHOW JOBS;
```

## Configuration Details

- **Execution Mode**: `remote` (connects directly to Flink Session cluster)
- **Flink Cluster**: `flink-session-cluster:80`
- **Primary Interpreter**: `%flink.ssql` (Flink Stream SQL)
- **Secondary Interpreter**: `%flink.bsql` (Flink Batch SQL)
- **Flink Web UI**: Available through cluster service

## Troubleshooting

1. Check if Flink Session cluster is running:
   ```bash
   curl http://flink-session-cluster:80/
   ```

2. Verify interpreter configuration in Zeppelin UI under Interpreter settings.

3. Check Flink cluster status:
   ```bash
   kubectl get flinkdeployment flink-session-cluster -n flink-studio
   ```
