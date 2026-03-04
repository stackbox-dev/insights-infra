# SOP: Kafka Alerting — Connector Health, Consumer Lag & Topic Size

**Last updated:** 2026-03-04
**Status:** Live on all 4 environments

---

## Overview

A Kubernetes CronJob (`kafka-connector-healthcheck`) runs every 10 minutes in the `kafka` namespace and performs **3 automated checks**, sending Slack alerts when issues are detected:

| # | Check | Alert Condition |
|---|-------|----------------|
| 1 | **Connector Health** | Any connector task goes to `FAILED` state |
| 2 | **Consumer Lag** | Any consumer group lag exceeds `10000` messages |
| 3 | **Topic Size** | Any topic exceeds `100 GB` in size |

---

## Repository & File Structure

```
insights-infra/
└── kafka-setup/
    ├── manifests/
    │   ├── digitaldc-prod/
    │   │   └── cronjob.yaml          ← CronJob + ConfigMap for digitaldc-prod
    │   ├── samadhan-prod/
    │   │   └── cronjob.yaml          ← CronJob + ConfigMap for samadhan-prod
    │   ├── sbx-prod/
    │   │   └── cronjob.yaml          ← CronJob + ConfigMap for sbx-prod
    │   └── nestle-prod/
    │       └── cronjob.yaml          ← CronJob + ConfigMap for nestle-prod
    └── docs/
        └── kafka-consumer-lag-alert-sop.md   ← this file
```

---

## Environment Reference

| Environment | kubectl Context | Cluster Name | Image |
|-------------|----------------|--------------|-------|
| Digitaldc Prod | `SbxDCProdCluster` | `digitaldc-kafka` | `alpine:3.23` |
| Samadhan Prod | `SbxCluster_2` | `samadhan-kafka` | `alpine:3.20` |
| SBX Prod | `gke_sbx-production_asia-south1_services-1-production` | `sbx-prod-kafka` | `alpine:3.20` |
| Nestle Prod | `gke_sbx-nestle-prod_asia-south1_sbx-nestle-prod` | `nestle-prod-kafka` | `alpine:3.20` |

---

## Kubernetes Resources

| Resource | Name | Namespace | Description |
|----------|------|-----------|-------------|
| CronJob | `kafka-connector-healthcheck` | `kafka` | Runs every 10 min, all 3 checks |
| ConfigMap | `kafka-connector-check-script` | `kafka` | Contains `check_connectors.sh` script |
| Secret | `slack-secret` | `kafka` | Slack bot token and channel ID |

---

## Architecture

```
CronJob: kafka-connector-healthcheck (*/10 * * * *)
  └── alpine container
        ├── Reads script from ConfigMap: kafka-connector-check-script
        ├── Reads credentials from Secret: slack-secret
        │
        ├── CHECK 1: Connector Health
        │     └── GET http://cp-connect.kafka/connectors
        │     └── GET http://cp-connect.kafka/connectors/{name}/status
        │     └── If task.state == FAILED → Slack alert (:x:)
        │
        ├── CHECK 2: Consumer Lag
        │     └── GET http://kafka-ui.kafka/api/clusters/{name}/consumer-groups/paged?perPage=1000
        │     └── Field: .consumerLag (aggregated across all partitions)
        │     └── If consumerLag > LAG_THRESHOLD (10000) → Slack alert (:warning:)
        │
        └── CHECK 3: Topic Size
              └── GET http://kafka-ui.kafka/api/clusters/{name}/topics?perPage=1000
              └── Field: .segmentSize (bytes)
              └── If segmentSize > 100GB (107374182400 bytes) → Slack alert (:red_circle:)
```

---

## API Endpoints Used

| Check | Internal API Endpoint | Field Used |
|-------|-----------------------|------------|
| Connector list | `http://cp-connect.kafka/connectors` | Array of connector names |
| Connector status | `http://cp-connect.kafka/connectors/{name}/status` | `.tasks[].state` |
| Consumer groups | `http://kafka-ui.kafka/api/clusters/{name}/consumer-groups/paged?perPage=1000` | `.consumerGroups[].consumerLag` |
| Topics | `http://kafka-ui.kafka/api/clusters/{name}/topics?perPage=1000` | `.topics[].segmentSize` |

