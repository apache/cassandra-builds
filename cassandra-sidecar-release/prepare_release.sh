#!/bin/bash

#set -o xtrace

##### BEFORE YOU BEGIN #####

# 1. Ensure your gpg configuration in ~/.gradle/gradle.properties
#    For example:
#    signing.gnupg.keyName=<your-key>
#    signing.gnupg.passphrase=<your-passphrase>
#    #signing.gnupg.executable=gpg # optional
#    #signing.gnupg.useLegacyGpg=true # optional
#    #signing.gnupg.homeDir=gnupg-home # optional
#    #signing.gnupg.optionsFile=gnupg-home/gpg.conf # optional

# 2. Ensure your maven credentials are configured in ~/.gradle/gradle.properties
#    For example:
#    maven.repository.url=https://repository.apache.org/service/local/staging/deploy/maven2
#    maven.username=<asf-username>
#    maven.password=<asf-password>

##### TO EDIT #####

asf_username="${asf_username:-$USER}"

if [ "x${asf_username}" != "x${USER}" ] ; then
  echo "Using ASF username ${asf_username}"
fi

# The name of remote for the asf remote in your git repo
git_asf_remote="${git_asf_remote:-origin}"

if [ "x${git_asf_remote}" != "xorigin" ] ; then
  echo "Using git ASF remote ${git_asf_remote}"
fi

# Where you want to put the mail draft that this script generate
mail_dir="$HOME/Mail"

###################
# prerequisites

command -v svn >/dev/null 2>&1 || { echo >&2 "subversion needs to be installed"; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "git needs to be installed"; exit 1; }
command -v shasum >/dev/null 2>&1 || { echo >&2 "shasum needs to be installed"; exit 1; }

###################
asf_git_repo="${asf_git_repo:-https://gitbox.apache.org/repos/asf}"

if [ "x${asf_git_repo}" != "xhttps://gitbox.apache.org/repos/asf" ] ; then
    echo "Using ASF git repo ${asf_git_repo}"
fi

staging_repo="https://repository.apache.org/content/repositories"

# Reset getopts in case it has been used previously in the shell.
OPTIND=1

# Initialize our own variables:
verbose=0
fake_mode=0
only_deb=0
only_rpm=0

show_help()
{
    local name=`basename $0`
    echo "$name [options] <release_version> <java_8_home> <java_11_home>"
    echo ""
    echo "where [options] are:"
    echo "  -h: print this help"
    echo "  -v: verbose mode (show everything that is going on)"
    echo "  -f: fake mode, print any output but don't do anything (for debugging)"
    echo "  -d: only publish the debian package"
    echo "  -r: only publish the rpm package"
    echo ""
    echo "Example: $name 1.0.0 /path/to/java8/home /path/to/java11/home"
}

while getopts ":hvfdr" opt; do
    case "$opt" in
    h)
        show_help
        exit 0
        ;;
    v)  verbose=1
        ;;
    f)  fake_mode=1
        ;;
    d)  only_deb=1
        ;;
    r)  only_rpm=1
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        show_help
        exit 1
        ;;
    esac
done

if [ $only_deb -eq 1 ] && [ $only_rpm -eq 1 ]
then
    echo "Options '-d' and '-r' are mutually exclusive"
    exit 1
fi

shift $(($OPTIND-1))

release=$1
deb_release=${release/-/\~}

if [ -z "$release" ]
then
    echo "Missing argument <release_version>"
    show_help
    exit 1
fi

shift

java_8_home=$1

if [ -z "$java_8_home" ]
then
    echo "Missing argument <java_8_home>"
    show_help
    exit 1
fi

shift

java_11_home=$1

if [ -z "$java_11_home" ]
then
    echo "Missing argument <java_11_home>"
    show_help
    exit 1
fi

if [ -x "${java_8_home}/bin/java" ]
then
    if [ "x$(${java_8_home}/bin/java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d '.' -f 1,2)" != "x1.8" ]
    then
        echo "Invalid java 8 version in ${java_8_home}"
        show_help
        exit 1
    fi
else
    echo "Invalid java_8_home argument. No java executable found"
    show_help
    exit 1
fi

if [ -x "${java_11_home}/bin/java" ]
then
    if [ "x$(${java_11_home}/bin/java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d '.' -f 1)" != "x11" ]
    then
        echo "Invalid java 11 version in ${java_11_home}"
        show_help
        exit 1
    fi
else
    echo "Invalid java_11_home argument. No java executable found"
    show_help
    exit 1
fi

if [ "$#" -gt 1 ]
then
    shift
    echo "Too many arguments. Don't know what to do with '$@'"
    show_help
    exit 1
fi

