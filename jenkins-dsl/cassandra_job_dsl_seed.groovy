////////////////////////////////////////////////////////////
//
// Common Vars and Branch List
//
//  Help on syntax see https://ci-cassandra.apache.org/plugin/job-dsl/api-viewer/index.html
//
//  To update the variable via the Jenkins UI, use the EnvInject plugin
//   example: https://github.com/apache/cassandra-builds/pull/19#issuecomment-610822772
//
////////////////////////////////////////////////////////////

def jobDescription = '<img src="http://cassandra.apache.org/img/cassandra_logo.png" /><br/>Apache Cassandra DSL-generated job - DSL git repo: <a href="https://github.com/apache/cassandra-builds">cassandra-builds</a>'
def jdkLabel = 'jdk_1.8_latest'
if(binding.hasVariable("CASSANDRA_JDK_LABEL")) {
    jdkLabel = "${CASSANDRA_JDK_LABEL}"
}

// architectures. blank is amd64
def archs = ['', '-arm64']
arm64_enabled = true
arm64_test_label_enabled = false
def use_arm64_test_label() { return arm64_enabled && arm64_test_label_enabled }

def slaveLabel = 'cassandra'
slaveDtestLabel = 'cassandra-dtest'
slaveDtestLargeLabel = 'cassandra-dtest-large'
slaveArm64Label = 'cassandra-arm64'
slaveArm64DtestLabel = 'cassandra-arm64-dtest'
slaveArm64DtestLargeLabel = 'cassandra-arm64-dtest-large'
def mainRepo = "https://github.com/apache/cassandra.git"
def githubRepo = "https://github.com/apache/cassandra"
if(binding.hasVariable("CASSANDRA_GIT_URL")) {
    mainRepo = "${CASSANDRA_GIT_URL}"
    // just presume custom repos are github, not critical if they are not
    githubRepo = "${mainRepo}".minus(".git")
}
def buildsRepo = "https://github.com/apache/cassandra-builds.git"
if(binding.hasVariable("CASSANDRA_BUILDS_GIT_URL")) {
    buildsRepo = "${CASSANDRA_BUILDS_GIT_URL}"
}
def buildsBranch = "trunk"
if(binding.hasVariable("CASSANDRA_BUILDS_BRANCH")) {
    buildsBranch = "${CASSANDRA_BUILDS_BRANCH}"
}
def dtestRepo = "https://github.com/apache/cassandra-dtest.git"
if(binding.hasVariable("CASSANDRA_DTEST_GIT_URL")) {
    dtestRepo = "${CASSANDRA_DTEST_GIT_URL}"
}
def buildDescStr = 'REF = ${GIT_BRANCH} <br /> COMMIT = ${GIT_COMMIT}'
// Cassandra active branches
def cassandraBranches = ['cassandra-2.2', 'cassandra-3.0', 'cassandra-3.11', 'cassandra-4.0', 'trunk']
if(binding.hasVariable("CASSANDRA_BRANCHES")) {
    cassandraBranches = "${CASSANDRA_BRANCHES}".split(",")
}
// Ant test targets
def testTargets = ['test', 'test-burn', 'test-cdc', 'test-compression', 'stress-test', 'fqltool-test', 'long-test', 'jvm-dtest', 'jvm-dtest-upgrade', 'microbench']
if(binding.hasVariable("CASSANDRA_ANT_TEST_TARGETS")) {
    testTargets = "${CASSANDRA_ANT_TEST_TARGETS}".split(",")
}
def testDockerImage = 'apache/cassandra-testing-ubuntu2004-java11-w-dependencies'

// Dtest test targets
def dtestTargets = ['dtest', 'dtest-novnode', 'dtest-offheap', 'dtest-large', 'dtest-large-novnode', 'dtest-upgrade']
if(binding.hasVariable("CASSANDRA_DTEST_TEST_TARGETS")) {
    dtestTargets = "${CASSANDRA_DTEST_TEST_TARGETS}".split(",")
}
def dtestDockerImage = 'apache/cassandra-testing-ubuntu2004-java11'

// expected longest job runtime
def maxJobHours = 18
if(binding.hasVariable("MAX_JOB_HOURS")) {
    maxJobHours = ${MAX_JOB_HOURS}
}

// how many splits are dtest jobs matrixed into
def testSplits = 8
def dtestSplits = 64
def dtestLargeSplits = 8

def isSplittableTest(targetName) {
    return targetName == 'test' || targetName == 'test-cdc' || targetName == 'test-compression' || targetName == 'test-burn' || targetName == 'long-test' || targetName == 'jvm-dtest' || targetName == 'jvm-dtest-upgrade';
}

////////////////////////////////////////////////////////////
//
// Job Templates
// - disabled by default
// - running jobs use templates for most configurations
//   and set details like branch
//
////////////////////////////////////////////////////////////

/**
 * Artifacts and eclipse-warnings template
 */
