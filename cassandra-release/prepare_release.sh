#!/bin/bash

##### TO EDIT #####

asf_username="$USER"

if [ -z "$gpg_key" ]; then
    gpg_key="XXXXXXXX"
fi

if [ "$gpg_key" = "XXXXXXXX" ]; then
    echo >&2 "Gpg key is unset. Pleae set gpg_key variable." && exit 1
fi

# The name of remote for the asf remote in your git repo
git_asf_remote="origin"

# Where you want to put the mail draft that this script generate
mail_dir="$HOME/Mail"

###################
# prerequisites
command -v svn >/dev/null 2>&1 || { echo >&2 "subversion needs to be installed"; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "git needs to be installed"; exit 1; }
command -v ant >/dev/null 2>&1 || { echo >&2 "ant needs to be installed"; exit 1; }
command -v debsign >/dev/null 2>&1 || { echo >&2 "devscripts needs to be installed"; exit 1; }
command -v reprepro >/dev/null 2>&1 || { echo >&2 "reprepro needs to be installed"; exit 1; }
command -v rpmsign >/dev/null 2>&1 || { echo >&2 "rpmsign needs to be installed"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo >&2 "docker needs to be installed"; exit 1; }
command -v createrepo_c >/dev/null 2>&1 || { echo >&2 "createrepo_c needs to be installed"; exit 1; }
command -v mvn >/dev/null 2>&1 || { echo >&2 "mvn needs to be installed"; exit 1; }
(docker info >/dev/null 2>&1) || { echo >&2 "docker needs to running"; exit 1; }

###################
asf_git_repo="https://gitbox.apache.org/repos/asf"
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
    echo "$name [options] <release_version>"
    echo ""
    echo "where [options] are:"
    echo "  -h: print this help"
    echo "  -v: verbose mode (show everything that is going on)"
    echo "  -f: fake mode, print any output but don't do anything (for debugging)"
    echo "  -d: only build the debian package"
    echo "  -r: only build the rpm package"
    echo ""
    echo "Example: $name 2.0.3"
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
    echo "You must run this from the Cassandra git source repository."
    exit 1
fi

if ! git diff-index --quiet HEAD --
then
    echo "This git Cassandra directory has uncommitted changes."
    echo "You must run this from a clean Cassandra git source repository."
    exit 1
fi

build_xml_version="$(grep 'property\s*name=\"base.version\"' build.xml |sed -ne 's/.*value=\"\([^"]*\)\".*/\1/p')"
if [ "${release}" != "${build_xml_version}" ] ; then
    echo "The release requested ${release} does not match build.xml's version ${build_xml_version}"
    exit 1
fi

if curl --output /dev/null --silent --head --fail "https://dist.apache.org/repos/dist/dev/cassandra/${release}" ; then
    echo "The release candidate for ${release} is already staged at https://dist.apache.org/repos/dist/dev/cassandra/${release}"
    exit 1
fi

if curl --output /dev/null --silent --head --fail "https://archive.apache.org/dist/cassandra/${release}" ; then
    echo "A published release for ${release} is already public at https://archive.apache.org/dist/cassandra/${release}"
    exit 1
fi

if curl --output /dev/null --silent --head --fail "https://github.com/apache/cassandra/tree/${release}-tentative" ; then
    echo "The release candidate tag for ${release}-tentative is already at https://github.com/apache/cassandra/tree/${release}-tentative"
    exit 1
fi

if curl --output /dev/null --silent --head --fail "https://github.com/apache/cassandra/tree/cassandra-${release}" ; then
    echo "The published release tag for ${release} is already at https://github.com/apache/cassandra/tree/cassandra-${release}"
    exit 1
fi

if git tag -l | grep -q "${release}-tentative"; then
    echo "Local git tag for ${release}-tentative already exists"
    exit 1
fi

if [ $only_deb -eq 0 ] && [ $only_rpm -eq 0 ]
then
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
declare -x cassandra_builds_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."
tmp_dir=`mktemp -d`
build_dir=${tmp_dir}/cassandra/build
debian_package_dir="${tmp_dir}/debian"
rpm_package_dir="${tmp_dir}/rpm"
rpmnoboolean_package_dir="${tmp_dir}/rpmnoboolean"

idx=`expr index "$release" -`
if [ $idx -eq 0 ]
then
    release_short=${release}
