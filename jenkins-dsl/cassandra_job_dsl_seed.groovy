////////////////////////////////////////////////////////////
//
// Common Vars and Branch List
//
////////////////////////////////////////////////////////////

def jobDescription = '<img src="http://cassandra.apache.org/img/cassandra_logo.png" /><br/>Apache Cassandra DSL-generated job - DSL git repo: <a href="https://gitbox.apache.org/repos/asf?p=cassandra-builds.git">cassandra-builds</a>'
def jdkLabel = 'JDK 1.8 (latest)'
if(binding.hasVariable("CASSANDRA_JDK_LABEL")) {
    jdkLabel = "${CASSANDRA_JDK_LABEL}"
}
def slaveLabel = 'cassandra'
if(binding.hasVariable("CASSANDRA_SLAVE_LABEL")) {
    slaveLabel = "${CASSANDRA_SLAVE_LABEL}"
}
// The dtest-large target needs to run on >=32G slaves
def largeSlaveLabel = 'cassandra-large'
if(binding.hasVariable("CASSANDRA_LARGE_SLAVE_LABEL")) {
    largeSlaveLabel = "${CASSANDRA_LARGE_SLAVE_LABEL}"
}
def mainRepo = "https://gitbox.apache.org/repos/asf/cassandra.git"
if(binding.hasVariable("CASSANDRA_GIT_URL")) {
    mainRepo = "${CASSANDRA_GIT_URL}"
}
def buildsRepo = "https://gitbox.apache.org/repos/asf/cassandra-builds.git"
if(binding.hasVariable("CASSANDRA_BUILDS_GIT_URL")) {
    buildsRepo = "${CASSANDRA_BUILDS_GIT_URL}"
}
def buildsBranch = "master"
if(binding.hasVariable("CASSANDRA_BUILDS_BRANCH")) {
    buildsBranch = "${CASSANDRA_BUILDS_BRANCH}"
}
def dtestRepo = "https://gitbox.apache.org/repos/asf/cassandra-dtest.git"
if(binding.hasVariable("CASSANDRA_DTEST_GIT_URL")) {
    dtestRepo = "${CASSANDRA_DTEST_GIT_URL}"
}
def buildDescStr = 'REF = ${GIT_BRANCH} <br /> COMMIT = ${GIT_COMMIT}'
// Cassandra active branches
def cassandraBranches = ['cassandra-2.2', 'cassandra-3.0', 'cassandra-3.11', 'trunk']
if(binding.hasVariable("CASSANDRA_BRANCHES")) {
    cassandraBranches = "${CASSANDRA_BRANCHES}".split(",")
}
// Ant test targets
def testTargets = ['test', 'test-burn', 'test-cdc', 'test-compression', 'stress-test', 'fqltool-test', 'long-test', 'jvm-dtest']
if(binding.hasVariable("CASSANDRA_ANT_TEST_TARGETS")) {
    testTargets = "${CASSANDRA_ANT_TEST_TARGETS}".split(",")
}

// Dtest test targets
def dtestTargets = ['dtest', 'dtest-novnode', 'dtest-offheap', 'dtest-large']
if(binding.hasVariable("CASSANDRA_DTEST_TEST_TARGETS")) {
    dtestTargets = "${CASSANDRA_DTEST_TEST_TARGETS}".split(",")
}
def dtestDockerImage = 'spod/cassandra-testing-ubuntu18-java11'
if(binding.hasVariable("CASSANDRA_DOCKER_IMAGE")) {
    dtestDockerImage = "${CASSANDRA_DOCKER_IMAGE}"
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
job('Cassandra-template-artifacts') {
    disabled(true)
    description(jobDescription)
    jdk(jdkLabel)
    label(slaveLabel)
    compressBuildLog()
    logRotator {
        numToKeep(25)
        artifactNumToKeep(1)
    }
    wrappers {
        timeout {
            noActivity(300)
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
            }
        }
    }
    steps {
        buildDescription('', buildDescStr)
        shell("git clean -xdff ; git clone -b ${buildsBranch} ${buildsRepo}")
    }
    publishers {
        archiveArtifacts('build/*.tar.gz, build/**/eclipse_compiler_checks.txt')
        archiveJavadoc {
            javadocDir 'build/javadoc'
            keepAll false
        }
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
        postBuildTask {
            task('.', '''
                echo "Cleaning project…"; ant realclean;
                echo "Reporting disk usage…"; df -h ; du -hs `pwd` ; du -hs ../* ;
                echo "Cleaning tmp…";
                find /tmp -type f -atime +3 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
                ''')
        }
    }
}

