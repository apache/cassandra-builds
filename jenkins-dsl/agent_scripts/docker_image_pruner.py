#
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

# Removes all apache/cassandra_ in-tree test images that are not from branch HEADs

import subprocess
import hashlib
import os
import requests

# str.removeprefix not available until python3.9
def remove_prefix(input_string, prefix):
    return input_string[len(prefix):] if prefix and input_string.startswith(prefix) else input_string

def prune_docker_images():

    docker_images = subprocess.run(['docker', 'images', '--filter', 'reference=apache/cassandra*', '--format', '{{.Repository}}'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.splitlines()

    debug(f"found images: {docker_images}")
    md5sums = set()
    for branch in ['cassandra-5.0','trunk']:
        for docker_image in docker_images:
            dockerfile=remove_prefix(docker_image,'apache/cassandra-')
            debug(f"checking {branch}/.build/docker/{dockerfile}")
            md5sums.add(fetch_url_md5sum(f"https://raw.githubusercontent.com/apache/cassandra/{branch}/.build/docker/{dockerfile}"))


    if 0 < len(md5sums):
        debug(f"in use md5sums are: {md5sums}")

        docker_tags = subprocess.run(['docker', 'images', '--filter', 'reference=apache/cassandra*', '--format', '{{.Repository}}:{{.Tag}}'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.splitlines()

        debug(f"local images are: {docker_tags}")
        for docker_tag in docker_tags:
            debug(docker_tag)
            if subprocess.run(['docker', 'image', 'inspect', '--format', '{{.Id}}', docker_tag], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip() not in md5sums:
                print(f"Pruning {docker_tag}")
                subprocess.run(['docker', 'rmi', docker_tag], check=False)

def fetch_url_md5sum(url):
    return hashlib.md5(requests.get(url).content).hexdigest()

def debug(line):
    if 'DEBUG' in os.environ:
        print(line)

if __name__ == "__main__":
    prune_docker_images()