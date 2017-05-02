#!/bin/bash -x
set -e

if [ "$#" -ne 1 ]; then
   echo "build-debs.sh <branch>"
   exit 1
fi

CASSANDRA_BRANCH=$1

cd $CASSANDRA_DIR
git fetch
git checkout $CASSANDRA_BRANCH

# Used version for build will always depend on the git referenced used for checkout above
# Branches will always be created as snapshots, while tags are releases
tag=`git describe --tags --exact-match` 2> /dev/null
branch=`git symbolic-ref -q --short HEAD` 2> /dev/null

is_tag=false
is_branch=false
git_version=''

if [ "$tag" ]; then
   # Official release
   is_tag=true
   regx_tag="cassandra-([0-9.]+)(-tentative)?$"
   if [[ $tag =~ $regx_tag ]]; then
      git_version=${BASH_REMATCH[1]}
   else
      echo "Error: could not recognize version from tag $tag">&2
      exit 2
   fi
elif [ "$branch" ]; then
   # Dev branch
   is_branch=true
   regx_branch="cassandra-([0-9.]+)$"
   if [[ $branch =~ $regx_branch ]]; then
      git_version=${BASH_REMATCH[1]}
   else
      # This could be either trunk or any dev branch, so we won't be able to get the version
      # from the branch name. In this case, fall back to debian change log version.
      git_version=$(dpkg-parsechangelog | sed -ne 's/^Version: \([^-|~|+]*\).*/\1/p')
      if [ -z $git_version ]; then
         echo "Error: could not recognize version from branch $branch">&2
         exit 2
      else
         echo "Warning: could not recognize version from branch, using dpkg version: $git_version"
      fi
   fi
else
   echo "Error: invalid git reference; must either be branch or tag">&2
   exit 1
fi

# The version used for the deb build process will the current version in the debian/changelog file.
# See debian/rules for how the value is read. The only thing left for us to do here is to check if
# the changes file contains the correct version for the checked out git revision. The version value
# has to be updated manually by a committer and we only warn and abort on mismatches here.
changelog_version=$(dpkg-parsechangelog | sed -ne 's/^Version: \([^~|+]*\).*/\1/p')
chl_expected="$git_version"
if $is_branch ; then
   chl_expected="${git_version}[0-9.]*-SNAPSHOT"
fi
if [[ ! $changelog_version =~ $chl_expected ]]; then
   echo "Error: changelog version seems to be missing -SNAPSHOT suffix for branch">&2
   exit 3
fi

# Version (base.version) in build.xml must be set manually as well. Let's validate the set value.
buildxml_version=`grep 'property\s*name="base.version"' build.xml |sed -ne 's/.*value="\([^"]*\)".*/\1/p'`
if [ $buildxml_version != $git_version ]; then
   echo "Error: build.xml version ($buildxml_version) not matching git tag derived version ($git_version)">&2
   exit 4
fi

# Install build dependencies and build package
echo "y" | sudo mk-build-deps --install
dpkg-buildpackage -uc -us

# Copy created artifacts to dist dir mapped to docker host directory (must have proper permissions)
cp ../cassandra[-_]* $DEB_DIST_DIR
