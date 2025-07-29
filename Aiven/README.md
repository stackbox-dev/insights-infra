# Kafka Cluster
- **Service URI:** sbx-stag-kafka-stackbox.e.aivencloud.com:22167

- **Host:** sbx-stag-kafka-stackbox.e.aivencloud.com

- **Port:** 22167

- **User:** < username >

- **Password:** < password >

---------------------------------------------------------------------

# Schema Registry
- **Service URI:** https://< username >:< password >@sbx-stag-kafka-stackbox.e.aivencloud.com:22159

- **Host:** sbx-stag-kafka-stackbox.e.aivencloud.com

- **Port:** 22159

- **User:** < username >

- **Password:** < password >

---------------------------------------------------------------------

- **Credentials secret for Aiven Kafka**

  ```bash
  kubectl create secret generic aiven-credentials \
    --from-literal=username=< username > \
    --from-literal=password=< password >\
    --from-literal=userinfo="< username >:< password >" \
    -n kafka
  ```

- **Credentials secret for Debezium User**

  ```bash
  kubectl create secret generic debezium-pg-pass \
    --from-literal=password=< db-password > \
    -n kafka 
  ```

---------------------------------------------------------------------

- **Conver CA to truststore to use in java based connectors**

  ```bash
  docker run --rm -v "$PWD":/work openjdk:17-jdk \
    keytool -import \
      -alias kafka-ca \
      -file /work/ca.pem \
      -keystore /work/kafka.truststore.jks \
      -storepass < secret-pass > \
      -noprompt
  ```
- **Credentials secret for truststore created above**

  ```bash
  kubectl create secret generic kafka-truststore-secret \
    --from-file=kafka.truststore.jks=./kafka.truststore.jks \
    --from-literal=truststore-password=< secret-pass > \
    -n kafka
  ```

- **Internal Urls**

  - Kafka-UI: http://kafka-ui.kafka.api.staging.stackbox.internal/ui/clusters/sbx-kafka/brokers

  - Connect-UI: http://cp-connect-ui.kafka.api.staging.stackbox.internal/#/cluster/kafka-connect-1