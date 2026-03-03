-- Avro Test: Create Avro sink and source with Schema Registry

-- 1. Avro sink (requires existing MV user_event_stats)
CREATE SINK IF NOT EXISTS kafka_sink_avro
FROM user_event_stats
WITH (
    connector = 'kafka',
    properties.bootstrap.server = '${KAFKA_BROKER}',
    topic = 'risingwave-sink-avro',
    primary_key = 'user_id,event_type,window_start',
    properties.message.timeout.ms = '30000',
    properties.security.protocol = 'SASL_SSL',
    properties.sasl.mechanism = 'PLAIN',
    properties.sasl.username = '${KAFKA_USERNAME}',
    properties.sasl.password = '${KAFKA_PASSWORD}',
    properties.enable.ssl.certificate.verification = 'false'
)
FORMAT UPSERT ENCODE AVRO (
    schema.registry = '${SCHEMA_REGISTRY_URL}',
    schema.registry.username = '${KAFKA_USERNAME}',
    schema.registry.password = '${KAFKA_PASSWORD}'
);

-- 2. Avro source (reads back the Avro data)
CREATE SOURCE IF NOT EXISTS kafka_source_avro
WITH (
    connector = 'kafka',
    topic = 'risingwave-sink-avro',
    properties.bootstrap.server = '${KAFKA_BROKER}',
    scan.startup.mode = 'earliest',
    properties.security.protocol = 'SASL_SSL',
    properties.sasl.mechanism = 'PLAIN',
    properties.sasl.username = '${KAFKA_USERNAME}',
    properties.sasl.password = '${KAFKA_PASSWORD}',
    properties.enable.ssl.certificate.verification = 'false'
)
FORMAT PLAIN ENCODE AVRO (
    schema.registry = '${SCHEMA_REGISTRY_URL}',
    schema.registry.username = '${KAFKA_USERNAME}',
    schema.registry.password = '${KAFKA_PASSWORD}'
);
