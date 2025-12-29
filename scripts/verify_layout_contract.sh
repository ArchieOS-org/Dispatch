#!/bin/bash

# Layout Contract Verification Script
# Enforces "Jobs Standards" for Dispatch codebase.

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

EXIT_CODE=0
PROJECT_ROOT="Dispatch"
SCREENS_DIR="$PROJECT_ROOT/Views/Screens"

echo "🔍 Verifying Layout Contract..."

# 1. Check for Rogue Padding/MaxWidth in Screens
# We want to catch .padding(.horizontal) or .frame(maxWidth:) at the top level.
# This simple grep catches any occurrence. Ideally we'd parse AST, but grep is a good first line of defense.
# We exclude StandardScreen itself if it ends up in Screens dir (it shouldn't).

echo "Checking for rogue layout modifiers in $SCREENS_DIR..."
GREP_RESULT=$(grep -rE "\.padding\(.*\.horizontal.|\.frame\(.*maxWidth:" "$SCREENS_DIR" --include="*.swift")

if [ ! -z "$GREP_RESULT" ]; then
    echo "${RED}❌ VIOLATION: Rogue layout modifiers found in Screens (Screens should be dumb content):${NC}"
    echo "$GREP_RESULT"
    EXIT_CODE=1
else
    echo "${GREEN}✅ No rogue layout modifiers found in Screens.${NC}"
fi

# 2. Check for Navigation Title in Screens
# Screens should provide title to StandardScreen, not set it themselves.
echo "Checking for direct .navigationTitle usage in $SCREENS_DIR..."
GREP_RESULT=$(grep -r "\.navigationTitle(" "$SCREENS_DIR" --include="*.swift")

if [ ! -z "$GREP_RESULT" ]; then
    echo "${RED}❌ VIOLATION: Direct .navigationTitle modifier found in Screens (StandardScreen must own this):${NC}"
    echo "$GREP_RESULT"
    EXIT_CODE=1
else
    echo "${GREEN}✅ No direct navigation titles found in Screens.${NC}"
fi

# 3. Check for Window Mutations outside MacWindowPolicy
# We scan the whole project excluding MacWindowPolicy.swift (and WindowAccessor until we delete it)
echo "Checking for NSWindow mutations outside policy..."
GREP_RESULT=$(grep -rE "NSApp|NSWindow" "$PROJECT_ROOT" --include="*.swift" \
    --exclude="MacWindowPolicy.swift" \
    --exclude="WindowAccessor.swift" \
    --exclude-dir="Tests" \
    --exclude="PlatformUtilities.swift") # Whitelist specific utils if needed

if [ ! -z "$GREP_RESULT" ]; then
    echo "${RED}❌ VIOLATION: NSWindow/NSApp usage found outside MacWindowPolicy:${NC}"
    echo "$GREP_RESULT"
    # Warning for now until we fully migrate, uncomment to error
    # EXIT_CODE=1 
    echo "${RED}⚠️ (Treating as warning during migration)${NC}"
else
    echo "${GREEN}✅ No rogue NSWindow usage found.${NC}"
fi

# 4. Check for .toolbarBackground outside AppShell/StandardScreen
echo "Checking for .toolbarBackground usage..."
GREP_RESULT=$(grep -r "\.toolbarBackground" "$PROJECT_ROOT" --include="*.swift" \
    --exclude="AppShellView.swift" \
    --exclude="StandardScreen.swift" \
    --exclude="StandardPageLayout.swift") # Allow legacy for a moment

if [ ! -z "$GREP_RESULT" ]; then
    echo "${RED}❌ VIOLATION: .toolbarBackground found outside AppShell/StandardScreen:${NC}"
    echo "$GREP_RESULT"
    EXIT_CODE=1
else
    echo "${GREEN}✅ No rogue .toolbarBackground usage found.${NC}"
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "${GREEN}🎉 Layout Contract Verified!${NC}"
else
    echo "${RED}🔥 Layout Contract Violations Detected.${NC}"
fi

exit $EXIT_CODE
