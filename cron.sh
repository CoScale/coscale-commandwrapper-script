#!/usr/bin/env sh
set -u

# Command to run
COMMAND=""
EXIT_CODE=1

# CoScale CLI information
COSCALE_CLI="/opt/coscale/cli/coscale-cli"
CONFIG_DIR="/opt/coscale/cli/api.conf"

# When LIVE execute command and send information to CoScale, else debug information is shown
LIVE=0

# Information send to CoScale
EVENT_NAME=""
EVENT_CATEGORY="" # Could be id or name

# Parse arguments
while [ "$#" -gt 0 ]
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
        while [ "$#" -gt 0 ]
        do
            COMMAND="${COMMAND}$1 "
            shift
        done
        ;;
    esac

    if [ "$#" -gt 0 ]
    then
        shift
    fi
done

# Only process command when live, else just show example output
if [ $LIVE -eq 0 ]
then
    echo
    echo "# CoScale CLI TOOL "
    echo

    echo
    echo "## Checking configuration and environment"
    echo
    echo "### Your command:"
    echo ${COMMAND}
    echo "### Category of command"
    if [ "$EVENT_CATEGORY" = "" ]
    then
        echo "ERROR: Missing event --category"
    else
        echo "${EVENT_CATEGORY}"
    fi
    echo "### Name of command"
    if [ "$EVENT_NAME" = "" ]
    then
        echo "ERROR: Missing event --name"
    else
        echo "${EVENT_NAME}"
    fi

    echo "### CoScale CLI"
    echo
    echo "#### Checking location"
    if [ -f "$COSCALE_CLI" ]; then
        echo "CoScale CLI found."
    else
        echo "ERROR: CoScale CLI not found."
    fi

    echo
    echo "#### Checking configuration"
    $COSCALE_CLI check-config | sed -e 's/[{}]//g' | awk --field-separator=":" '{print $2 }'
    echo
fi

# Execute users command
if [ $LIVE -eq 0 ]
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
if [ $LIVE -eq 0 ]
then
    echo " - Pushing event category to coscale"
    if [ "$EVENT_CATEGORY" = "" ]
    then
        echo "   ERROR: Missing event --category"
    else
        echo "   ${EVENT_CATEGORY}"
    fi


    echo " - Pushing event to coscale"
    if [ "$EVENT_NAME" = "" ]
    then
        echo "   ERROR: Missing event --name"
    else
        echo "   ${EVENT_NAME}"
    fi
else
    if [ "$EVENT_NAME" != "" ] && [ "$EVENT_CATEGORY" != "" ]
    then
        echo
        echo "# Sending event to CoScale"
        $COSCALE_CLI event new --name "${EVENT_CATEGORY}" --attributeDescriptions "\[{\"name\":\"exitCode\", \"type\":\"integer\"}, {\"name\":\"executionTime\", \"type\":\"integer\", \"unit\":\"s\"}\]" --source "CLI"
        $COSCALE_CLI event data --name "${EVENT_CATEGORY}" --message "${EVENT_NAME}" --subject "a" --timestamp "${COMMAND_START}" --stopTime "${COMMAND_STOP}" --attribute "{\"exitCode\":${EXIT_CODE}, \"executionTime\":${COMMAND_DIFF}}"
    fi
fi

# Return COMMAND exit code
exit $EXIT_CODE
