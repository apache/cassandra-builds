#!/bin/bash

# Parameters
# $1 release
# $2 maven artefacts url number (as specified in the vote email)
#
# Example use: `./cassandra-check-release.sh 4.0-beta3 1224
#
# This script is very basic and experimental. I beg of you to help improve it.
#

###################
# prerequisites

command -v wget >/dev/null 2>&1 || { echo >&2 "wget needs to be installed"; exit 1; }
command -v gpg >/dev/null 2>&1 || { echo >&2 "gpg needs to be installed"; exit 1; }
command -v sha1sum >/dev/null 2>&1 || { echo >&2 "sha1sum needs to be installed"; exit 1; }
command -v md5sum >/dev/null 2>&1 || { echo >&2 "md5sum needs to be installed"; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo >&2 "sha256sum needs to be installed"; exit 1; }
command -v sha512sum >/dev/null 2>&1 || { echo >&2 "sha512sum needs to be installed"; exit 1; }
command -v tar >/dev/null 2>&1 || { echo >&2 "tar needs to be installed"; exit 1; }
command -v ant >/dev/null 2>&1 || { echo >&2 "ant needs to be installed"; exit 1; }
command -v timeout >/dev/null 2>&1 || { echo >&2 "timeout needs to be installed"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo >&2 "docker needs to be installed"; exit 1; }
(docker info >/dev/null 2>&1) || { echo >&2 "docker needs to running"; exit 1; }
(java -version 2>&1 | grep -q "1.8") || { echo >&2 "Java 8 must be used"; exit 1; }
(java -version 2>&1 | grep -iq jdk ) || { echo >&2 "Java JDK must be used"; exit 1; }
(curl --output /dev/null --silent --head --fail "https://dist.apache.org/repos/dist/dev/cassandra/$1/") || { echo >&2 "Not Found: https://dist.apache.org/repos/dist/dev/cassandra/$1/"; exit 1; }
(curl --output /dev/null --silent --head --fail "https://repository.apache.org/content/repositories/orgapachecassandra-$2/org/apache/cassandra/cassandra-all/$1") || { echo >&2 "Not Found: https://repository.apache.org/content/repositories/orgapachecassandra-$2/org/apache/cassandra/cassandra-all/$1"; exit 1; }

###################

mkdir -p /tmp/$1
cd /tmp/$1
echo "Downloading KEYS"
wget -q https://downloads.apache.org/cassandra/KEYS
echo "Downloading https://repository.apache.org/content/repositories/orgapachecassandra-$2/org/apache/cassandra/cassandra-all/$1"
wget -Nqnd -e robots=off --recursive --no-parent https://repository.apache.org/content/repositories/orgapachecassandra-$2/org/apache/cassandra/cassandra-all/$1
echo "Downloading https://dist.apache.org/repos/dist/dev/cassandra/$1/"
wget -Nqe robots=off --recursive --no-parent https://dist.apache.org/repos/dist/dev/cassandra/$1/

echo
echo "====== CHECK RESULTS ======"
echo

gpg --import KEYS

(compgen -G "*.asc" >/dev/null) || { echo >&2 "No *.asc files found in $(pwd)"; exit 1; }
for f in *.asc ; do gpg --verify $f ; done
(compgen -G "*.pom" >/dev/null) || { echo >&2 "No *.pom files found in $(pwd)"; exit 1; }
(compgen -G "*.jar" >/dev/null) || { echo >&2 "No *.jar files found in $(pwd)"; exit 1; }
for f in *.pom *.jar *.asc ; do echo -n "sha1: " ; echo "$(cat $f.sha1) $f" | sha1sum -c ; echo -n "md5: " ; echo "$(cat $f.md5) $f" | md5sum -c ; done

cd dist.apache.org/repos/dist/dev/cassandra/$1
(compgen -G "*.asc" >/dev/null) || { echo >&2 "No *.asc files found in $(pwd)"; exit 1; }
for f in *.asc ; do gpg --verify $f ; done
(compgen -G "*.gz" >/dev/null) || { echo >&2 "No *.gz files found in $(pwd)"; exit 1; }
(compgen -G "*.sha256" >/dev/null) || { echo >&2 "No *.sha256 files found in $(pwd)"; exit 1; }
(compgen -G "*.sha512" >/dev/null) || { echo >&2 "No *.sha512 files found in $(pwd)"; exit 1; }
for f in *.gz ; do echo -n "sha256: " ; echo "$(cat $f.sha256) $f" | sha256sum -c ; echo -n "sha512:" ; echo "$(cat $f.sha512) $f" | sha512sum -c ; done

