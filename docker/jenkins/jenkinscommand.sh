#!/bin/sh
if [ "$#" -lt 7 ]; then
   echo "Usage: jenkinscommand.sh GITHUB_USER BRANCH DTEST_REPO_URL DTEST_BRANCH BUILDS_REPO_URL BUILDS_BRANCH DOCKER_IMAGE [target]"
   exit 1
fi
BUILDSREPO=$5
BUILDSBRANCH=$6
DOCKER_IMAGE=$7
TARGET=$8
cat > env.list <<EOF
REPO=$1
BRANCH=$2
DTEST_REPO=$3
DTEST_BRANCH=$4
EOF

echo "jenkinscommand.sh: running: git clone --branch $BUILDSBRANCH $BUILDSREPO; sh ./cassandra-builds/docker/jenkins/dtest.sh $TARGET"
ID=$(docker run --env-file env.list -dt $DOCKER_IMAGE dumb-init bash -ilc "git clone --branch $BUILDSBRANCH $BUILDSREPO; sh ./cassandra-builds/docker/jenkins/dtest.sh $TARGET")

# use docker attach instead of docker wait to get output
docker attach --no-stdin $ID
status="$?"
echo "$ID done (${status}), copying files"

if [ "$status" -ne 0 ] ; then
    docker ps -a
    docker info
fi

# pytest results
docker cp $ID:/home/cassandra/cassandra/cassandra-dtest/nosetests.xml .
# pytest logs
docker cp $ID:/home/cassandra/cassandra/test_stdout.txt .
docker cp $ID:/home/cassandra/cassandra/cassandra-dtest/ccm_logs.tar.xz .

docker rm $ID