matrixJob('Cassandra-template-artifacts') {
    disabled(true)
    description(jobDescription)
    concurrentBuild()
    compressBuildLog()
    logRotator {
        numToKeep(10)
        artifactNumToKeep(5)
        artifactDaysToKeep(1)
    }
    wrappers {
        timeout {
            noActivity(300)
        }
        timestamps()
    }
    properties {
        githubProjectUrl(githubRepo)
        priorityJobProperty {
            useJobPriority(true)
            priority(1)
        }
    }
    scm {
        git {
            remote {
                url(mainRepo)
            }
            branch('*/null')
            extensions {
                cleanAfterCheckout()
                cloneOption {
                    shallow(false)
                    reference('.')
                    honorRefspec(true)
                    noTags(true)
                    timeout(maxJobHours * 60)
                }
            }
        }
    }
    steps {
        buildDescription('', buildDescStr)
        shell("""
                git clean -xdff ;
                git clone --depth 1 --single-branch -b ${buildsBranch} ${buildsRepo} ;
                echo "cassandra-builds at: `git -C cassandra-builds log -1 --pretty=format:'%h %an %ad %s'`" ;
              """)
    }
    publishers {
        extendedEmail {
            recipientList('builds@cassandra.apache.org')
            triggers {
                failure {
                    sendTo {
                        recipientList()
                        developers()
                        requester()
                        culprits()
                    }
                }
                fixed {
                    sendTo {
                        recipientList()
                        developers()
                        requester()
                        culprits()
                    }
                }
            }
        }
    }
}

/**
 * Ant test template
 */
matrixJob('Cassandra-template-test') {
    disabled(true)
    description(jobDescription)
    concurrentBuild()
    compressBuildLog()
    logRotator {
        numToKeep(10)
        artifactNumToKeep(5)
        artifactDaysToKeep(1)
    }
    wrappers {
        timeout {
            noActivity(1200)
        }
        timestamps()
    }
    properties {
        githubProjectUrl(githubRepo)
        priorityJobProperty {
            useJobPriority(true)
            priority(3)
        }
    }
    scm {
        git {
            remote {
                url(mainRepo)
            }
            branch('*/null')
            extensions {
                cleanAfterCheckout()
                cloneOption {
                    shallow(false)
                    reference('.')
                    honorRefspec(true)
                    noTags(true)
                    timeout(maxJobHours * 60)
                }
            }
        }
    }
    steps {
        buildDescription('', buildDescStr)
        shell("""
                git clean -xdff -e build/test/jmh-result.json ;
                git clone --depth 1 --single-branch -b ${buildsBranch} ${buildsRepo} ;
                echo "cassandra-builds at: `git -C cassandra-builds log -1 --pretty=format:'%h %an %ad %s'`" ;
                echo "\${BUILD_TAG}) cassandra: `git log -1 --pretty=format:'%h %an %ad %s'`" > \${BUILD_TAG}.head
              """)
    }
    publishers {
        archiveArtifacts {
            pattern('build/test/**/TEST-*.xml, **/*.head')
            allowEmpty()
            fingerprint()
        }
    }
}

/**
 * Dtest template
 */
matrixJob('Cassandra-template-dtest-matrix') {
    disabled(true)
    description(jobDescription)
    concurrentBuild()
    compressBuildLog()
    logRotator {
        numToKeep(10)
        artifactNumToKeep(5)
        artifactDaysToKeep(1)
    }
    wrappers {
        timeout {
            noActivity(1200)
        }
        timestamps()
    }
    properties {
        githubProjectUrl(githubRepo)
        priorityJobProperty {
            useJobPriority(true)
            priority(7)
        }
    }
    scm {
        git {
            remote {
                url(mainRepo)
            }
            branch('*/null')
            extensions {
                cleanAfterCheckout()
                cloneOption {
                    shallow(false)
                    reference('.')
                    honorRefspec(true)
                    noTags(true)
                    timeout(maxJobHours * 60)
                }
            }
        }
    }
    steps {
        buildDescription('', buildDescStr)
        shell("""
                git clean -xdff ;
                git clone --depth 1 --single-branch -b ${buildsBranch} ${buildsRepo} ;
                echo "cassandra-builds at: `git -C cassandra-builds log -1 --pretty=format:'%h %an %ad %s'`" ;
                echo "\${BUILD_TAG}) cassandra: `git log -1 --pretty=format:'%h %an %ad %s'`" > \${BUILD_TAG}.head ;
              """)
    }
}

/**
 * cqlsh template
 */
matrixJob('Cassandra-template-cqlsh-tests') {
    disabled(true)
    description(jobDescription)
    concurrentBuild()
    compressBuildLog()
    logRotator {
        numToKeep(10)
        artifactNumToKeep(5)
        artifactDaysToKeep(1)
    }
    wrappers {
        timeout {
            noActivity(1200)
        }
        timestamps()
    }
    throttleConcurrentBuilds {
        categories(['Cassandra'])
    }
    axes {
        text('cython', 'yes', 'no')
        jdk(jdkLabel)
        if (use_arm64_test_label()) {
            label('label', slaveLabel, slaveArm64Label)
        } else {
            label('label', slaveLabel)
        }
    }
    // this should prevent long path expansion from the axis definitions
    childCustomWorkspace('.')
    properties {
        githubProjectUrl(githubRepo)
        priorityJobProperty {
            useJobPriority(true)
            priority(3)
        }
    }
    scm {
        git {
            remote {
                url(mainRepo)
            }
            branch('*/null')
            extensions {
                cleanAfterCheckout()
                cloneOption {
                    shallow(false)
                    reference('.')
                    honorRefspec(true)
                    noTags(true)
                    timeout(maxJobHours * 60)
                }
            }
        }
    }
    steps {
        buildDescription('', buildDescStr)
        shell("git clean -xdff")
        shell('./pylib/cassandra-cqlsh-tests.sh $WORKSPACE')
        shell("""echo "\${BUILD_TAG}) cassandra: `git log -1 --pretty=format:'%h %an %ad %s'`" > \${BUILD_TAG}.head """)
    }
}