# Somewhat lame way to check we're in a git repo but that will do
git log -1 &> /dev/null
if [ $? -ne 0 ]
then
    echo "The current directory does not appear to be a git repository."
    echo "You must run this from the Cassandra Sidecar git source repository."
    exit 1
fi

if ! git diff-index --quiet HEAD --
then
    echo "This git Cassandra Sidecar directory has uncommitted changes."
    echo "You must run this from a clean Cassandra Sidecar git source repository."
    exit 1
fi

gradle_properties_version="$(grep ^version= gradle.properties)"
if [ "${release}" != "${gradle_properties_version#version=}" ] ; then
    echo "The release requested ${release} does not match gradle.properties's version ${gradle_properties_version}"
    exit 1
fi

if [ $only_deb -eq 0 ] && [ $only_rpm -eq 0 ]
then
    if curl --output /dev/null --silent --head --fail "https://dist.apache.org/repos/dist/dev/cassandra/cassandra-sidecar/${release}" ; then
        echo "The release candidate for ${release} is already staged at https://dist.apache.org/repos/dist/dev/cassandra/cassandra-sidecar/${release}"
        exit 1
    fi

    if curl --output /dev/null --silent --head --fail "https://archive.apache.org/dist/cassandra/cassandra-sidecar/${release}" ; then
        echo "A published release for ${release} is already public at https://archive.apache.org/dist/cassandra/cassandra-sidecar/${release}"
        exit 1
    fi

    if curl --output /dev/null --silent --head --fail "https://github.com/apache/cassandra-sidecar/tree/${release}-tentative" ; then
        echo "The release candidate tag for ${release}-tentative is already at https://github.com/apache/cassandra-sidecar/tree/${release}-tentative"
        exit 1
    fi

    if curl --output /dev/null --silent --head --fail "https://github.com/apache/cassandra-sidecar/tree/cassandra-sidecar-${release}" ; then
        echo "The published release tag for ${release} is already at https://github.com/apache/cassandra-sidecar/tree/cassandra-sidecar-${release}"
        exit 1
    fi

    if git tag -l | grep -q "${release}-tentative"; then
        echo "Local git tag for ${release}-tentative already exists"
        exit 1
    fi

    head_commit=`git log --pretty=oneline -1 | cut -d " " -f 1`

    if [ "$release" == "$deb_release" ]
    then
        echo "Preparing release for $release from commit:"
    else
        echo "Preparing release for $release (debian will use $deb_release) from commit:"
    fi
    echo ""
    git show $head_commit
    java -version

    echo "Is this what you want?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes) break;;
            No) echo "Alright, come back when you've made up your mind"; exit 0;;
        esac
    done
fi

# "Saves" stdout to other descriptor since we might redirect them below
exec 3>&1 4>&2

if [ $verbose -eq 0 ]
then
    # Not verbose, redirect all output to a logfile
    logfile="vote-${release}.log"
    [ ! -e "$logfile" ] || rm $logfile
    touch $logfile
    exec > $logfile
    exec 2> $logfile
fi

execute()
{
    local cmd=$1

    echo ">> $cmd"
    [ $fake_mode -eq 1 ] || $cmd
    if [ $? -ne 0 ]
    then
        echo "Error running $cmd" 1>&3 2>&4
        exit $?
    fi
}

current_dir=`pwd`
tmp_dir=`mktemp -d`
distributions_dir=${tmp_dir}/cassandra-sidecar/build/distributions

if [ $only_deb -eq 0 ] && [ $only_rpm -eq 0 ]
then
    echo "Tagging release ..." 1>&3 2>&4
    execute "git tag $release-tentative"
    execute "git push $git_asf_remote refs/tags/$release-tentative"

    echo "Cloning fresh repository ..." 1>&3 2>&4
    execute "cd $tmp_dir"
    ## We clone from the original repository to make extra sure we're not screwing, even if that's definitively slower
    execute "git clone $asf_git_repo/cassandra-sidecar.git"

    echo "Building and uploading artifacts ..." 1>&3 2>&4
    execute "cd cassandra-sidecar"
    execute "git checkout $release-tentative"
    # First let's build and publish java 8 artifacts
    execute "./gradlew --no-daemon -Dorg.gradle.java.home=${java_8_home} clean"
    execute "./gradlew --no-daemon -Dorg.gradle.java.home=${java_8_home} -PforceSigning -Prelease=true -Pversion=${release}-jdk8 publish --stacktrace"
    # Then build java 11 artifacts and publish
    execute "./gradlew --no-daemon -Dorg.gradle.java.home=${java_11_home} clean"
    execute "./gradlew --no-daemon -PskipIntegrationTest -Dorg.gradle.java.home=${java_11_home} -PforceSigning -Prelease=true -Pversion=${release} assemble publish --stacktrace"

    echo "Artifacts uploaded, find the staging repository on repository.apache.org, \"Close\" it, and indicate its staging number:" 1>&3 2>&4
    read -p "staging number Java 11? " staging_number 1>&3 2>&4
    read -p "staging number Java 8? " staging_number_java_8 1>&3 2>&4

    execute "cd $tmp_dir"
    execute "svn co https://dist.apache.org/repos/dist/dev/cassandra/cassandra-sidecar cassandra-sidecar-dist-dev"
    execute "mkdir cassandra-sidecar-dist-dev/${release}"
    execute "cp ${distributions_dir}/apache-cassandra-sidecar-${release}-src.tar.gz* cassandra-sidecar-dist-dev/${release}/"
    execute "cp ${distributions_dir}/apache-cassandra-sidecar-${release}.tar.gz* cassandra-sidecar-dist-dev/${release}/"
    execute "svn add cassandra-sidecar-dist-dev/${release}"
    echo "staging Cassandra Sidecar $release" > "_tmp_msg_"
    execute "svn ci -F _tmp_msg_ cassandra-sidecar-dist-dev/${release}"
    execute "rm _tmp_msg_"
    execute "cd $current_dir"