> **Note:** Kafka UI v0.7.2 requires the `/paged` suffix for consumer groups. `/consumer-groups` without `/paged` returns HTTP 404.

---

## Configuration Reference

| Environment Variable | Description | Default |
|---------------------|-------------|---------|
| `CONNECT_URL` | Internal Kafka Connect REST API | `http://cp-connect.kafka` |
| `CONNECT_UI_URL` | Browser-accessible Connect UI link (for Slack) | Environment-specific |
| `KAFKA_UI_URL` | Internal Kafka UI service | `http://kafka-ui.kafka` |
| `CLUSTER_NAME` | Kafka cluster name as registered in Kafka UI | Environment-specific |
| `KAFKA_UI_CONSUMER_GROUPS_URL` | Browser-accessible consumer groups link (for Slack) | Environment-specific |
| `KAFKA_UI_TOPICS_URL` | Browser-accessible topics link (for Slack) | Environment-specific |
| `LAG_THRESHOLD` | Alert when `consumerLag > threshold` | `10000` |
| `TOPIC_SIZE_THRESHOLD_GB` | Alert when topic size > this value in GB | `100` |
| `SKIP_GROUPS` | Comma-separated consumer group IDs to skip | `connect-configs,connect-offsets,connect-status,connect-cluster` |
| `ENVIRONMENT_NAME` | Display name shown in Slack alerts | e.g. `Digitaldc Prod` |
| `SLACK_BOT_TOKEN` | From `slack-secret` (key: `bot_token`) | — |
| `SLACK_CHANNEL_ID` | From `slack-secret` (key: `channel_id`) | — |

---

## Prerequisites

### Step 1 — Verify Kafka UI is running
```bash
kubectl get pods -n kafka | grep kafka-ui
# Expected:
# kafka-ui-xxxx-xxxx   1/1   Running   0   Xd
```

### Step 2 — Verify Kafka Connect is running
```bash
kubectl get pods -n kafka | grep cp-connect
# Expected:
# cp-connect-xxxx-xxxx   1/1   Running   0   Xd
```

### Step 3 — Verify Slack secret exists in kafka namespace
```bash
kubectl get secret slack-secret -n kafka
# Expected:
# NAME           TYPE     DATA   AGE
# slack-secret   Opaque   2      Xd
```

If the secret is missing, create it:
```bash
kubectl create secret generic slack-secret \
  --from-literal=bot_token=<your-slack-bot-token> \
  --from-literal=channel_id=<your-slack-channel-id> \
  -n kafka
```

---

## Deployment Steps

### Step 1 — Clone / pull the repository
```bash
cd /path/to/insights-infra
git pull origin main
```

### Step 2 — Deploy to each environment

#### Digitaldc Prod
```bash
kubectl config use-context SbxDCProdCluster
kubectl apply -f kafka-setup/manifests/digitaldc-prod/cronjob.yaml -n kafka
# Expected:
# cronjob.batch/kafka-connector-healthcheck configured
# configmap/kafka-connector-check-script configured
```

#### Samadhan Prod
```bash
kubectl config use-context SbxCluster_2
kubectl apply -f kafka-setup/manifests/samadhan-prod/cronjob.yaml -n kafka
```

#### SBX Prod
```bash
kubectl config use-context gke_sbx-production_asia-south1_services-1-production
kubectl apply -f kafka-setup/manifests/sbx-prod/cronjob.yaml -n kafka
```

#### Nestle Prod
```bash
kubectl config use-context gke_sbx-nestle-prod_asia-south1_sbx-nestle-prod
kubectl apply -f kafka-setup/manifests/nestle-prod/cronjob.yaml -n kafka
```

