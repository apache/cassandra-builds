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
    git clone --depth 1 --single-branch --branch=$BRANCH https://github.com/$REPO/cassandra.git
    cd cassandra
    echo "running: git clone --depth 1 --single-branch --branch=$DTEST_BRANCH $DTEST_REPO"
    git clone --depth 1 --single-branch --branch=$DTEST_BRANCH $DTEST_REPO
    echo "cassandra-dtest-pytest.sh (${1} ${2}) cassandra: `git log -1 --pretty=format:'%h %an %ad %s'`" | tee "${1}-$(echo $2 | sed 's/\//-/')-cassandra.head"
    echo "cassandra-dtest-pytest.sh (${1} ${2}) cassandra-dtest: `git -C cassandra-dtest log -1 --pretty=format:'%h %an %ad %s'`" | tee -a "${1}-$(echo $2 | sed 's/\//-/')-cassandra.head"
    echo "cassandra-dtest-pytest.sh (${1} ${2}) cassandra-builds: `git -C ../cassandra-builds log -1 --pretty=format:'%h %an %ad %s'`" | tee -a "${1}-$(echo $2 | sed 's/\//-/')-cassandra.head"
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

    echo "cassandra-dtest-pytest-docker.sh: running: git clone --single-branch --depth 1 --branch $BUILDSBRANCH $BUILDSREPO; sh ./cassandra-builds/build-scripts/cassandra-dtest-pytest-docker.sh $TARGET $SPLIT_CHUNK"
    ID=$(docker run -m 15g --memory-swap 15g --env-file env.list -dt $DOCKER_IMAGE dumb-init bash -ilc "git clone --single-branch --depth 1 --branch $BUILDSBRANCH $BUILDSREPO; sh ./cassandra-builds/build-scripts/cassandra-dtest-pytest-docker.sh $TARGET $SPLIT_CHUNK")

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
fi