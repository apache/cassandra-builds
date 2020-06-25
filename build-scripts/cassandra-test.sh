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

_list_distributed_tests_no_upgrade() {
  _list_tests "distributed" | grep -v "upgrade"
}

_timeout_for() {
  grep "name=\"$1\"" build.xml | awk -F'"' '{print $4}'
}

_main() {
  local target="${1:-}"
  local java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F. '{print $1}')
  if [ "$java_version" -ge 11 ]; then
    export CASSANDRA_USE_JDK11=true
  fi

  ant clean jar
  mkdir -p tmp

  case $target in
    "stress-test" | "fqltool-test")
      ant -DforceJenkinsListenAddress=true $target -Dtmp.dir="$(pwd)/tmp" || echo "failed $target"
      ;;
    "test")
      ant -DforceJenkinsListenAddress=true testclasslist -Dtest.classlistfile=<( _list_tests "unit" ) -Dtmp.dir="$(pwd)/tmp" || echo "failed $target"
      ;;
    "test-cdc")
      ant -DforceJenkinsListenAddress=true testclasslist-cdc -Dtest.classlistfile=<( _list_tests "unit" ) -Dtmp.dir="$(pwd)/tmp" || echo "failed $target"
      ;;
    "test-compression")
      ant -DforceJenkinsListenAddress=true testclasslist-compression -Dtest.classlistfile=<( _list_tests "unit" ) -Dtmp.dir="$(pwd)/tmp" || echo "failed $target"
      ;;
    "test-burn")
      ant -DforceJenkinsListenAddress=true testclasslist -Dtest.classlistprefix=burn -Dtest.timeout=$(_timeout_for "test.burn.timeout") -Dtest.classlistfile=<( _list_tests "burn" ) -Dtmp.dir="$(pwd)/tmp" || echo "failed $target"
      ;;
    "long-test")
      ant -DforceJenkinsListenAddress=true testclasslist -Dtest.classlistprefix=long -Dtest.timeout=$(_timeout_for "test.long.timeout") -Dtest.classlistfile=<( _list_tests "long" ) -Dtmp.dir="$(pwd)/tmp" || echo "failed $target"
      ;;
    "jvm-dtest")
      ant -DforceJenkinsListenAddress=true testclasslist -Dtest.classlistprefix=distributed -Dtest.timeout=$(_timeout_for "test.distributed.timeout") -Dtest.classlistfile=<( _list_distributed_tests_no_upgrade ) -Dtmp.dir="$(pwd)/tmp" || echo "failed $target"
      ;;
    *)
      echo "unregconised \"$target\""
      exit 1
      ;;
  esac
}

_main "$@"
