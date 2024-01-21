#!/bin/bash

# merge all the unit test xml files into one TESTS-TestSuites.xml file (which will get archived at nightlies.a.o)
#  set java heap max to known jenkins executor available memory
ANT_OPTS="-Xmx15G ${ANT_OPTS}" ant -quiet -silent -f ./cassandra-builds/build-scripts/cassandra-test-report.xml || ( echo "WARN failed to unify test results" && touch TESTS-TestSuites.xml )
