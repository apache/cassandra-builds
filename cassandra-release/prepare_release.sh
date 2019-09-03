#!/bin/bash

##### TO EDIT #####

asf_username="$USER"
gpg_key="XXXXXXXX"

# The name of remote for the asf remote in your git repo
git_asf_remote="origin"

# Where you want to put the mail draft that this script generate
mail_dir="$HOME/Mail"

# Where you want to put the debian files
debian_package_dir="$HOME/tmp/debian"

###################

asf_git_repo="https://gitbox.apache.org/repos/asf"
staging_repo="https://repository.apache.org/content/repositories"
apache_host="people.apache.org"

# Reset getopts in case it has been used previously in the shell.
OPTIND=1

# Initialize our own variables:
verbose=0
fake_mode=0
only_deb=0

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
    echo ""
    echo "Example: $name 2.0.3"
}

while getopts ":hvfd" opt; do
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
    \?)
        echo "Invalid option: -$OPTARG" >&2
        show_help
        exit 1
        ;;
    esac
done

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

head_commit=`git log --pretty=oneline -1 | cut - -d " " -f 1`

if [ "$release" == "$deb_release" ]
then
    echo "Preparing release for $release from commit:"
else
    echo "Preparing release for $release (debian will use $deb_release) from commit:"
fi
echo ""
git show $head_commit

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
    # Not verbose, redirect all ouptut to a logfile 
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
# This appear to be the simpler way to make this work for both linux and OSX (http://goo.gl/9RKld3)
tmp_dir=`mktemp -d 2>/dev/null || mktemp -d -t 'release'`

if [ $only_deb -eq 0 ]
then
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
    execute "ant publish -Drelease=true -Dbase.version=$release"

    echo "Artifacts uploaded, please close release on repository.apache.org and indicate the staging number:" 1>&3 2>&4
else
    echo "Please indicate staging number:" 1>&3 2>&4
fi

read -p "staging number? " staging_number 1>&3 2>&4

## Debian Stuffs ##

execute "cd $debian_package_dir"

deb_dir=cassandra_${release}_debian
[ ! -e "$deb_dir" ] || rm -rf $deb_dir
execute "mkdir $deb_dir"
execute "cd $deb_dir"

echo "Building debian package ..." 1>&3 2>&4

execute "wget $staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/apache-cassandra/$release/apache-cassandra-$release-src.tar.gz"
execute "mv apache-cassandra-$release-src.tar.gz cassandra_${deb_release}.orig.tar.gz"
execute "tar xvzf cassandra_${deb_release}.orig.tar.gz"
execute "cd apache-cassandra-${release}-src"
execute "dpkg-buildpackage -rfakeroot -us -uc"
execute "cd .."
# Debsign might ask the passphrase on stdin so don't hide what he says even if no verbose
# (I haven't tested carefully but I've also seen it fail unexpectedly with it's output redirected.
execute "debsign -k$gpg_key cassandra_${deb_release}_amd64.changes" 1>&3 2>&4

echo "Uploading debian package ..." 1>&3 2>&4

cat > /tmp/sftpbatch.txt <<EOF
cd public_html
put cassandra* 
EOF


execute "sftp -b /tmp/sftpbatch.txt ${asf_username}@${apache_host}"

execute "cd $current_dir"

# Restore stdout/stderr (and close temporary descriptors) if not verbose
[ $verbose -eq 1 ] || exec 1>&3 3>&- 2>&4 4>&-

# Cleaning up
rm -rf $tmp_dir

## Email for vote ##

mail_file="$mail_dir/mail_vote_$release"
[ ! -e "$mail_file" ] || rm $mail_file

echo "[VOTE] Release Apache Cassandra $release" > $mail_file
echo "" >> $mail_file
echo "I propose the following artifacts for release as $release." >> $mail_file
echo "" >> $mail_file
echo "sha1: $head_commit" >> $mail_file
echo "Git: $asf_git_repo?p=cassandra.git;a=shortlog;h=refs/tags/$release-tentative" >> $mail_file
echo "Artifacts: $staging_repo/orgapachecassandra-$staging_number/org/apache/cassandra/apache-cassandra/$release/" >> $mail_file
echo "Staging repository: $staging_repo/orgapachecassandra-$staging_number/" >> $mail_file
echo "" >> $mail_file
echo "The Debian and RPM packages are available here: http://$apache_host/~$asf_username" >> $mail_file
echo "" >> $mail_file
echo "The vote will be open for 72 hours (longer if needed)." >> $mail_file
echo "" >> $mail_file
echo "[1]: CHANGES.txt: $asf_git_repo?p=cassandra.git;a=blob_plain;f=CHANGES.txt;hb=refs/tags/$release-tentative" >> $mail_file
echo "[2]: NEWS.txt: $asf_git_repo?p=cassandra.git;a=blob_plain;f=CHANGES.txt;hb=refs/tags/$release-tentative" >> $mail_file

echo "Mail written to $mail_file"