////////////////////////////////////////////////////////////
//
// Branch Job Definitions
// - set to disabled(false)
// - running jobs use templates for most configurations
//   and set details like branch
//
////////////////////////////////////////////////////////////

cassandraBranches.each {
    def branchName = it
    def jobNamePrefix = "Cassandra-${branchName}".replaceAll('cassandra-', '')

    /**
     * Main branch artifacts and eclipse-warnings job
     */
    matrixJob("${jobNamePrefix}-artifacts") {
        disabled(false)
        using('Cassandra-template-artifacts')
        axes {
            if (branchName == 'trunk' || branchName == 'cassandra-4.0') {
                jdk('jdk_1.8_latest','jdk_11_latest')
            } else {
                jdk('jdk_1.8_latest')
            }
            if (arm64_enabled) {
                label('label', slaveLabel, slaveArm64Label)
            } else {
                label('label', slaveLabel)
            }
        }
        configure { node ->
            node / scm / branches / 'hudson.plugins.git.BranchSpec' / name(branchName)
        }
        steps {
            shell('./cassandra-builds/build-scripts/cassandra-artifacts.sh')
        }
        publishers {
            publishOverSsh {
                server('Nightlies') {
                    transferSet {
                        sourceFiles("build/apache-cassandra-*.tar.gz, build/apache-cassandra-*.jar, build/apache-cassandra-*.pom, build/cassandra*.deb, build/cassandra*.rpm")
                        remoteDirectory("cassandra/${branchName}/${jobNamePrefix}-artifacts/\${BUILD_NUMBER}/\${JOB_NAME}/")
                    }
                }
                failOnError(false)
            }
            postBuildTask {
                // docker needs to (soon or later) prune its volumes too, but that can only be done when the agent is idle
                // if the agent is busy, just prune everything that is older than maxJobHours
                task('.', """
                    echo "Cleaning project…"; git clean -xdff ;
                    echo "Pruning docker…" ;
                    if pgrep -af "cassandra-builds/build-scripts" ; then docker system prune --all --force --filter "until=${maxJobHours}h" ; else  docker system prune --all --force --volumes ;  fi;
                    echo "Reporting disk usage…"; df -h ;
                    echo "Cleaning tmp…";
                    find . -type d -name tmp -delete 2>/dev/null ;
                    find /tmp -type f -atime +2 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
                """)
            }
        }
    }

    /**
     * Main branch ant test target jobs
     */
    testTargets.each {
        def targetName = it

        // Skip tests that don't exist before cassandra-3.11
        if ((targetName == 'test-cdc' || targetName == 'stress-test') && ((branchName == 'cassandra-2.2') || (branchName == 'cassandra-3.0'))) {
            println("Skipping ${targetName} on branch ${branchName}")

            // Skip tests that don't exist before cassandra-4.0
        } else if ((targetName == 'fqltool-test') && ((branchName == 'cassandra-2.2') || (branchName == 'cassandra-3.0') || (branchName == 'cassandra-3.11'))) {
            println("Skipping ${targetName} on branch ${branchName}")

        } else {
            matrixJob("${jobNamePrefix}-${targetName}") {
                disabled(false)
                using('Cassandra-template-test')
                axes {
                    if (isSplittableTest(targetName)) {
                        List<String> values = new ArrayList<String>()
                        (1..testSplits).each { values << it.toString() }
                        text('split', values)
                    }
                    // jvm-dtest-upgrade would require mixed JDK compilations to support JDK11+
                    if ((branchName == 'trunk' || branchName == 'cassandra-4.0') && targetName != 'jvm-dtest-upgrade') {
                        jdk(jdkLabel,'jdk_11_latest')
                    } else {
                        jdk(jdkLabel)
                    }
                    if (use_arm64_test_label()) {
                        label('label', slaveLabel, slaveArm64Label)
                    } else {
                        label('label', slaveLabel)
                    }
                }
                configure { node ->
                    node / scm / branches / 'hudson.plugins.git.BranchSpec' / name(branchName)
                }
                steps {
                    if (arch == "-arm64") {
                        shell("""
                                # docker image has to be built on arm64 (they are not currently published to dockerhub)
                                cd cassandra-builds/docker/testing ;
                                docker build -t ${dtestDockerImage}:latest -f ubuntu2004_j11.docker . ;
                                docker build -t ${testDockerImage}:latest -f ubuntu2004_j11_w_dependencies.docker .
                              """)
                    }
                    shell("""
                            ./cassandra-builds/build-scripts/cassandra-test-docker.sh apache ${branchName} ${buildsRepo} ${buildsBranch} ${testDockerImage} ${targetName} \${split}/${testSplits} ;
                            ./cassandra-builds/build-scripts/cassandra-test-report.sh ;
                             xz TESTS-TestSuites.xml
                          """)
                }
                publishers {
                    if (targetName == 'microbench') {
                        jmhReport {
                            resultPath('build/test/jmh-result.json')
                        }
                        archiveJunit('build/test/**/TEST-*.xml') {
                            allowEmptyResults(true)
                        }
                    } else {
                        archiveJunit('build/test/**/TEST-*.xml') {
                            testDataPublishers {
                                publishTestStabilityData()
                            }
                        }
                    }
                    publishOverSsh {
                        server('Nightlies') {
                            transferSet {
                                sourceFiles("TESTS-TestSuites.xml.xz,build/test/logs/**,build/test/jmh-result.json")
                                remoteDirectory("cassandra/${branchName}/${jobNamePrefix}-${targetName}/\${BUILD_NUMBER}/\${JOB_NAME}/")
                            }
                        }
                        failOnError(false)
                    }
                    postBuildTask {
                        // docker needs to (soon or later) prune its volumes too, but that can only be done when the agent is idle
                        // if the agent is busy, just prune everything that is older than maxJobHours
                        task('.', """
                            echo "Cleaning project…"; git clean -xdff -e build/test/jmh-result.json ;
                            echo "Pruning docker…" ;
                            if pgrep -af "cassandra-builds/build-scripts" ; then docker system prune --all --force --filter "until=${maxJobHours}h" ; else  docker system prune --all --force --volumes ;  fi;
                            echo "Reporting disk usage…"; du -xm / 2>/dev/null | sort -rn | head -n 30 ; df -h ;
                            echo "Cleaning tmp…";
                            find . -type d -name tmp -delete 2>/dev/null ;
                            find /tmp -type f -atime +2 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
                        """)
                    }
                }
            }
        }
    }

    /**
     * Main branch dtest variation jobs
     */
    archs.each {
        def arch = it
        dtestTargets.each {
            def targetName = it
            def targetArchName = targetName + arch

            // Skip dtest-offheap on cassandra-3.0 branch
            if ((targetName == 'dtest-offheap') && (branchName == 'cassandra-3.0')) {
                println("Skipping ${targetArchName} on branch ${branchName}")
            } else {
                matrixJob("${jobNamePrefix}-${targetArchName}") {
                    disabled(false)
                    using('Cassandra-template-dtest-matrix')
                    axes {
                        List<String> values = new ArrayList<String>()
                        if (targetName == 'dtest-large' || targetName == 'dtest-large-novnode') {
                            splits = dtestLargeSplits
                        } else {
                            splits = dtestSplits
                        }
                        (1..splits).each { values << it.toString() }
                        text('split', values)
                        if (targetName == 'dtest-large' || targetName == 'dtest-large-novnode') {
                            if (arch == "-arm64") {
                                label('label', slaveArm64DtestLargeLabel)
                            } else {
                                label('label', slaveDtestLargeLabel)
                            }
                        } else {
                            if (arch == "-arm64") {
                                label('label', slaveArm64DtestLabel)
                            } else {
                                label('label', slaveDtestLabel)
                            }
                        }
                    }
                    configure { node ->
                        node / scm / branches / 'hudson.plugins.git.BranchSpec' / name(branchName)
                    }
                    steps {
                        if (arch == "-arm64") {
                            shell("""
                                    # docker image has to be built on arm64 (they are not currently published to dockerhub)
                                    cd cassandra-builds/docker/testing ;
                                    docker build -t ${dtestDockerImage}:latest -f ubuntu2004_j11.docker .
                                  """)
                        }
                        shell("""
                            ./cassandra-builds/build-scripts/cassandra-dtest-pytest-docker.sh apache ${branchName} https://github.com/apache/cassandra-dtest.git trunk ${buildsRepo} ${buildsBranch} ${dtestDockerImage} ${targetName} \${split}/${splits} ;
                            """)
                    }
                    publishers {
                        publishOverSsh {
                            server('Nightlies') {
                                transferSet {
                                    sourceFiles("**/nosetests.xml,**/test_stdout.txt.xz,**/ccm_logs.tar.xz")
                                    remoteDirectory("cassandra/${branchName}/${jobNamePrefix}-${targetArchName}/\${BUILD_NUMBER}/\${JOB_NAME}/")
                                }
                            }
                            failOnError(false)
                        }
                        archiveArtifacts {
                            pattern('**/nosetests.xml,**/*.head')
                            allowEmpty()
                            fingerprint()
                        }
                        archiveJunit('nosetests.xml') {
                            testDataPublishers {
                                publishTestStabilityData()
                            }
                        }
                        postBuildTask {
                            // docker needs to (soon or later) prune its volumes too, but that can only be done when the agent is idle
                            // if the agent is busy, just prune everything that is older than maxJobHours
                            task('.', """
                                echo "Cleaning project…"; git clean -xdff ;
                                echo "Pruning docker…" ;
                                if pgrep -af "cassandra-builds/build-scripts" ; then docker system prune --all --force --filter "until=${maxJobHours}h" ; else  docker system prune --all --force --volumes ;  fi;
                                echo "Reporting disk usage…"; df -h ;
                                echo "Cleaning tmp…";
                                find . -type d -name tmp -delete 2>/dev/null ;
                                find /tmp -type f -atime +2 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
                            """)
                        }
                    }
                }
            }
        }
    }

    /**
     * Main branch cqlsh jobs
     */
    if (branchName == 'cassandra-2.2') {
        println("Skipping ${jobNamePrefix}-cqlsh-tests, not supported on branch ${branchName}")
    } else {
        matrixJob("${jobNamePrefix}-cqlsh-tests") {
            disabled(false)
            using('Cassandra-template-cqlsh-tests')
            configure { node ->
                node / scm / branches / 'hudson.plugins.git.BranchSpec' / name(branchName)
            }
            publishers {
                publishOverSsh {
                    server('Nightlies') {
                        transferSet {
                            sourceFiles("**/cqlshlib.xml,**/*.head")
                            remoteDirectory("cassandra/${branchName}/${jobNamePrefix}-cqlsh-tests/\${BUILD_NUMBER}/\${JOB_NAME}/")
                        }
                    }
                    failOnError(false)
                }
                archiveArtifacts {
                    pattern('**/cqlshlib.xml,**/*.head')
                    allowEmpty()
                    fingerprint()
                }
                archiveJunit('**/cqlshlib.xml') {
                    testDataPublishers {
                        publishTestStabilityData()
                    }
                }
                postBuildTask {
                    // docker needs to (soon or later) prune its volumes too, but that can only be done when the agent is idle
                    // if the agent is busy, just prune everything that is older than maxJobHours
                    task('.', """
                        echo "Cleaning project…"; git clean -xdff ;
                        echo "Pruning docker…" ;
                        if pgrep -af "cassandra-builds/build-scripts" ; then docker system prune --all --force --filter "until=${maxJobHours}h" ; else  docker system prune --all --force --volumes ;  fi;
                        echo "Reporting disk usage…"; df -h ;
                        echo "Cleaning tmp…";
                        find . -type d -name tmp -delete 2>/dev/null ;
                        find /tmp -type f -atime +2 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
                    """)
                }
            }
        }
    }

    /**
     * Branch Pipelines
     */
    pipelineJob("${jobNamePrefix}") {
        description(jobDescription)
        logRotator {
            numToKeep(30)
            artifactNumToKeep(10)
        }
        properties {
            githubProjectUrl(githubRepo)
            priorityJobProperty {
                useJobPriority(true)
                priority(1)
            }
        }
        definition {
            cpsScm {
                scm {
                    git {
                        remote {
                            url(mainRepo)
                        }
                        branch("${branchName}")
                        extensions {
                            cleanAfterCheckout()
                            cloneOption {
                                shallow(false)
                                reference('.')
                                honorRefspec(true)
                                noTags(true)
                                timeout(maxJobHours * 60)
                            }
                        }
                    }
                }
                scriptPath('.jenkins/Jenkinsfile')
            }
        }
        triggers {
            scm('H/5 * * * *')
        }
    }
}

