#!/bin/bash -x

################################
#
# Prep
#
################################

export PYTHONIOENCODING="utf-8"
export PYTHONUNBUFFERED=true
export CCM_MAX_HEAP_SIZE="2048M"
export CCM_HEAP_NEWSIZE="200M"
export NUM_TOKENS="32"
export CASSANDRA_DIR=${WORKSPACE}

# Loop to prevent failure due to maven-ant-tasks not downloading a jar..
for x in $(seq 1 3); do
    ant clean jar
    RETURN="$?"
    if [ "${RETURN}" -eq "0" ]; then
        break
    fi
done
# Exit, if we didn't build successfully
if [ "${RETURN}" -ne "0" ]; then
    echo "Build failed with exit code: ${RETURN}"
    exit ${RETURN}
fi

################################
#
# Main
#
################################

if [ "$cython" = "yes" ]; then
    virtualenv --python=python2 --no-site-packages venv
    source venv/bin/activate
    pip install "Cython>=0.20,<0.25"
    pip freeze
    cd pylib/; python setup.py build_ext --inplace
    cd ${WORKSPACE}
fi

ccm create test -n 1
ccm updateconf "enable_user_defined_functions: true"

version_from_build=$(ccm node1 versionfrombuild)
export pre_or_post_cdc=$(python -c """from distutils.version import LooseVersion
print \"postcdc\" if LooseVersion(\"${version_from_build}\") >= \"3.8\" else \"precdc\"
""")
case "${pre_or_post_cdc}" in
    postcdc)
        ccm updateconf "cdc_enabled: true"
        ;;
    precdc)
        :
        ;;
    *)
        echo "${pre_or_post_cdc}" is an invalid value.
        exit 1
        ;;
esac

ccm start --wait-for-binary-proto

cd pylib/cqlshlib/
cat << 'EOF' > setup.cfg
[nosetests]
verbosity=3
detailed-errors=1
with-xunit=1
EOF

nosetests

ccm remove
mv nosetests.xml ${WORKSPACE}/cqlshlib.xml
if [ "$cython" = "yes" ]; then
    deactivate  # venv
fi
cd ${WORKSPACE}


# run dtest cqlsh suite
cd cassandra-dtest/
if [ "$cython" = "no" ]; then
    export CASS_DRIVER_NO_EXTENSIONS=true
    export CASS_DRIVER_NO_CYTHON=true
fi
virtualenv --python=python2 --no-site-packages venv
source venv/bin/activate
pip install -r requirements.txt
pip freeze

nosetests --verbosity=3 --with-xunit --nocapture cqlsh_tests/

mv nosetests.xml ${WORKSPACE}/
deactivate  # venv
