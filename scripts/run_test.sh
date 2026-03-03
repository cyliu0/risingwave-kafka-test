#!/bin/bash
# Unified test runner for RisingWave Kafka integration tests

# Don't exit on error - run all tests and report summary
# set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SQL_DIR="$PROJECT_DIR/sql"

# Source libs
source "$SCRIPT_DIR/env.sh"
source "$SCRIPT_DIR/lib.sh"

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
ALL_TESTS=()
TEST_RESULTS=()

# Run a test function and track results
run_test() {
    local test_name=$1
    local test_func=$2
    
    info "========================================"
    info "  Test: $test_name"
    info "========================================"
    
    ALL_TESTS+=("$test_name")
    
    if $test_func; then
        ((TESTS_PASSED++))
        TEST_RESULTS+=("✓ $test_name - PASSED")
        info "✓ Test '$test_name' PASSED"
    else
        ((TESTS_FAILED++))
        TEST_RESULTS+=("✗ $test_name - FAILED")
        error "✗ Test '$test_name' FAILED"
    fi
    echo ""
}

# Show usage
usage() {
    cat <<EOF
RisingWave Kafka Test Suite

Usage: $0 <command>

Commands:
  sink       Test JSON sink (RisingWave → Kafka)
  source     Test JSON source (Kafka → RisingWave)
  avro       Test Avro format with Schema Registry
  e2e        End-to-end test (Kafka → RisingWave → Kafka)
  verify     Verify all data consistency
  cleanup    Clean up RisingWave resources
  all        Run all tests in sequence

Examples:
  $0 sink      # Run sink test only
  $0 all       # Run complete test suite
  $0 cleanup   # Remove all RisingWave test resources
EOF
    exit 1
}

# Test: JSON Sink
test_sink() {
    step "Setting up sink test..."
    exec_sql "$SQL_DIR/sink/setup.sql" "Create sink infrastructure" || return 1
    
    step "Waiting for data to propagate..."
    sleep 5
    
    step "Verifying sink data..."
    local count=$(kafka_count "risingwave-sink-plain-json")
    info "PLAIN sink: $count messages"
    
    local count2=$(kafka_count "risingwave-sink-upsert-json")
    info "UPSERT sink: $count2 messages"
    
    # At least one sink should have messages (may have existing data)
    if [ "$count" -gt 0 ] || [ "$count2" -gt 0 ]; then
        return 0
    else
        error "No messages in any sink topic"
        return 1
    fi
}

# Test: JSON Source
test_source() {
    step "Setting up source test..."
    exec_sql "$SQL_DIR/source/setup.sql" "Create source infrastructure" || return 1
    
    step "Producing test messages to Kafka..."
    for i in {1..10}; do
        produce_msg "risingwave-test-source-topic" "$i" "page_view" "$((i*1000))"
        echo -ne "\r  Produced $i/10"
    done
    echo ""
    
    step "Waiting for data ingestion..."
    sleep 10
    
    step "Verifying source data..."
    local count=$(psql "$RW_PSQL_URL" -t -c "SELECT COUNT(*) FROM kafka_table_user_events WHERE user_id > 0;" 2>/dev/null | xargs)
    info "Table rows: $count"
    
    if [ "$count" -gt 0 ]; then
        return 0
    else
        error "No data ingested from Kafka source"
        return 1
    fi
}