////////////////////////////////////////////////////////////
//
// Parameterized Dev Branch Job Definitions
//
////////////////////////////////////////////////////////////

/**
 * Parameterized Artifacts
 */
matrixJob('Cassandra-devbranch-artifacts') {
    description(jobDescription)
    concurrentBuild()
    axes {
        jdk(jdkLabel,'jdk_11_latest')
        if (arm64_enabled) {
            label('label', slaveLabel, slaveArm64Label)
        } else {
            label('label', slaveLabel)
        }
    }
    compressBuildLog()
    logRotator {
        numToKeep(90)
        artifactNumToKeep(5)
        artifactDaysToKeep(1)
    }
    wrappers {
        timeout {
            noActivity(300)
        }
        timestamps()
    }
    parameters {
        stringParam('REPO', 'apache', 'The github user/org to clone cassandra repo from')
        stringParam('BRANCH', 'trunk', 'The branch of cassandra to checkout')
    }
    properties {
        githubProjectUrl(githubRepo)
        priorityJobProperty {
            useJobPriority(true)
            priority(1)
        }
    }
    scm {
        git {
            remote {
                url('https://github.com/${REPO}/cassandra.git')
            }
            branch('${BRANCH}')
            extensions {
                cleanAfterCheckout()
                cloneOption {
                    shallow(false)
                    reference('.')
                    honorRefspec(true)
                    noTags(true)
                    timeout(maxJobHours * 60)
                }
            }
        }
    }
    steps {
        buildDescription('', buildDescStr)
        shell("""
                git clean -xdff ;
                git clone --depth 1 --single-branch -b ${buildsBranch} ${buildsRepo} ;
                echo "cassandra-builds at: `git -C cassandra-builds log -1 --pretty=format:'%h %an %ad %s'`" ;
              """)
        shell('./cassandra-builds/build-scripts/cassandra-artifacts.sh')
    }
    publishers {
        publishOverSsh {
            server('Nightlies') {
                transferSet {
                    sourceFiles("build/apache-cassandra-*.tar.gz, build/apache-cassandra-*.jar, build/apache-cassandra-*.pom, build/cassandra*.deb, build/cassandra*.rpm")
                    remoteDirectory("cassandra/devbranch/Cassandra-devbranch-artifacts/\${BUILD_NUMBER}/\${JOB_NAME}/")
                }
            }
            failOnError(false)
        }
        postBuildTask {
            // docker needs to (soon or later) prune its volumes too, but that can only be done when the agent is idle
            // if the agent is busy, just prune everything that is older than maxJobHours
            task('.', """
                echo "Cleaning project…"; git clean -xdff ;
                echo "Pruning docker…" ;
                if pgrep -af "cassandra-builds/build-scripts" ; then docker system prune --all --force --filter "until=${maxJobHours}h" ; else  docker system prune --all --force --volumes ;  fi;
                echo "Reporting disk usage…"; df -h ;
                echo "Cleaning tmp…";
                find . -type d -name tmp -delete 2>/dev/null ;
                find /tmp -type -f -atime +3 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
            """)
        }
    }
}