echo
rm -fR apache-cassandra-$1-src
tar -xzf apache-cassandra-$1-src.tar.gz
rm -fR apache-cassandra-$1
tar -xzf apache-cassandra-$1-bin.tar.gz

JDKS="8"
if [[ $1 =~ [4]\. ]] ; then
    JDKS=("8" "11")
elif [[ $1 =~ [5]\. ]] ; then
    JDKS=("11" "17")
fi

for JDK in ${JDKS[@]} ; do

    # test source tarball build

    if [ "$JDK" == "11" ] ; then
        BUILD_OPT="-Duse.jdk11=true"
    fi
    echo
    rm -f procfifo
    mkfifo procfifo
    docker run -i -v `pwd`/apache-cassandra-$1-src:/apache-cassandra-$1-src openjdk:${JDK}-jdk-slim-buster timeout 2160 /bin/bash -c "
        ( apt -qq update;
          apt -qq install -y ant build-essential git python procps ) 2>&1 >/dev/null;
        cd apache-cassandra-$1-src ;
        ant artifacts ${BUILD_OPT}" 2>&1 >procfifo &

    PID=$!
    success=false
    while read LINE && ! $success ; do
        if [[ $LINE =~ 'BUILD SUCCESSFUL' ]] ; then
            echo "Source build (JDK ${JDK}) OK"
            kill "$PID"
            success=true
        fi
    done < procfifo
    rm -f procfifo
    wait "$PID"
    if ! $success ; then
        echo "Source build (JDK ${JDK}) FAILED"
    fi

    # test binary tarball startup

    echo
    rm -f procfifo
    mkfifo procfifo
    docker run -i -v `pwd`/apache-cassandra-$1:/apache-cassandra-$1 openjdk:${JDK}-jdk-slim-buster timeout 2160 /bin/bash -c "
        ( apt -qq update;
          apt -qq install -y python python3 procps ) 2>&1 >/dev/null;
        apache-cassandra-$1/bin/cassandra -R -f" 2>&1 >procfifo &

    PID=$!
    success=false
    while read LINE && ! $success ; do
        if [[ $LINE =~ "Starting listening for CQL clients on" ]] ; then
            echo "Binary artefact (JDK ${JDK}) OK"
            kill "$PID"
            success=true
        fi
    done < procfifo
    rm -f procfifo
    wait "$PID"
    if ! $success ; then
        echo "Binary artefact (JDK ${JDK}) FAILED"
    fi

    # test deb package startup
    if [ "$JDK" == "8" ] ; then
        DEBIAN_IMAGE="openjdk:8-jdk-slim-buster"
    else
        DEBIAN_IMAGE="debian:bullseye-slim"
    fi

    echo
    rm -f procfifo
    mkfifo procfifo
    docker run -i -v `pwd`/debian:/debian ${DEBIAN_IMAGE} timeout 2160 /bin/bash -c "
        ( apt -qq update ;
          apt -qq install -y python ; # will silently fail on debian latest
          apt -qq install -y python3 procps ;
          apt -qq install -y openjdk-${JDK}-jre-headless ; # will silently fail on *jdk-slim-buster
          dpkg --ignore-depends=java7-runtime --ignore-depends=java8-runtime -i debian/*.deb ) 2>&1 >/dev/null ;
        CASSANDRA_CONF=file:///etc/cassandra/ HEAP_NEWSIZE=500m MAX_HEAP_SIZE=1g cassandra -R -f" 2>&1 >procfifo &

    PID=$!
    success=false
    while read LINE && ! $success ; do
        if [[ $LINE =~ "Starting listening for CQL clients on" ]] ; then
            echo "Debian package (JDK ${JDK}) OK"
            kill "$PID"
            success=true
        fi
    done < procfifo
    rm -f procfifo
    wait "$PID"
    if ! $success ; then
        echo "Debian package (JDK ${JDK}) FAILED"
    fi

    # test deb repository startup

    idx=`expr index "$1" -`
    if [ $idx -eq 0 ]
    then
        release_short=${1}
    else
        release_short=${1:0:$((idx-1))}
    fi
    debian_series="$(echo ${release_short} | cut -d '.' -f 1)$(echo ${release_short} | cut -d '.' -f 2)x"

    echo
    rm -f procfifo
    mkfifo procfifo
    docker run -i ${DEBIAN_IMAGE} timeout 2160 /bin/bash -c "
        ( echo 'deb https://dist.apache.org/repos/dist/dev/cassandra/${1}/debian ${debian_series} main' | tee -a /etc/apt/sources.list.d/cassandra.sources.list ;
          apt -qq update ;
          apt -qq install -y curl gnupg2 ;
          apt-key adv --keyserver keyserver.ubuntu.com  --recv-key E91335D77E3E87CB ;
          curl https://downloads.apache.org/cassandra/KEYS | apt-key add - ;
          apt update  ;
          apt-get install -y cassandra ) 2>&1 >/dev/null ;
        cassandra -R -f" 2>&1 >procfifo &

    PID=$!
    success=false
    while read LINE && ! $success ; do
        if [[ $LINE =~ "Starting listening for CQL clients on" ]] ; then
            echo "Debian repository (JDK ${JDK}) OK"
            kill "$PID"
            success=true
        fi
    done < procfifo
    rm -f procfifo
    wait "$PID"
    if ! $success ; then
        echo "Debian repository (JDK ${JDK}) FAILED"
    fi

    if [ "$JDK" == "8" ] ; then
        JDK_RH="java-1.8.0-openjdk"
    else
        JDK_RH="java-${JDK}-openjdk-devel"
    fi

    RH_DISTS="almalinux"
    if ! [[ $1 =~ [23]\. ]] ; then
        RH_DISTS=("almalinux" "centos:7")
    fi
    for RH_DIST in ${RH_DISTS[@]} ; do

        NOBOOLEAN_REPO=""
        if [ "$RH_DIST" == "centos:7" ] ; then
            NOBOOLEAN_REPO="/noboolean"
        fi

        # test rpm package startup

        echo
        rm -f procfifo
        mkfifo procfifo
        docker run -i -v `pwd`/redhat${NOBOOLEAN_REPO}:/redhat ${RH_DIST} timeout 2160 /bin/bash -c "
            ( yum install -y  procps-ng python3-pip;
            if [ "centos:7" == "$RH_DIST" ] && [ "java-17-openjdk-devel" == "$JDK_RH" ] ; then
                # centos7 doesn't have jdk17, so manual install ;
                curl https://download.oracle.com/java/17/latest/jdk-17_linux-x64_bin.rpm -o jdk-17_linux-x64_bin.rpm ;
                yum -y install ./jdk-17_linux-x64_bin.rpm ;
            else
                yum install -y ${JDK_RH} ;
            fi
            rpm -i --nodeps redhat/*.rpm ) 2>&1 >/dev/null ;
            cassandra -R -f " 2>&1  >procfifo &

        PID=$!
        success=false
        while read LINE && ! $success ; do
            if [[ $LINE =~ "Starting listening for CQL clients on" ]] ; then
                echo "Redhat package (${RH_DIST} JDK ${JDK}) OK"
                kill "$PID"
                success=true
            fi
        done < procfifo
        rm -f procfifo
        wait "$PID"
        if ! $success ; then
            echo "Redhat package (${RH_DIST} JDK ${JDK}) FAILED"
        fi

        # test redhat repository startup

        echo
        rm -f procfifo
        mkfifo procfifo
        # yum repo installation failing due to a legacy (SHA1) third-party sig in our KEYS file, hence use of update-crypto-policies. Impacts all rhel9+ users.
        docker run -i  ${RH_DIST} timeout 2160 /bin/bash -c "(
            echo '[cassandra]' >> /etc/yum.repos.d/cassandra.repo ;
            echo 'name=Apache Cassandra' >> /etc/yum.repos.d/cassandra.repo ;
            echo 'baseurl=https://dist.apache.org/repos/dist/dev/cassandra/${1}/redhat${NOBOOLEAN_REPO}' >> /etc/yum.repos.d/cassandra.repo ;
            echo 'gpgcheck=1' >> /etc/yum.repos.d/cassandra.repo ;
            echo 'repo_gpgcheck=1' >> /etc/yum.repos.d/cassandra.repo ;
            echo 'gpgkey=https://downloads.apache.org/cassandra/KEYS' >> /etc/yum.repos.d/cassandra.repo ;

            update-crypto-policies --set LEGACY ;

            yum install -y ${JDK_RH} ;
            yum install -y cassandra ) 2>&1 >/dev/null ;

            cassandra -R -f" 2>&1 >procfifo &

        PID=$!
        success=false
        while read LINE && ! $success ; do
            if [[ $LINE =~ "Starting listening for CQL clients on" ]] ; then
                echo "Redhat repository (${RH_DIST} JDK ${JDK}) OK"
                kill "$PID"
                success=true
            fi
        done < procfifo
        rm -f procfifo
        wait "$PID"
        if ! $success ; then
            echo "Redhat repository (${RH_DIST} JDK ${JDK}) FAILED"
        fi
    done
done

echo "Done."
