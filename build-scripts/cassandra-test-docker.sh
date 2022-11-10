#!/bin/bash
#
# A wrapper script to cassandra-test.sh
#  that split the test list into multiple docker runs, collecting results.
#
# The docker image used is normally based from those found in docker/testing/
#
# Usage: cassandra-test-docker.sh REPO BRANCH BUILDS_REPO_URL BUILDS_BRANCH DOCKER_IMAGE [target] [split_chunk]
#

if [ "$#" -lt 3 ]; then
    # inside the docker container, setup env before calling cassandra-test.sh
    export WORKSPACE=/home/cassandra/cassandra
    export LANG=en_US.UTF-8
    export LC_CTYPE=en_US.UTF-8
    export PYTHONIOENCODING=utf-8
    export PYTHONUNBUFFERED=true
    if [ "${JAVA_VERSION}" -ge 11 ] ; then
        sudo update-java-alternatives --set java-1.11.0-openjdk-$(dpkg --print-architecture)
        export CASSANDRA_USE_JDK11=true
        export JAVA_HOME=$(sudo update-java-alternatives -l | grep "java-1.11.0-openjdk" | awk '{print $3}')
    fi
    java -version
    javac -version
    echo "running: git clone --quiet --depth 1 --single-branch --branch=$BRANCH https://github.com/$REPO/cassandra.git"
    until git clone --quiet --depth 1 --single-branch --branch=$BRANCH https://github.com/$REPO/cassandra.git ; do echo "git clone failed… trying again… " ; done
    cd cassandra
    echo "cassandra-test.sh (${1} ${2}) cassandra: `git log -1 --pretty=format:'%H %an %ad %s'`" | tee "${1}-$(echo $2 | sed 's/\//-/')-cassandra.head"
    echo "cassandra-test.sh (${1} ${2}) cassandra-builds: `git -C ../cassandra-builds log -1 --pretty=format:'%H %an %ad %s'`" | tee -a "${1}-$(echo $2 | sed 's/\//-/')-cassandra.head"
    ../cassandra-builds/build-scripts/cassandra-test.sh "$@"
    if [ -d build/test/logs ]; then find build/test/logs -type f -name "*.log" | xargs xz -qq ; fi
else

    # pre-conditions
    command -v docker >/dev/null 2>&1 || { echo >&2 "docker needs to be installed"; exit 1; }
    (docker info >/dev/null 2>&1) || { echo >&2 "docker needs to running"; exit 1; }

    # print debug information on versions
    docker --version

    # start the docker container
    if [ "$#" -lt 5 ]; then
       echo "Usage: cassandra-test-docker.sh REPO BRANCH BUILDS_REPO_URL BUILDS_BRANCH DOCKER_IMAGE [target] [split_chunk]"
       exit 1
    fi
    BUILDSREPO=$3
    BUILDSBRANCH=$4
    DOCKER_IMAGE=$5
    TARGET=${6:-"test"}
    SPLIT_CHUNK=${7:-"1/1"}

    # Setup JDK
    java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F. '{print $1}')
    if [ "$java_version" -ge 11 ]; then
        java_version="11"
        if ! grep -q CASSANDRA_USE_JDK11 build.xml ; then
            echo "Skipping build. JDK11 not supported against $(grep 'property\s*name=\"base.version\"' build.xml |sed -ne 's/.*value=\"\([^"]*\)\".*/\1/p')"
            exit 0
        fi
    else
        java_version="8"
    fi

    cat > env.list <<EOF
