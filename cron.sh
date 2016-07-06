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

echo "CoScale commandwrapper tool"
echo

# Only process command when live, else just show example output
if [ $LIVE -eq 0 ]
then
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
    else
        echo "Everything is configured correctly, add --live before the '--' to start using the cron wrapper"
    fi
    echo
else
    # Gather start
    COMMAND_START=$(date +%s)

    # Send start event to CoScale
    if [ "$EVENT_MESSAGE" != "" ] && [ "$EVENT_CATEGORY" != "" ]
    then
        echo
        echo "- Pushing event category"
        $COSCALE_CLI event new \
            --name "${EVENT_CATEGORY}" \
            --attributeDescriptions "[{\"name\":\"exitCode\", \"type\":\"integer\"}, {\"name\":\"executionTime\", \"type\":\"integer\", \"unit\":\"s\"}, {\"name\":\"message\", \"type\":\"string\"}]" \
            --source "CLI" || true

        echo
        echo "- Pushing start time event"
        # Create event with empty stopTime
        output=$($COSCALE_CLI event newdata \
            --name "${EVENT_CATEGORY}" \
            --message "${EVENT_MESSAGE}" \
            --subject "a" \
            --timestamp "${COMMAND_START}" \
            --attribute "{\"exitCode\":-1, \"executionTime\":-1, \"message\":\"${EVENT_MESSAGE}\"}" \
            || true)
        echo "$output"
        eventId=$(echo "$output" | grep "eventId" | awk '{ print $2; }' | sed 's/"//g')
        dataId=$(echo "$output" | grep "\"id\"" | awk '{ print $2; }' | sed 's/[",]//g')
    fi

    # Execute and catch exit code
    echo
    echo "- Executing command"
    bash -c "${COMMAND}"
    EXIT_CODE=$?

    # Gather stop and calculate diff
    COMMAND_STOP=$(date +%s)

    # shellcheck disable=SC2004
    COMMAND_DIFF=$(($COMMAND_STOP-$COMMAND_START))

    # Send stop event to CoScale
    if [ "$EVENT_MESSAGE" != "" ] && [ "$EVENT_CATEGORY" != "" ]
    then
        # Set stoptime of event
        echo "- Pushing stop time event"
        $COSCALE_CLI event updatedata \
            --id "${eventId}" \
            --dataid "${dataId}" \
            --stopTime "${COMMAND_STOP}" \
            --attribute "{\"exitCode\":${EXIT_CODE}, \"executionTime\":${COMMAND_DIFF}, \"message\":\"${EVENT_MESSAGE}\"}" || true
    fi
fi

# Return COMMAND exit code
exit $EXIT_CODE
