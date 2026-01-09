#!/bin/bash

# APK Analysis Script - Simple version
# Shows library name, React Native package name, and 16KB alignment status
#
# Usage:
#   ./scripts/analyze_apk.sh <path_to_apk>

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if APK path is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <path_to_apk>"
    exit 1
fi

APK_PATH="$1"

if [ ! -f "$APK_PATH" ]; then
    echo "Error: APK file not found: $APK_PATH"
    exit 1
fi

# Check if unzip is available
if ! command -v unzip &> /dev/null; then
    echo "Error: unzip command not found"
    exit 1
fi

# Check if zipalign is available
ZIPALIGN_AVAILABLE=false
ZIPALIGN_CMD=""

# Check in PATH first
if command -v zipalign &> /dev/null; then
    ZIPALIGN_AVAILABLE=true
    ZIPALIGN_CMD="zipalign"
else
    # Check common Android SDK locations
    SDK_PATHS=()
    
    if [ -n "$ANDROID_HOME" ]; then
        SDK_PATHS+=("$ANDROID_HOME")
    fi
    
    if [ -n "$ANDROID_SDK_ROOT" ]; then
        SDK_PATHS+=("$ANDROID_SDK_ROOT")
    fi
    
    # macOS default
    if [ -d "$HOME/Library/Android/sdk" ]; then
        SDK_PATHS+=("$HOME/Library/Android/sdk")
    fi
    
    # Linux default
    if [ -d "$HOME/Android/Sdk" ]; then
        SDK_PATHS+=("$HOME/Android/Sdk")
    fi
    
    # Search in build-tools directories
    for sdk_path in "${SDK_PATHS[@]}"; do
        if [ -d "$sdk_path/build-tools" ]; then
            # Find zipalign in any build-tools version (use find to be more reliable)
            ZIPALIGN_PATH=$(find "$sdk_path/build-tools" -name "zipalign" -type f 2>/dev/null | head -1)
            if [ -n "$ZIPALIGN_PATH" ] && [ -f "$ZIPALIGN_PATH" ]; then
                ZIPALIGN_AVAILABLE=true
                ZIPALIGN_CMD="$ZIPALIGN_PATH"
                break
            fi
        fi
    done
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
SEEN_LIBS_FILE=$(mktemp)
trap "rm -rf $TEMP_DIR $SEEN_LIBS_FILE" EXIT

# Extract APK
unzip -q "$APK_PATH" -d "$TEMP_DIR" 2>/dev/null || {
    echo "Error: Failed to extract APK"
    exit 1
}

# Function to get React Native package name
get_rn_package_name() {
    local lib_name=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    
    case "$lib_name" in
        rnscreens|reactnativescreens)
            echo "react-native-screens"
            ;;
        reactnativereanimated|reanimated)
            echo "react-native-reanimated"
            ;;
        reactnativewebview|webview)
            echo "react-native-webview"
            ;;
        reactnativeblob|blob)
            echo "react-native-blob-util"
            ;;
        reactnativepermissions|permissions)
            echo "react-native-permissions"
            ;;
        reactnativebiometrics|biometrics)
            echo "react-native-biometrics"
            ;;
        reactnativesvg|svg)
            echo "react-native-svg"
            ;;
        reactnativepdf|pdf|jniPdfium|modpdfium)
            echo "react-native-pdf"
            ;;
        reactnativepushnotification|pushnotification)
            echo "react-native-push-notification"
            ;;
        reactnativecalendars|calendars)
            echo "react-native-calendars"
            ;;
        reactnativedatepicker|datepicker)
            echo "react-native-date-picker"
            ;;
        reactnativedropdownpicker|dropdownpicker)
            echo "react-native-dropdown-picker"
            ;;
        reactnativegiftedcharts|giftedcharts)
            echo "react-native-gifted-charts"
            ;;
        reactnativeshare|share)
            echo "react-native-share"
            ;;
        reactnativeskeleton|skeleton)
            echo "react-native-skeleton-placeholder"
            ;;
        reactnativequeueit|queueit)
            echo "react-native-queue-it"
            ;;
        reactnativequantum|quantum)
            echo "react-native-quantum-metric-library"
            ;;
        hermes|hermes_executor|hermesinstancejni)
            echo "hermes-engine"
            ;;
        fbjni)
            echo "react-native (fbjni)"
            ;;
        folly|folly_runtime)
            echo "react-native (folly)"
            ;;
        yoga)
            echo "react-native (yoga)"
            ;;
        jsc|jscinstance)
            echo "react-native (jsc)"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to extract library name from path
extract_lib_name() {
    local path="$1"
    local basename=$(basename "$path")
    echo "${basename#lib}" | sed 's/\.so$//'
}

# Function to check alignment using zipalign output
check_alignment() {
    local rel_path="$1"
    
    if [ "$ZIPALIGN_AVAILABLE" != true ]; then
        echo "NO"
        return
    fi
    
    # zipalign -c -v 4 output format is:
    # "31014912 lib/arm64-v8a/libname.so (OK)"
    # "31014912 lib/arm64-v8a/libname.so (FAILED - offset = 1234 at position 5678)"
    # Format: offset filepath (status)
    
    # Find line containing this file path (path comes after offset)
    local zipalign_line=$(echo "$ZIPALIGN_OUTPUT" | grep " $rel_path")
    
    if [ -z "$zipalign_line" ]; then
        echo "NO"
        return
    fi
    
    # Check for (OK) at the end - means aligned
    if echo "$zipalign_line" | grep -q " (OK)$"; then
        echo "YES"
        return
    fi
    
    # Check for (FAILED - means misaligned
    if echo "$zipalign_line" | grep -q " (FAILED"; then
        echo "NO"
        return
    fi
    
    # Default to NO if unclear
    echo "NO"
}

# Get zipalign output if available
ZIPALIGN_OUTPUT=""
if [ "$ZIPALIGN_AVAILABLE" = true ]; then
    ZIPALIGN_OUTPUT=$("$ZIPALIGN_CMD" -c -v 4 "$APK_PATH" 2>&1)
    
    # Check if zipalign actually worked
    if [ -z "$ZIPALIGN_OUTPUT" ] || echo "$ZIPALIGN_OUTPUT" | grep -qi "error\|not found\|cannot"; then
        ZIPALIGN_AVAILABLE=false
    fi
fi

# Find and process all .so files
echo "Library Name | React Native Package | 16KB Aligned"
echo "------------------------------------------------------------"

# Process libraries, tracking seen ones to avoid duplicates
find "$TEMP_DIR" -name "*.so" -type f | sort | while read -r so_file; do
    rel_path="${so_file#$TEMP_DIR/}"
    lib_name=$(extract_lib_name "$rel_path")
    
    # Skip if we've already seen this library name
    if grep -q "^$lib_name$" "$SEEN_LIBS_FILE" 2>/dev/null; then
        continue
    fi
    
    # Mark as seen
    echo "$lib_name" >> "$SEEN_LIBS_FILE"
    
    rn_package=$(get_rn_package_name "$lib_name")
    
    # Check alignment (check first occurrence found)
    align_status=$(check_alignment "$rel_path")
    
    # Format alignment status - show YES or NO (no colors)
    if [ "$align_status" = "YES" ]; then
        align_display="YES"
    else
        align_display="NO"
    fi
    
    # Display
    if [ -n "$rn_package" ]; then
        printf "%-40s | %-35s | %s\n" "$lib_name.so" "$rn_package" "$align_display"
    else
        printf "%-40s | %-35s | %s\n" "$lib_name.so" "-" "$align_display"
    fi
done
