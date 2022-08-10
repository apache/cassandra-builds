#!/bin/bash -xe
#
# Builds (inside docker) the rpm packages for the provided git sha
#
# Called from build-scripts/cassandra-artifacts.sh or cassandra-release/prepare_release.sh

if [ "$#" -lt 1 ]; then
   echo "$0 <branch|tag|sha> <java version> [dist type]"
   echo "if Java version is not set, it is set to 8 by default, choose from 8 or 11"
   echo "dist types are [rpm, noboolean] and rpm is default"
   exit 1
fi

sha=$1
java_version=$2
rpm_dist=$3

# required arguments
[ "x${sha}" != "x" ] || { echo >&2 "Missing argument <branch|tag|sha>"; exit 1; }

# variables, with defaults
[ "x${rpm_dir}" != "x" ] || rpm_dir="`pwd`"
[ "x${cassandra_builds_dir}" != "x" ] || cassandra_builds_dir="`pwd`"
[ "x${CASSANDRA_GIT_URL}" != "x" ] || CASSANDRA_GIT_URL="https://gitbox.apache.org/repos/asf/cassandra.git"
[ "x${java_version}" != "x" ] || java_version="8"
[ "x${rpm_dist}" != "x" ] || rpm_dist="rpm"

if [ "${rpm_dist}" == "rpm" ]; then
    dist_name="almalinux"
else # noboolean
    dist_name="centos7"
fi

# pre-conditions
command -v docker >/dev/null 2>&1 || { echo >&2 "docker needs to be installed"; exit 1; }
(docker info >/dev/null 2>&1) || { echo >&2 "docker needs to running"; exit 1; }
[ -d "${cassandra_builds_dir}" ] || { echo >&2 "cassandra-builds directory must exist"; exit 1; }
[ -f "${cassandra_builds_dir}/docker/${dist_name}-image.docker" ] || { echo >&2 "docker/${dist_name}-image.docker must exist"; exit 1; }
[ -f "${cassandra_builds_dir}/docker/build-rpms.sh" ] || { echo >&2 "docker/build-rpms.sh must exist"; exit 1; }



# remove any previous older built images
docker image prune --all --force --filter label=org.cassandra.buildenv=${dist_name} --filter "until=4h" || true

pushd $cassandra_builds_dir

# Create build images containing the build tool-chain, Java and an Apache Cassandra git working directory
docker build --build-arg CASSANDRA_GIT_URL=$CASSANDRA_GIT_URL --build-arg UID_ARG=`id -u` --build-arg GID_ARG=`id -g` -t cassandra-artifacts-${dist_name}:${sha} -f docker/${dist_name}-image.docker docker/

# Run build script through docker (specify branch, tag, or sha)
docker run --rm -v "${rpm_dir}":/dist -v ~/.m2/repository/:/home/build/.m2/repository/ cassandra-artifacts-${dist_name}:${sha} /home/build/build-rpms.sh ${sha} ${java_version}

popd