/**
 * Parameterized Dev Branch `ant test`
 */
testTargets.each {
    def targetName = it

    matrixJob("Cassandra-devbranch-${targetName}") {
        description(jobDescription)
        concurrentBuild()
        axes {
            if (isSplittableTest(targetName)) {
                List<String> values = new ArrayList<String>()
                (1..testSplits).each { values << it.toString() }
                text('split', values)
            }
            jdk(jdkLabel,'jdk_11_latest')
            if (use_arm64_test_label()) {
                label('label', slaveLabel, slaveArm64Label)
            } else {
                label('label', slaveLabel)
            }
        }
        compressBuildLog()
        logRotator {
            numToKeep(90)
            artifactNumToKeep(5)
            artifactDaysToKeep(1)
        }
        wrappers {
            timeout {
                noActivity(1200)
            }
            timestamps()
        }
        parameters {
            stringParam('REPO', 'apache', 'The github user/org to clone cassandra repo from')
            stringParam('BRANCH', 'trunk', 'The branch of cassandra to checkout')
        }
        properties {
            githubProjectUrl(githubRepo)
            priorityJobProperty {
                useJobPriority(true)
                priority(3)
            }
        }
        scm {
            git {
                remote {
                    url('https://github.com/${REPO}/cassandra.git')
                }
                branch('${BRANCH}')
                extensions {
                    cleanAfterCheckout()
                    cloneOption {
                        shallow(false)
                        reference('.')
                        honorRefspec(true)
                        noTags(true)
                        timeout(maxJobHours * 60)
                    }
                }
            }
        }
        steps {
            buildDescription('', buildDescStr)
            shell("""
                    git clean -xdff ${targetName == 'microbench' ? '-e build/test/jmh-result.json' : ''};
                    git clone --depth 1 --single-branch -b ${buildsBranch} ${buildsRepo} ;
                    echo "cassandra-builds at: `git -C cassandra-builds log -1 --pretty=format:'%h %an %ad %s'`" ;
                    echo "Cassandra-devbranch-${targetName}) cassandra: `git log -1 --pretty=format:'%h %an %ad %s'`" > Cassandra-devbranch-${targetName}.head 
                    """)
            if (arch == "-arm64") {
                shell("""
                        # docker image has to be built on arm64 (they are not currently published to dockerhub)
                        cd cassandra-builds/docker/testing ;
                        docker build -t ${dtestDockerImage}:latest -f ubuntu2004_j11.docker . ;
                        docker build -t ${testDockerImage}:latest -f ubuntu2004_j11_w_dependencies.docker .
                      """)
            }
            shell("""
                    ./cassandra-builds/build-scripts/cassandra-test-docker.sh \${REPO} \${BRANCH} ${buildsRepo} ${buildsBranch} ${testDockerImage} ${targetName} \${split}/${testSplits} ;
                    ./cassandra-builds/build-scripts/cassandra-test-report.sh ;
                    xz TESTS-TestSuites.xml
                  """)
        }
        publishers {
            publishOverSsh {
                server('Nightlies') {
                    transferSet {
                        sourceFiles("TESTS-TestSuites.xml.xz,build/test/logs/**,build/test/jmh-result.json")
                        remoteDirectory("cassandra/devbranch/Cassandra-devbranch-${targetName}/\${BUILD_NUMBER}/\${JOB_NAME}/")
                    }
                }
                failOnError(false)
            }
            archiveArtifacts {
                pattern('build/test/**/TEST-*.xml, **/*.head')
                allowEmpty()
                fingerprint()
            }
            archiveJunit('build/test/**/TEST-*.xml') {
                allowEmptyResults()
            }
            postBuildTask {
                // docker needs to (soon or later) prune its volumes too, but that can only be done when the agent is idle
                // if the agent is busy, just prune everything that is older than maxJobHours
                task('.', """
                    echo "Cleaning project…"; git clean -xdff ${targetName == 'microbench' ? '-e build/test/jmh-result.json' : ''};
                    echo "Pruning docker…" ;
                    if pgrep -af "cassandra-builds/build-scripts" ; then docker system prune --all --force --filter "until=${maxJobHours}h" ; else  docker system prune --all --force --volumes ;  fi;
                    echo "Reporting disk usage…"; du -xm / 2>/dev/null | sort -rn | head -n 30 ; df -h ;
                    echo "Cleaning tmp…";
                    find . -type d -name tmp -delete 2>/dev/null ;
                    find /tmp -type f -atime +2 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
                """)
            }
        }
    }
}

