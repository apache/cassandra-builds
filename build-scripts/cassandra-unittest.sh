#!/bin/bash -x

################################
#
# Prep
#
################################

# Pass in target to run, default to `ant test`
TEST_TARGET="${1:-test}"

################################
#
# Main
#
################################

# Loop to prevent failure due to maven-ant-tasks not downloading a jar..
for x in $(seq 1 3); do
    ant clean jar
    RETURN="$?"
    if [ "${RETURN}" -eq "0" ]; then
        # Run target and exit cleanly for usable "Unstable" status
        ant "${TEST_TARGET}"
        exit 0
    fi
done

################################
#
# Clean
#
################################

# If we failed `ant jar` loop
exit "${RETURN}"
