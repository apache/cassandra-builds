#!/bin/bash -x

# merge all the unit test xml files into one TESTS-TestSuites.xml file (which will get archived at nightlies.a.o)
ant -f ./cassandra-builds/build-scripts/cassandra-test-report.xml
