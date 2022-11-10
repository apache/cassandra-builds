#!/usr/bin/env bash

set -o xtrace
set -o errexit
set -o pipefail
set -o nounset

# pre-conditions
command -v ant >/dev/null 2>&1 || { echo >&2 "ant needs to be installed"; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "git needs to be installed"; exit 1; }
[ -f "build.xml" ] || { echo >&2 "build.xml must exist"; exit 1; }

# print debug information on versions
ant -version
git --version

# lists all tests for the specific test type
_list_tests() {
  local -r classlistprefix="$1"
  find "test/$classlistprefix" -name '*Test.java' | sed "s;^test/$classlistprefix/;;g" | sort
}

_split_tests() {
  local -r split_chunk="$1"
  if [[ "x" == "x${split_chunk}" ]] ; then
    split -n r/1/1
  else
    split -n r/${split_chunk}
  fi
}

_timeout_for() {
  grep "name=\"$1\"" build.xml | awk -F'"' '{print $4}'
}

_build_all_dtest_jars() {
    mkdir -p build
    cd $TMP_DIR
    until git clone --quiet --depth 1 --no-single-branch https://github.com/apache/cassandra.git cassandra-dtest-jars ; do echo "git clone failed… trying again… " ; done
    cd cassandra-dtest-jars
    for branch in cassandra-2.2 cassandra-3.0 cassandra-3.11 cassandra-4.0 cassandra-4.1 trunk; do
        git checkout $branch
        ant realclean
        ant jar dtest-jar
        cp build/dtest*.jar ../../build/
    done
    cd ../..
    rm -fR ${TMP_DIR}/cassandra-dtest-jars
    ant clean dtest-jar
    ls -l build/dtest*.jar
}

_run_testlist() {
    local _target_prefix=$1
    local _testlist_target=$2
    local _split_chunk=$3
    local _test_timeout=$4
    testlist="$( _list_tests "${_target_prefix}" | _split_tests "${_split_chunk}")"
    if [[ -z "$testlist" ]]; then
      # something has to run in the split to generate a junit xml result
      echo Hacking ${_target_prefix} ${_testlist_target} to run only first test found as no tests in split ${_split_chunk} were found
      testlist="$( _list_tests "${_target_prefix}" | head -n1)"
    fi
    ant clean jar
    ant $_testlist_target -Dtest.classlistprefix="${_target_prefix}" -Dtest.classlistfile=<(echo "${testlist}") -Dtest.timeout="${_test_timeout}" -Dtmp.dir="${TMP_DIR}" || echo "failed ${_target_prefix} ${_testlist_target}"
}

_main() {
  # parameters
  local -r target="${1:-}"
  local -r split_chunk="${2:-}" # Optional: pass in chunk to test, formatted as "K/N" for the Kth chunk of N chunks

  local -r java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F. '{print $1}')
  local -r version=$(grep 'property\s*name=\"base.version\"' build.xml |sed -ne 's/.*value=\"\([^"]*\)\".*/\1/p')

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
    "cqlsh-test")
      [[ -f "./pylib/cassandra-cqlsh-tests.sh" ]] || { echo "Skipping ${target}. It does not exist in ${version}"; exit 0; }
      ;;
    *)
      ;;
  esac

  export TMP_DIR="$(pwd)/tmp"
  mkdir -p ${TMP_DIR}

  case $target in
    "stress-test")
      # hard fail on test compilation, but dont fail the test run as unstable test reports are processed
      ant clean jar stress-build-test
      ant $target -Dtmp.dir="$(pwd)/tmp" || echo "failed $target"
      ;;
    "fqltool-test")
      # hard fail on test compilation, but dont fail the test run so unstable test reports are processed
      ant clean jar fqltool-build-test
      ant $target -Dtmp.dir="$(pwd)/tmp" || echo "failed $target"
      ;;
    "microbench")
      ant clean $target -Dtmp.dir="$(pwd)/tmp" -Dmaven.test.failure.ignore=true
      ;;
    "test")
      _run_testlist "unit" "testclasslist" "${split_chunk}" "$(_timeout_for 'test.timeout')"
      ;;
    "test-cdc")
      _run_testlist "unit" "testclasslist-cdc" "${split_chunk}" "$(_timeout_for 'test.timeout')"
      ;;
    "test-compression")
      _run_testlist "unit" "testclasslist-compression" "${split_chunk}" "$(_timeout_for 'test.timeout')"
      ;;
    "test-burn")
      _run_testlist "burn" "testclasslist" "${split_chunk}" "$(_timeout_for 'test.burn.timeout')"
      ;;
    "long-test")
      _run_testlist "long" "testclasslist" "${split_chunk}" "$(_timeout_for 'test.long.timeout')"
      ;;
    "jvm-dtest")
      ant clean jar
      testlist=$( _list_tests "distributed" | grep -v "upgrade" | _split_tests "${split_chunk}")
      if [[ -z "$testlist" ]]; then
          # something has to run in the split to generate a junit xml result
          echo Hacking jvm-dtest to run only first test found as no tests in split ${split_chunk} were found
          testlist="$( _list_tests "distributed"  | grep -v "upgrade" | head -n1)"
      fi
      ant testclasslist -Dtest.classlistprefix=distributed -Dtest.timeout=$(_timeout_for "test.distributed.timeout") -Dtest.classlistfile=<(echo "${testlist}") -Dtmp.dir="${TMP_DIR}" || echo "failed $target"
      ;;
    "jvm-dtest-upgrade")
      _build_all_dtest_jars
      testlist=$( _list_tests "distributed"  | grep "upgrade" | _split_tests "${split_chunk}")
      if [[ -z "$testlist" ]]; then
          # something has to run in the split to generate a junit xml result
          echo Hacking jvm-dtest-upgrade to run only first test found as no tests in split ${split_chunk} were found
          testlist="$( _list_tests "distributed"  | grep "upgrade" | head -n1)"
      fi
      ant testclasslist -Dtest.classlistprefix=distributed -Dtest.timeout=$(_timeout_for "test.distributed.timeout") -Dtest.classlistfile=<(echo "${testlist}") -Dtmp.dir="${TMP_DIR}" || echo "failed $target"
      ;;
    "cqlsh-test")
      ./pylib/cassandra-cqlsh-tests.sh $(pwd)
      ;;
    *)
      echo "unregconised \"$target\""
      exit 1
      ;;
  esac
}

_main "$@"