# Test: Avro with Schema Registry
test_avro() {
    step "Checking Schema Registry..."
    if ! command -v curl &>/dev/null; then
        warn "curl not found, skipping SR check"
    else
        local status=$(curl -s -o /dev/null -w "%{http_code}" -u "${KAFKA_USERNAME}:${KAFKA_PASSWORD}" "${SCHEMA_REGISTRY_URL}/subjects" 2>/dev/null || echo "000")
        if [ "$status" = "200" ]; then
            info "✓ Schema Registry accessible"
        else
            error "Schema Registry returned: $status"
        fi
    fi
    
    # Ensure sink test is set up first
    if ! psql "$RW_PSQL_URL" -c "SELECT 1 FROM user_event_stats LIMIT 1;" &>/dev/null; then
        step "Setting up base infrastructure..."
        exec_sql "$SQL_DIR/sink/setup.sql" "Create base infrastructure" || return 1
        sleep 5
    fi
    
    step "Creating Avro sink..."
    if ! envsubst < "$SQL_DIR/avro/setup.sql" | psql "$RW_PSQL_URL" -v ON_ERROR_STOP=1 2>&1; then
        warn "Avro sink creation failed - Schema Registry may need pre-configured subjects"
        return 1
    fi
    
    step "Waiting for Avro data..."
    sleep 10
    
    step "Checking Avro topic..."
    local bytes=$(kcat -b "$KAFKA_BROKER" -t "risingwave-sink-avro" -X security.protocol=SASL_SSL \
        -X sasl.mechanism=PLAIN -X sasl.username="$KAFKA_USERNAME" \
        -X sasl.password="$KAFKA_PASSWORD" -X enable.ssl.certificate.verification=false \
        -C -e 2>/dev/null | wc -c)
    info "Avro topic: $bytes bytes"
    
    if [ "$bytes" -gt 0 ]; then
        return 0
    else
        warn "No Avro data written"
        return 1
    fi
}

# Test: End-to-End
test_e2e() {
    # Run source test first (but don't double-count)
    if [ "$1" != "skip_source" ]; then
        test_source || return 1
    fi
    
    step "Creating sink from source MV..."
    if ! psql "$RW_PSQL_URL" -v ON_ERROR_STOP=1 <<EOF 2>&1
create sink if not exists kafka_sink_from_source
from mv_kafka_source_stats
with (
    connector = 'kafka',
    properties.bootstrap.server = '${KAFKA_BROKER}',
    topic = 'risingwave-sink-from-source',
    properties.message.timeout.ms = '30000',
    properties.security.protocol = 'SASL_SSL',
    properties.sasl.mechanism = 'PLAIN',
    properties.sasl.username = '${KAFKA_USERNAME}',
    properties.sasl.password = '${KAFKA_PASSWORD}',
    properties.enable.ssl.certificate.verification = 'false'
)
format plain encode json (force_append_only = 'true');
EOF
    then
        error "Failed to create E2E sink"
        return 1
    fi
    
    step "Producing more data..."
    for i in {100..105}; do
        produce_msg "risingwave-test-source-topic" "$i" "click" "$((i*100))"
    done
    
    sleep 5
    
    local count=$(kafka_count "risingwave-sink-from-source")
    info "E2E sink: $count messages"
    
    if [ "$count" -gt 0 ]; then
        return 0
    else
        error "No messages in E2E sink topic"
        return 1
    fi
}

# Cleanup
cleanup() {
    info "========================================"
    info "  Cleaning up RisingWave resources"
    info "========================================"
    
    if exec_sql "$SQL_DIR/cleanup/all.sql" "Drop all test resources"; then
        return 0
    else
        return 1
    fi
}

# Main
main() {
    [ $# -eq 0 ] && usage
    
    check_prereqs
    wait_for_rw || exit 1
    
    case "$1" in
        sink)      run_test "JSON Sink" test_sink ;;
        source)    run_test "JSON Source" test_source ;;
        avro)      run_test "Avro" test_avro ;;
        e2e)       run_test "End-to-End" test_e2e ;;
        verify)    run_test "Data Verification" verify_data ;;
        cleanup)   run_test "Cleanup" cleanup ;;
        all)
            run_test "JSON Sink" test_sink
            run_test "JSON Source" test_source
            run_test "Avro" test_avro
            run_test "End-to-End" test_e2e
            run_test "Data Verification" verify_data
            
            # Summary
            info "========================================"
            info "  Test Summary"
            info "========================================"
            info ""
            info "Test Results:"
            for result in "${TEST_RESULTS[@]}"; do
                info "  $result"
            done
            info ""
            info "Statistics:"
            info "  Passed: $TESTS_PASSED"
            info "  Failed: $TESTS_FAILED"
            info "  Total:  ${#ALL_TESTS[@]}"
            
            if [ $TESTS_FAILED -gt 0 ]; then
                exit 1
            else
                info ""
                info "✓ All tests passed!"
                exit 0
            fi
            ;;
        *) usage ;;
    esac
}

main "$@"
