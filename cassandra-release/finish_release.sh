#!/bin/bash

##### TO EDIT #####

asf_username="$USER"

# The name of remote for the asf remote in your git repo
git_asf_remote="origin"

# Same as for .prepare_release.sh
mail_dir="$HOME/Mail"
debian_package_dir="$HOME/tmp/debian"

# The directory for reprepro
reprepro_dir="$debian_package_dir/packages"
artifacts_svn_dir="$HOME/svn/cassandra-dist"

###################

asf_git_repo="http://git-wip-us.apache.org/repos/asf"
apache_host="people.apache.org"

# Reset getopts in case it has been used previously in the shell.
OPTIND=1

# Initialize our own variables:
verbose=0
fake_mode=0

show_help()
{
    local name=`basename $0`
    echo "$name [options] <release_version> <staging_number>"
    echo ""
    echo "where [options] are:"
    echo "  -h: print this help"
    echo "  -v: verbose mode (show everything that is going on)"
    echo "  -f: fake mode, print any output but don't do anything (for debugging)"
    echo ""
    echo "Example: $name 2.0.3 1024"
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
staging_number=$2
deb_release=${release/-/\~}

if [ -z "$release" ]
then
    echo "Missing argument <release_version>"
    show_help
    exit 1
fi
if [ -z "$staging_number" ]
then
    echo "Missing argument <staging_number>"
    show_help
    exit 1
fi

if [ "$#" -gt 2 ]
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
    echo "Publishing release $release using staging number $staging_number"
else
    echo "Publishing release $release (debian uses $deb_release) using staging number $staging_number"
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

idx=`expr index "$release" -`
if [ $idx -eq 0 ]
then
    release_short=${release}
else
    release_short=${release:0:$((idx-1))}
fi

echo "Deploying artifacts ..." 1>&3 2>&4
start_dir=$PWD
cd $artifacts_svn_dir
mkdir $release_short
cd $release_short
for type in bin src; do
    for part in gz gz.md5 gz.sha1 gz.asc gz.asc.md5 gz.asc.sha1; do
        echo "Downloading apache-cassandra-${release}-$type.tar.$part..." 1>&3 2>&4
        curl -O https://repository.apache.org/content/repositories/orgapachecassandra-${staging_number}/org/apache/cassandra/apache-cassandra/${release}/apache-cassandra-${release}-$type.tar.$part
    done
done

cd $start_dir

echo "Tagging release ..." 1>&3 2>&4
execute "git checkout $release-tentative"

# Ugly but somehow 'execute "git tag -a cassandra-$release -m 'Apache Cassandra $release release' "' doesn't work
echo "Apache Cassandra $release release" > "_tmp_msg_"
execute "git tag -a cassandra-$release -F _tmp_msg_"
rm _tmp_msg_
execute "git push $git_asf_remote refs/tags/cassandra-$release"
execute "git tag -d $release-tentative"
execute "git push $git_asf_remote :refs/tags/$release-tentative"

echo "Deploying debian packages ..." 1>&3 2>&4

current_dir=`pwd`

debian_series="${release_short:0:1}${release_short:2:2}x"

execute "cd $reprepro_dir"
execute "reprepro --ignore=wrongdistribution include $debian_series $debian_package_dir/cassandra_${release}_debian/cassandra_${deb_release}_*.changes"
execute "cp -p pool/main/c/cassandra/cassandra*_${deb_release}* ${artifacts_svn_dir}/debian/pool/main/c/cassandra"
execute "cp -p ${artifacts_svn_dir}/$release_short/apache-cassandra-${release}-src.tar.gz.asc ${artifacts_svn_dir}/debian/pool/main/c/cassandra/cassandra_${deb_release}.orig.tar.gz.asc"
execute "cp -a dists/$debian_series ${artifacts_svn_dir}/debian/dists"

execute "cd $current_dir"

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
series="${release_short:0:1}.${release_short:2:1}"
echo "This version is a bug fix release[1] on the $series series. As always, please pay attention to the release notes[2] and Let us know[3] if you were to encounter any problem." >> $mail_file
echo "" >> $mail_file
echo "Enjoy!" >> $mail_file
echo "" >> $mail_file
echo "[1]: (CHANGES.txt)" >> $mail_file
echo "[2]: (NEWS.txt)" >> $mail_file
echo "[3]: https://issues.apache.org/jira/browse/CASSANDRA" >> $mail_file


echo "Done deploying artifacts. Please make sure to:"
echo " 0) commit changes to ${artifacts_svn_dir}"
echo " 1) release artifacts from repository.apache.org"
echo " 2) wait for the artifacts to sync at http://www.apache.org/dist/cassandra/"
echo " 3) upload debian repo to bintray: ./upload_bintray.sh ${artifacts_svn_dir}/debian"
echo " 4) update the website (~/Git/hyde/hyde.py -g -s src/ -d publish/)"  # TODO - this is old info and needs updating..
echo " 5) update CQL doc if appropriate"
echo " 6) update wikipedia page if appropriate"
echo " 7) send announcement email: draft in $mail_dir/mail_release_$release, misses short links for"
echo "    > CHANGES.txt: $asf_git_repo?p=cassandra.git;a=blob_plain;f=CHANGES.txt;hb=refs/tags/cassandra-$release"
echo "    > NEWS.txt:    $asf_git_repo?p=cassandra.git;a=blob_plain;f=NEWS.txt;hb=refs/tags/cassandra-$release"
echo " 8) update #cassandra topic on irc (/msg chanserv op #cassandra)"
echo " 9) tweet from @cassandra"
echo " 10) release version in JIRA"
echo " 11) remove old version from people.apache.org (in /www/www.apache.org/dist/cassandra and debian)"
echo " 12) increment build.xml base.version for the next release"

