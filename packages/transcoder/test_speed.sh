#!/bin/bash

HOST="http://localhost:8000"
LOG_FILE="./transcode_test_results.log"
MODE="sequential"

JOBS=(
    "hi-res-test:high:High-Res to High Quality AAC (320k)"
    "hi-res-test:efficiency:High-Res to Efficiency AAC (128k)"
    "hi-res-test:cd:High-Res to CD Quality FLAC (44.1/16)"
    "cd-test:high:CD Quality to High Quality AAC (320k)"
    "cd-test:efficiency:CD Quality to Efficiency AAC (128k)"
)

if [[ "$1" == "--concurrent" ]]; then
    MODE="concurrent"
fi

setup_log() {
    echo "--- Sonic Atlas Transcoder Testing ---" > "$LOG_FILE"
    echo "Mode: $MODE" >> "$LOG_FILE"
    echo "Time: $(date)" >> "$LOG_FILE"
    echo "-------------------------------------" >> "$LOG_FILE"
    echo "Ensure the Python service is running on port 8000."
    echo "Results logged to $LOG_FILE"
}

run_job() {
    local TRACK_ID="$1"
    local QUALITY="$2"
    local DESCRIPTION="$3"

    local TEMP_OUTPUT=$(mktemp)
    
    curl -s -w "\n%{time_total}\n" -X POST "$HOST/transcode/$TRACK_ID" \
        -H "Content-Type: application/json" \
        -d "{\"quality\": \"$QUALITY\"}" > "$TEMP_OUTPUT" 2>/dev/null
    
    local HTTP_TIME=$(tail -n 1 "$TEMP_OUTPUT" | tr -d '\n')
    local RESPONSE_BODY=$(head -n -1 "$TEMP_OUTPUT")
    
    rm "$TEMP_OUTPUT"

    if [[ "$RESPONSE_BODY" == *"completed"* ]]; then
        echo "$DESCRIPTION: SUCCESS (Time: ${HTTP_TIME}s)" | tee -a "$LOG_FILE"
        return 0
    else
        echo "$DESCRIPTION: FAILURE (Response Body: ${RESPONSE_BODY:-EMPTY / CONNECTION ERROR})" | tee -a "$LOG_FILE"
        return 1
    fi
}
test_sequential() {
    echo -e "\n\n--- 1. SEQUENTIAL TESTS (Individual Speeds) ---" | tee -a "$LOG_FILE"
    
    local TOTAL_START=$(date +%s.%N)
    
    for JOB in "${JOBS[@]}"; do
        IFS=: read -r TRACK_ID QUALITY DESCRIPTION <<< "$JOB"
        
        run_job "$TRACK_ID" "$QUALITY" "$DESCRIPTION"
    done

    local TOTAL_END=$(date +%s.%N)
    local TOTAL_TIME=$(echo "$TOTAL_END - $TOTAL_START" | bc -l)
    echo -e "\nSequential Total Time: ${TOTAL_TIME}s" | tee -a "$LOG_FILE"
}


test_concurrent() {
    echo -e "\n\n--- 2. CONCURRENT TEST (Max Load) ---" | tee -a "$LOG_FILE"
    echo "Starting ${#JOBS[@]} jobs simultaneously (Concurrent Mode)..." | tee -a "$LOG_FILE"

    local PIDS=()
    local JOB_COUNT=0
    local TOTAL_START=$(date +%s.%N)

    for JOB in "${JOBS[@]}"; do
        IFS=: read -r TRACK_ID QUALITY DESCRIPTION <<< "$JOB"
        
        ( run_job "$TRACK_ID" "$QUALITY" "$DESCRIPTION" ) &
        PIDS+=($!)
        JOB_COUNT=$((JOB_COUNT + 1))
    done

    wait "${PIDS[@]}"

    local TOTAL_END=$(date +%s.%N)
    local TOTAL_TIME=$(echo "$TOTAL_END - $TOTAL_START" | bc -l)
    
    echo -e "\nConcurrent Test Details:" | tee -a "$LOG_FILE"
    echo "  Total Jobs Started: $JOB_COUNT" | tee -a "$LOG_FILE"
    echo "  Concurrent Total Time: ${TOTAL_TIME}s" | tee -a "$LOG_FILE"
}



main() {
    setup_log

    if [[ "$MODE" == "concurrent" ]]; then
        test_concurrent
    else
        test_sequential
    fi
    
    echo -e "\nTest finished. See $LOG_FILE for results."
}

main
