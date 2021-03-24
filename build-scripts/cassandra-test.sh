#!/usr/bin/env bash

set -o xtrace
set -o errexit
set -o pipefail
set -o nounset

# lists all tests for the specific test type
_list_tests() {
  local readonly classlistprefix="$1"
  find "test/$classlistprefix" -name '*Test.java' | sed "s;^test/$classlistprefix/;;g"
}

_timeout_for() {
  grep "name=\"$1\"" build.xml | awk -F'"' '{print $4}'
}

_build_all_dtest_jars() {
    cd $TMP_DIR
    git clone --depth 1 --no-single-branch https://gitbox.apache.org/repos/asf/cassandra.git cassandra-dtest-jars
    cd cassandra-dtest-jars
    for branch in cassandra-2.2 cassandra-3.0 cassandra-3.11 trunk; do
        git checkout $branch
        ant realclean
        ant jar dtest-jar
        cp build/dtest*.jar ../../build/
    done
    cd ../..
    rm -fR ${TMP_DIR}/cassandra-dtest-jars
    ant dtest-jar
    ls -l build/dtest*.jar
}

_main() {
  local target="${1:-}"
  local java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F. '{print $1}')
  local version=$(grep 'property\s*name=\"base.version\"' build.xml |sed -ne 's/.*value=\"\([^"]*\)\".*/\1/p')
  if [ "$java_version" -ge 11 ]; then
    export CASSANDRA_USE_JDK11=true
    if ! grep -q CASSANDRA_USE_JDK11 build.xml ; then
        echo "Skipping ${target}. JDK11 not supported against ${version}"
        exit 0
    elif [[ "${target}" == "jvm-dtest-upgrade" ]] ; then
        echo "Skipping JDK11 execution. Mixed JDK compilation required for ${target}"
        exit 0
    fi
  fi

  # check test target exists in code
  case $target in
    "stress-test" | "fqltool-test")
      ant -projecthelp | grep -q " $target " || { echo "Skipping ${target}. It does not exist in ${version}"; exit 0; }
      ;;
    "test-cdc")
      regx_version="(2.2|3.0).([0-9]+)$"
      ! [[ $version =~ $regx_version ]] || { echo "Skipping ${target}. It does not exist in ${version}"; exit 0; }
      ;;
    *)
      ;;
  esac

  export TMP_DIR="$(pwd)/tmp"
  mkdir -p ${TMP_DIR}
  ant clean jar

  case $target in
    "stress-test")
      # hard fail on test compilation, put dont fail the test run as unstable test reports are processed
      ant stress-build-test
      ant $target -Dtmp.dir="$(pwd)/tmp" || echo "failed $target"
      ;;
    "fqltool-test")
      # hard fail on test compilation, put dont fail the test run so unstable test reports are processed
      ant fqltool-build-test
      ant $target -Dtmp.dir="$(pwd)/tmp" || echo "failed $target"
      ;;
    "microbench")
      ant $target -Dtmp.dir="$(pwd)/tmp" -Dmaven.test.failure.ignore=true
      ;;
    "test")
      ant testclasslist -Dtest.classlistfile=<( _list_tests "unit" ) -Dtmp.dir="${TMP_DIR}" -Dtest.runners=1 || echo "failed $target"
      ;;
    "test-cdc")
      ant testclasslist-cdc -Dtest.classlistfile=<( _list_tests "unit" ) -Dtmp.dir="${TMP_DIR}" -Dtest.runners=1 || echo "failed $target"
      ;;
    "test-compression")
      ant testclasslist-compression -Dtest.classlistfile=<( _list_tests "unit" ) -Dtmp.dir="${TMP_DIR}" -Dtest.runners=1 || echo "failed $target"
      ;;
    "test-burn")
      ant testclasslist -Dtest.classlistprefix=burn -Dtest.timeout=$(_timeout_for "test.burn.timeout") -Dtest.classlistfile=<( _list_tests "burn" ) -Dtmp.dir="${TMP_DIR}" -Dtest.runners=1 || echo "failed $target"
      ;;
    "long-test")
      ant testclasslist -Dtest.classlistprefix=long -Dtest.timeout=$(_timeout_for "test.long.timeout") -Dtest.classlistfile=<( _list_tests "long" ) -Dtmp.dir="${TMP_DIR}" -Dtest.runners=1 || echo "failed $target"
      ;;
    "jvm-dtest")
      ant testclasslist -Dtest.classlistprefix=distributed -Dtest.timeout=$(_timeout_for "test.distributed.timeout") -Dtest.classlistfile=<( _list_tests "distributed" | grep -v "upgrade" ) -Dtmp.dir="${TMP_DIR}" -Dtest.runners=1 || echo "failed $target"
      ;;
    "jvm-dtest-upgrade")
      _build_all_dtest_jars
      ant testclasslist -Dtest.classlistprefix=distributed -Dtest.timeout=$(_timeout_for "test.distributed.timeout") -Dtest.classlistfile=<( _list_tests "distributed" | grep "upgrade" ) -Dtmp.dir="${TMP_DIR}" -Dtest.runners=1 || echo "failed $target"
      ;;
    *)
      echo "unregconised \"$target\""
      exit 1
      ;;
  esac
}

_main "$@"