else
    release_short=${release:0:$((idx-1))}
fi
release_major=$(echo ${release_short} | cut -d '.' -f 1)
release_minor=$(echo ${release_short} | cut -d '.' -f 2)


if [ $only_deb -eq 0 ] && [ $only_rpm -eq 0 ]
then
    echo "Update debian changelog, please correct changelog, name, and email."
    read -n 1 -s -r -p "press any key to continue…" 1>&3 2>&4
    echo ""
    execute "dch -r -D unstable"
    echo "Prepare debian changelog for $release" > "_tmp_msg_"
    execute "git commit -F _tmp_msg_ debian/changelog"
    execute "rm _tmp_msg_"
    head_commit=`git log --pretty=oneline -1 | cut -d " " -f 1`
    # this commit needs to be forward merged and atomic pushed (see reminders at bottom)

    echo "Tagging release ..." 1>&3 2>&4
    execute "git tag $release-tentative"
    execute "git push $git_asf_remote refs/tags/$release-tentative"

    echo "Cloning fresh repository ..." 1>&3 2>&4
    execute "cd $tmp_dir"
    ## We clone from the original repository to make extra sure we're not screwing, even if that's definitively slower
    execute "git clone $asf_git_repo/cassandra.git"

    echo "Building and uploading artifacts ..." 1>&3 2>&4
    execute "cd cassandra"
    execute "git checkout $release-tentative"
    execute "ant realclean"
    execute "ant publish -Drelease=true -Dno-checkstyle=true -Drat.skip=true -Dant.gen-doc.skip=true"

    echo "Artifacts uploaded, find the staging repository on repository.apache.org, \"Close\" it, and indicate its staging number:" 1>&3 2>&4
    read -p "staging number? " staging_number 1>&3 2>&4

    execute "cd $tmp_dir"
    execute "svn co https://dist.apache.org/repos/dist/dev/cassandra cassandra-dist-dev"
    execute "mkdir cassandra-dist-dev/${release}"
    execute "cp ${build_dir}/apache-cassandra-${release}-src.tar.gz* cassandra-dist-dev/${release}/"
    execute "cp ${build_dir}/apache-cassandra-${release}-bin.tar.gz* cassandra-dist-dev/${release}/"
    execute "svn add cassandra-dist-dev/${release}"
    echo "staging cassandra $release" > "_tmp_msg_"
    execute "svn ci -F _tmp_msg_ cassandra-dist-dev/${release}"
    execute "rm _tmp_msg_"
    execute "cd $current_dir"
fi

## Debian Stuffs ##

if [ $only_rpm -eq 0 ]
then
    execute "cd $tmp_dir"
    execute "svn co https://dist.apache.org/repos/dist/dev/cassandra cassandra-dist-dev"

    execute "mkdir -p $debian_package_dir"
    execute "cd $debian_package_dir"

    [ $fake_mode -eq 1 ] && echo ">> declare -x deb_dir=${debian_package_dir}/cassandra_${release}_debian"
    declare -x deb_dir=${debian_package_dir}/cassandra_${release}_debian
    [ ! -e "$deb_dir" ] || rm -rf $deb_dir
    execute "mkdir $deb_dir"
    execute "cd $deb_dir"

    echo "Building debian package ..." 1>&3 2>&4
    execute "mkdir ${tmp_dir}/cassandra-dist-dev/${release}/debian"

    if [ -f ${tmp_dir}/cassandra/.build/docker/build-debian.sh ] ; then
        execute "cd ${tmp_dir}/cassandra"
        execute "ant realclean"
        execute ".build/docker/build-debian.sh"
        execute "cp build/cassandra* ${tmp_dir}/cassandra-dist-dev/${release}/debian/"
    else
        execute "${cassandra_builds_dir}/build-scripts/cassandra-deb-packaging.sh ${release}-tentative"
        execute "cp cassandra* ${tmp_dir}/cassandra-dist-dev/${release}/debian/"
    fi

    execute "cd ${tmp_dir}/cassandra-dist-dev/${release}/debian/"
    # Debsign might ask the passphrase on stdin so don't hide what he says even if no verbose
    # (I haven't tested carefully but I've also seen it fail unexpectedly with it's output redirected.
    execute "debsign -k$gpg_key cassandra_${deb_release}_amd64.changes" 1>&3 2>&4

    echo "Building debian repository ..." 1>&3 2>&4
    debian_series="${release_major}${release_minor}x"

    echo "Origin: Apache Cassandra Packages" > $tmp_dir/distributions
    echo "Label: Apache Cassandra Packages" >> $tmp_dir/distributions
    echo "Codename: $debian_series" >> $tmp_dir/distributions
    echo "Architectures: i386 amd64 arm64 source" >> $tmp_dir/distributions
    echo "Components: main" >> $tmp_dir/distributions
    echo "Description: Apache Cassandra APT Repository" >> $tmp_dir/distributions
    echo "SignWith: $gpg_key" >> $tmp_dir/distributions

    execute "mkdir conf"
    execute "mv $tmp_dir/distributions conf/"
    execute "reprepro --ignore=wrongdistribution include $debian_series cassandra_${deb_release}_*.changes"
    execute "rm -R db conf"

    execute "cd $tmp_dir"
    execute "svn add --force cassandra-dist-dev/${release}/debian"
    echo "staging cassandra debian packages for $release" > "_tmp_msg_"
    execute "svn ci -F _tmp_msg_ cassandra-dist-dev/${release}/debian"
    execute "cd $current_dir"
