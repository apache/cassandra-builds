#!/bin/sh
DOCKER_IMAGE="kjellman/cassandra-test:0.4.4"
BUILDSREPO=$5
BUILDSBRANCH=$6
cat > env.list <<EOF
REPO=$1
BRANCH=$2
DTEST_REPO=$3
DTEST_BRANCH=$4
EOF
echo "jenkinscommand.sh: running: git clone --branch $BUILDSBRANCH $BUILDSREPO; sh ./cassandra-builds/docker/jenkins/dtest.sh $7"
ID=$(docker run --env-file env.list -dt $DOCKER_IMAGE dumb-init bash -ilc "git clone --branch $BUILDSBRANCH $BUILDSREPO; sh ./cassandra-builds/docker/jenkins/dtest.sh $7")
# use docker attach instead of docker wait to get output
docker attach --no-stdin $ID
echo "$ID done, copying files"
docker cp $ID:/home/cassandra/cassandra/cassandra-dtest/nosetests.xml .
docker cp $ID:/home/cassandra/cassandra/test_stdout.txt .
docker rm $ID
