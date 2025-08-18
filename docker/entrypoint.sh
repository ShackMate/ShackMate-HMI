#!/bin/bash

echo "🏁 Entrypoint started..."

if echo "10.146.1.241 shackmate.router" >> /etc/hosts; then
    echo "✅ /etc/hosts updated"
else
    echo "❌ Failed to update /etc/hosts"
fi

exec "$@"
