#!/bin/sh
export WORKSPACE=/home/cassandra/cassandra
export LANG=en_US.UTF-8
export PYTHONIOENCODING=utf-8
export PYTHONUNBUFFERED=true
git clone --depth=1 --branch=$BRANCH https://github.com/$REPO/cassandra.git
cd cassandra
git clone --branch=$DTEST_BRANCH $DTEST_REPO
../cassandra-builds/build-scripts/cassandra-dtest-pytest.sh
