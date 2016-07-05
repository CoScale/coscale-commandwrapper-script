#!/usr/bin/env sh
set -u

# Command to run
COMMAND=""
EXIT_CODE=1

# CoScale CLI information
COSCALE_CLI="/opt/coscale/agent/coscale-cli"

# When LIVE execute command and send information to CoScale, else debug information is shown
LIVE=0
TEST_ERROR=0

# Information send to CoScale
EVENT_MESSAGE=""
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
        --message)
        EVENT_MESSAGE="$2"
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
    echo "CoScale commandwrapper tool"
    echo
    echo "Environment check"
    if [ -f "$COSCALE_CLI" ]; then
        echo "- Checking CLI installation: \t\tFound"
    else
        echo "- Checking CLI installation: \t\tMissing!"
        TEST_ERROR=1
    fi

    echo -n "- Checking CLI authentication: \t\t"
    output=$($COSCALE_CLI config check 2>&1 >/dev/null)
    echo "$output"
    if [ "$output" != "Configuration successfuly checked" ]; then
        TEST_ERROR=1
    fi
    echo
fi

# Execute users command
if [ $LIVE -eq 0 ]
then
    echo "Starting test run"
    echo -n "- Pushing event category:"
    if [ "$EVENT_CATEGORY" = "" ]
    then
        echo "\t\tERROR: Missing event category parameter, check documentation for more information"
        TEST_ERROR=1
    else
        echo "\t\tOk"
    fi

    echo -n "- Pushing start time event:"
    if [ "$EVENT_MESSAGE" = "" ]
    then
        echo "\tERROR: Missing event message parameter, check documentation for more information"
        TEST_ERROR=1
    else
        echo "\t\tOk"
    fi

    echo -n "- Executing command"
    if [ "$COMMAND" = "" ]
    then
        echo "\tERROR: Missing command parameter, check documentation for more information"
        TEST_ERROR=1
    else
        echo "\t\t\tOk"
    fi

    if [ ! "$EVENT_MESSAGE" = "" ]
    then
        echo "- Pushing stop time event: \t\tOk"
    fi

    echo
    if [ $TEST_ERROR -eq 1 ]
    then
        echo "! Errors detected, please check your configuration."
    fi
    echo
else
    # Gather start
    COMMAND_START=$(date +%s)

    # Send start event to CoScale
    if [ "$EVENT_MESSAGE" != "" ] && [ "$EVENT_CATEGORY" != "" ]
    then
        echo
        echo "# Sending event to CoScale"

        # Create event category
        $COSCALE_CLI event new --name "${EVENT_CATEGORY}" --attributeDescriptions "[{\"name\":\"exitCode\", \"type\":\"integer\"}, {\"name\":\"executionTime\", \"type\":\"integer\", \"unit\":\"s\"}]" --source "CLI" || true

        # Create event with empty stopTime
        output=$($COSCALE_CLI event data \
            --name "${EVENT_CATEGORY}" \
            --message "${EVENT_MESSAGE}" \
            --subject "a" \
            --timestamp "${COMMAND_START}" \
            --attribute "{\"exitCode\":-1, \"executionTime\":-1}" \
            || true)
        echo "$output"
        eventId=$(echo "$output" | grep "eventId" | awk '{ print $2; }' | sed 's/"//g')
    fi

    # Execute and catch exit code
    bash -c "${COMMAND}"
    EXIT_CODE=$?

    # Gather stop and calculate diff
    COMMAND_STOP=$(date +%s)

    # shellcheck disable=SC2004
    COMMAND_DIFF=$(($COMMAND_STOP-$COMMAND_START))

    # Send stop event to CoScale
    if [ "$EVENT_MESSAGE" != "" ] && [ "$EVENT_CATEGORY" != "" ]
    then
        echo
        echo "# Updating stopTime on event in CoScale"

        # Set stoptime of event
        $($COSCALE_CLI event updatedate \
            --id "${eventId}" \
            --stopTime "${COMMAND_STOP}" \
            --attribute "{\"exitCode\":${EXIT_CODE}, \"executionTime\":${COMMAND_DIFF}}" \
            || true)
    fi
fi

# Return COMMAND exit code
exit $EXIT_CODE
