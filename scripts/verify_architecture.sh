#!/bin/bash

# verify_architecture.sh
# Enforces "One Boss" Architecture Standards for Dispatch
#
# Rules:
# 1. No NavigationStack in Views/Screens (except *Sheet.swift)
# 2. No embedInNavigationStack flags in Views/Screens or Views/Containers
# 3. No .navigationDestination in Views/Screens (must be in AppShell)
# 4. No lensState.currentScreen assignments in Views (must be derived)

EXIT_CODE=0

echo "🔍 Starting One Boss Architecture Verification..."
echo "=================================================="

# Function to check for forbidden patterns
check_pattern() {
    local pattern="$1"
    local message="$2"
    local path="$3"
    local exclude="$4"

    echo "Checking: $message..."
    
    if [ -n "$exclude" ]; then
        grep -r "$pattern" "$path" --include="*.swift" --exclude-dir="Deprecated" | grep -v "$exclude" > violations.tmp
    else
        grep -r "$pattern" "$path" --include="*.swift" --exclude-dir="Deprecated" > violations.tmp
    fi

    if [ -s violations.tmp ]; then
        echo "❌ VIOLATION FOUND: $message"
        cat violations.tmp
        echo "--------------------------------------------------"
        EXIT_CODE=1
    else
        echo "✅ Passed"
    fi
    rm violations.tmp
}

# 1. Check for NavigationStack in Screens (excluding Sheets and Previews)
# We exclude 'Sheet.swift' files because sheets are mini-apps allowed to have their own stack.
# We exclude 'Preview' files because they need stacks for testing.
check_pattern "NavigationStack {" "Checking for NavigationStack in Screens" "Dispatch/Views/Screens" "Sheet.swift"

# 2. Check for embedInNavigationStack usage in Screens and Containers
check_pattern "embedInNavigationStack" "Checking for embedInNavigationStack in Views" "Dispatch/Views" ""

# 3. Check for .navigationDestination in Screens
# Destinations should only be attached at the Root (Shell), not in individual screens.
check_pattern "\.navigationDestination(for:" "Checking for .navigationDestination in Screens" "Dispatch/Views/Screens" ""

# 4. Check for direct lensState mutation in Views
# Views should not drive state; the Router should.
check_pattern "lensState.currentScreen =" "Checking for lensState assignment in Screens" "Dispatch/Views/Screens" ""

echo "=================================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "🎉 ARCHITECTURE VERIFIED: ONE BOSS RULED SUPREME."
    exit 0
else
    echo "🚫 ARCHITECTURE VIOLATIONS FOUND. FIX THEM BEFORE SHIPPING."
    exit 1
fi
