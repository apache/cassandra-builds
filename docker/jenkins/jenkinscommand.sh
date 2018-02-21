#!/bin/sh
cat > env.list <<EOF
REPO=$REPO
BRANCH=$BRANCH
DTEST_REPO=$DTEST_REPO
DTEST_BRANCH=$DTEST_BRANCH
EOF
ID=$(docker run --env-file env.list -dt kjellman/cassandra-test:0.4.3 bash -ilc "git clone --depth=1 --branch dock https://github.com/krummas/cassandra-builds.git; sh ./cassandra-builds/docker/jenkins/dtest.sh")
# use docker attach instead of docker wait to get output
docker attach --no-stdin $ID
echo "$ID done, copying files"
docker cp $ID:/home/cassandra/cassandra/cassandra-dtest/nosetests.xml .
docker cp $ID:/home/cassandra/cassandra/test_stdout.txt .
