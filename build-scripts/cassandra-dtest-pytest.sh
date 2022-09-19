#!/bin/bash -x

################################
#
# Prep
#
################################

# Pass in target to run, default to base dtest
DTEST_TARGET="${1:-dtest}"
# Optional: pass in chunk to test, formatted as "K/N" for the Kth chunk of N chunks
DTEST_SPLIT_CHUNK="$2"

export PYTHONIOENCODING="utf-8"
export PYTHONUNBUFFERED=true
export CASS_DRIVER_NO_EXTENSIONS=true
export CASS_DRIVER_NO_CYTHON=true
export CCM_MAX_HEAP_SIZE="1024M"
export CCM_HEAP_NEWSIZE="512M"
export CCM_CONFIG_DIR=${WORKSPACE}/.ccm
export NUM_TOKENS="16"
export CASSANDRA_DIR=${WORKSPACE}
#Have Cassandra skip all fsyncs to improve test performance and reliability
export CASSANDRA_SKIP_SYNC=true
export TMPDIR="./tmp"

# set JAVA_HOME environment to enable multi-version jar files for >4.0
# both JAVA8/11_HOME env variables must exist
grep -q _build_multi_java $CASSANDRA_DIR/build.xml
if [ $? -eq 0 -a -n "$JAVA8_HOME" -a -n "$JAVA11_HOME" ]; then
   export JAVA_HOME="$JAVA11_HOME"
fi

# pre-conditions
command -v ant >/dev/null 2>&1 || { echo >&2 "ant needs to be installed"; exit 1; }
command -v pip3 >/dev/null 2>&1 || { echo >&2 "pip3 needs to be installed"; exit 1; }
command -v virtualenv >/dev/null 2>&1 || { echo >&2 "virtualenv needs to be installed"; exit 1; }

# print debug information on versions
ant -version
pip3 --version
virtualenv --version

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

# restore JAVA_HOME to Java 8 version we intent to run tests with
if [ -n "$JAVA8_HOME" ]; then
   export JAVA_HOME="$JAVA8_HOME"
fi

# Set up venv with dtest dependencies
set -e # enable immediate exit if venv setup fails
virtualenv --python=python3 venv
source venv/bin/activate
pip3 install --exists-action w -r cassandra-dtest/requirements.txt
pip3 freeze

################################
#
# Main
#
################################

cd cassandra-dtest/
mkdir -p ${TMPDIR}
set +e # disable immediate exit from this point
if [ "${DTEST_TARGET}" = "dtest" ]; then
    DTEST_ARGS="--use-vnodes --num-tokens=${NUM_TOKENS} --skip-resource-intensive-tests --keep-failed-test-dir"
elif [ "${DTEST_TARGET}" = "dtest-novnode" ]; then
    DTEST_ARGS="--skip-resource-intensive-tests --keep-failed-test-dir"
elif [ "${DTEST_TARGET}" = "dtest-offheap" ]; then
    DTEST_ARGS="--use-vnodes --num-tokens=${NUM_TOKENS} --use-off-heap-memtables --skip-resource-intensive-tests --keep-failed-test-dir"
elif [ "${DTEST_TARGET}" = "dtest-large" ]; then
    DTEST_ARGS="--use-vnodes --num-tokens=${NUM_TOKENS} --only-resource-intensive-tests --force-resource-intensive-tests --keep-failed-test-dir"
elif [ "${DTEST_TARGET}" = "dtest-large-novnode" ]; then
    DTEST_ARGS="--only-resource-intensive-tests --force-resource-intensive-tests --keep-failed-test-dir"
elif [ "${DTEST_TARGET}" = "dtest-upgrade" ]; then
    DTEST_ARGS="--execute-upgrade-tests-only --upgrade-target-version-only --upgrade-version-selection all"
else
    echo "Unknown dtest target: ${DTEST_TARGET}"
    exit 1
fi

SPLIT_TESTS=""
if [ "x${DTEST_SPLIT_CHUNK}" != "x" ] ; then
    ./run_dtests.py --cassandra-dir=$CASSANDRA_DIR ${DTEST_ARGS} --dtest-print-tests-only --dtest-print-tests-output=${WORKSPACE}/test_list.txt 2>&1 > ${WORKSPACE}/test_stdout.txt
    SPLIT_TESTS=$(split -n r/${DTEST_SPLIT_CHUNK} ${WORKSPACE}/test_list.txt)
fi

PYTEST_OPTS="-vv --log-cli-level=DEBUG --junit-xml=nosetests.xml --junit-prefix=${DTEST_TARGET} -s"

pytest ${PYTEST_OPTS} --cassandra-dir=$CASSANDRA_DIR ${DTEST_ARGS} ${SPLIT_TESTS} 2>&1 | tee -a ${WORKSPACE}/test_stdout.txt

# tar up any ccm logs for easy retrieval
tar -cJf ccm_logs.tar.xz ${TMPDIR}/*/test/*/logs/*

################################
#
# Clean
#
################################

# /virtualenv
deactivate

# Exit cleanly for usable "Unstable" status
exit 0
