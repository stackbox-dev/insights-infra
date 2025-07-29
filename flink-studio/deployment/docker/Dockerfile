FROM flink:2.0.0-scala_2.12-java21

# Copy dependency configuration and preparation script
COPY dependency-versions.json prepare-image.sh /opt/flink/

# Run the preparation script
RUN bash /opt/flink/prepare-image.sh
