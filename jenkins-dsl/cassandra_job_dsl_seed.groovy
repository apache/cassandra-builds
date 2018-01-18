////////////////////////////////////////////////////////////
//
// Common Vars and Branch List
//
////////////////////////////////////////////////////////////

def jobDescription = 'Apache Cassandra DSL-generated job - DSL git repo: <a href="https://git-wip-us.apache.org/repos/asf?p=cassandra-builds.git">cassandra-builds</a>'
def jdkLabel = 'JDK 1.8 (latest)'
if(binding.hasVariable("CASSANDRA_JDK_LABEL")) {
    jdkLabel = "${CASSANDRA_JDK_LABEL}"
}
def slaveLabel = 'cassandra'
if(binding.hasVariable("CASSANDRA_SLAVE_LABEL")) {
    slaveLabel = "${CASSANDRA_SLAVE_LABEL}"
}
// The dtest-large target needs to run on >=32G slaves, so we provide an "OR" list of those servers
def largeSlaveLabel = 'cassandra6||cassandra7'
if(binding.hasVariable("CASSANDRA_LARGE_SLAVE_LABEL")) {
    largeSlaveLabel = "${CASSANDRA_LARGE_SLAVE_LABEL}"
}
def mainRepo = "https://git-wip-us.apache.org/repos/asf/cassandra.git"
if(binding.hasVariable("CASSANDRA_GIT_URL")) {
    mainRepo = "${CASSANDRA_GIT_URL}"
}
def buildsRepo = "https://git.apache.org/cassandra-builds.git"
if(binding.hasVariable("CASSANDRA_BUILDS_GIT_URL")) {
    buildsRepo = "${CASSANDRA_BUILDS_GIT_URL}"
}
def buildsBranch = "master"
if(binding.hasVariable("CASSANDRA_BUILDS_BRANCH")) {
    buildsBranch = "${CASSANDRA_BUILDS_BRANCH}"
}
def dtestRepo = "https://git.apache.org/cassandra-dtest.git"
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
def testTargets = ['test', 'test-all', 'test-burn', 'test-cdc', 'test-compression']
if(binding.hasVariable("CASSANDRA_ANT_TEST_TARGETS")) {
    testTargets = "${CASSANDRA_ANT_TEST_TARGETS}".split(",")
}
// Dtest test targets
def dtestTargets = ['dtest', 'dtest-novnode', 'dtest-offheap', 'dtest-large']
if(binding.hasVariable("CASSANDRA_DTEST_TEST_TARGETS")) {
    dtestTargets = "${CASSANDRA_DTEST_TEST_TARGETS}".split(",")
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
    logRotator {
        numToKeep(50)
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
    triggers {
        scm('H/30 * * * *')
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
    logRotator {
        numToKeep(50)
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
    triggers {
        scm('@daily')
    }
    steps {
        buildDescription('', buildDescStr)
        shell("git clean -xdff ; git clone -b ${buildsBranch} ${buildsRepo}")
    }
    publishers {
        archiveJunit('**/TEST-*.xml') {
            testDataPublishers {
                publishTestStabilityData()
            }
        }
        postBuildTask {
            task('.', 'echo "Finding job process orphans.."; if pgrep -af ${JOB_BASE_NAME}; then pkill -9 -f ${JOB_BASE_NAME}; fi')
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
    logRotator {
        numToKeep(50)
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
        archiveArtifacts('test_stdout.txt')
        archiveJunit('cassandra-dtest/nosetests.xml') {
            testDataPublishers {
                publishTestStabilityData()
            }
        }
        postBuildTask {
            task('.', 'echo "Finding job process orphans.."; if pgrep -af ${JOB_BASE_NAME}; then pkill -9 -f ${JOB_BASE_NAME}; fi')
        }
    }
}

/**
 * cqlsh template
 */
matrixJob('Cassandra-template-cqlsh-tests') {
    disabled(true)
    description(jobDescription)
    logRotator {
        numToKeep(50)
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
    triggers {
        scm('@weekly')
    }
    steps {
        buildDescription('', buildDescStr)
        shell("git clean -xdff ; git clone -b ${buildsBranch} ${buildsRepo} ; git clone ${dtestRepo}")
    }
    publishers {
        archiveJunit('cqlshlib.xml, nosetests.xml') {
            testDataPublishers {
                publishTestStabilityData()
            }
        }
        postBuildTask {
            task('.', 'echo "Finding job process orphans.."; if pgrep -af ${JOB_BASE_NAME}; then pkill -9 -f ${JOB_BASE_NAME}; fi')
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

        // Run default ant test daily and variations weekly
        if (targetName == 'test') {
            triggerInterval = '@daily'
        } else {
            triggerInterval = '@weekly'
        }

        // Skip test-cdc on cassandra-2.2 and cassandra-3.0 branches
        if ((targetName == 'test-cdc') && ((branchName == 'cassandra-2.2') || (branchName == 'cassandra-3.0'))) {
            println("Skipping ${targetName} on branch ${branchName}")
        } else {
             job("${jobNamePrefix}-${targetName}") {
                disabled(false)
                using('Cassandra-template-test')
                configure { node ->
                    node / scm / branches / 'hudson.plugins.git.BranchSpec' / name(branchName)
                }
                triggers {
                    scm(triggerInterval)
                }
                steps {
                    shell("./cassandra-builds/build-scripts/cassandra-unittest.sh ${targetName}")
                }
            }
        }
    }

    /**
     * Main branch dtest variation jobs
     */
    dtestTargets.each {
        def targetName = it

        // Run default dtest daily and variations weekly
        if (targetName == 'dtest') {
            triggerInterval = '@daily'
        } else {
            triggerInterval = '@weekly'
        }

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
                triggers {
                    scm(triggerInterval)
                }
                steps {
                    shell("./cassandra-builds/build-scripts/cassandra-dtest.sh ${targetName}")
                }
            }
        }
    }

    /**
     * Main branch cqlsh jobs
     */
    matrixJob("${jobNamePrefix}-cqlsh-tests") {
        disabled(false)
        using('Cassandra-template-cqlsh-tests')
        configure { node ->
            node / scm / branches / 'hudson.plugins.git.BranchSpec' / name(branchName)
        }
        steps {
            shell('./cassandra-builds/build-scripts/cassandra-cqlsh-tests.sh')
        }
    }
}

////////////////////////////////////////////////////////////
//
// Parameterized Dev Branch Job Definitions
//
////////////////////////////////////////////////////////////

/**
 * Parameterized Dev Branch `ant test-all`
 */
job('Cassandra-devbranch-testall') {
    description(jobDescription)
    concurrentBuild()
    jdk(jdkLabel)
    label(slaveLabel)
    logRotator {
        numToKeep(50)
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
        shell('./cassandra-builds/build-scripts/cassandra-unittest.sh test-all')
    }
    publishers {
        archiveJunit('**/TEST-*.xml') {
            testDataPublishers {
                publishTestStabilityData()
            }
        }
        postBuildTask {
            task('.', 'echo "Finding job process orphans.."; if pgrep -af ${JOB_BASE_NAME}; then pkill -9 -f ${JOB_BASE_NAME}; fi')
        }
    }
}

/**
 * Parameterized Dev Branch dtest
 */
job('Cassandra-devbranch-dtest') {
    description(jobDescription)
    concurrentBuild()
    jdk(jdkLabel)
    label(slaveLabel)
    logRotator {
        numToKeep(50)
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
        stringParam('DTEST_SCRIPT', './cassandra-builds/build-scripts/cassandra-dtest.sh', 'A temporary means of specifying an alternate script to run the dtests.')
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
        shell('git clone -b ${DTEST_BRANCH} ${DTEST_REPO}')
        shell('${DTEST_SCRIPT}')
    }
    publishers {
        archiveArtifacts('test_stdout.txt')
        archiveJunit('cassandra-dtest/nosetests.xml') {
            testDataPublishers {
                publishTestStabilityData()
            }
        }
        postBuildTask {
            task('.', 'echo "Finding job process orphans.."; if pgrep -af ${JOB_BASE_NAME}; then pkill -9 -f ${JOB_BASE_NAME}; fi')
        }
    }
}

/**
 * Parameterized Dev Branch cqlsh-tests
 */
matrixJob('Cassandra-devbranch-cqlsh-tests') {
    description(jobDescription)
    concurrentBuild()
    logRotator {
        numToKeep(50)
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
        shell("git clean -xdff ; git clone -b ${buildsBranch} ${buildsRepo}")
        shell('git clone -b ${DTEST_BRANCH} ${DTEST_REPO}')
        shell('./cassandra-builds/build-scripts/cassandra-cqlsh-tests.sh')
    }
    publishers {
        archiveJunit('cqlshlib.xml, nosetests.xml') {
            testDataPublishers {
                publishTestStabilityData()
            }
        }
        postBuildTask {
            task('.', 'echo "Finding job process orphans.."; if pgrep -af ${JOB_BASE_NAME}; then pkill -9 -f ${JOB_BASE_NAME}; fi')
        }
    }
}
