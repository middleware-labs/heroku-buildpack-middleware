#!/bin/bash

if [ "$DYNOTYPE" == "run" ]; then
    exit 0
fi
MW_AGENT_DIR="$HOME/mw-agent"
if [ -z "$MW_FETCH_ACCOUNT_OTEL_CONFIG" ]; then
    export MW_FETCH_ACCOUNT_OTEL_CONFIG=false
fi
if [ "$MW_DYNO_HOSTNAME" == "true" ]; then
    export OTEL_RESOURCE_ATTRIBUTES="host.name=${HEROKU_APP_NAME}.${DYNO}"
fi
echo "Starting mw-agent in the background..."
nohup $MW_AGENT_DIR/opt/mw-agent/bin/mw-agent start --otel-config-file=$MW_AGENT_DIR/etc/mw-agent/otel-config.yaml > $MW_AGENT_DIR/mw-agent.log &
