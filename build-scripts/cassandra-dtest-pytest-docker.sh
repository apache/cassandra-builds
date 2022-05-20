#!/bin/bash
#
# A wrapper script to cassandra-dtest-pytest.sh
#  that runs it in docker, collecting results.
#
# The docker image used is normally based from those found in docker/testing/
#
# Usage: cassandra-dtest-pytest-docker.sh REPO BRANCH DTEST_REPO_URL DTEST_BRANCH BUILDS_REPO_URL BUILDS_BRANCH DOCKER_IMAGE [target] [split_chunk]
#

if [ "$#" -lt 3 ]; then
    # inside the docker container, setup env before calling cassandra-dtest-pytest.sh
    export WORKSPACE=/home/cassandra/cassandra
    export LANG=en_US.UTF-8
    export LC_CTYPE=en_US.UTF-8
    export PYTHONIOENCODING=utf-8
    export PYTHONUNBUFFERED=true
    echo "running: git clone --depth 1 --single-branch --branch=$BRANCH https://github.com/$REPO/cassandra.git"
    git clone --quiet --depth 1 --single-branch --branch=$BRANCH https://github.com/$REPO/cassandra.git
    cd cassandra
    echo "running: git clone --depth 1 --single-branch --branch=$DTEST_BRANCH $DTEST_REPO"
    git clone --quiet --depth 1 --single-branch --branch=$DTEST_BRANCH $DTEST_REPO
    echo "cassandra-dtest-pytest.sh (${1} ${2}) cassandra: `git log -1 --pretty=format:'%H %an %ad %s'`" | tee "${1}-$(echo $2 | sed 's/\//-/')-cassandra.head"
    echo "cassandra-dtest-pytest.sh (${1} ${2}) cassandra-dtest: `git -C cassandra-dtest log -1 --pretty=format:'%H %an %ad %s'`" | tee -a "${1}-$(echo $2 | sed 's/\//-/')-cassandra.head"
    echo "cassandra-dtest-pytest.sh (${1} ${2}) cassandra-builds: `git -C ../cassandra-builds log -1 --pretty=format:'%H %an %ad %s'`" | tee -a "${1}-$(echo $2 | sed 's/\//-/')-cassandra.head"
    ../cassandra-builds/build-scripts/cassandra-dtest-pytest.sh "$@"
    xz test_stdout.txt
else
    # start the docker container
    if [ "$#" -lt 7 ]; then
       echo "Usage: cassandra-dtest-pytest.sh REPO BRANCH DTEST_REPO_URL DTEST_BRANCH BUILDS_REPO_URL BUILDS_BRANCH DOCKER_IMAGE [target] [split_chunk]"
       exit 1
    fi
    BUILDSREPO=$5
    BUILDSBRANCH=$6
    DOCKER_IMAGE=$7
    TARGET=$8
    SPLIT_CHUNK=$9
    cat > env.list <<EOF
REPO=$1
BRANCH=$2
DTEST_REPO=$3
DTEST_BRANCH=$4
EOF

    # pre-conditions
    command -v docker >/dev/null 2>&1 || { echo >&2 "docker needs to be installed"; exit 1; }

    # print debug information on versions
    docker --version

    set -x # debug, sometimes ${docker_cpus} is not evaluated
    # Jenkins agents run multiple executors per machine. `jenkins_executors=1` is used for anything non-jenkins.
    jenkins_executors=1
    if [[ ! -z ${JENKINS_URL+x} ]] && [[ ! -z ${NODE_NAME+x} ]] ; then
        fetched_jenkins_executors=$(curl -s --retry 9 --retry-connrefused --retry-delay 1 "${JENKINS_URL}/computer/${NODE_NAME}/api/json?pretty=true" | grep 'numExecutors' | awk -F' : ' '{print $2}' | cut -d',' -f1)
        # use it if we got a valid number (despite retry settings the curl above can still fail)
        [[ ${fetched_jenkins_executors} =~ '^[0-9]+$' ]] && jenkins_executors=${fetched_jenkins_executors}
    fi
    cores=1
    command -v nproc >/dev/null 2>&1 && cores=$(nproc --all)
    docker_cpus=$(echo "scale=2; ${cores} / ${jenkins_executors}" | bc)

    # docker login to avoid rate-limiting apache images. credentials are expected to already be in place
    docker login || true
    [[ "$(docker images -q $DOCKER_IMAGE 2>/dev/null)" != "" ]] || docker pull -q $DOCKER_IMAGE

    echo "cassandra-dtest-pytest-docker.sh: running: git clone --single-branch --depth 1 --branch $BUILDSBRANCH $BUILDSREPO; sh ./cassandra-builds/build-scripts/cassandra-dtest-pytest-docker.sh $TARGET $SPLIT_CHUNK"
    ID=$(docker run --cpus=${docker_cpus} -m 15g --memory-swap 15g --env-file env.list -dt $DOCKER_IMAGE dumb-init bash -ilc "git clone --quiet --single-branch --depth 1 --branch $BUILDSBRANCH $BUILDSREPO; sh ./cassandra-builds/build-scripts/cassandra-dtest-pytest-docker.sh $TARGET $SPLIT_CHUNK")

    # use docker attach instead of docker wait to get output
    docker attach --no-stdin $ID
    status="$?"

    if [ "$status" -ne 0 ] ; then
        echo "$ID failed (${status}), debug…"
        docker inspect $ID
        echo "–––"
        docker logs $ID
        echo "–––"
        docker ps -a
        echo "–––"
        docker info
        echo "–––"
        dmesg
    else
        echo "$ID done (${status}), copying files"
        # dtest.sh meta
        docker cp "$ID:/home/cassandra/cassandra/${TARGET}-$(echo $SPLIT_CHUNK | sed 's/\//-/')-cassandra.head" .
        # pytest results
        docker cp $ID:/home/cassandra/cassandra/cassandra-dtest/nosetests.xml .
        # pytest logs
        docker cp $ID:/home/cassandra/cassandra/test_stdout.txt.xz .
        docker cp $ID:/home/cassandra/cassandra/cassandra-dtest/ccm_logs.tar.xz .
    fi

    docker rm $ID
    exit $status
fi