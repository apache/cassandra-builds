#!/bin/bash -x

################################
#
# Prep
#
################################

# Pass in target to run, default to base dtest
DTEST_TARGET="${1:-dtest}"

export PYTHONIOENCODING="utf-8"
export PYTHONUNBUFFERED=true
export CASS_DRIVER_NO_EXTENSIONS=true
export CASS_DRIVER_NO_CYTHON=true
export CCM_MAX_HEAP_SIZE="2048M"
export CCM_HEAP_NEWSIZE="200M"
export NUM_TOKENS="32"
export CASSANDRA_DIR=${WORKSPACE}

# Loop to prevent failure due to maven-ant-tasks not downloading a jar..
for x in $(seq 1 3); do
    ant clean jar
    RETURN="$?"
    if [ "${RETURN}" -eq "0" ]; then
        break
    fi
done
# Exit, if we didn't build successfully
if [ "${RETURN}" -ne "0" ]; then
    echo "Build failed with exit code: ${RETURN}"
    exit ${RETURN}
fi

# Set up venv with dtest dependencies
set -e # enable immediate exit if venv setup fails
virtualenv --python=python2 --no-site-packages venv
source venv/bin/activate
pip install -r cassandra-dtest/requirements.txt
pip freeze

################################
#
# Main
#
################################

cd cassandra-dtest/
rm -r upgrade_tests/ # TEMP: remove upgrade_tests - we have no dual JDK installation
set +e # disable immediate exit from this point
if [ "${DTEST_TARGET}" = "dtest" ]; then
    ./run_dtests.py --vnodes true --nose-options="--verbosity=3 --with-xunit --nocapture --attr=!resource-intensive" | tee -a ${WORKSPACE}/test_stdout.txt
elif [ "${DTEST_TARGET}" = "dtest-novnode" ]; then
    export DISABLE_VNODES="true"
    ./run_dtests.py --vnodes true --nose-options="--verbosity=3 --with-xunit --nocapture --attr=!resource-intensive" | tee -a ${WORKSPACE}/test_stdout.txt
elif [ "${DTEST_TARGET}" = "dtest-offheap" ]; then
    export OFFHEAP_MEMTABLES="true"
    ./run_dtests.py --vnodes true --nose-options="--verbosity=3 --with-xunit --nocapture --attr=!resource-intensive" | tee -a ${WORKSPACE}/test_stdout.txt
elif [ "${DTEST_TARGET}" = "dtest-large" ]; then
    ./run_dtests.py --vnodes true --nose-options="--verbosity=3 --with-xunit --nocapture --attr=resource-intensive" | tee -a ${WORKSPACE}/test_stdout.txt
else
    echo "Unknown dtest target: ${DTEST_TARGET}"
    exit 1
fi

################################
#
# Clean
#
################################

# /virtualenv
deactivate

# Exit cleanly for usable "Unstable" status
exit 0