/**
 * Ant test template
 */
job('Cassandra-template-test') {
    disabled(true)
    description(jobDescription)
    jdk(jdkLabel)
    label(slaveLabel)
    compressBuildLog()
    logRotator {
        numToKeep(25)
        artifactNumToKeep(1)
    }
    wrappers {
        timeout {
            noActivity(1200)
        }
    }
    throttleConcurrentBuilds {
        categories(['Cassandra'])
    }
    scm {
        git {
            remote {
                url(mainRepo)
            }
            branch('*/null')
            extensions {
                cleanAfterCheckout()
            }
        }
    }
    steps {
        buildDescription('', buildDescStr)
        shell("git clean -xdff ; git clone -b ${buildsBranch} ${buildsRepo}")
    }
    publishers {
        archiveArtifacts {
            pattern('build/test/**/TEST-*.xml,build/**/eclipse_compiler_checks.txt')
            allowEmpty()
            fingerprint()
        }
        archiveJunit('build/test/**/TEST-*.xml') {
            testDataPublishers {
                publishTestStabilityData()
            }
        }
        postBuildTask {
            task('.', '''
                echo "Finding job process orphans…"; if pgrep -af ${JOB_BASE_NAME}; then pkill -9 -f ${JOB_BASE_NAME}; fi;
                echo "Cleaning project…"; ant realclean;
                echo "Reporting disk usage…"; df -h ; du -hs `pwd` ; du -hs ../* ;
                echo "Cleaning tmp…";
                find /tmp -type f -atime +3 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
            ''')
        }
    }
}

/**
 * Dtest template
 */
job('Cassandra-template-dtest') {
    disabled(true)
    description(jobDescription)
    jdk(jdkLabel)
    label(slaveLabel)
    compressBuildLog()
    logRotator {
        numToKeep(25)
        artifactNumToKeep(1)
    }
    wrappers {
        timeout {
            noActivity(1200)
        }
    }
    throttleConcurrentBuilds {
        categories(['Cassandra'])
    }
    scm {
        git {
            remote {
                url(mainRepo)
            }
            branch('*/null')
            extensions {
                cleanAfterCheckout()
            }
        }
    }
    steps {
        buildDescription('', buildDescStr)
        shell("git clean -xdff ; git clone -b ${buildsBranch} ${buildsRepo} ; git clone ${dtestRepo}")
    }
    publishers {
        archiveArtifacts {
            pattern('**/test_stdout.txt,**/nosetests.xml')
            allowEmpty()
            fingerprint()
        }
        archiveJunit('nosetests.xml') {
            testDataPublishers {
                publishTestStabilityData()
            }
        }
        postBuildTask {
            task('.', '''
                echo "Finding job process orphans…"; if pgrep -af ${JOB_BASE_NAME}; then pkill -9 -f ${JOB_BASE_NAME}; fi;
                echo "Cleaning project…"; ant realclean;
                echo "Reporting disk usage…"; df -h ; du -hs `pwd` ; du -hs ../* ;
                echo "Cleaning tmp…";
                find /tmp -type f -atime +3 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
            ''')
        }
    }
}

/**
 * cqlsh template
 */
