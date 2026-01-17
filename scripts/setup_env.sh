#!/bin/bash
#
# Setup script for Dispatch environment variables
# Run: ./scripts/setup_env.sh
#

ZSHRC="$HOME/.zshrc"

# Check if already configured
if grep -q "SUPABASE_URL" "$ZSHRC" 2>/dev/null; then
    echo "⚠️  Supabase environment variables already exist in $ZSHRC"
    echo "    Remove them first if you want to reconfigure."
    exit 0
fi

# Add environment variables
cat >> "$ZSHRC" << 'EOF'

# Dispatch - Supabase credentials
export SUPABASE_URL="https://uhkrvxlclflgevocqtkh.supabase.co"
export SUPABASE_ANON_KEY="sb_publishable_RPjCcEeqvKdGnVWzBHjP0A_P3C9pCZO"
EOF

echo "✅ Added Supabase environment variables to $ZSHRC"
echo ""
echo "Run this to apply now:"
echo "    source ~/.zshrc"
echo ""
echo "Or restart your terminal."
