#!/bin/bash
#
# Generate contribulyse.py reports, for all git repositories, on a number of different time periods.
#
# Example run in docker
# docker run -t -v`pwd`/build/html:/tmp/contribulyze-html -v`pwd`:/contribulyze apache/cassandra-testing-ubuntu2004-java11-w-dependencies bash -lc 'pip3 install --quiet python-dateutil ; cd /contribulyze ; bash contribulyze.sh '
#

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
mkdir -p /tmp/contribulyze-repos
mkdir -p /tmp/contribulyze-html
cd /tmp/contribulyze-repos
for repo in "https://github.com/apache/cassandra.git" "https://github.com/apache/cassandra-dtest.git" "https://github.com/apache/cassandra-builds.git" "https://github.com/apache/cassandra-website.git" ; do
    git clone --quiet $repo
done

for period in "all_time" "last_3_years" "last_6_months" "last_1_month" ; do
    mkdir -p /tmp/contribulyze-html/$period
    cd /tmp/contribulyze-html/$period
    if [ $period == "all_time" ] ; then
        git_since="last 50 years"
    else
        git_since="${period//_/ }"
        title=
    fi
    echo git log --no-merges --since=\""$git_since"\"
    ( for d in $(ls /tmp/contribulyze-repos) ; do cd /tmp/contribulyze-repos/$d ; git log --no-merges --since="$git_since" ; cd - ; done  ) | ${script_dir}/contribulyze.py -t "${period//_/ }"
done
