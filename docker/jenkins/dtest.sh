#!/bin/sh
export WORKSPACE=/home/cassandra/cassandra
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export PYTHONIOENCODING=utf-8
export PYTHONUNBUFFERED=true
echo "dtest.sh: running: git clone --depth=1 --branch=$BRANCH https://github.com/$REPO/cassandra.git"
git clone --depth=1 --branch=$BRANCH https://github.com/$REPO/cassandra.git
cd cassandra
echo git clone --branch=$DTEST_BRANCH $DTEST_REPO
git clone --branch=$DTEST_BRANCH $DTEST_REPO
../cassandra-builds/build-scripts/cassandra-dtest-pytest.sh $1