### Step 3 — Verify CronJob is live
```bash
kubectl get cronjob kafka-connector-healthcheck -n kafka
# Expected:
# NAME                          SCHEDULE       SUSPEND   ACTIVE   LAST SCHEDULE
# kafka-connector-healthcheck   */10 * * * *   False     0        <time>
```

---

## Testing Steps

### Step 1 — Run a manual test job
```bash
# Switch to target environment first
kubectl config use-context SbxDCProdCluster

# Create test job
kubectl create job --from=cronjob/kafka-connector-healthcheck manual-test-1 -n kafka
```

### Step 2 — Watch the logs
```bash
kubectl logs -n kafka -l job-name=manual-test-1 -f
```

### Step 3 — Verify expected output

**Healthy output (no alerts):**
```
[2026-03-04 08:00:00] ===== CHECK 1: Connector Health =====
[2026-03-04 08:00:01]   Checking connector: clickhouse-connect-digitaldc_prod-wms-inventory
[2026-03-04 08:00:01]     State: RUNNING
[2026-03-04 08:00:01]     ✅ Task 0 is RUNNING
...
[2026-03-04 08:00:03] ✅ All connector tasks are healthy.

[2026-03-04 08:00:03] ===== CHECK 2: Consumer Lag (threshold: 10000) =====
[2026-03-04 08:00:04] Found 14 consumer groups.
[2026-03-04 08:00:04]   Group: digitaldc_prod-wms-inventory-events-staging | Lag: 568
[2026-03-04 08:00:04]   ✅ digitaldc_prod-wms-inventory-events-staging is healthy (lag: 568)
...
[2026-03-04 08:00:05] ✅ All consumer groups are within the lag threshold.

[2026-03-04 08:00:05] ===== CHECK 3: Topic Size (threshold: 100GB) =====
[2026-03-04 08:00:06] Found 148 topics.
[2026-03-04 08:00:14] ✅ All topics are within the size threshold.
```

### Step 4 — Force-test Slack alerts (optional)
To confirm Slack integration works, temporarily lower the threshold to trigger an alert:
```bash
# Edit the YAML — change LAG_THRESHOLD value to "-1"
vi kafka-setup/manifests/digitaldc-prod/cronjob.yaml

# Apply and run test
kubectl apply -f kafka-setup/manifests/digitaldc-prod/cronjob.yaml -n kafka
kubectl create job --from=cronjob/kafka-connector-healthcheck slack-test-1 -n kafka
kubectl logs -n kafka -l job-name=slack-test-1 -f

# After confirming Slack received alert, revert threshold back to 10000
```

### Step 5 — Check job completion status
```bash
kubectl get pods -n kafka -l job-name=manual-test-1
# Expected: STATUS = Completed
```

### Step 6 — Clean up test jobs
```bash
kubectl delete job manual-test-1 slack-test-1 -n kafka 2>/dev/null || true
```

---

## Slack Alert Formats

### Alert 1 — Connector Task Failed (:x:)
```
:x: Kafka Connector Task Failed!
Connector     │ Environment
<link>        │ Digitaldc Prod
Task ID       │ Worker
0             │ worker-host:8083
Error Trace (truncated)
org.apache.kafka.connect.errors.ConnectException: ...
```

### Alert 2 — Consumer Lag (:warning:)
```
:warning: Kafka Consumer Lag Alert!
Consumer Group                              │ Environment
<link to Kafka UI consumer groups page>    │ Digitaldc Prod
Lag (messages behind)  │ Threshold
15234                  │ 10000
```

### Alert 3 — Topic Size (:red_circle:)
```
:red_circle: Kafka Topic Size Alert!
Topic          │ Environment
<link>         │ Digitaldc Prod
Size           │ Threshold
112.4GB        │ 100GB
```

---

## Troubleshooting

### No Slack alerts received

**Step 1** — Check the latest job logs:
```bash
# Find latest job
kubectl get jobs -n kafka | grep kafka-connector-healthcheck

# Get logs
kubectl logs -n kafka -l job-name=<latest-job-name> --tail=100
```

