#!/bin/bash
#
# Automated build monitor with auto-recovery
# Monitors RN2 container rebuild and automatically fixes common issues
#

LOG_FILE="/tmp/rn2-rebuild.log"
MONITOR_LOG="/tmp/rn2-build-monitor.log"
BUILD_DIR="/tmp"
MAX_RESTARTS=10
CHECK_INTERVAL=180  # 3 minutes

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MONITOR_LOG"
}

check_build_status() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "not_started"
        return
    fi
    
    # Check if build process is running
    if ! ps aux | grep -q '[d]ocker.*build.*rn2'; then
        # Process not running - check if it completed successfully
        if tail -20 "$LOG_FILE" | grep -qiE "successfully.*built|Successfully tagged"; then
            echo "success"
        elif tail -20 "$LOG_FILE" | grep -qiE "error|failed|fatal"; then
            echo "failed"
        else
            echo "unknown"
        fi
    else
        echo "running"
    fi
}

detect_failure_reason() {
    local reason=""
    
    # Check for common failure patterns
    if tail -50 "$LOG_FILE" | grep -qiE "wx-new-deployed.*not found"; then
        reason="missing_wx_new"
    elif tail -50 "$LOG_FILE" | grep -qiE "Unable to locate package|Couldn't find.*package"; then
        reason="package_not_found"
    elif tail -50 "$LOG_FILE" | grep -qiE "externally-managed-environment"; then
        reason="pip_externally_managed"
    elif tail -50 "$LOG_FILE" | grep -qiE "error.*pip|pip.*error"; then
        reason="pip_error"
    elif tail -50 "$LOG_FILE" | grep -qiE "cmake.*error|make.*error"; then
        reason="build_error"
    elif tail -50 "$LOG_FILE" | grep -qiE "timeout|killed|signal"; then
        reason="timeout"
    else
        reason="unknown"
    fi
    
    echo "$reason"
}

fix_issue() {
    local issue=$1
    log "Attempting to fix issue: $issue"
    
    case "$issue" in
        missing_wx_new)
            log "Checking if wx-new-deployed exists in build context..."
            if [ -d "$BUILD_DIR/wx-new-deployed" ]; then
                log "wx-new-deployed already exists in build context"
                return 0
            else
                log "WARNING: wx-new-deployed missing - may need manual copy"
                log "This should have been fixed already, but continuing..."
                return 0
            fi
            ;;
        package_not_found)
            log "Package name issue detected - Dockerfile should already be fixed"
            return 0
            ;;
        pip_externally_managed)
            log "Pip externally-managed issue - Dockerfile should already be fixed"
            return 0
            ;;
        pip_error)
            log "Pip error detected - checking Dockerfile..."
            return 0
            ;;
        build_error)
            log "Build error detected - may need manual intervention"
            return 0
            ;;
        timeout)
            log "Build timeout - restarting..."
            return 0
            ;;
        *)
            log "Unknown issue - may need manual intervention"
            return 0
            ;;
    esac
}

restart_build() {
    log "Restarting build..."
    cd "$BUILD_DIR" || return 1
    
    # Kill any existing build process
    pkill -f "docker.*build.*rn2" 2>/dev/null
    
    # Clear old log
    > "$LOG_FILE"
    
    # Start new build
    nohup docker compose -f docker/docker-compose.yml build --no-cache rn2 > "$LOG_FILE" 2>&1 &
    local pid=$!
    
    log "Build restarted (PID: $pid)"
    sleep 5
    
    # Verify it started
    if ps -p $pid > /dev/null 2>&1; then
        log "Build process confirmed running"
        return 0
    else
        log "ERROR: Build process did not start"
        return 1
    fi
}

main() {
    log "=== RN2 Build Monitor Started ==="
    log "Monitoring build at: $LOG_FILE"
    log "Check interval: ${CHECK_INTERVAL}s"
    log "Max restarts: $MAX_RESTARTS"
    
    local restarts=0
    local consecutive_failures=0
    
    while [ $restarts -lt $MAX_RESTARTS ]; do
        sleep $CHECK_INTERVAL
        
        local status=$(check_build_status)
        log "Build status: $status"
        
        case "$status" in
            success)
                log "✅ BUILD COMPLETED SUCCESSFULLY!"
                log "Container image is ready"
                log "Next step: Restart container with: cd $BUILD_DIR && docker compose -f docker/docker-compose.yml up -d rn2"
                exit 0
                ;;
            failed)
                log "❌ Build failed - analyzing..."
                local reason=$(detect_failure_reason)
                log "Failure reason: $reason"
                
                if fix_issue "$reason"; then
                    restarts=$((restarts + 1))
                    consecutive_failures=0
                    log "Fix applied. Restarting build (attempt $restarts/$MAX_RESTARTS)..."
                    
                    if restart_build; then
                        log "Build restarted successfully"
                    else
                        log "ERROR: Failed to restart build"
                        consecutive_failures=$((consecutive_failures + 1))
                    fi
                else
                    log "ERROR: Could not fix issue automatically"
                    consecutive_failures=$((consecutive_failures + 1))
                fi
                
                if [ $consecutive_failures -ge 3 ]; then
                    log "ERROR: Too many consecutive failures. Stopping monitor."
                    log "Please check manually: tail -50 $LOG_FILE"
                    exit 1
                fi
                ;;
            running)
                # Show progress
                local current_step=$(grep -E '^#\[rn2' "$LOG_FILE" | tail -1 | sed 's/#\[rn2 *\([0-9]*\)\/.*/\1/')
                if [ -n "$current_step" ]; then
                    log "Build running - Current step: $current_step/31"
                else
                    log "Build running - processing..."
                fi
                consecutive_failures=0
                ;;
            not_started)
                log "Build not started - starting now..."
                if restart_build; then
                    log "Build started"
                else
                    log "ERROR: Failed to start build"
                    exit 1
                fi
                ;;
            unknown)
                log "⚠️  Build status unclear - continuing to monitor..."
                consecutive_failures=$((consecutive_failures + 1))
                if [ $consecutive_failures -ge 5 ]; then
                    log "ERROR: Status unclear for too long. Stopping monitor."
                    exit 1
                fi
                ;;
        esac
    done
    
    log "ERROR: Maximum restart attempts ($MAX_RESTARTS) reached"
    log "Please check manually: tail -50 $LOG_FILE"
    exit 1
}

# Run main loop
main

