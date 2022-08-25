#!/bin/bash

##### TO EDIT #####

asf_username="$USER"

if [ -z "$ARTIFACTORY_API_KEY" ]; then
    ARTIFACTORY_API_KEY="XXXXXXXX"
fi

if [ "$ARTIFACTORY_API_KEY" = "XXXXXXXX" ]; then
    exit -e "Get your jfrog artifactory API Key from https://apache.jfrog.io/ui/admin/artifactory/user_profile and set ARTIFACTORY_API_KEY to it"
fi

# The name of remote for the asf remote in your git repo
git_asf_remote="origin"

mail_dir="$HOME/Mail"

###################
# prerequisites
command -v svn >/dev/null 2>&1 || { echo >&2 "subversion needs to be installed"; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "git needs to be installed"; exit 1; }

###################

asf_git_repo="https://gitbox.apache.org/repos/asf"

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
    echo "Example: $name 2.0.3"
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

if [ "$release" == "$deb_release" ]
then
    echo "Publishing release $release"
else
    echo "Publishing release $release (debian uses $deb_release)"
fi

# "Saves" stdout to other descriptor since we might redirect them below
exec 3>&1 4>&2

if [ $verbose -eq 0 ]
then
    # Not verbose, redirect all ouptut to a logfile
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
# Rename the git tag, removing the -tenative suffix
#

execute "cd $cassandra_dir"

echo "Tagging release ..." 1>&3 2>&4
execute "git checkout $release-tentative"

# Ugly but somehow 'execute "git tag -a cassandra-$release -m 'Apache Cassandra $release release' "' doesn't work
echo "Apache Cassandra $release release" > "_tmp_msg_"
execute "git tag -a cassandra-$release -F _tmp_msg_"
rm _tmp_msg_
execute "git push $git_asf_remote refs/tags/cassandra-$release"
execute "git tag -d $release-tentative"
execute "git push $git_asf_remote :refs/tags/$release-tentative"

#
# Move staging artifacts to release distribution location
#

tmp_dir=`mktemp -d`
cd $tmp_dir
echo "Apache Cassandra $release release" > "_tmp_msg_"
execute "svn mv -F _tmp_msg_ https://dist.apache.org/repos/dist/dev/cassandra/$release https://dist.apache.org/repos/dist/release/cassandra/"
rm _tmp_msg_

#
# Determine deb/rpm repo series
#

idx=`expr index "$release" -`
if [ $idx -eq 0 ]
then
    release_short=${release}
else
    release_short=${release:0:$((idx-1))}
fi
release_major=$(echo ${release_short} | cut -d '.' -f 1)
release_minor=$(echo ${release_short} | cut -d '.' -f 2)
repo_series="${release_major}${release_minor}x"

#
# Public deploy the Debian packages
#

echo "Deploying debian packages ..." 1>&3 2>&4

# Upload to ASF jfrog artifactory
debian_dist_dir=$tmp_dir/cassandra-dist-$release-debian
execute "svn co https://dist.apache.org/repos/dist/release/cassandra/$release/debian $debian_dist_dir"
[ -e "$debian_dist_dir" ] || mkdir $debian_dist_dir # create it for fake mode, to satisfy `find …` command below
execute "cd $debian_dist_dir"

