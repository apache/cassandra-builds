#!/bin/bash

##### TO EDIT #####

asf_username="${asf_username:-$USER}"

ARTIFACTORY_API_KEY="${ARTIFACTORY_API_KEY:-XXXXXXXX}"

if [ "x$ARTIFACTORY_API_KEY" = "xXXXXXXXX" ]; then
    exit -e "Get your jfrog artifactory API Key from https://apache.jfrog.io/ui/admin/artifactory/user_profile and set ARTIFACTORY_API_KEY to it"
fi

# The name of remote for the asf remote in your git repo
git_asf_remote="${git_asf_remote:-origin}"

if [ "x${git_asf_remote}" != "xorigin" ] ; then
  echo "Using git ASF remote ${git_asf_remote}"
fi

mail_dir="$HOME/Mail"

###################
# prerequisites
command -v svn >/dev/null 2>&1 || { echo >&2 "subversion needs to be installed"; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "git needs to be installed"; exit 1; }

###################

asf_git_repo="${asf_git_repo:-git@github.com:apache/cassandra-analytics.git}"

if [ "x${asf_git_repo}" != "xgit@github.com:apache/cassandra-analytics.git" ] ; then
    echo "Using ASF git repo ${asf_git_repo}"
fi

# Reset getopts in case it has been used previously in the shell.
OPTIND=1

# Initialize our own variables:
verbose=0
fake_mode=0

show_help()
{
    local name=`basename $0`
    echo "$name [options] <release_version>"
    echo ""
    echo "where [options] are:"
    echo "  -h: print this help"
    echo "  -v: verbose mode (show everything that is going on)"
    echo "  -f: fake mode, print any output but don't do anything (for debugging)"
    echo ""
    echo "Example: $name 1.0.0"
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

if [ "$release" == "$deb_release" ]
then
    echo "Publishing Analytics release $release"
else
    echo "Publishing Analytics release $release (debian uses $deb_release)"
fi

# "Saves" stdout to other descriptor since we might redirect them below
exec 3>&1 4>&2

if [ $verbose -eq 0 ]
then
    # Not verbose, redirect all output to a logfile
    logfile="release-${release}.log"
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

echo "Deploying artifacts ..." 1>&3 2>&4
cassandra_dir=$PWD

#
# Rename the git tag, removing the -tentative suffix
#

execute "cd $cassandra_dir"

echo "Tagging release ..." 1>&3 2>&4
execute "git checkout $release-tentative"

# Ugly but somehow 'execute "git tag -a cassandra-analytics-$release -m 'Apache Cassandra $release release' "' doesn't work
echo "Apache Cassandra Analytics $release release" > "_tmp_msg_"
execute "git tag -a cassandra-analytics-$release -F _tmp_msg_"
rm _tmp_msg_
execute "git push $git_asf_remote refs/tags/cassandra-analytics-$release"
execute "git tag -d $release-tentative"
execute "git push $git_asf_remote :refs/tags/$release-tentative"

#
# Move staging artifacts to release distribution location
#

tmp_dir=`mktemp -d`
cd $tmp_dir
echo "Apache Cassandra Analytics $release release" > "_tmp_msg_"
execute "svn mv -F _tmp_msg_ https://dist.apache.org/repos/dist/dev/cassandra/cassandra-analytics/${release} https://dist.apache.org/repos/dist/release/cassandra/cassandra-analytics/"
rm _tmp_msg_

# Cleaning up
execute "cd $cassandra_dir"
rm -rf $tmp_dir

# Restore stdout/stderr (and close temporary descriptors) if not verbose
[ $verbose -eq 1 ] || exec 1>&3 3>&- 2>&4 4>&-

mail_file="$mail_dir/mail_release_$release"
[ ! -e "$mail_file" ] || rm $mail_file

echo "[RELEASE] Apache Cassandra Analytics $release released" > $mail_file
echo "" >> $mail_file
echo "The Cassandra team is pleased to announce the release of Apache Analytics Cassandra version $release." >> $mail_file
echo "" >> $mail_file
echo "" >> $mail_file
echo "Downloads of source and binary distributions are available here:" >> $mail_file
echo "" >> $mail_file
echo " https://dlcdn.apache.org/cassandra/cassandra-analytics/$release/" >> $mail_file
echo "" >> $mail_file
echo "" >> $mail_file
echo "The Maven artifacts can be found at: " >> $mail_file
echo "" >> $mail_file
echo " https://repo.maven.apache.org/maven2/org/apache/cassandra/" >> $mail_file
echo "" >> $mail_file
echo "These will be mirrored to other repositories." >> $mail_file
echo "" >> $mail_file
echo "" >> $mail_file
echo "As always, please review the changes[1] and pay attention to the release notes[2]. Let us know[3] if you were to encounter any problem." >> $mail_file
echo "" >> $mail_file
echo "" >> $mail_file
echo 'Enjoy!' >> $mail_file
echo "" >> $mail_file
echo "[1]: CHANGES.txt https://github.com/apache/cassandra-analytics/blob/cassandra-analytics-$release/CHANGES.txt" >> $mail_file
echo "[2]: NEWS.txt https://github.com/apache/cassandra-analytics/blob/cassandra-analytics-$release/NEWS.txt" >> $mail_file
echo "[3]: https://issues.apache.org/jira/browse/CASSANALYTICS" >> $mail_file


echo 'Done deploying artifacts. Please make sure to:'
echo ' 1) "Release" the staging repository from repository.apache.org'
echo ' 2) update the website (TODO provide link)'  # TODO - this is old info and needs updating..
echo " 3) send announcement email: draft in $mail_file"
echo ' 4) tweet from @cassandra'
echo ' 5) release version in JIRA'
echo ' 6) remove old version (eg: `svn rm https://dist.apache.org/repos/dist/release/cassandra/cassandra-analytics/<previous_version>`)'
echo ' 7) increment gradle.properties (version) and CHANGES.txt'
echo ' 8) Add release in https://reporter.apache.org/addrelease.html?cassandra (same as instructions in email you will receive from the \"Apache Reporter Service\")'