matrixJob('Cassandra-template-cqlsh-tests') {
    disabled(true)
    description(jobDescription)
    compressBuildLog()
    logRotator {
        numToKeep(25)
        artifactNumToKeep(1)
    }
    wrappers {
        timeout {
            noActivity(1200)
        }
    }
    throttleConcurrentBuilds {
        categories(['Cassandra'])
    }
    axes {
        text('cython', 'yes', 'no')
        jdk(jdkLabel)
        label('label', slaveLabel)
    }
    // this should prevent long path expansion from the axis definitions
    childCustomWorkspace('.')
    scm {
        git {
            remote {
                url(mainRepo)
            }
            branch('*/null')
            extensions {
                cleanAfterCheckout()
            }
        }
    }
    steps {
        buildDescription('', buildDescStr)
        shell("git clean -xdff ; git clone ${dtestRepo}")
    }
    publishers {
        archiveArtifacts {
            pattern('**/cqlshlib.xml,**/nosetests.xml')
            allowEmpty()
            fingerprint()
        }
        archiveJunit('**/cqlshlib.xml,**/nosetests.xml') {
            testDataPublishers {
                publishTestStabilityData()
            }
        }
        postBuildTask {
            task('.', '''
                echo "Finding job process orphans…"; if pgrep -af ${JOB_BASE_NAME}; then pkill -9 -f ${JOB_BASE_NAME}; fi;
                echo "Cleaning project…"; ant realclean;
                echo "Reporting disk usage…"; df -h ; du -hs `pwd` ; du -hs ../* ;
                echo "Cleaning tmp…";
                find /tmp -type f -atime +3 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
            ''')
        }
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
    job("${jobNamePrefix}-artifacts") {
        disabled(false)
        using('Cassandra-template-artifacts')
        configure { node ->
            node / scm / branches / 'hudson.plugins.git.BranchSpec' / name(branchName)
        }
        steps {
            shell('./cassandra-builds/build-scripts/cassandra-artifacts.sh')
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
             job("${jobNamePrefix}-${targetName}") {
                disabled(false)
                using('Cassandra-template-test')
                configure { node ->
                    node / scm / branches / 'hudson.plugins.git.BranchSpec' / name(branchName)
                }
                steps {
                    shell("./cassandra-builds/build-scripts/cassandra-test.sh ${targetName}")
                }
            }
        }
    }

    /**
     * Main branch dtest variation jobs
     */
    dtestTargets.each {
        def targetName = it

        // Skip dtest-offheap on cassandra-3.0 branch
        if ((targetName == 'dtest-offheap') && (branchName == 'cassandra-3.0')) {
            println("Skipping ${targetName} on branch ${branchName}")
        } else {
            job("${jobNamePrefix}-${targetName}") {
                disabled(false)
                using('Cassandra-template-dtest')
                if (targetName == 'dtest-large') {
                    label(largeSlaveLabel)
                }
                configure { node ->
                    node / scm / branches / 'hudson.plugins.git.BranchSpec' / name(branchName)
                }
                steps {
                    shell("sh ./cassandra-builds/docker/jenkins/jenkinscommand.sh apache ${branchName} https://github.com/apache/cassandra-dtest.git master ${buildsRepo} ${buildsBranch} ${dtestDockerImage} ${targetName}")
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
            steps {
                shell("git clean -xdff")
                shell('./pylib/cassandra-cqlsh-tests.sh $WORKSPACE')
            }
        }
    }

    /**
     * Branch Pipelines
     */
    pipelineJob("${jobNamePrefix}") {
        description(jobDescription)
        compressBuildLog()
        logRotator {
            numToKeep(25)
            artifactNumToKeep(1)
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
job('Cassandra-devbranch-artifacts') {
    description(jobDescription)
    jdk(jdkLabel)
    label(slaveLabel)
    compressBuildLog()
    logRotator {
        numToKeep(25)
        artifactNumToKeep(1)
    }
    wrappers {
        timeout {
            noActivity(300)
        }
    }
    throttleConcurrentBuilds {
        categories(['Cassandra'])
    }
    parameters {
        stringParam('REPO', 'apache', 'The github user/org to clone cassandra repo from')
        stringParam('BRANCH', 'trunk', 'The branch of cassandra to checkout')
    }
    scm {
        git {
            remote {
                url('https://github.com/${REPO}/cassandra.git')
            }
            branch('${BRANCH}')
            extensions {
                cleanAfterCheckout()
            }
        }
    }
    steps {
        buildDescription('', buildDescStr)
        shell("git clean -xdff ; git clone -b ${buildsBranch} ${buildsRepo}")
    }
    publishers {
        postBuildTask {
            task('.', '''
                echo "Cleaning project…";
                ant realclean;
                echo "Reporting disk usage…";
                df -h ; du -hs `pwd` ; du -hs ../* ;
                echo "Cleaning tmp…";
                find /tmp -type -f -atime +3 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
                ''')
        }
    }
}

/**
 * Parameterized Dev Branch `ant test`
 */
testTargets.each {
    def targetName = it

    job("Cassandra-devbranch-${targetName}") {
        description(jobDescription)
        concurrentBuild()
        jdk(jdkLabel)
        label(slaveLabel)
        compressBuildLog()
        logRotator {
            numToKeep(25)
            artifactNumToKeep(1)
        }
        wrappers {
            timeout {
                noActivity(1200)
            }
        }
        throttleConcurrentBuilds {
            categories(['Cassandra'])
        }
        parameters {
            stringParam('REPO', 'apache', 'The github user/org to clone cassandra repo from')
            stringParam('BRANCH', 'trunk', 'The branch of cassandra to checkout')
        }
        scm {
            git {
                remote {
                    url('https://github.com/${REPO}/cassandra.git')
                }
                branch('${BRANCH}')
                extensions {
                    cleanAfterCheckout()
                }
            }
        }
        steps {
            buildDescription('', buildDescStr)
            shell("git clean -xdff ; git clone -b ${buildsBranch} ${buildsRepo}")
            shell("./cassandra-builds/build-scripts/cassandra-test.sh ${targetName}")
        }
        publishers {
            archiveArtifacts {
                pattern('build/test/**/TEST-*.xml,build/**/eclipse_compiler_checks.txt')
                allowEmpty()
                fingerprint()
            }
            archiveJunit('build/test/**/TEST-*.xml') {
                testDataPublishers {
                    publishTestStabilityData()
                }
            }
            postBuildTask {
                task('.', '''
                    echo "Finding job process orphans…"; if pgrep -af ${JOB_BASE_NAME}; then pkill -9 -f ${JOB_BASE_NAME}; fi;
                    echo "Cleaning project…"; ant realclean;
                    echo "Reporting disk usage…"; df -h ; du -hs `pwd` ; du -hs ../* ;
                    echo "Cleaning tmp…";
                    find /tmp -type f -atime +3 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
                ''')
            }
        }
    }
}

/**
 * Parameterized Dev Branch dtest in docker
 */
job('Cassandra-devbranch-dtest') {
    description(jobDescription)
    concurrentBuild()
    jdk(jdkLabel)
    label(slaveLabel)
    compressBuildLog()
    logRotator {
        numToKeep(25)
        artifactNumToKeep(1)
    }
    wrappers {
        timeout {
            noActivity(2400)
        }
    }
    throttleConcurrentBuilds {
        categories(['Cassandra'])
    }
    parameters {
        stringParam('REPO', 'apache', 'The github user/org to clone cassandra repo from')
        stringParam('BRANCH', 'trunk', 'The branch of cassandra to checkout')
        stringParam('DTEST_REPO', "${dtestRepo}", 'The cassandra-dtest repo URL')
        stringParam('DTEST_BRANCH', 'master', 'The branch of cassandra-dtest to checkout')
        stringParam('DOCKER_IMAGE', "${dtestDockerImage}", 'Docker image for running dtests')
    }
    scm {
        git {
            remote {
                url('https://github.com/${REPO}/cassandra.git')
            }
            branch('${BRANCH}')
            extensions {
                cleanAfterCheckout()
            }
        }
    }
    steps {
        buildDescription('', buildDescStr)
        shell("git clean -xdff ; git clone -b ${buildsBranch} ${buildsRepo}")
        shell("sh ./cassandra-builds/docker/jenkins/jenkinscommand.sh \$REPO \$BRANCH \$DTEST_REPO \$DTEST_BRANCH ${buildsRepo} ${buildsBranch} \$DOCKER_IMAGE")
    }
    publishers {
        archiveArtifacts {
            pattern('**/test_stdout.txt,**/nosetests.xml')
            allowEmpty()
            fingerprint()
        }
        archiveJunit('nosetests.xml') {
            testDataPublishers {
                publishTestStabilityData()
            }
        }
        postBuildTask {
            task('.', '''
                echo "Finding job process orphans…"; if pgrep -af ${JOB_BASE_NAME}; then pkill -9 -f ${JOB_BASE_NAME}; fi;
                echo "Cleaning project…"; ant realclean;
                echo "Reporting disk usage…"; df -h ; du -hs `pwd` ; du -hs ../* ;
                echo "Cleaning tmp…";
                find /tmp -type f -atime +3 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
            ''')
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
        numToKeep(25)
        artifactNumToKeep(1)
    }
    wrappers {
        timeout {
            noActivity(1200)
        }
    }
    throttleConcurrentBuilds {
        categories(['Cassandra'])
    }
    parameters {
        stringParam('REPO', 'apache', 'The github user/org to clone cassandra repo from')
        stringParam('BRANCH', 'trunk', 'The branch of cassandra to checkout')
        stringParam('DTEST_REPO', "${dtestRepo}", 'The cassandra-dtest repo URL')
        stringParam('DTEST_BRANCH', 'master', 'The branch of cassandra-dtest to checkout')
    }
    axes {
        text('cython', 'yes', 'no')
        jdk(jdkLabel)
        label('label', slaveLabel)
    }
    // this should prevent long path expansion from the axis definitions
    childCustomWorkspace('.')
    scm {
        git {
            remote {
                url('https://github.com/${REPO}/cassandra.git')
            }
            branch('${BRANCH}')
            extensions {
                cleanAfterCheckout()
            }
        }
    }
    steps {
        buildDescription('', buildDescStr)
        shell("git clean -xdff")
        shell('./pylib/cassandra-cqlsh-tests.sh $WORKSPACE')
    }
    publishers {
        archiveArtifacts {
            pattern('**/cqlshlib.xml,**/nosetests.xml')
            allowEmpty()
            fingerprint()
        }
        archiveJunit('**/cqlshlib.xml,**/nosetests.xml') {
            testDataPublishers {
                publishTestStabilityData()
            }
        }
        postBuildTask {
            task('.', '''
                echo "Finding job process orphans…"; if pgrep -af ${JOB_BASE_NAME}; then pkill -9 -f ${JOB_BASE_NAME}; fi;
                echo "Cleaning project…"; ant realclean;
                echo "Reporting disk usage…"; df -h ; du -hs `pwd` ; du -hs ../* ;
                echo "Cleaning tmp…";
                find /tmp -type f -atime +3 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
            ''')
        }
    }
}


/**
 * Parameterized Dev Branch Pipeline
 */
pipelineJob('Cassandra-devbranch') {
    description(jobDescription)
    compressBuildLog()
    logRotator {
        numToKeep(25)
        artifactNumToKeep(1)
    }
    parameters {
        stringParam('REPO', 'apache', 'The github user/org to clone cassandra repo from')
        stringParam('BRANCH', 'trunk', 'The branch of cassandra to checkout')
        stringParam('DTEST_REPO', "${dtestRepo}", 'The cassandra-dtest repo URL')
        stringParam('DTEST_BRANCH', 'master', 'The branch of cassandra-dtest to checkout')
        stringParam('DOCKER_IMAGE', "${dtestDockerImage}", 'Docker image for running dtests')
    }
    definition {
        cps {
            // Cassandra-devbranch still needs custom Jenkinsfile because of the parameters passed into the build jobs.
            script(readFileFromWorkspace('Cassandra-Job-DSL', 'jenkins-dsl/cassandra_pipeline.groovy'))
            sandbox()
        }
    }
}