REPO=$1
BRANCH=$2
JAVA_VERSION=${java_version}
cython=${cython}
EOF

    # Jenkins agents run multiple executors per machine. `jenkins_executors=1` is used for anything non-jenkins.
    jenkins_executors=1
    if [[ ! -z ${JENKINS_URL+x} ]] && [[ ! -z ${NODE_NAME+x} ]] ; then
        fetched_jenkins_executors=$(curl -s --retry 9 --retry-connrefused --retry-delay 1 "${JENKINS_URL}/computer/${NODE_NAME}/api/json?pretty=true" | grep 'numExecutors' | awk -F' : ' '{print $2}' | cut -d',' -f1)
        # use it if we got a valid number (despite retry settings the curl above can still fail
        [[ ${fetched_jenkins_executors} =~ '^[0-9]+$' ]] && jenkins_executors=${fetched_jenkins_executors}
    fi
    cores=1
    command -v nproc >/dev/null 2>&1 && cores=$(nproc --all)
    # for relevant test targets calculate how many docker containers we should split the test list over
    case $TARGET in
      # test-burn doesn't have enough tests in it to split beyond 8, and burn and long we want a bit more resources anyway
      "stress-test" | "fqltool-test" | "microbench" | "test-burn" | "long-test" | "cqlsh-test")
          docker_runs=1
        ;;
      "test"| "test-cdc" | "test-compression" | "jvm-dtest" | "jvm-dtest-upgrade")
          mem=1
          # linux
          command -v free >/dev/null 2>&1 && mem=$(free -b | grep Mem: | awk '{print $2}')
          # macos
          sysctl -n hw.memsize >/dev/null 2>&1 && mem=$(sysctl -n hw.memsize)
          max_docker_runs_by_cores=$( echo "sqrt( $cores / $jenkins_executors )" | bc )
          max_docker_runs_by_mem=$(( $mem / ( 5 * 1024 * 1024 * 1024 * $jenkins_executors ) ))
          docker_runs=$(( $max_docker_runs_by_cores < $max_docker_runs_by_mem ? $max_docker_runs_by_cores : $max_docker_runs_by_mem ))
          docker_runs=$(( $docker_runs < 1 ? 1 : $docker_runs ))
        ;;
      *)
        echo "unrecognized \"$target\""
        exit 1
        ;;
    esac

    # Break up the requested split chunk into a number of concurrent docker runs, as calculated above
    # This will typically be between one to four splits. Five splits would require >25 cores and >25GB ram
    INNER_SPLITS=$(( $(echo $SPLIT_CHUNK | cut -d"/" -f2 ) * $docker_runs ))
    INNER_SPLIT_FIRST=$(( ( $(echo $SPLIT_CHUNK | cut -d"/" -f1 ) * $docker_runs ) - ( $docker_runs - 1 ) ))
    docker_cpus=$(echo "scale=2; ${cores} / ( ${jenkins_executors} * ${docker_runs} )" | bc)
    docker_flags="--cpus=${docker_cpus} -m 5g --memory-swap 5g --env-file env.list -dt"

    # hack: long-test does not handle limited CPUs
    if [ "$TARGET" == "long-test" ] ; then
        docker_flags="-m 5g --memory-swap 5g --env-file env.list -dt"
    fi

    # docker login to avoid rate-limiting apache images. credentials are expected to already be in place
    docker login || true
    [[ "$(docker images -q $DOCKER_IMAGE 2>/dev/null)" != "" ]] || docker pull -q $DOCKER_IMAGE

    mkdir -p build/test/logs
    declare -a DOCKER_IDS
    declare -a PROCESS_IDS
    declare -a STATUSES

    for i in `seq 1 $docker_runs` ; do
        inner_split=$(( $INNER_SPLIT_FIRST + ( $i - 1 ) ))
        # start the container
        echo "cassandra-test-docker.sh: running: git clone --quiet --single-branch --depth 1 --branch $BUILDSBRANCH $BUILDSREPO; bash ./cassandra-builds/build-scripts/cassandra-test-docker.sh $TARGET ${inner_split}/${INNER_SPLITS}"
        docker_id=$(docker run ${docker_flags} $DOCKER_IMAGE dumb-init bash -ilc "until git clone --quiet --single-branch --depth 1 --branch $BUILDSBRANCH $BUILDSREPO ; do echo 'git clone failed… trying again… ' ; done ; ./cassandra-builds/build-scripts/cassandra-test-docker.sh ${TARGET} ${inner_split}/${INNER_SPLITS}")

        # capture logs and pid for container
        docker attach --no-stdin $docker_id > build/test/logs/docker_attach_${i}.log &
        PROCESS_IDS+=( $! )
        DOCKER_IDS+=( $docker_id )
    done

    exit_result=0
    i=0
    for process_id in "${PROCESS_IDS[@]}" ; do
        # wait for each container to complete
        docker_id=${DOCKER_IDS[$i]}
        inner_split=$(( $INNER_SPLIT_FIRST + $i ))
        cat build/test/logs/docker_attach_$(( $i + 1 )).log
        tail -F build/test/logs/docker_attach_$(( $i + 1 )).log &
        tail_process=$!
        wait $process_id
        status=$?
        PROCESS_IDS+=( $status )
        kill $tail_process

        if [ "$status" -ne 0 ] ; then
            echo "${docker_id} failed (${status}), debug…"
            docker inspect ${docker_id}
            echo "–––"
            docker logs ${docker_id}
            echo "–––"
            docker ps -a
            echo "–––"
            docker info
            echo "–––"
            dmesg
            exit_result=1
        else
            echo "${docker_id} done (${status}), copying files"
            docker cp "$docker_id:/home/cassandra/cassandra/${TARGET}-${inner_split}-${INNER_SPLITS}-cassandra.head" .
            docker cp $docker_id:/home/cassandra/cassandra/build/test/output/. build/test/output
            docker cp $docker_id:/home/cassandra/cassandra/build/test/logs/. build/test/logs
            docker cp $docker_id:/home/cassandra/cassandra/cqlshlib.xml cqlshlib.xml
        fi
        docker rm $docker_id
        ((i++))
    done

    xz build/test/logs/docker_attach_*.log
    exit $exit_result
fi
