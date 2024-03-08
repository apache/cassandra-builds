#!/bin/bash -xe
#
# Builds (inside docker) the rpm packages for the provided git sha
#
# Called from build-scripts/cassandra-artifacts.sh or cassandra-release/prepare_release.sh

if [ "$#" -lt 1 ]; then
   echo "$0 <branch|tag|sha> <java version>"
   echo "if Java version is not set, it is set to 8 by default, choose from 8 or 11 or 17"
   exit 1
fi

sha=$1
java_version=$2

# required arguments
[ "x${sha}" != "x" ] || { echo >&2 "Missing argument <branch|tag|sha>"; exit 1; }

# variables, with defaults
[ "x${deb_dir}" != "x" ] || deb_dir="`pwd`"
[ "x${cassandra_builds_dir}" != "x" ] || cassandra_builds_dir="`pwd`"
[ "x${CASSANDRA_GIT_URL}" != "x" ] || CASSANDRA_GIT_URL="https://github.com/apache/cassandra.git"
[ "x${java_version}" != "x" ] || java_version="8"

# pre-conditions
command -v docker >/dev/null 2>&1 || { echo >&2 "docker needs to be installed"; exit 1; }
(docker info >/dev/null 2>&1) || { echo >&2 "docker needs to running"; exit 1; }
[ -d "${cassandra_builds_dir}" ] || { echo >&2 "cassandra-builds directory must exist"; exit 1; }
[ -f "${cassandra_builds_dir}/docker/bullseye-image.docker" ] || { echo >&2 "docker/bullseye-image.docker must exist"; exit 1; }
[ -f "${cassandra_builds_dir}/docker/build-debs.sh" ] || { echo >&2 "docker/build-debs.sh must exist"; exit 1; }

# remove any previous older built images
docker image prune --all --force --filter label=org.cassandra.buildenv=bullseye --filter "until=4h" || true

pushd $cassandra_builds_dir

# Create build images containing the build tool-chain, Java and an Apache Cassandra git working directory, with retry
until docker build --build-arg CASSANDRA_GIT_URL=$CASSANDRA_GIT_URL --build-arg UID_ARG=`id -u` --build-arg GID_ARG=`id -g` -t cassandra-artifacts-bullseye:${sha} -f docker/bullseye-image.docker docker/  ; do echo "docker build failed… trying again in 10s… " ; sleep 10 ; done


# Run build script through docker (specify branch, tag, or sha)
mkdir -p ~/.m2/repository
docker run --rm -v "${deb_dir}":/dist -v ~/.m2/repository/:/home/build/.m2/repository/ cassandra-artifacts-bullseye:${sha} /home/build/build-debs.sh ${sha} ${java_version}

popd
