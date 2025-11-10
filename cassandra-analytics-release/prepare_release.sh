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
echo "Using ASF username ${asf_username}"
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

show_help()
{
    local name=`basename $0`
    echo "$name [options] <release_version> <java_11_home>"
    echo ""
    echo "where [options] are:"
    echo "  -h: print this help"
    echo "  -v: verbose mode (show everything that is going on)"
    echo "  -f: fake mode, print any output but don't do anything (for debugging)"
    echo ""
    echo "Example: $name 1.0.0 /path/to/java11/home"
}

while getopts ":hvf" opt; do
    case "$opt" in
    h)
        show_help
        exit 0
        ;;
    v)  verbose=1
        ;;
    f)  fake_mode=1
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        show_help
        exit 1
        ;;
    esac
done

shift $(($OPTIND-1))

release=$1

if [ -z "$release" ]
then
    echo "Missing argument <release_version>"
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
    echo "You must run this from the Cassandra Analytics git source repository."
    exit 1
fi

if ! git diff-index --quiet HEAD --
then
    echo "This git Cassandra Sidecar directory has uncommitted changes."
    echo "You must run this from a clean Cassandra Analytics git source repository."
    exit 1
fi

gradle_properties_version="$(grep ^version= gradle.properties)"
if [ "${release}" != "${gradle_properties_version#version=}" ] ; then
    echo "The release requested ${release} does not match gradle.properties's version ${gradle_properties_version}"
    exit 1
fi

if curl --output /dev/null --silent --head --fail "https://dist.apache.org/repos/dist/dev/cassandra/cassandra-analytics/${release}" ; then
    echo "The release candidate for ${release} is already staged at https://dist.apache.org/repos/dist/dev/cassandra/cassandra-analytics/${release}"
    exit 1
fi

if curl --output /dev/null --silent --head --fail "https://archive.apache.org/dist/cassandra/cassandra-analytics/${release}" ; then
    echo "A published release for ${release} is already public at https://archive.apache.org/dist/cassandra/cassandra-analytics/${release}"
    exit 1
fi

if curl --output /dev/null --silent --head --fail "https://github.com/apache/cassandra-analytics/tree/${release}-tentative" ; then
    echo "The release candidate tag for ${release}-tentative is already at https://github.com/apache/cassandra-analytics/tree/${release}-tentative"
    exit 1
fi

if curl --output /dev/null --silent --head --fail "https://github.com/apache/cassandra-analytics/tree/cassandra-analytics-${release}" ; then
    echo "The published release tag for ${release} is already at https://github.com/apache/cassandra-analytics/tree/cassandra-analytics-${release}"
    exit 1
fi

if git tag -l | grep -q "${release}-tentative"; then
    echo "Local git tag for ${release}-tentative already exists"
    exit 1
fi

head_commit=`git log --pretty=oneline -1 | cut -d " " -f 1`

echo "Preparing release for $release from commit:"

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
distributions_dir=${tmp_dir}/cassandra-analytics/build/distributions

echo "Tagging release ..." 1>&3 2>&4
execute "git tag $release-tentative"
execute "git push $git_asf_remote refs/tags/$release-tentative"

echo "Cloning fresh repository ..." 1>&3 2>&4
execute "cd $tmp_dir"
## We clone from the original repository to make extra sure we're not screwing, even if that's definitively slower
execute "git clone $asf_git_repo/cassandra-analytics.git"

echo "Building and uploading artifacts ..." 1>&3 2>&4
execute "cd $tmp_dir/cassandra-analytics"
execute "git checkout -b $release-tentative"
# Build java 11 artifacts and publish
execute "./scripts/build-dependencies.sh"
execute "./gradlew --no-daemon -Dorg.gradle.java.home=${java_11_home} clean"
execute "./gradlew --no-daemon -Pscala=2.12 -P-Dorg.gradle.java.home=${java_11_home} -PartifactType=common -PforceSigning -Prelease=true -Pversion=${release} assemble publish --stacktrace"
execute "./gradlew --no-daemon -Pscala=2.13 -Dorg.gradle.java.home=${java_11_home} -PartifactType=common -PforceSigning -Prelease=true -Pversion=${release} assemble publish --stacktrace"
execute "./gradlew --no-daemon -Pscala=2.12 -P-Dorg.gradle.java.home=${java_11_home} -PartifactType=spark -PforceSigning -Prelease=true -Pversion=${release} assemble publish --stacktrace"
execute "./gradlew --no-daemon -Pscala=2.13 -Dorg.gradle.java.home=${java_11_home} -PartifactType=spark -PforceSigning -Prelease=true -Pversion=${release} assemble publish --stacktrace"

echo "Artifacts uploaded, find the staging repository on repository.apache.org, \"Close\" it, and indicate its staging number:" 1>&3 2>&4
read -p "staging number Scala 2.12, Java 11, Spark 3? " staging_number_212_11_3 1>&3 2>&4
read -p "staging number Scala 2.13, Java 11, Spark 3? " staging_number_213_11_3 1>&3 2>&4

