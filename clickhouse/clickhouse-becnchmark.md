https://datazip.io/blog/solve-memory-limit-errors-and-speed-up-queries-in-clickhouse

```bash
clickhouse-benchmark -c 100 -i 1000 \
  --host localhost \
  --port 9000 \
  --user default \
  --password 1TOj1z6ynT \
  <<< "select 1"

```