**Step 2** — Check if the job is even running:
```bash
kubectl get cronjob kafka-connector-healthcheck -n kafka
kubectl describe cronjob kafka-connector-healthcheck -n kafka
kubectl get events -n kafka | grep kafka-connector-healthcheck
```

**Step 3** — Verify Slack secret values:
```bash
kubectl get secret slack-secret -n kafka -o jsonpath='{.data.bot_token}' | base64 -d
kubectl get secret slack-secret -n kafka -o jsonpath='{.data.channel_id}' | base64 -d
```

---

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `❌ No response from Kafka UI API` | Kafka UI pod down or wrong KAFKA_UI_URL | `kubectl get pods -n kafka \| grep kafka-ui` |
| `❌ No response from Kafka Connect API` | Kafka Connect pod down | `kubectl get pods -n kafka \| grep cp-connect` |
| HTTP 404 on consumer groups API | Missing `/paged` suffix | Endpoint must be `/consumer-groups/paged?perPage=1000` |
| All consumer lags = 0 despite real lag | Wrong jq field | Must use `.consumerLag` not `.messagesBehind` |
| `Slack alert failed: channel_not_found` | Wrong channel ID in secret | Update `channel_id` in `slack-secret` |
| `Slack alert failed (HTTP 401)` | Invalid bot token | Update `bot_token` in `slack-secret` |
| Job stuck in `Running` for >5 min | Script hanging | Check `activeDeadlineSeconds: 300` is set |
| Job not triggering at scheduled time | CronJob suspended | `kubectl patch cronjob kafka-connector-healthcheck -n kafka -p '{"spec":{"suspend":false}}'` |

---

### Verify API manually (from inside cluster)

```bash
# Get Kafka UI pod name
kubectl get pods -n kafka | grep kafka-ui

# Test consumer groups API
kubectl exec -n kafka <kafka-ui-pod> -- wget -qO- \
  "http://localhost:8080/api/clusters/digitaldc-kafka/consumer-groups/paged?perPage=5" | head -c 500

# Test topics API
kubectl exec -n kafka <kafka-ui-pod> -- wget -qO- \
  "http://localhost:8080/api/clusters/digitaldc-kafka/topics?perPage=5" | head -c 500

# Test connector API
kubectl exec -n kafka <cp-connect-pod> -- curl -s \
  "http://localhost:8083/connectors" | head -c 500
```

---

## Updating Thresholds

### Change consumer lag threshold
```bash
# Edit the YAML
vi kafka-setup/manifests/digitaldc-prod/cronjob.yaml
# Find: LAG_THRESHOLD
# Change: value: "10000"  →  value: "5000"

# Apply
kubectl config use-context SbxDCProdCluster
kubectl apply -f kafka-setup/manifests/digitaldc-prod/cronjob.yaml -n kafka
```

### Change topic size threshold
```bash
# Edit the YAML
vi kafka-setup/manifests/digitaldc-prod/cronjob.yaml
# Find: TOPIC_SIZE_THRESHOLD_GB
# Change: value: "100"  →  value: "50"

# Apply
kubectl apply -f kafka-setup/manifests/digitaldc-prod/cronjob.yaml -n kafka
```

> Apply the same change to other environments if needed.

---

## Important Notes

- **`karapace-autogenerated-*` groups** — Schema Registry internal groups. Their lag in Kafka UI showing N/A is normal; the API returns `consumerLag: 0` for them.
- **Negative lag values** (e.g. `-42`) — Can appear for groups consuming ahead of committed offsets. These are treated as healthy (below threshold).
- **`concurrencyPolicy: Forbid`** — If a job takes longer than 10 minutes, the next scheduled run is skipped. `activeDeadlineSeconds: 300` kills jobs stuck beyond 5 minutes.
- **EMPTY state groups** — Consumer groups with 0 members can accumulate lag when Flink consumers are not running. This is expected during restarts.
- **The `consumerLag` field** aggregates lag across all partitions for the group (not per-partition).