execute "cd $tmp_dir"
execute "svn co https://dist.apache.org/repos/dist/dev/cassandra/cassandra-analytics cassandra-analytics-dist-dev"
execute "mkdir cassandra-analytics-dist-dev/${release}"
execute "cp ${distributions_dir}/apache-cassandra-analytics-${release}-src.tar.gz* cassandra-analytics-dist-dev/${release}/"
execute "cp ${distributions_dir}/apache-cassandra-analytics-${release}.tar.gz* cassandra-analytics-dist-dev/${release}/"
execute "svn add cassandra-analytics-dist-dev/${release}"
echo "staging Cassandra Analytics $release" > "_tmp_msg_"
execute "svn ci -F _tmp_msg_ cassandra-analytics-dist-dev/${release}"
execute "rm _tmp_msg_"
execute "cd $current_dir"

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

echo "[ANNOUNCE] Apache Cassandra Analytics $release test artifact available" > $mail_test_announce_file
echo "" >> $mail_test_announce_file
echo "The test build of Cassandra Analytics ${release} is available." >> $mail_test_announce_file
echo "" >> $mail_test_announce_file
echo "sha1: $head_commit" >> $mail_test_announce_file
echo "Git: https://github.com/apache/cassandra-analytics/tree/$release-tentative" >> $mail_test_announce_file
echo "Maven Artifacts:" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-codec_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-sidecar_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-common_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-core-example_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-core_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-spark-converter_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-bridge_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-codec_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-sidecar_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-common_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-core-example_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-core_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-spark-converter_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-bridge_spark3_2.13/$release/" >> $mail_test_announce_file

echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-codec_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-sidecar_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-common_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-core-example_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-core_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-spark-converter_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-bridge_spark3_2.12/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-codec_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-sidecar_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-common_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-core-example_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-core_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-spark-converter_spark3_2.13/$release/" >> $mail_test_announce_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-bridge_spark3_2.13/$release/" >> $mail_test_announce_file

echo "The Source and Build Artifacts and repositories, are available here: https://dist.apache.org/repos/dist/dev/cassandra/cassandra-analytics/$release/" >> $mail_test_announce_file
echo "" >> $mail_test_announce_file
echo "A vote of this test build will be initiated within the next couple of days." >> $mail_test_announce_file
echo "" >> $mail_test_announce_file
echo "[1]: CHANGES.txt: https://github.com/apache/cassandra-analytics/blob/$release-tentative/CHANGES.txt" >> $mail_test_announce_file

echo "Test announcement mail written to $mail_test_announce_file"


echo "[VOTE] Release Apache Cassandra Analytics $release" > $mail_vote_file
echo "" >> $mail_vote_file
echo "Proposing the test build of Cassandra Analytics ${release} for release." >> $mail_vote_file
echo "" >> $mail_vote_file
echo "sha1: $head_commit" >> $mail_vote_file
echo "Git: https://github.com/apache/cassandra-analytics/tree/$release-tentative" >> $mail_vote_file
echo "Maven Artifacts:" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-codec_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-sidecar_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-common_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-core-example_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-core_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-spark-converter_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-bridge_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-codec_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-sidecar_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-common_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-core-example_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-core_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-analytics-spark-converter_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_212_11_3/org/apache/cassandra/analytics-cassandra-bridge_spark3_2.13/$release/" >> $mail_vote_file

echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-codec_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-sidecar_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-common_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-core-example_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-core_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-spark-converter_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-bridge_spark3_2.12/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-codec_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc-sidecar_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-cdc_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-common_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-core-example_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-core_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-analytics-spark-converter_spark3_2.13/$release/" >> $mail_vote_file
echo "$staging_repo/orgapachecassandra-$staging_number_213_11_3/org/apache/cassandra/analytics-cassandra-bridge_spark3_2.13/$release/" >> $mail_vote_file
echo "" >> $mail_vote_file
echo "The Source and Build Artifacts and repositories, are available here: https://dist.apache.org/repos/dist/dev/cassandra/cassandra-analytics/$release/" >> $mail_vote_file
echo "" >> $mail_vote_file
echo "The vote will be open for 72 hours (longer if needed). Everyone who has tested the build is invited to vote. Votes by PMC members are considered binding. A vote passes if there are at least three binding +1s and no -1's." >> $mail_vote_file
echo "" >> $mail_vote_file
echo "[1]: CHANGES.txt: https://github.com/apache/cassandra-analytics/blob/$release-tentative/CHANGES.txt" >> $mail_vote_file
echo "[2]: NEWS.txt: https://github.com/apache/cassandra-analytics/blob/$release-tentative/NEWS.txt" >> $mail_vote_file

echo "Vote mail written to $mail_vote_file"

echo "Done cutting and staging release artifacts. Please make sure to:"
echo " 1) verify all staged artifacts"
echo " 2) email the announcement email"
echo " 3) after a couple of days, email the vote email"
