#!/bin/bash

if [ "$DYNOTYPE" == "run" ]; then
    exit 0
fi

MW_AGENT_DIR="$HOME/mw-agent"
export MW_FETCH_ACCOUNT_OTEL_CONFIG=false
echo "Starting mw-agent in the background..."
nohup "$MW_AGENT_DIR/opt/mw-agent/bin/mw-agent start --config=$MW_AGENT_DIR/etc/mw-agent/otel-config.yaml" > /dev/null 2>&1 &