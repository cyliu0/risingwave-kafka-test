# RisingWave Kafka Integration Test Results

## Test Execution Summary

**Date:** 2026-03-03 13:06:18  
**Environment:** RisingWave Cloud + StreamNative Kafka  
**Test Suite Version:** 1.0

---

## Overall Results

| Metric | Value |
|--------|-------|
| **Total Tests** | 5 |
| **Passed** | 4 ✅ |
| **Failed** | 1 ❌ |
| **Success Rate** | 80% |

---

## Detailed Test Results

### ✅ JSON Sink Test
**Status:** PASSED

| Component | Result |
|-----------|--------|
| PLAIN Sink | 52 messages |
| UPSERT Sink | 52 messages |
| Data Inserted | 8 rows |

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

### ❌ Avro Test
**Status:** FAILED

**Error Details:**
```
Failed to build key encoder
Schema Registry error 40401: 
Subject 'risingwave-sink-avro-key' not found
```

**Root Cause:**  
StreamNative Schema Registry requires pre-registered key schemas for UPSERT Avro format. The schema subject needs to be created manually in the StreamNative Console before running this test.

**Recommended Fix:**
1. Log into StreamNative Cloud Console
2. Navigate to Schema Registry
3. Create subject: `risingwave-sink-avro-key`
4. Register the Avro key schema

---

### ✅ End-to-End Pipeline Test
**Status:** PASSED

| Component | Result |
|-----------|--------|
| Source → MV | ✅ Working |
| MV → Sink | ✅ Working |
| Messages in E2E Topic | 116 |

**Description:** Validates the complete data flow: Kafka Source → RisingWave Materialized View → Kafka Sink, demonstrating real-time stream processing pipeline.

---

### ✅ Data Verification Test
**Status:** PASSED

| Check | Result |
|-------|--------|
| PLAIN Sink Messages | 52 ✅ |
| UPSERT Sink Messages | 52 ✅ |
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
| Materialized Views | 2 active |

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
| Pre-configured Subjects | ⚠️ Missing (Avro test only) |

---

## Key Findings

### ✅ Working Features
- JSON Sink (PLAIN and UPSERT formats)
- JSON Source with metadata inclusion
- Real-time materialized views on streaming data
- SASL_SSL authentication
- End-to-end stream processing pipeline

### ⚠️ Requires Configuration
- Avro format with Schema Registry (needs pre-registered key schemas)

---

## Next Steps

1. **For Avro Testing:** Configure Schema Registry subjects in StreamNative Console
2. **Production Use:** All JSON-based integrations are production-ready
3. **Monitoring:** Set up alerts for sink/source lag metrics

---

## Test Artifacts

**Kafka Topics:**
- `risingwave-sink-plain-json` (52 messages)
- `risingwave-sink-upsert-json` (52 messages)
- `risingwave-sink-from-source` (116 messages)
- `risingwave-test-source-topic` (373+ messages)

**RisingWave Objects:**
- Tables: `user_events`, `kafka_table_user_events`
- Sources: `kafka_source_user_events`
- Sinks: `kafka_sink_plain_json`, `kafka_sink_upsert_json`, `kafka_sink_from_source`
- MVs: `user_event_stats`, `mv_kafka_source_stats`
