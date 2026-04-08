#!/bin/sh
set -e

# Write .env at container START TIME (when Render env vars are available)
mkdir -p /usr/share/nginx/html/assets/assets
cat > /usr/share/nginx/html/assets/assets/.env <<EOF
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
GROQ_API_KEY=${GROQ_API_KEY}
EOF

echo "✅ .env written:"
cat /usr/share/nginx/html/assets/assets/.env

# Start nginx
exec nginx -g "daemon off;"