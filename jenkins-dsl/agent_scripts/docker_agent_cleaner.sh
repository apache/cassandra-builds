#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Cleans jenkins agents. Primarily used by ci-cassandra.a.o
#
# First argument is `maxJobHours`, all docker objects older than this are pruned
#
# Assumes a CI running multiple C* branches and other jobs


# pre-conditions
command -v docker >/dev/null 2>&1 || { error 1 "docker needs to be installed"; }
command -v virtualenv >/dev/null 2>&1 || { error 1 "virtualenv needs to be installed"; }
(docker info >/dev/null 2>&1) || { error 1 "docker needs to running"; }
[ -f "./docker_image_pruner.py" ] || { error 1 "./docker_image_pruner.py must exist"; }

# arguments
maxJobHours=12
[ "$#" -gt 0 ] && maxJobHours=$1

error() {
    echo >&2 $2;
    set -x
    exit $1
}

echo -n "docker system prune --all --force --filter \"until=${maxJobHours}h\" : "
docker system prune --all --force --filter "until=${maxJobHours}h"
if !( pgrep -xa docker &> /dev/null || pgrep -af "build/docker" &> /dev/null || pgrep -af "cassandra-builds/build-scripts" &> /dev/null ) ; then
    echo -n "docker system prune --force : "
    docker system prune --force || true ;
fi;

virtualenv -p python3 -q .venv
source .venv/bin/activate
pip -q install requests
python docker_image_pruner.py
deactivate