#!/bin/bash
# Common library functions for RisingWave Kafka tests

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check prerequisites
check_prereqs() {
    local missing=()
    command -v psql &>/dev/null || missing+=("psql")
    command -v kcat &>/dev/null || command -v kafkacat &>/dev/null || missing+=("kcat/kafkacat")
    
    if [ ${#missing[@]} -ne 0 ]; then
        error "Missing: ${missing[*]}"
        exit 1
    fi
}

# Execute SQL file with env substitution
exec_sql() {
    local file=$1
    local desc=$2
    step "$desc"
    envsubst < "$file" | psql "$RW_PSQL_URL" -v ON_ERROR_STOP=1 2>&1
    local rc=$?
    if [ $rc -eq 0 ]; then
        info "✓ $desc"
    else
        error "✗ $desc failed"
    fi
    return $rc
}

# Wait for RisingWave
wait_for_rw() {
    info "Waiting for RisingWave..."
    for i in {1..30}; do
        if psql "$RW_PSQL_URL" -c "SELECT 1;" &>/dev/null; then
            info "✓ RisingWave is ready"
            return 0
        fi
        sleep 2
    done
    error "RisingWave not available"
    return 1
}

# Produce JSON message to Kafka
produce_msg() {
    local topic=$1
    local user_id=$2
    local event_type=$3
    local duration=$4
    
    printf '{"user_id":%s,"event_type":"%s","page_url":"/test","session_id":"sess_%s","event_timestamp":"%s","duration_ms":%s}' \
        "$user_id" "$event_type" "$(date +%s)" "$(date -u +"%Y-%m-%d %H:%M:%S")" "$duration" | \
    kcat -b "$KAFKA_BROKER" -t "$topic" -X security.protocol=SASL_SSL \
        -X sasl.mechanism=PLAIN -X sasl.username="$KAFKA_USERNAME" \
        -X sasl.password="$KAFKA_PASSWORD" -X enable.ssl.certificate.verification=false \
        -P 2>/dev/null
}

# Get Kafka message count
kafka_count() {
    local topic=$1
    kcat -b "$KAFKA_BROKER" -t "$topic" -X security.protocol=SASL_SSL \
        -X sasl.mechanism=PLAIN -X sasl.username="$KAFKA_USERNAME" \
        -X sasl.password="$KAFKA_PASSWORD" -X enable.ssl.certificate.verification=false \
        -C -e 2>/dev/null | wc -l | xargs
}

# Verify data consistency
verify_data() {
    info "========================================"
    info "  Data Verification"
    info "========================================"
    
    local pass=0
    local fail=0
    
    # Check sink topics
    local plain_count=$(kafka_count "risingwave-sink-plain-json")
    local upsert_count=$(kafka_count "risingwave-sink-upsert-json")
    
    if [ "$plain_count" -gt 0 ]; then
        info "✓ PLAIN sink: $plain_count msgs"
        ((pass++))
    else
        error "✗ PLAIN sink empty"
        ((fail++))
    fi
    
    if [ "$upsert_count" -gt 0 ]; then
        info "✓ UPSERT sink: $upsert_count msgs"
        ((pass++))
    else
        error "✗ UPSERT sink empty"
        ((fail++))
    fi
    
    # Check RisingWave
    local user_count=$(psql "$RW_PSQL_URL" -t -c "SELECT COUNT(*) FROM user_events;" 2>/dev/null | xargs)
    local mv_count=$(psql "$RW_PSQL_URL" -t -c "SELECT COUNT(*) FROM user_event_stats;" 2>/dev/null | xargs)
    
    if [ "$user_count" -gt 0 ]; then
        info "✓ user_events: $user_count rows"
        ((pass++))
    else
        error "✗ user_events empty"
        ((fail++))
    fi
    
    if [ "$mv_count" -gt 0 ]; then
        info "✓ user_event_stats: $mv_count rows"
        ((pass++))
    else
        error "✗ user_event_stats empty"
        ((fail++))
    fi
    
    info "Results: $pass passed, $fail failed"
    
    if [ $fail -eq 0 ]; then
        return 0
    else
        return 1
    fi
}
