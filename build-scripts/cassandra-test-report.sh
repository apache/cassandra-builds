#!/bin/bash -x

################################
#
# Prep
#
################################

# TODO move this script into a docker image so these tools are available
#sudo apt install -y html2text libsaxonb-java

################################
#
# Main
#
################################

set +e # disable immediate exit from this point

# merge all the unit test xml files into one TESTS-TestSuites.xml file
ant -f ./cassandra-builds/build-scripts/cassandra-test-report.xml

# xslt transform, convert to plaintext, and truncate (ASF ML limit is 1MB), to the cassandra-test-report.txt file

# uncomment once these tools are available inside a docker container
#saxonb-xslt -s:TESTS-TestSuites.xml -xsl:./cassandra-builds/build-scripts/cassandra-test-report.xsl | html2text -nobs -style pretty | head -c 900KB > cassandra-test-report.txt
