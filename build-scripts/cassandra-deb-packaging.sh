#!/bin/bash -xe
#
# Builds (inside docker) the rpm packages for the provided git sha
#
# Called from build-scripts/cassandra-artifacts.sh or cassandra-release/prepare_release.sh

if [ "$#" -lt 1 ]; then
   echo "$0 <branch|tag|sha> <java version>"
   echo "if Java version is not set, it is set to 8 by default, choose from 8 or 11"
   exit 1
fi

sha=$1
java_version=$2

# required arguments
[ "x${sha}" != "x" ] || { echo >&2 "Missing argument <branch|tag|sha>"; exit 1; }

# variables, with defaults
[ "x${deb_dir}" != "x" ] || deb_dir="`pwd`"
[ "x${cassandra_builds_dir}" != "x" ] || cassandra_builds_dir="`pwd`"
[ "x${CASSANDRA_GIT_URL}" != "x" ] || CASSANDRA_GIT_URL="https://gitbox.apache.org/repos/asf/cassandra.git"
[ "x${java_version}" != "x" ] || java_version="8"

# pre-conditions
command -v docker >/dev/null 2>&1 || { echo >&2 "docker needs to be installed"; exit 1; }
(docker info >/dev/null 2>&1) || { echo >&2 "docker needs to running"; exit 1; }
[ -d "${cassandra_builds_dir}" ] || { echo >&2 "cassandra-builds directory must exist"; exit 1; }
[ -f "${cassandra_builds_dir}/docker/buster-image.docker" ] || { echo >&2 "docker/buster-image.docker must exist"; exit 1; }
[ -f "${cassandra_builds_dir}/docker/build-debs.sh" ] || { echo >&2 "docker/build-debs.sh must exist"; exit 1; }

# remove any previous older built images
docker image prune -f --filter label=org.cassandra.buildenv=buster --filter "until=4h"

pushd $cassandra_builds_dir

# Create build images containing the build tool-chain, Java and an Apache Cassandra git working directory
docker build --build-arg CASSANDRA_GIT_URL=$CASSANDRA_GIT_URL -t cassandra-artifacts-buster:${sha} -f docker/buster-image.docker docker/

# Run build script through docker (specify branch, tag, or sha)
chmod 777 "${deb_dir}"
docker run --rm -v "${deb_dir}":/dist cassandra-artifacts-buster:${sha} /home/build/build-debs.sh ${sha} ${java_version}

popd