/**
 * Parameterized Dev Branch dtest in docker.
 *
 * Only the vanilla dtest target is used in the Cassandra-devbranch pipeline,
 *  but they are all added here for developers needing to pre-commit test them specifically.
 */
archs.each {
    def arch = it
    dtestTargets.each {
        def targetName = it
        def targetArchName = targetName + arch

        matrixJob("Cassandra-devbranch-${targetArchName}") {
            description(jobDescription)
            concurrentBuild()
            compressBuildLog()
            compressBuildLog()
            logRotator {
                numToKeep(90)
                artifactNumToKeep(5)
                artifactDaysToKeep(1)
            }
            wrappers {
                timeout {
                    noActivity(2400)
                }
                timestamps()
            }
            parameters {
                stringParam('REPO', 'apache', 'The github user/org to clone cassandra repo from')
                stringParam('BRANCH', 'trunk', 'The branch of cassandra to checkout')
                stringParam('DTEST_REPO', "${dtestRepo}", 'The cassandra-dtest repo URL')
                stringParam('DTEST_BRANCH', 'trunk', 'The branch of cassandra-dtest to checkout')
                stringParam('DOCKER_IMAGE', "${dtestDockerImage}", 'Docker image for running dtests')
            }
            axes {
                List<String> values = new ArrayList<String>()
                if (targetName == 'dtest-large' || targetName == 'dtest-large-novnode') {
                    splits = dtestLargeSplits
                } else {
                    splits = dtestSplits
                }
                (1..splits).each { values << it.toString() }
                text('split', values)
                if (targetName == 'dtest-large' || targetName == 'dtest-large-novnode') {
                    if (arch == "-arm64") {
                        label('label', slaveArm64DtestLargeLabel)
                    } else {
                        label('label', slaveDtestLargeLabel)
                    }
                } else {
                    if (arch == "-arm64") {
                        label('label', slaveArm64DtestLabel)
                    } else {
                        label('label', slaveDtestLabel)
                    }
                }
            }
            properties {
                githubProjectUrl(githubRepo)
                priorityJobProperty {
                    useJobPriority(true)
                    priority(6)
                }
            }
            scm {
                git {
                    remote {
                        url('https://github.com/${REPO}/cassandra.git')
                    }
                    branch('${BRANCH}')
                    extensions {
                        cleanAfterCheckout()
                        cloneOption {
                            shallow(false)
                            reference('.')
                            honorRefspec(true)
                            noTags(true)
                            timeout(maxJobHours * 60)
                        }
                    }
                }
            }
            steps {
                buildDescription('', buildDescStr)
                shell("""
                        git clean -xdff ;
                        git clone --depth 1 --single-branch -b ${buildsBranch} ${buildsRepo} ;
                        echo "cassandra-builds at: `git -C cassandra-builds log -1 --pretty=format:'%h %an %ad %s'`" ;
                        echo "Cassandra-devbranch-${targetArchName}) cassandra: `git log -1 --pretty=format:'%h %an %ad %s'`" > Cassandra-devbranch-${targetArchName}.head ;
                      """)
                if (arch == "-arm64") {
                    shell("""
                            # docker image has to be built on arm64 (they are not currently published to dockerhub)
                            cd cassandra-builds/docker/testing ;
                            docker build -t \$DOCKER_IMAGE:latest -f ubuntu2004_j11.docker .
                          """)
                }
                shell("""
                    ./cassandra-builds/build-scripts/cassandra-dtest-pytest-docker.sh \$REPO \$BRANCH \$DTEST_REPO \$DTEST_BRANCH ${buildsRepo} ${buildsBranch} \$DOCKER_IMAGE ${targetName} \${split}/${splits} ;
                      """)
            }
            publishers {
                publishOverSsh {
                    server('Nightlies') {
                        transferSet {
                            sourceFiles("**/nosetests.xml,**/test_stdout.txt.xz,**/ccm_logs.tar.xz")
                            remoteDirectory("cassandra/devbranch/Cassandra-devbranch-${targetArchName}/\${BUILD_NUMBER}/\${JOB_NAME}/")
                        }
                    }
                    failOnError(false)
                }
                archiveArtifacts {
                    pattern('**/nosetests.xml,**/*.head')
                    allowEmpty()
                    fingerprint()
                }
                archiveJunit('nosetests.xml')
                postBuildTask {
                    // docker needs to (soon or later) prune its volumes too, but that can only be done when the agent is idle
                    // if the agent is busy, just prune everything that is older than maxJobHours
                    task('.', """
                        echo "Cleaning project…" ; git clean -xdff ;
                        echo "Pruning docker…" ;
                        if pgrep -af "cassandra-builds/build-scripts" ; then docker system prune --all --force --filter "until=${maxJobHours}h" ; else  docker system prune --all --force --volumes ;  fi;
                        echo "Reporting disk usage…"; df -h ;
                        echo "Cleaning tmp…";
                        find . -type d -name tmp -delete 2>/dev/null ;
                        find /tmp -type f -atime +2 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
                    """)
                }
            }
        }
    }
}


