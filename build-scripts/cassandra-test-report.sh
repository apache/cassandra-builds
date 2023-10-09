#!/bin/bash

# merge all the unit test xml files into one TESTS-TestSuites.xml file (which will get archived at nightlies.a.o)
ant -quiet -silent -f ./cassandra-builds/build-scripts/cassandra-test-report.xml || ( echo "WARN failed to unify test results" && touch TESTS-TestSuites.xml )
