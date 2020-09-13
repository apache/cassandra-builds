#!/bin/sh
export WORKSPACE=/home/cassandra/cassandra
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export PYTHONIOENCODING=utf-8
export PYTHONUNBUFFERED=true
echo "dtest.sh: running: git clone --depth 1 --single-branch --branch=$BRANCH https://github.com/$REPO/cassandra.git"
git clone --depth 1 --single-branch --branch=$BRANCH https://github.com/$REPO/cassandra.git
cd cassandra
echo git clone --depth 1 --single-branch --branch=$DTEST_BRANCH $DTEST_REPO
git clone --depth 1 --single-branch --branch=$DTEST_BRANCH $DTEST_REPO
echo "dtest.sh (${1} ${2}) cassandra: `git log -1 --pretty=format:'%h %an %ad %s'`" | tee "${1}-$(echo $2 | sed 's/\//-/')-cassandra.head"
echo "dtest.sh (${1} ${2}) cassandra-dtest: `git -C cassandra-dtest log -1 --pretty=format:'%h %an %ad %s'`" | tee -a "${1}-$(echo $2 | sed 's/\//-/')-cassandra.head"
echo "dtest.sh (${1} ${2}) cassandra-builds: `git -C ../cassandra-builds log -1 --pretty=format:'%h %an %ad %s'`" | tee -a "${1}-$(echo $2 | sed 's/\//-/')-cassandra.head"
../cassandra-builds/build-scripts/cassandra-dtest-pytest.sh "$@"