ROOTLEN=$(( ${#debian_dist_dir} + 1))

for i in $(find ${debian_dist_dir}/ -mindepth 2 -type f -mtime -10 -not -path "*/.svn/*" -printf "%T@ %p\n" | sort -n -r | cut -d' ' -f 2); do
    IFILE=`echo $(basename -- "$i") | cut -c 1`
    if [[ $IFILE != "." ]];
    then
    	FDIR=`echo $i | cut -c ${ROOTLEN}-${#i}`
    	echo "Uploading $FDIR"
        execute "curl -X PUT -T $i -u${asf_username}:${ARTIFACTORY_API_KEY} https://apache.jfrog.io/artifactory/cassandra/${FDIR}?override=1"
        execute "curl -X PUT -T $i -u${asf_username}:${ARTIFACTORY_API_KEY} https://apache.jfrog.io/artifactory/cassandra-deb/${FDIR}?override=1"
    	sleep 1
    fi
done
cd $tmp_dir

# Remove dist debian directory. Official download location is https://debian.cassandra.apache.org
echo "Apache Cassandra $release debian artifacts" > "_tmp_msg_"
execute "svn rm -F _tmp_msg_ https://dist.apache.org/repos/dist/release/cassandra/$release/debian"

#
# Public deploy the RedHat packages
#

echo "Deploying redhat packages ..." 1>&3 2>&4

# Upload to ASF jfrog artifactory
redhat_dist_dir=$tmp_dir/cassandra-dist-$release-redhat
execute "svn co https://dist.apache.org/repos/dist/release/cassandra/$release/redhat $redhat_dist_dir"
[ -e "$redhat_dist_dir" ] || mkdir $redhat_dist_dir # create it for fake mode, to satisfy `find …` command below
execute "cd $redhat_dist_dir"

ROOTLEN=$(( ${#redhat_dist_dir} + 1))

for i in $(find ${redhat_dist_dir} -mindepth 1 -type f -mtime -10 -not -path "*/.svn/*" -printf "%T@ %p\n" | sort -n -r | cut -d' ' -f 2); do
    IFILE=`echo $(basename -- "$i") | cut -c 1`
    if [[ $IFILE != "." ]];
    then
        FDIR=`echo $i | cut -c ${ROOTLEN}-${#i}`
        echo "Uploading $FDIR"
        execute "curl -X PUT -T $i -u${asf_username}:${ARTIFACTORY_API_KEY} https://apache.jfrog.io/artifactory/cassandra-rpm/${repo_series}/${FDIR}?override=1"
        sleep 1
    fi
done
cd $tmp_dir

# Remove dist redhat directory. Official download location is https://redhat.cassandra.apache.org
echo "Apache Cassandra $release redhat artifacts" > "_tmp_msg_"
execute "svn rm -F _tmp_msg_ https://dist.apache.org/repos/dist/release/cassandra/$release/redhat"

# Cleaning up
execute "cd $cassandra_dir"
rm -rf $tmp_dir

# Restore stdout/stderr (and close temporary descriptors) if not verbose
[ $verbose -eq 1 ] || exec 1>&3 3>&- 2>&4 4>&-

mail_file="$mail_dir/mail_release_$release"
[ ! -e "$mail_file" ] || rm $mail_file

echo "[RELEASE] Apache Cassandra $release released" > $mail_file
echo "" >> $mail_file
echo "The Cassandra team is pleased to announce the release of Apache Cassandra version $release." >> $mail_file
echo "" >> $mail_file
echo "Apache Cassandra is a fully distributed database. It is the right choice when you need scalability and high availability without compromising performance." >> $mail_file
echo "" >> $mail_file
echo " http://cassandra.apache.org/" >> $mail_file
echo "" >> $mail_file
echo "Downloads of source and binary distributions are listed in our download section:" >> $mail_file
echo "" >> $mail_file
echo " http://cassandra.apache.org/download/" >> $mail_file
echo "" >> $mail_file
series="${release_major}.${release_minor}"
echo "This version is a bug fix release[1] on the $series series. As always, please pay attention to the release notes[2] and Let us know[3] if you were to encounter any problem." >> $mail_file
echo "" >> $mail_file
series="${release_major}.${release_minor}"
echo "[WARNING] Debian and RedHat package repositories have moved! Debian /etc/apt/sources.list.d/cassandra.sources.list and RedHat /etc/yum.repos.d/cassandra.repo files must be updated to the new repository URLs. For Debian it is now https://debian.cassandra.apache.org . For RedHat it is now https://redhat.cassandra.apache.org/${repo_series}/ ." >> $mail_file
echo "" >> $mail_file
echo "Enjoy!" >> $mail_file
echo "" >> $mail_file
echo "[1]: CHANGES.txt $asf_git_repo?p=cassandra.git;a=blob_plain;f=CHANGES.txt;hb=refs/tags/cassandra-$release" >> $mail_file
echo "[2]: NEWS.txt $asf_git_repo?p=cassandra.git;a=blob_plain;f=NEWS.txt;hb=refs/tags/cassandra-$release" >> $mail_file
echo "[3]: https://issues.apache.org/jira/browse/CASSANDRA" >> $mail_file


echo 'Done deploying artifacts. Please make sure to:'
echo ' 1) "Release" the staging repository from repository.apache.org'
echo ' 2) wait for the artifacts to sync at https://downloads.apache.org/cassandra/'
echo ' 3) update the website (TODO provide link)'  # TODO - this is old info and needs updating..
echo ' 4) update CQL doc if appropriate'
echo ' 5) update wikipedia page if appropriate ( https://en.wikipedia.org/wiki/Apache_Cassandra )'
echo " 6) send announcement email: draft in $mail_file"
echo ' 7) update #cassandra topic on slack'
echo ' 8) tweet from @cassandra'
echo ' 9) release version in JIRA'
echo ' 10) remove old version (eg: `svn rm https://dist.apache.org/repos/dist/release/cassandra/<previous_version>`)'
echo ' 11) increment build.xml base.version for the next release'
echo ' 12) follow instructions in email you will receive from the \"Apache Reporter Service\" to update the project`s list of releases in reporter.apache.org'
