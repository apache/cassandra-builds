#!/bin/bash
#
# A wrapper script to cassandra-test.sh
#  that runs it in docker, collecting results.
#
# The docker image used is normally based from those found in docker/testing/
#
# Usage: cassandra-test-docker.sh REPO BRANCH BUILDS_REPO_URL BUILDS_BRANCH DOCKER_IMAGE [target] [split_chunk]
#

if [ "$#" -lt 3 ]; then
    # inside the docker container, setup env before calling cassandra-test.sh
    export WORKSPACE=/home/cassandra/cassandra
    export LANG=en_US.UTF-8
    export LC_CTYPE=en_US.UTF-8
    export PYTHONIOENCODING=utf-8
    export PYTHONUNBUFFERED=true
    echo "running: git clone --depth 1 --single-branch --branch=$BRANCH https://github.com/$REPO/cassandra.git"
    git clone --depth 1 --single-branch --branch=$BRANCH https://github.com/$REPO/cassandra.git
    cd cassandra
    echo "cassandra-test.sh (${1} ${2}) cassandra: `git log -1 --pretty=format:'%h %an %ad %s'`" | tee "${1}-$(echo $2 | sed 's/\//-/')-cassandra.head"
    echo "cassandra-test.sh (${1} ${2}) cassandra-builds: `git -C ../cassandra-builds log -1 --pretty=format:'%h %an %ad %s'`" | tee -a "${1}-$(echo $2 | sed 's/\//-/')-cassandra.head"
    bash ../cassandra-builds/build-scripts/cassandra-test.sh "$@"
    find build/test/logs -type f -name "*.log" | xargs xz -qq
else
    # start the docker container
    if [ "$#" -lt 5 ]; then
       echo "Usage: cassandra-test-docker.sh REPO BRANCH BUILDS_REPO_URL BUILDS_BRANCH DOCKER_IMAGE [target] [split_chunk]"
       exit 1
    fi
    BUILDSREPO=$3
    BUILDSBRANCH=$4
    DOCKER_IMAGE=$5
    TARGET=$6
    SPLIT_CHUNK=$7
    cat > env.list <<EOF
REPO=$1
BRANCH=$2
EOF

    echo "cassandra-test-docker.sh: running: git clone --single-branch --depth 1 --branch $BUILDSBRANCH $BUILDSREPO; sh ./cassandra-builds/build-scripts/cassandra-test-docker.sh $TARGET $SPLIT_CHUNK"
    ID=$(docker run -m 15g --memory-swap 15g --env-file env.list -dt $DOCKER_IMAGE dumb-init bash -ilc "git clone --single-branch --depth 1 --branch $BUILDSBRANCH $BUILDSREPO; sh ./cassandra-builds/build-scripts/cassandra-test-docker.sh $TARGET $SPLIT_CHUNK")

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
        # test meta
        docker cp "$ID:/home/cassandra/cassandra/${TARGET}-$(echo $SPLIT_CHUNK | sed 's/\//-/')-cassandra.head" .
        # test results
        mkdir -p build/test
        docker cp $ID:/home/cassandra/cassandra/build/test/output/. build/test/output
        # test logs
        docker cp $ID:/home/cassandra/cassandra/build/test/logs/. build/test/logs
    fi

    docker rm $ID
fi