/**
 * Parameterized Dev Branch cqlsh-tests
 */
matrixJob('Cassandra-devbranch-cqlsh-tests') {
    description(jobDescription)
    concurrentBuild()
    compressBuildLog()
    logRotator {
        numToKeep(90)
        artifactNumToKeep(5)
        artifactDaysToKeep(1)
    }
    wrappers {
        timeout {
            noActivity(1200)
        }
        timestamps()
    }
    throttleConcurrentBuilds {
        categories(['Cassandra'])
    }
    parameters {
        stringParam('REPO', 'apache', 'The github user/org to clone cassandra repo from')
        stringParam('BRANCH', 'trunk', 'The branch of cassandra to checkout')
        stringParam('DTEST_REPO', "${dtestRepo}", 'The cassandra-dtest repo URL')
        stringParam('DTEST_BRANCH', 'trunk', 'The branch of cassandra-dtest to checkout')
    }
    axes {
        text('cython', 'yes', 'no')
        jdk(jdkLabel)
        if (use_arm64_test_label()) {
            label('label', slaveLabel, slaveArm64Label)
        } else {
            label('label', slaveLabel)
        }
    }
    // this should prevent long path expansion from the axis definitions
    childCustomWorkspace('.')
    properties {
        githubProjectUrl(githubRepo)
        priorityJobProperty {
            useJobPriority(true)
            priority(3)
        }
    }
    scm {
        git {
            remote {
                url('https://github.com/${REPO}/cassandra.git')
            }
            branch('${BRANCH}')
            extensions {
                cleanAfterCheckout()
                cloneOption {
                    shallow(false)
                    reference('.')
                    honorRefspec(true)
                    noTags(true)
                    timeout(maxJobHours * 60)
                }
            }
        }
    }
    steps {
        buildDescription('', buildDescStr)
        shell("""
                git clean -xdff ;
                echo "Cassandra-devbranch-cqlsh-tests) cassandra: `git log -1 --pretty=format:'%h %an %ad %s'`" > Cassandra-devbranch-cqlsh-tests.head ;
              """)
        shell('./pylib/cassandra-cqlsh-tests.sh $WORKSPACE')
    }
    publishers {
        publishOverSsh {
            server('Nightlies') {
                transferSet {
                    sourceFiles("**/test_stdout.txt.xz,**/ccm_logs.tar.xz")
                    remoteDirectory("cassandra/devbranch/Cassandra-devbranch-cqlsh-tests/\${BUILD_NUMBER}/\${JOB_NAME}/")
                }
            }
            failOnError(false)
        }
        archiveArtifacts {
            pattern('**/cqlshlib.xml,**/*.head')
            allowEmpty()
            fingerprint()
        }
        archiveJunit('**/cqlshlib.xml')
        postBuildTask {
            // docker needs to (soon or later) prune its volumes too, but that can only be done when the agent is idle
            // if the agent is busy, just prune everything that is older than maxJobHours
            task('.', """
                echo "Cleaning project…"; git clean -xdff ;
                echo "Pruning docker…" ;
                if pgrep -af "cassandra-builds/build-scripts" ; then docker system prune --all --force --filter "until=${maxJobHours}h" ; else  docker system prune --all --force --volumes ;  fi;
                echo "Reporting disk usage…"; df -h ;
                echo "Cleaning tmp…";
                find . -type d -name tmp -delete 2>/dev/null ;
                find /tmp -type f -atime +2 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
            """)
        }
    }
}


