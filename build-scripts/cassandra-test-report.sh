#!/bin/bash -x

# merge all the unit test xml files into one TESTS-TestSuites.xml file
ant -f ./cassandra-builds/build-scripts/cassandra-test-report.xml

# perform the xslt and plaintext transformation inside a docker container
docker build --tag apache_cassandra_ci/generate_plaintext_test_report -f cassandra-builds/docker/jenkins/generate_plaintext_test_report.docker .
docker run --rm -v `pwd`:/tmp apache_cassandra_ci/generate_plaintext_test_report > cassandra-test-report.txt
