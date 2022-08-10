#!/bin/bash -xe

################################
#
# Prep
#
################################

# variables, with defaults
[ "x${cassandra_builds_dir}" != "x" ] || cassandra_builds_dir="cassandra-builds"

# pre-conditions
command -v ant >/dev/null 2>&1 || { echo >&2 "ant needs to be installed"; exit 1; }
command -v pip >/dev/null 2>&1 || { echo >&2 "pip needs to be installed"; exit 1; }
command -v virtualenv >/dev/null 2>&1 || { echo >&2 "virtualenv needs to be installed"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo >&2 "docker needs to be installed"; exit 1; }
(docker info >/dev/null 2>&1) || { echo >&2 "docker needs to running"; exit 1; }
[ -f "build.xml" ] || { echo >&2 "build.xml must exist"; exit 1; }
[ -d "${cassandra_builds_dir}" ] || { echo >&2 "cassandra-builds directory must exist"; exit 1; }

# print debug information on versions
ant -version
pip --version
virtualenv --version
docker --version

# Sphinx is needed for the gen-doc target
virtualenv venv
source venv/bin/activate
# setuptools 45.0.0 requires python 3.5+
python -m pip install "setuptools<45" Sphinx sphinx_rtd_theme

################################
#
# Main
#
################################

# Setup JDK
java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F. '{print $1}')
if [ "$java_version" -ge 11 ]; then
    java_version="11"
    export CASSANDRA_USE_JDK11=true
    if ! grep -q CASSANDRA_USE_JDK11 build.xml ; then
        echo "Skipping build. JDK11 not supported against $(grep 'property\s*name=\"base.version\"' build.xml |sed -ne 's/.*value=\"\([^"]*\)\".*/\1/p')"
        exit 0
    fi
else
    java_version="8"
fi

# Loop to prevent failure due to maven-ant-tasks not downloading a jar..
set +e # disable immediate exit from this point

ARTIFACTS_BUILD_RUN=0
ECLIPSE_WARNINGS_RUN=0

#HAS_DEPENDENCY_CHECK_TARGET=$(ant -p build.xml | grep "dependency-check " | wc -l)
HAS_DEPENDENCY_CHECK_TARGET=0
# versions starting from 6.4.1 contain "rate limiter" functionality to make builds more stable
# https://github.com/jeremylong/DependencyCheck/pull/3725
DEPENDENCY_CHECK_VERSION=6.4.1

for x in $(seq 1 3); do
    if [ "${ARTIFACTS_BUILD_RUN}" -eq "0" ]; then
      ant clean artifacts
      RETURN="$?"
    fi
    if [ "${RETURN}" -eq "0" ]; then
        ARTIFACTS_BUILD_RUN=1
        if [ "${ECLIPSE_WARNINGS_RUN}" -eq "0" ]; then
          # Run eclipse-warnings if build was successful
          ant eclipse-warnings
          RETURN="$?"
        fi
        if [ "${RETURN}" -eq "0" ]; then
            ECLIPSE_WARNINGS_RUN=1
            if [ "${HAS_DEPENDENCY_CHECK_TARGET}" -eq "1" ]; then
                ant -Ddependency-check.version=${DEPENDENCY_CHECK_VERSION} -Ddependency-check.home=/tmp/dependency-check-${DEPENDENCY_CHECK_VERSION} dependency-check
                RETURN="$?"
            else
                RETURN="0"
            fi
            if [ ! "${RETURN}" -eq "0" ]; then
                if [ -f /tmp/dependency-check-${DEPENDENCY_CHECK_VERSION}/dependency-check-ant/dependency-check-ant.jar ]; then
                    # Break the build here only in case dep zip was downloaded (hence JAR was extracted) just fine
                    # but the check itself has failed. If JAR does not exist, it is probably
                    # because the network was down so the ant target did not download the zip in the first place.
                    echo "Failing the build on OWASP dependency check. Run 'ant dependency-check' locally and consult build/dependency-check-report.html to see the details."
                    break
                else
                    # sleep here to give the net the chance to resume after probable partition
                    sleep 10
                    continue
                fi
            fi
            set -e
            # build debian and rpm packages
            head_commit=`git log --pretty=oneline -1 | cut -d " " -f 1`
            declare -x cassandra_builds_dir="${cassandra_builds_dir}"
            declare -x CASSANDRA_GIT_URL="`git remote get-url origin`"

            mkdir -p "`pwd`/build/packages/deb"
            mkdir -p "`pwd`/build/packages/rpm"
            # debian
            deb_dir="`pwd`/build/packages/deb" ${cassandra_builds_dir}/build-scripts/cassandra-deb-packaging.sh ${head_commit} ${java_version}
            # rpm
            rpm_dir="`pwd`/build/packages/rpm" ${cassandra_builds_dir}/build-scripts/cassandra-rpm-packaging.sh ${head_commit} ${java_version}
            # rpm-noboolean
            if [ -d "`pwd`/redhat/noboolean" ]; then
                mkdir -p "`pwd`/build/packages/rpmnoboolean"
                rpm_dir="`pwd`/build/packages/rpmnoboolean" ${cassandra_builds_dir}/build-scripts/cassandra-rpm-packaging.sh ${head_commit} ${java_version} noboolean
            fi
        fi
        break
    fi
    # sleep here to give the net the chance to resume after probable partition
    sleep 10
done

################################
#
# Clean
#
################################

# /virtualenv
deactivate

exit "${RETURN}"
