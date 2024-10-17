#!/bin/bash
#
# Generate contribulyse.py reports, for all git repositories, on a number of different time periods.
#
# Example run in docker (from the cassandra-builds/contribulyze directory)
#
# docker run -t -v`pwd`/build/html:/tmp/contribulyze-html -v`pwd`:/contribulyze apache/cassandra-testing-ubuntu2004-java11-w-dependencies bash -lc 'pip3 install --quiet python-dateutil ; cd /contribulyze ; bash contribulyze.sh '
#

set -e
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
mkdir -p /tmp/contribulyze-repos
mkdir -p /tmp/contribulyze-html
cd /tmp/contribulyze-repos

repos=("https://github.com/apache/cassandra.git" "https://github.com/apache/cassandra-dtest.git" "https://github.com/apache/cassandra-builds.git" "https://github.com/apache/cassandra-in-jvm-dtest-api.git" "https://github.com/apache/cassandra-harry.git" "https://github.com/apache/cassandra-website.git" "https://github.com/apache/cassandra-java-driver.git" "https://github.com/apache/cassandra-gocql-driver.git" "https://github.com/datastax/python-driver.git" "https://github.com/apache/cassandra-sidecar.git" "https://github.com/apache/cassandra-analytics.git" "https://github.com/apache/cassandra-accord.git")

# the different groups we want separate contribulyze reports on. note '..' refers to everything.
groups=('..' 'website_and_docs' 'build_and_tools' 'packaging_and_release' 'test_and_ci' 'cassandra_src' 'drivers' 'python-driver' 'cassandra-sidecar' 'cassandra-analytics' 'cassandra-accord')

for repo in ${repos[*]} ; do
    git clone --quiet ${repo}
done

for group in ${groups[*]} ; do
  for period in "all_time" "last_3_years" "last_6_months" "last_1_month" ; do
    mkdir -p /tmp/contribulyze-html/subcomponents/${group}/${period}
    cd /tmp/contribulyze-html/subcomponents/${group}/${period}
    if [ ${period} == "all_time" ] ; then
        git_since="last 50 years"
    else
        git_since="${period//_/ }"
    fi
    echo "${group} ; $(pwd) ; git log --no-merges --since=\"'${git_since}'\" ."

    case "${group}" in

     "website_and_docs")
      groupings=("cassandra/doc" "cassandra-website")
     ;;

     "build_and_tools")
      groupings=("cassandra/bin" "cassandra/tools" "cassandra/.build" "cassandra/ide" "cassandra-builds")
     ;;

     "packaging_and_release")
      groupings=("cassandra/bin" "cassandra/tools" "cassandra/.build" "cassandra/debian" "cassandra/redhat" "cassandra/pylib" "cassandra-builds/cassandra-release" "cassandra-builds/docker")
     ;;

     "test_and_ci")
      groupings=("cassandra/.circleci" "cassandra/.jenkins" "cassandra/test" "cassandra/pylib/cqlshlib/test" "cassandra-dtest" "cassandra-in-jvm-dtest-api" "cassandra-harry" "cassandra-builds/build-scripts")
     ;;

     "cassandra_src")
      groupings=("cassandra/src")
     ;;

     "drivers")
      groupings=("cassandra-java-driver" "cassandra-gocql-driver")
     ;;

     "python-driver")
      groupings=("python-driver")
      continue # FIXME commit messages in python-driver do not follow the "patch by …; reviewed by … for CASSANDRA-" precedence
     ;;

     "cassandra-sidecar")
      groupings=("cassandra-sidecar")
     ;;

     "cassandra-analytics")
      groupings=("cassandra-analytics")
     ;;

     "cassandra-accord")
      groupings=("cassandra-accord")
     ;;

     *)
      groupings=("cassandra" "cassandra-dtest" "cassandra-in-jvm-dtest-api" "cassandra-harry" "cassandra-builds" "cassandra-website" "cassandra-java-driver" "cassandra-gocql-driver" "cassandra-sidecar" "cassandra-analytics" "cassandra-accord")
      ;;
    esac

    ( for d in ${groupings[*]} ; do cd /tmp/contribulyze-repos/${d} ; git log --no-merges --since="${git_since}" . ; cd - >/dev/null ; done  ) | ${script_dir}/contribulyze.py -t "${group//../} ${period//_/ }"
  done
done
