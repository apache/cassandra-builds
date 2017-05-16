#!/bin/bash -xe

CASSANDRA_BUILDS_DIR="${WORKSPACE}/cassandra-builds"
CASSANDRA_GIT_URL=$1
CASSANDRA_BRANCH=$2
CASSANDRA_VERSION=$3

# Create build images containing the build tool-chain, Java and an Apache Cassandra git working directory
docker build --build-arg CASSANDRA_GIT_URL=$CASSANDRA_GIT_URL  -f ${CASSANDRA_BUILDS_DIR}/docker/centos7-image.docker ${CASSANDRA_BUILDS_DIR}/docker/

# Create target directory for packages generated in docker run below
mkdir -p ${CASSANDRA_BUILDS_DIR}/dist
chmod 777 ${CASSANDRA_BUILDS_DIR}/dist

# Run build script through docker (specify branch, e.g. cassandra-3.0 and version, e.g. 3.0.11):
docker run --rm -v ${CASSANDRA_BUILDS_DIR}/dist:/dist `docker images -f label=org.cassandra.buildenv=centos -q | awk 'NR==1'` /home/build/build-rpms.sh $CASSANDRA_BRANCH $CASSANDRA_VERSION

