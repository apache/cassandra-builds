#!/bin/bash
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
#

set -e

supported_versions=("3.0" "3.11" "4.0" "4.1" "trunk")

# Read the remote Apache Cassandra repository name
apache_repository=""
for r in $(git remote show); do
  url="$(git remote get-url "$r")"
  if [[ "$url" == *"apache/cassandra.git" ]]; then
    apache_repository="$r"
    break
  elif [[ "$url" == *"asf/cassandra.git" ]]; then
    apache_repository="$r"
  fi
done
echo "Remote repositories: "
git remote -v show
echo ""
read -r -e -i "$apache_repository" -p "Enter Apache Cassandra remote repository name: " apache_repository
git fetch "$apache_repository"
echo ""

# Read the feature repository and branch
branch="$(git status -b --porcelain=v2 | grep branch.upstream | cut -f 3 -d ' ')"

if [[ "$branch" =~ ^([^/]*)/(CASSANDRA-[0-9]+).*$ ]]; then
  repository="${BASH_REMATCH[1]}"
  ticket="${BASH_REMATCH[2]}"
fi

read -r -e -i "$repository" -p "Enter a feature repository name: " repository
read -r -e -i "$ticket" -p "Enter a ticket ID: " ticket
if [ -z "$repository" ] || [ -z "$ticket" ]; then
  exit 0
fi
echo ""

git fetch "$repository"

# Read all feature branches based on the ticket name
readarray -t branches < <(git ls-remote --refs -h -q "$repository" | grep "$ticket" | cut -d '/' -f 3 | sort)
if [[ "${#branches[@]}" == 0 ]]; then
  echo "Found no feature branches that include a $ticket in name"
  exit 0
fi

echo "The following feature branches were found:"
for branch in "${branches[@]}"; do
  echo "$branch"
done
echo ""

# Read the oldest Cassandra version where the feature should be applied
matched=0
while [[ $matched == 0 ]]; do
  read -r -e -p "What is the oldest target version you want to merge? " oldest_target_version
  if [[ -z "$oldest_target_version" ]]; then
    exit 0
  fi

  feature_versions=()
  for v in "${supported_versions[@]}"; do
    if [[ "$v" == "$oldest_target_version" ]]; then
      matched=1
    fi
    if [[ $matched == 1 ]]; then
      feature_versions+=("$v")
    fi
  done
done

echo "Will merge to the following Cassandra versions:"
for v in "${feature_versions[@]}"; do
  echo "$v"
done
echo ""

function find_matching_branch() {
  local infix="$1"
  for b in "${branches[@]}"; do
    if [[ "$infix" == "" ]] && [[ "$b" == "$ticket" ]]; then
      echo "$b"
      return 0
    elif [[ "$b" == *"$infix"* ]]; then
      echo "$b"
      return 0
    fi
  done

  return 1
}

# Confirm which feature branches are for which Cassandra versions
feature_branches=()
target_branches=()
for v in "${feature_versions[@]}"; do
  branch=""
  if [[ "$v" == "trunk" ]]; then
    target_branches+=("trunk")
    branch="$(find_matching_branch trunk || find_matching_branch "" || true)"
  else
    target_branches+=("cassandra-$v")
    branch="$(find_matching_branch "$v" || true)"
  fi
  read -r -e -i "$branch" -p "Enter branch for version $v or leave empty if there nothing to merge for this version: " branch
  feature_branches+=("$branch")
done

# Generate a script

echo ""
echo ""
echo ""
echo "git fetch $apache_repository"
echo "git fetch $repository"

# Get a subject from the first commit which will serve as a title to be pasted into CHANGES.txt
first_commit="$(git log --pretty=format:%s --reverse "$apache_repository/${target_branches[0]}..$repository/${feature_branches[0]}" | head -n 1)"

push_command="git push --atomic $apache_repository"
skipped_branches_found=0
for i in $(seq 0 $((${#target_branches[@]} - 1))); do
  echo ""
  echo ""
  echo ""
  echo "# $repository/${feature_branches[$i]} -> ${target_branches[$i]}"
  echo "# --------------------------------------------------------------------------------------------------------"

  if [[ $i == 0 ]] && [[ "${feature_branches[$i]}" == "" ]]; then
    # Although we can skip a feature for some versions, we cannot skip it for the oldest version (which is quite obvious)
    exit 1
  fi

  # Read the list of commits between the remote head and the feature branch - we need to cherry pick them (or some of them)

  echo "git switch ${target_branches[$i]}"
  echo "git reset --hard $apache_repository/${target_branches[$i]}"
  if [[ "${feature_branches[$i]}" == "" ]]; then
    skipped_branches_found=1
    # A script for the case where there is no fix for a version
    echo "git merge -s ours --log --no-edit ${target_branches[$((i - 1))]}"
  else
    readarray -t commits < <(git log --reverse --oneline "$apache_repository/${target_branches[$i]}..$repository/${feature_branches[$i]}")

    if [[ $i != 0 ]]; then
      # When this isn't the oldest version (we want to have only the merge commit)
      echo "git merge -s ours --log --no-edit ${target_branches[$((i - 1))]}"
    fi

    for c in $(seq 0 $((${#commits[@]} - 1))); do
      commit_sha="$(echo "${commits[$c]}" | cut -f 1 -d ' ')"
      if [[ $i == 0 ]] && [[ $c == 0 ]]; then
        # we want to have only one feature commit (c == 0), which is in the oldest version (i == 0)
        echo "git cherry-pick $commit_sha # ${commits[$c]}"
      else
        # otherwise we squash the commits to the previous one
        echo "git cherry-pick -n $commit_sha && git commit -a --amend --no-edit # ${commits[$c]}"
      fi
    done
  fi

  if [[ "$skipped_branches_found" == "0" ]]; then
    if [[ $i == 0 ]]; then
      echo "grep '$ticket' CHANGES.txt || sed -E -i '/^[0-9]+\.[0-9]+/{s/.*/&\n\ * $first_commit ($ticket)/;:a;n;ba}' CHANGES.txt"
    else
      echo "grep '$ticket' CHANGES.txt || sed -E -i '/^Merged from ${oldest_target_version}/{s/.*/&\n\ * $first_commit ($ticket)/;:a;n;ba}' CHANGES.txt"
    fi
    echo "git diff CHANGES.txt"
  else
    echo "Update CHANGES.txt by adding the following line:"
    echo " * $first_commit ($ticket)"
  fi
  echo "git add CHANGES.txt"
  echo "git commit --amend --no-edit"

  echo "(git diff $apache_repository/${target_branches[$i]}..HEAD -- .circleci/ | git apply -R --index) && git commit -a --amend --no-edit # Remove all changes in .circleci directory if you need to"

  echo "git diff --name-only $apache_repository/${target_branches[$i]}..HEAD # print a list of all changes files"

  push_command+=" ${target_branches[$i]}"
done

echo ""
echo ""
echo ""
echo "$push_command -n"


