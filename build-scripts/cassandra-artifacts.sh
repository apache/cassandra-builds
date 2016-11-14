#!/bin/bash -xe

################################
#
# Prep
#
################################

# Sphinx is needed for the gen-doc target
virtualenv venv
source venv/bin/activate
pip install Sphinx sphinx_rtd_theme

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