fi

## RPM Stuff ##

if [ $only_deb -eq 0 ]
then

    execute "cd $tmp_dir"
    execute "svn co https://dist.apache.org/repos/dist/dev/cassandra cassandra-dist-dev"

    # "regular" RPMs
    execute "mkdir -p $rpm_package_dir"
    execute "cd $rpm_package_dir"

    echo "Building redhat packages ..." 1>&3 2>&4
    execute "mkdir $tmp_dir/cassandra-dist-dev/${release}/redhat"

    [ $fake_mode -eq 1 ] && echo ">> declare -x rpm_dir=$rpm_package_dir/cassandra_${release}_rpm"
    declare -x rpm_dir=$rpm_package_dir/cassandra_${release}_rpm
    [ ! -e "$rpm_dir" ] || rm -rf $rpm_dir
    execute "mkdir $rpm_dir"

    if [ -f ${tmp_dir}/cassandra/.build/docker/build-redhat.sh ] ; then
        execute "cd ${tmp_dir}/cassandra"
        execute "ant realclean"
        execute ".build/docker/build-redhat.sh rpm"
        execute "cp build/*.rpm  ${tmp_dir}/cassandra-dist-dev/${release}/redhat/"
    else
        execute "${cassandra_builds_dir}/build-scripts/cassandra-rpm-packaging.sh ${release}-tentative 8 rpm"
        execute "cp ${rpm_dir}/*.rpm  ${tmp_dir}/cassandra-dist-dev/${release}/redhat/"
    fi

    execute "cd ${tmp_dir}/cassandra-dist-dev/${release}/redhat/"
    execute "rpmsign --addsign *.rpm"

    # build repositories
    echo "Building redhat repository ..." 1>&3 2>&4
    execute "createrepo_c ."
    # FIXME - put into execute "…"
    [ $fake_mode -eq 1 ] || for f in repodata/repomd.xml repodata/*.bz2 repodata/*.gz ; do gpg --detach-sign --armor $f ; done


    # noboolean RPMs
    if [ -d "$current_dir/redhat/noboolean" ]; then
        execute "cd $tmp_dir"

        execute "mkdir -p $rpmnoboolean_package_dir"
        execute "cd $rpmnoboolean_package_dir"

        echo "Building redhat noboolean packages ..." 1>&3 2>&4
        execute "mkdir ${tmp_dir}/cassandra-dist-dev/${release}/redhat/noboolean"

        [ $fake_mode -eq 1 ] && echo ">> declare -x rpm_dir=$rpmnoboolean_package_dir/cassandra_${release}_rpmnoboolean"
        declare -x rpm_dir=$rpmnoboolean_package_dir/cassandra_${release}_rpmnoboolean
        [ ! -e "$rpm_dir" ] || rm -rf $rpm_dir
        execute "mkdir $rpm_dir"

        if [ -f ${tmp_dir}/cassandra/.build/docker/build-redhat.sh ] ; then
            execute "cd ${tmp_dir}/cassandra"
            execute "ant realclean"
            execute ".build/docker/build-redhat.sh noboolean"
            execute "cp build/*.rpm  ${tmp_dir}/cassandra-dist-dev/${release}/redhat/noboolean/"
        else
            execute "${cassandra_builds_dir}/build-scripts/cassandra-rpm-packaging.sh ${release}-tentative 8 noboolean"
            execute "cp ${rpm_dir}/*.rpm  ${tmp_dir}/cassandra-dist-dev/${release}/redhat/noboolean/"
        fi

        execute "cd ${tmp_dir}/cassandra-dist-dev/${release}/redhat/noboolean"
        execute "rpmsign --addsign *.rpm"

        # build repositories
        echo "Building redhat noboolean repository ..." 1>&3 2>&4
        execute "createrepo_c ."
        # FIXME - put into execute "…"
        [ $fake_mode -eq 1 ] || for f in repodata/repomd.xml repodata/*.bz2 repodata/*.gz ; do gpg --detach-sign --armor $f ; done
    fi

    execute "cd $tmp_dir"
    execute "svn add --force cassandra-dist-dev/${release}/redhat"
    echo "staging cassandra rpm packages for $release" > "_tmp_msg_"
    execute "svn ci -F _tmp_msg_ cassandra-dist-dev/${release}/redhat"
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

    echo "[ANNOUNCE] Apache Cassandra $release test artifact available" > $mail_test_announce_file
    echo "" >> $mail_test_announce_file
    echo "The test build of Cassandra ${release} is available." >> $mail_test_announce_file
    echo "" >> $mail_test_announce_file
    echo "sha1: $head_commit" >> $mail_test_announce_file
    echo "Git: https://github.com/apache/cassandra/tree/$release-tentative" >> $mail_test_announce_file
    echo "Maven Artifacts: $staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/cassandra-all/$release/" >> $mail_test_announce_file
    echo "" >> $mail_test_announce_file
    echo "The Source and Build Artifacts, and the Debian and RPM packages and repositories, are available here: https://dist.apache.org/repos/dist/dev/cassandra/$release/" >> $mail_test_announce_file
    echo "" >> $mail_test_announce_file
    echo "A vote of this test build will be initiated within the next couple of days." >> $mail_test_announce_file
    echo "" >> $mail_test_announce_file
    echo "[1]: CHANGES.txt: https://github.com/apache/cassandra/blob/$release-tentative/CHANGES.txt" >> $mail_test_announce_file
    echo "[2]: NEWS.txt: https://github.com/apache/cassandra/blob/$release-tentative/NEWS.txt" >> $mail_test_announce_file

    echo "Test announcement mail written to $mail_test_announce_file"


    echo "[VOTE] Release Apache Cassandra $release" > $mail_vote_file
    echo "" >> $mail_vote_file
    echo "Proposing the test build of Cassandra ${release} for release." >> $mail_vote_file
    echo "" >> $mail_vote_file
    echo "sha1: $head_commit" >> $mail_vote_file
    echo "Git: https://github.com/apache/cassandra/tree/$release-tentative" >> $mail_vote_file
    echo "Maven Artifacts: $staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/cassandra-all/$release/" >> $mail_vote_file
    echo "" >> $mail_vote_file
    echo "The Source and Build Artifacts, and the Debian and RPM packages and repositories, are available here: https://dist.apache.org/repos/dist/dev/cassandra/$release/" >> $mail_vote_file
    echo "" >> $mail_vote_file
    echo "The vote will be open for 72 hours (longer if needed). Everyone who has tested the build is invited to vote. Votes by PMC members are considered binding. A vote passes if there are at least three binding +1s and no -1's." >> $mail_vote_file
    echo "" >> $mail_vote_file
    echo "[1]: CHANGES.txt: https://github.com/apache/cassandra/blob/$release-tentative/CHANGES.txt" >> $mail_vote_file
    echo "[2]: NEWS.txt: https://github.com/apache/cassandra/blob/$release-tentative/NEWS.txt" >> $mail_vote_file

    echo "Vote mail written to $mail_vote_file"
fi


echo "Done cutting and staging release artifacts. Please make sure to:"
echo " 1) verify all staged artifacts"
echo " 2) forward merge and atomic push the debian/changelog commit"
echo " 3) email the announcement email"
echo " 4) after a couple of days, email the vote email"
