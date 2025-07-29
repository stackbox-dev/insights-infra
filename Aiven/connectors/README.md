# Working with connectors

### Deploy and update the connectors:
- Run the script.

**Note:** Here change the connector name as per requirement

- 1. Pause the connector
```bash
curl -X PUT http://localhost:8083/connectors/<connector-name>/pause
```
- 2. Delete offsets (resets from beginning, for this first stop the connector)
```bash
curl -X DELETE http://localhost:8083/connectors/<connector-name>/offsets
```
- 3. Resume the connector
```bash
curl -X PUT http://localhost:8083/connectors/<connector-name>/resume
```
- 4. Stop the connector
```bash
curl -X PUT http://localhost:8083/connectors/<connector-name>/stop
```
- 5. Restart the connector:
```bash
curl -X POST http://localhost:8083/connectors/<connector-name>/restart
```
- 6. Delete the connector:
```bash
curl -X DELETE http://localhost:8083/connectors/<connector-name>
```