fi

## Debian Stuff ##

if [ $only_rpm -eq 0 ]
then
    execute "cd $tmp_dir"
    execute "svn co https://dist.apache.org/repos/dist/dev/cassandra/cassandra-sidecar cassandra-sidecar-dist-dev"

    echo "Copying debian package ..." 1>&3 2>&4
    execute "mkdir ${tmp_dir}/cassandra-sidecar-dist-dev/${release}/debian"
    execute "cp ${distributions_dir}/apache-cassandra-sidecar_${release}_all.deb* ${tmp_dir}/cassandra-sidecar-dist-dev/${release}/debian/"

    execute "cd $tmp_dir"
    execute "svn add --force cassandra-sidecar-dist-dev/${release}/debian"
    echo "Staging Cassandra Sidecar debian packages for $release" > "_tmp_msg_"
    execute "svn ci -F _tmp_msg_ cassandra-sidecar-dist-dev/${release}/debian"
    execute "cd $current_dir"
fi

## RPM Stuff ##

if [ $only_deb -eq 0 ]
then
    execute "cd $tmp_dir"
    execute "svn co https://dist.apache.org/repos/dist/dev/cassandra/cassandra-sidecar cassandra-sidecar-dist-dev"

    echo "Copying redhat packages ..." 1>&3 2>&4
    execute "mkdir $tmp_dir/cassandra-sidecar-dist-dev/${release}/redhat"
    execute "cp ${distributions_dir}/apache-cassandra-sidecar-${release}.noarch.rpm* ${tmp_dir}/cassandra-sidecar-dist-dev/${release}/redhat/"

    execute "cd $tmp_dir"
    execute "svn add --force cassandra-sidecar-dist-dev/${release}/redhat"
    echo "staging cassandra rpm packages for $release" > "_tmp_msg_"
    execute "svn ci -F _tmp_msg_ cassandra-sidecar-dist-dev/${release}/redhat"
    execute "cd $current_dir"
fi

