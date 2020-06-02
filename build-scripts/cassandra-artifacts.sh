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


# Sphinx is needed for the gen-doc target
virtualenv venv
source venv/bin/activate
# setuptools 45.0.0 requires python 3.5+
pip install "setuptools<45" Sphinx sphinx_rtd_theme

################################
#
# Main
#
################################

# Loop to prevent failure due to maven-ant-tasks not downloading a jar..
set +e # disable immediate exit from this point
for x in $(seq 1 3); do
    ant clean artifacts
    RETURN="$?"
    if [ "${RETURN}" -eq "0" ]; then
        # Run eclipse-warnings if build was successful
        ant eclipse-warnings
        RETURN="$?"
        if [ "${RETURN}" -eq "0" ]; then
            set -e
            # build debian and rpm packages
            head_commit=`git log --pretty=oneline -1 | cut -d " " -f 1`
            declare -x cassandra_builds_dir="${cassandra_builds_dir}"
            declare -x CASSANDRA_GIT_URL="`git remote get-url origin`"
            # debian
            deb_dir="`pwd`/build" ${cassandra_builds_dir}/build-scripts/cassandra-deb-packaging.sh ${head_commit}
            # rpm
            rpm_dir="`pwd`/build" ${cassandra_builds_dir}/build-scripts/cassandra-rpm-packaging.sh ${head_commit}
        fi
        break
    fi
done

################################
#
# Clean
#
################################

# /virtualenv
deactivate

exit "${RETURN}"
