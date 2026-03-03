# RisingWave Kafka Integration Test Results

## Test Execution Summary

**Date:** 2026-03-03 13:25:00  
**Environment:** RisingWave Cloud + StreamNative Kafka  
**Test Suite Version:** 1.0

---

## Overall Results

| Metric | Value |
|--------|-------|
| **Total Tests** | 5 |
| **Passed** | 5 ✅ |
| **Failed** | 0 ❌ |
| **Success Rate** | 100% |

---

## Detailed Test Results

### ✅ JSON Sink Test
**Status:** PASSED

| Component | Result |
|-----------|--------|
| PLAIN Sink | 64 messages |
| UPSERT Sink | 64 messages |
| Data Inserted | 16 rows |

**Description:** Tests writing data from RisingWave materialized views to Kafka topics in JSON format using both PLAIN (append-only) and UPSERT (key-based) modes.

---

### ✅ JSON Source Test
**Status:** PASSED

| Component | Result |
|-----------|--------|
| Kafka Source Created | ✅ |
| Kafka Table Created | ✅ |
| Messages Produced | 10 |
| Rows Ingested | 46 total |

**Description:** Tests reading data from Kafka into RisingWave using both CREATE SOURCE (streaming) and CREATE TABLE (persisted) approaches with real-time ingestion.

---

### ✅ Avro Test
**Status:** PASSED

| Component | Result |
|-----------|--------|
| Schema Registry Key Subject | ✅ Created (HTTP 200) |
| Schema Registry Value Subject | ✅ Created (HTTP 200) |
| Avro Sink Created | ✅ |
| Avro Source Created | ✅ |
| Data Written | 682 bytes |

**Description:** Tests Avro format with Confluent Schema Registry. The test now automatically creates Schema Registry subjects for key and value schemas using the Confluent Schema Registry API. The Avro-compatible MV (`user_event_stats_avro`) casts timestamps to BIGINT (microseconds) for proper Avro encoding.

**Schema Details:**
- **Key Schema:** `UserEventStatsAvroKey` (user_id, event_type, window_start_us)
- **Value Schema:** `UserEventStatsAvro` (full record with microsecond timestamps)

---

### ✅ End-to-End Pipeline Test
**Status:** PASSED

| Component | Result |
|-----------|--------|
| Source → MV | ✅ Working |
| MV → Sink | ✅ Working |
| Messages in E2E Topic | 168 messages |

**Description:** Validates the complete data flow: Kafka Source → RisingWave Materialized View → Kafka Sink, demonstrating real-time stream processing pipeline.

---

### ✅ Data Verification Test
**Status:** PASSED

| Check | Result |
|-------|--------|
| PLAIN Sink Messages | 64 ✅ |
| UPSERT Sink Messages | 64 ✅ |
| user_events Table | 16 rows ✅ |
| user_event_stats MV | 6 rows ✅ |

**Description:** Validates data consistency between RisingWave and Kafka, ensuring all sinks have data and source tables are properly populated.

---

## Infrastructure Status

### RisingWave
| Resource | Status |
|----------|--------|
| Connection | ✅ Online |
| Sinks Created | 4 active |
| Sources Created | 2 active |
| Materialized Views | 3 active |

### Kafka (StreamNative)
| Resource | Status |
|----------|--------|
| Broker Connection | ✅ Online |
| SASL_SSL Auth | ✅ Working |
| Topics Used | 5 topics |

### Schema Registry
| Resource | Status |
|----------|--------|
| Connection | ✅ Accessible |
| Authentication | ✅ Working |
| Auto-registered Subjects | ✅ Working |

---

## Key Findings

### ✅ Working Features
- JSON Sink (PLAIN and UPSERT formats)
- JSON Source with metadata inclusion
- Avro Sink and Source with Schema Registry
- Real-time materialized views on streaming data
- SASL_SSL authentication
- End-to-end stream processing pipeline
- Automatic Schema Registry subject creation

### 🔧 Technical Implementation

**Schema Registry Subject Creation:**
The test suite now automatically creates Schema Registry subjects using the Confluent Schema Registry API:

```bash
curl -X POST "${SCHEMA_REGISTRY_URL}/subjects/${subject}/versions" \
    -u "${KAFKA_USERNAME}:${KAFKA_PASSWORD}" \
    -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data "{\"schema\":\"${escaped_schema}\"}"
```

**Avro Timestamp Handling:**
RisingWave's Avro encoder doesn't support `TIMESTAMP WITHOUT TIME ZONE` directly. The solution:
- Created `user_event_stats_avro` MV that casts timestamps to BIGINT (microseconds)
- Avro schema uses plain `long` type for timestamp fields
- This provides a work-around for Avro encoding limitations

---

## Next Steps

1. **Production Use:** All integrations (JSON and Avro) are production-ready
2. **Monitoring:** Set up alerts for sink/source lag metrics
3. **Schema Evolution:** Test schema updates and compatibility modes

---

## Test Artifacts

**Kafka Topics:**
- `risingwave-sink-plain-json` (64 messages)
- `risingwave-sink-upsert-json` (64 messages)
- `risingwave-sink-avro` (Avro binary data, 682+ bytes)
- `risingwave-sink-from-source` (168 messages)
- `risingwave-test-source-topic` (373+ messages)

**RisingWave Objects:**
- Tables: `user_events`, `kafka_table_user_events`
- Sources: `kafka_source_user_events`, `kafka_source_avro`
- Sinks: `kafka_sink_plain_json`, `kafka_sink_upsert_json`, `kafka_sink_avro`, `kafka_sink_from_source`
- MVs: `user_event_stats`, `user_event_stats_avro`, `mv_kafka_source_stats`

**Schema Registry Subjects:**
- `risingwave-sink-avro-key`
- `risingwave-sink-avro-value`
