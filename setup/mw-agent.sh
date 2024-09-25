#!/bin/bash

# By default, the mw-agent will be enabled
if [ -z "$MW_DYNO_DISABLE_AGENT" ]; then
    export MW_DYNO_DISABLE_AGENT="false"
fi

# If preexec script exists, run it
if [ -f "$MW_DYNO_PREEXEC_SCRIPT" ]; then
    echo "Running mw-agent dyno preexec script..." 
    source $MW_DYNO_PREEXEC_SCRIPT
fi

# If mw-agent is disabled, exit
if [ "$MW_DYNO_DISABLE_AGENT" == "true" ]; then
    echo "mw-agent is disabled. Exiting..." 
    return
fi

MW_AGENT_DIR="$HOME/mw-agent"
if [ -z "$MW_FETCH_ACCOUNT_OTEL_CONFIG" ]; then
    export MW_FETCH_ACCOUNT_OTEL_CONFIG=false
fi

if [ -n "$MW_DYNO_HOSTNAME" ] && [ "$MW_DYNO_HOSTNAME" == "true" ]; then
    export OTEL_RESOURCE_ATTRIBUTES="host.name=${HEROKU_APP_NAME}.${DYNO}"
fi

if [ -z "$MW_LOGFILE" ]; then
    export MW_LOGFILE="$MW_AGENT_DIR/mw-agent.log"
fi

if [ -z "$OTEL_EXPORTER_OTLP_ENDPOINT" ]; then
    export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:9320"
fi

if [ -z "$OTEL_SERVICE_NAME" ]; then
    if [ -n "$HEROKU_APP_NAME" ]; then
        export OTEL_SERVICE_NAME="${HEROKU_APP_NAME}"
    else
        export OTEL_SERVICE_NAME="heroku"
    fi
fi

export MW_API_KEY=$MW_API_KEY
export MW_TARGET=$MW_TARGET
echo "Starting mw-agent in the background..." 
nohup $MW_AGENT_DIR/mw-agent start --otel-config-file=$MW_AGENT_DIR/otel-config.yaml --logfile $MW_LOGFILE &
