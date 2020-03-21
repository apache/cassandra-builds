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

  case $target in
    "stress-test" | "fqltool-test")
      ant $target || echo "failed $target"
      ;;
    "test")
      ant testclasslist -Dtest.classlistfile=<( _list_tests "unit" ) || echo "failed $target"
      ;;
    "test-cdc")
      ant testclasslist-cdc -Dtest.classlistfile=<( _list_tests "unit" ) || echo "failed $target"
      ;;
    "test-compression")
      ant testclasslist-compression -Dtest.classlistfile=<( _list_tests "unit" ) || echo "failed $target"
      ;;
    "test-burn")
      ant testclasslist -Dtest.timeout=$(_timeout_for "test.burn.timeout") -Dtest.classlistfile=<( _list_tests "burn" ) || echo "failed $target"
      ;;
    "long-test")
      ant testclasslist -Dtest.timeout=$(_timeout_for "test.long.timeout") -Dtest.classlistfile=<( _list_tests "long" ) || echo "failed $target"
      ;;
    "test-jvm-dtest-forking")
      ant testclasslist -Dtest.timeout=$(_timeout_for "test.distributed.timeout") -Dtest.classlistfile=<( _list_distributed_tests_no_upgrade ) -Dtest.classlistprefix=distributed || echo "failed $target"
      ;;
    *)
      echo "unregconised \"$target\""
      exit 1
      ;;
  esac
}

_main "$@"
