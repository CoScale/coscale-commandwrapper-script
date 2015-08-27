#!/usr/bin/env bash
set -u

# Command to run
COMMAND=""
EXIT_CODE=1

# CoScale CLI information
CLI=$(which coscale-cli)
APP_ID=""
APP_TOKEN=""

# When LIVE execute command and send information to CoScale, else debug information is shown
LIVE=0

# Information send to CoScale
EVENT_NAME=""
EVENT_CATEGORY="" # Could be id or name

# Parse arguments
while [[ $# -gt 0 ]]
do
key="$1"
    case $key in
        --app_id)
        APP_ID="$2"
        shift
        ;;
        --app_token)
        APP_TOKEN="$2"
        shift
        ;;
        --cli)
        CLI="$2"
        shift
        ;;
        --name)
        EVENT_NAME="$2"
        shift
        ;;
        --category)
        EVENT_CATEGORY="$2"
        shift
        ;;
        --live)
        LIVE=1
        ;;
        --)
        shift
        while [[ $# -gt 0 ]]
        do
            COMMAND="${COMMAND}$1 "
            shift
        done
        ;;
    esac
    shift || true
done

# Only process command when live, else just show example output
if [[ $LIVE -eq 0 ]]
then
    CONFIG_DIR="$(dirname "${CLI}")/api.conf"

    echo
    echo "# CoScale CLI TOOL "
    echo
    echo "Configuration"
    echo " - COMMAND: ${COMMAND}"
    echo " - CLI: ${CLI}"

    # Show CLI config
    if [[ -f $CONFIG_DIR ]] && [[ $APP_ID = "" ]] && [[ $APP_TOKEN = "" ]]; then
        CONFIG=$(gunzip -c "${CONFIG_DIR}")
        echo " - CONFIG: ${CONFIG}"
    else
        echo " - APP_ID: ${APP_ID}"
        echo " - APP_TOKEN: ${APP_TOKEN}"
    fi

    echo
    echo "Environment checks"

    # Check CLI binary
    if [[ ! -x "${CLI}" ]]
    then
        echo "- CoScale CLI: not found. Use --cli to pass its location."
        exit 1
    else
        echo "- CoScale CLI: found"
    fi

    echo
    echo "Initializing dry run"
fi

# Execute users command
if [[ $LIVE -eq 0 ]]
then
    echo " - Executing: ${COMMAND}"
else
    # Gather start
    COMMAND_START=$(date +%s)

    # Execute and catch exit code
    bash -c "${COMMAND}"
    EXIT_CODE=$?

    # Gather stop and calculate diff
    COMMAND_STOP=$(date +%s)

    # shellcheck disable=SC2004
    COMMAND_DIFF=$(($COMMAND_STOP-$COMMAND_START))
fi

# Push information to CoScale
if [[ $LIVE -eq 0 ]]
then
    echo " - Pushing event category to coscale"
    if [[ $EVENT_CATEGORY = "" ]]
    then
        echo "   ERROR: Missing event --category"
    else
        echo "   ${EVENT_CATEGORY}"
    fi


    echo " - Pushing event to coscale"
    if [[ $EVENT_NAME = "" ]]
    then
        echo "   ERROR: Missing event --name"
    else
        echo "   ${EVENT_NAME}"
    fi
else
    if [[ $EVENT_NAME != "" ]] && [[ $EVENT_CATEGORY != "" ]]
    then
        ${CLI} event new --name "${EVENT_CATEGORY}" --attributeDescriptions "[{\"name\":\"exitCode\", \"type\":\"integer\"}, {\"name\":\"executionTime\", \"type\":\"integer\", \"unit\":\"s\"}]" --source "CLI"
        ${CLI} event data --name "${EVENT_CATEGORY}" --message "${EVENT_NAME}" --subject "a" --timestamp "${COMMAND_START}" --stopTime "${COMMAND_STOP}" --attribute "{\"exitCode\":${EXIT_CODE}, \"executionTime\":${COMMAND_DIFF}}"
    fi
fi

# Return COMMAND exit code
exit $EXIT_CODE
