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

_list_tests_no_upgrade() {
 _list_tests "distributed" | grep -v "upgrade"
}

_main() {
  local java_version
  java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F. '{print $1}')
  if [ "$java_version" -ge 11 ]; then
    export CASSANDRA_USE_JDK11=true
  fi

  local test_timeout
  test_timeout=$(grep 'name="test.distributed.timeout"' build.xml | awk -F'"' '{print $4}')

  ant testclasslist -Dtest.timeout="$test_timeout" -Dtest.classlistfile=<( _list_tests_no_upgrade ) -Dtest.classlistprefix=distributed
}

_main "$@"
