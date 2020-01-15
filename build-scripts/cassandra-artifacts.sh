#!/bin/bash -xe

################################
#
# Prep
#
################################

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