if [ $only_deb -eq 0 ] && [ $only_rpm -eq 0 ]
then

    # Restore stdout/stderr (and close temporary descriptors) if not verbose
    [ $verbose -eq 1 ] || exec 1>&3 3>&- 2>&4 4>&-

    # Cleaning up
    [ $fake_mode -eq 1 ] && echo ">> rm -rf $tmp_dir"
    rm -rf $tmp_dir

    ## Email templates ##
    [ $fake_mode -eq 1 ] && echo ">> rm -rf $mail_dir"
    mkdir -p $mail_dir
    mail_test_announce_file="$mail_dir/mail_stage_announce_$release"
    mail_vote_file="$mail_dir/mail_vote_$release"

    echo "[ANNOUNCE] Apache Cassandra Sidecar $release test artifact available" > $mail_test_announce_file
    echo "" >> $mail_test_announce_file
    echo "The test build of Cassandra Sidecar ${release} is available." >> $mail_test_announce_file
    echo "" >> $mail_test_announce_file
    echo "sha1: $head_commit" >> $mail_test_announce_file
    echo "Git: https://github.com/apache/cassandra-sidecar/tree/$release-tentative" >> $mail_test_announce_file
    echo "Maven Artifacts:" >> $mail_test_announce_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-server/$release/" >> $mail_test_announce_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-client/$release/" >> $mail_test_announce_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-adapters-cassandra41/$release/" >> $mail_test_announce_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-adapters-base/$release/" >> $mail_test_announce_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-vertx-client/$release/" >> $mail_test_announce_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-client-common/$release/" >> $mail_test_announce_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-vertx-client-all/$release/" >> $mail_test_announce_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-server-common/$release/" >> $mail_test_announce_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-vertx-auth-mtls/$release/" >> $mail_test_announce_file
    echo "$staging_repo/orgapachecassandra-$staging_number_java_8/org/apache/cassandra/sidecar-client/$release-jdk8/" >> $mail_test_announce_file
    echo "$staging_repo/orgapachecassandra-$staging_number_java_8/org/apache/cassandra/sidecar-vertx-client/$release-jdk8/" >> $mail_test_announce_file
    echo "$staging_repo/orgapachecassandra-$staging_number_java_8/org/apache/cassandra/sidecar-client-common/$release-jdk8/" >> $mail_test_announce_file
    echo "$staging_repo/orgapachecassandra-$staging_number_java_8/org/apache/cassandra/sidecar-vertx-client-all/$release-jdk8/" >> $mail_test_announce_file
    echo "" >> $mail_test_announce_file
    echo "The Source and Build Artifacts, and the Debian and RPM packages and repositories, are available here: https://dist.apache.org/repos/dist/dev/cassandra/cassandra-sidecar/$release/" >> $mail_test_announce_file
    echo "" >> $mail_test_announce_file
    echo "A vote of this test build will be initiated within the next couple of days." >> $mail_test_announce_file
    echo "" >> $mail_test_announce_file
    echo "[1]: CHANGES.txt: https://github.com/apache/cassandra-sidecar/blob/$release-tentative/CHANGES.txt" >> $mail_test_announce_file
    echo "[2]: NEWS.txt: https://github.com/apache/cassandra-sidecar/blob/$release-tentative/NEWS.txt" >> $mail_test_announce_file

    echo "Test announcement mail written to $mail_test_announce_file"


    echo "[VOTE] Release Apache Cassandra Sidecar $release" > $mail_vote_file
    echo "" >> $mail_vote_file
    echo "Proposing the test build of Cassandra Sidecar ${release} for release." >> $mail_vote_file
    echo "" >> $mail_vote_file
    echo "sha1: $head_commit" >> $mail_vote_file
    echo "Git: https://github.com/apache/cassandra-sidecar/tree/$release-tentative" >> $mail_vote_file
    echo "Maven Artifacts:" >> $mail_vote_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-server/$release/" >> $mail_vote_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-client/$release/" >> $mail_vote_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-adapters-cassandra41/$release/" >> $mail_vote_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-adapters-base/$release/" >> $mail_vote_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-vertx-client/$release/" >> $mail_vote_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-client-common/$release/" >> $mail_vote_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-vertx-client-all/$release/" >> $mail_vote_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-server-common/$release/" >> $mail_vote_file
    echo "$staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/sidecar-vertx-auth-mtls/$release/" >> $mail_vote_file
    echo "$staging_repo/orgapachecassandra-$staging_number_java_8/org/apache/cassandra/sidecar-client/$release-jdk8/" >> $mail_vote_file
    echo "$staging_repo/orgapachecassandra-$staging_number_java_8/org/apache/cassandra/sidecar-vertx-client/$release-jdk8/" >> $mail_vote_file
    echo "$staging_repo/orgapachecassandra-$staging_number_java_8/org/apache/cassandra/sidecar-client-common/$release-jdk8/" >> $mail_vote_file
    echo "$staging_repo/orgapachecassandra-$staging_number_java_8/org/apache/cassandra/sidecar-vertx-client-all/$release-jdk8/" >> $mail_vote_file
    echo "" >> $mail_vote_file
    echo "The Source and Build Artifacts, and the Debian and RPM packages and repositories, are available here: https://dist.apache.org/repos/dist/dev/cassandra/cassandra-sidecar/$release/" >> $mail_vote_file
    echo "" >> $mail_vote_file
    echo "The vote will be open for 72 hours (longer if needed). Everyone who has tested the build is invited to vote. Votes by PMC members are considered binding. A vote passes if there are at least three binding +1s and no -1's." >> $mail_vote_file
    echo "" >> $mail_vote_file
    echo "[1]: CHANGES.txt: https://github.com/apache/cassandra-sidecar/blob/$release-tentative/CHANGES.txt" >> $mail_vote_file
    echo "[2]: NEWS.txt: https://github.com/apache/cassandra-sidecar/blob/$release-tentative/NEWS.txt" >> $mail_vote_file

    echo "Vote mail written to $mail_vote_file"
fi


echo "Done cutting and staging release artifacts. Please make sure to:"
echo " 1) verify all staged artifacts"
echo " 2) email the announcement email"
echo " 3) after a couple of days, email the vote email"