/**
 * Parameterized Dev Branch Pipeline
 */
pipelineJob('Cassandra-devbranch') {
    description(jobDescription)
    logRotator {
        numToKeep(90)
        artifactNumToKeep(10)
    }
    parameters {
        stringParam('REPO', 'apache', 'The github user/org to clone cassandra repo from')
        stringParam('BRANCH', 'trunk', 'The branch of cassandra to checkout')
        stringParam('DTEST_REPO', "${dtestRepo}", 'The cassandra-dtest repo URL')
        stringParam('DTEST_BRANCH', 'trunk', 'The branch of cassandra-dtest to checkout')
        stringParam('DOCKER_IMAGE', "${dtestDockerImage}", 'Docker image for running dtests')
    }
    properties {
        githubProjectUrl(githubRepo)
        priorityJobProperty {
            useJobPriority(true)
            priority(1)
        }
    }
    definition {
        cps {
            // Cassandra-devbranch still needs custom Jenkinsfile because of the parameters passed into the build jobs.
            script(readFileFromWorkspace('Cassandra-Job-DSL', 'jenkins-dsl/cassandra_pipeline.groovy'))
        }
    }
}

////////////////////////////////////////////////////////////
//
// Jobs for Other Cassandra Projects
//
////////////////////////////////////////////////////////////

job('cassandra-website') {
    description(jobDescription)
    label('git-websites')
    compressBuildLog()
    logRotator {
        numToKeep(10)
        artifactNumToKeep(10)
    }
    wrappers {
        preBuildCleanup()
        timeout {
            noActivity(300)
        }
        timestamps()
    }
    properties {
        githubProjectUrl('https://github.com/apache/cassandra-website/')
        priorityJobProperty {
            useJobPriority(true)
            priority(1)
        }
    }
    scm {
        git {
            remote {
                url('https://gitbox.apache.org/repos/asf/cassandra-website.git')
                credentials('9b041bd0-aea9-4498-a576-9eeb771411dd') // "jenkins"
            }
            branch('*/trunk')
            extensions {
                wipeOutWorkspace()
                cleanBeforeCheckout()
                cleanAfterCheckout()
            }
        }
    }
    triggers {
        scm('H/5 * * * *')
    }
    steps {
        buildDescription('', buildDescStr)
        // the chmod below is a hack for INFRA-20814
        // for debugging it can be useful to add a `git show --stat HEAD` before the push
        shell("""
                git checkout asf-staging ;
                git reset --hard origin/trunk ;
                docker-compose build --build-arg UID=`id -u` --build-arg GID=`id -g` cassandra-website ;
                chmod -R 777 src content ;
                docker-compose run cassandra-website ;
                git add content/ src/doc/ ;
                git commit -a -m "generate docs for `git rev-parse --short HEAD`" ;
                git push -f origin asf-staging ;
              """)
    }
}
