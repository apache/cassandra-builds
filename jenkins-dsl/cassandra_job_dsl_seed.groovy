////////////////////////////////////////////////////////////
//
// Common Vars and Branch List
//
//  To update the variable via the Jenkins UI, use the EnvInject plugin
//   example: https://github.com/apache/cassandra-builds/pull/19#issuecomment-610822772
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
def githubRepo = "https://github.com/apache/cassandra"
if(binding.hasVariable("CASSANDRA_GIT_URL")) {
    mainRepo = "${CASSANDRA_GIT_URL}"
    // just presume custom repos are github, not critical if they are not
    githubRepo = "${mainRepo}".minus(".git")
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
def dtestTargets = ['dtest', 'dtest-novnode', 'dtest-offheap', 'dtest-large', 'dtest-upgrade']
if(binding.hasVariable("CASSANDRA_DTEST_TEST_TARGETS")) {
    dtestTargets = "${CASSANDRA_DTEST_TEST_TARGETS}".split(",")
}
def dtestDockerImage = 'nastra/cassandra-testing-ubuntu1910-java11'
if(binding.hasVariable("CASSANDRA_DOCKER_IMAGE")) {
    dtestDockerImage = "${CASSANDRA_DOCKER_IMAGE}"
}

// expected longest job runtime
def maxJobHours = '18'
if(binding.hasVariable("MAX_JOB_HOURS")) {
    maxJobHours = "${MAX_JOB_HOURS}"
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
        artifactNumToKeep(10)
    }
    wrappers {
        timeout {
            noActivity(300)
        }
        timestamps()
    }
    properties {
        githubProjectUrl(githubRepo)
        priority(1)
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
        shell("git clean -xdff ; git clone --depth 1 --single-branch -b ${buildsBranch} ${buildsRepo}")
    }
    publishers {
        archiveArtifacts('build/apache-cassandra-*.tar.gz, build/apache-cassandra-*.jar, build/apache-cassandra-*.pom, build/cassandra*.deb, build/cassandra*.rpm, build/**/eclipse_compiler_checks.txt')
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
            task('.', """
                echo "Cleaning project…"; git clean -xdff ;
                echo "Pruning docker…" ; docker system prune -f --filter "until=${maxJobHours}h"  ;
                echo "Reporting disk usage…"; df -h ; du -hs ../* ; du -hs ../../* ;
                echo "Cleaning tmp…";
                find . -type d -name tmp -delete 2>/dev/null ;
                find /tmp -type f -atime +2 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
            """)
        }
    }
}

/**
 * Ant test template
 */
job('Cassandra-template-test') {
    disabled(true)
    description(jobDescription)
    concurrentBuild()
    jdk(jdkLabel)
    label(slaveLabel)
    compressBuildLog()
    logRotator {
        numToKeep(10)
        artifactNumToKeep(10)
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
    properties {
        githubProjectUrl(githubRepo)
        priority(3)
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
        shell("git clean -xdff ; git clone --depth 1 --single-branch -b ${buildsBranch} ${buildsRepo}")
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
            task('.', """
                echo "Finding job process orphans…"; if pgrep -af "${JOB_BASE_NAME}"; then pkill -9 -f "${JOB_BASE_NAME}"; fi;
                echo "Cleaning project…"; git clean -xdff ;
                echo "Pruning docker…" ; docker system prune -f --filter "until=${maxJobHours}h"  ;
                echo "Reporting disk usage…"; df -h ; du -hs ../* ; du -hs ../../* ;
                echo "Cleaning tmp…";
                find . -type d -name tmp -delete 2>/dev/null ;
                find /tmp -type f -atime +2 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
            """)
        }
    }
}

/**
 * Dtest template
 */
job('Cassandra-template-dtest') {
    disabled(true)
    description(jobDescription)
    concurrentBuild()
    jdk(jdkLabel)
    label(slaveLabel)
    compressBuildLog()
    logRotator {
        numToKeep(10)
        artifactNumToKeep(10)
    }
    wrappers {
        timeout {
            noActivity(1200)
        }
        timestamps()
    }
    properties {
        githubProjectUrl(githubRepo)
        priority(5)
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
        shell("git clean -xdff ; git clone --depth 1 --single-branch -b ${buildsBranch} ${buildsRepo} ; git clone --depth 1 --single-branch ${dtestRepo}")
    }
    publishers {
        archiveArtifacts {
            pattern('**/test_stdout.txt,**/nosetests.xml,**/ccm_logs.tar.xz')
            allowEmpty()
            fingerprint()
        }
        archiveJunit('nosetests.xml') {
            testDataPublishers {
                publishTestStabilityData()
            }
        }
        postBuildTask {
            task('.', """
                echo "Cleaning project…"; git clean -xdff ;
                echo "Pruning docker…" ; if pgrep -af jenkinscommand.sh; then docker system prune -f --filter 'until=${maxJobHours}h'; else docker system prune -f --volumes ; fi;
                echo "Reporting disk usage…"; df -h ; du -hs ../* ; du -hs ../../* ;
                echo "Cleaning tmp…";
                find . -type d -name tmp -delete 2>/dev/null ;
                find /tmp -type f -atime +2 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
            """)
        }
    }
}

// wip – parallelise dtests, starting with just upgrade dtests
matrixJob('Cassandra-template-dtest-matrix') {
    disabled(true)
    description(jobDescription)
    concurrentBuild()
    compressBuildLog()
    logRotator {
        numToKeep(10)
        artifactNumToKeep(10)
    }
    wrappers {
        timeout {
            noActivity(1200)
        }
        timestamps()
    }
    properties {
        githubProjectUrl(githubRepo)
        priority(7)
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
        shell("git clean -xdff ; git clone --depth 1 --single-branch -b ${buildsBranch} ${buildsRepo} ; git clone --depth 1 --single-branch ${dtestRepo}")
    }
    publishers {
        archiveArtifacts {
            pattern('**/test_stdout.txt,**/nosetests.xml,**/ccm_logs.tar.xz')
            allowEmpty()
            fingerprint()
        }
        archiveJunit('nosetests.xml') {
            testDataPublishers {
                publishTestStabilityData()
            }
        }
        postBuildTask {
            task('.', """
                echo "Cleaning project…"; git clean -xdff ;
                echo "Pruning docker…" ; if pgrep -af jenkinscommand.sh; then docker system prune -f --filter 'until=${maxJobHours}h'; else docker system prune -f --volumes ; fi;
                echo "Reporting disk usage…"; df -h ; du -hs ../* ; du -hs ../../* ;
                echo "Cleaning tmp…";
                find . -type d -name tmp -delete 2>/dev/null ;
                find /tmp -type f -atime +2 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
            """)
        }
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
        artifactNumToKeep(10)
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
        label('label', slaveLabel)
    }
    // this should prevent long path expansion from the axis definitions
    childCustomWorkspace('.')
    properties {
        githubProjectUrl(githubRepo)
        priority(3)
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
        shell("git clean -xdff ; git clone --depth 1 --single-branch ${dtestRepo}")
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
            task('.', """
                echo "Finding job process orphans…"; if pgrep -af "${JOB_BASE_NAME}"; then pkill -9 -f "${JOB_BASE_NAME}"; fi;
                echo "Cleaning project…"; git clean -xdff ;
                echo "Pruning docker…" ; docker system prune -f --filter "until=${maxJobHours}h"  ;
                echo "Reporting disk usage…"; df -h ; du -hs ../* ; du -hs ../../* ;
                echo "Cleaning tmp…";
                find . -type d -name tmp -delete 2>/dev/null ;
                find /tmp -type f -atime +2 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
            """)
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
    matrixJob("${jobNamePrefix}-artifacts") {
        disabled(false)
        using('Cassandra-template-artifacts')
        axes {
            if (branchName == 'trunk') {
                jdk('JDK 1.8 (latest)','JDK 11 (latest)')
            } else {
                jdk('JDK 1.8 (latest)')
            }
            label('label', slaveLabel)
        }
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
        } else if (targetName == 'dtest-upgrade') {
            // wip – parallelise dtests, starting with just upgrade dtests
            matrixJob("${jobNamePrefix}-${targetName}") {
                disabled(false)
                using('Cassandra-template-dtest-matrix')
                axes {
                    splits = 64
                    List<String> values = new ArrayList<String>()
                    (1..splits).each { values << it.toString() }
                    text('split', values)
                    label('label', slaveLabel)
                }
                configure { node ->
                    node / scm / branches / 'hudson.plugins.git.BranchSpec' / name(branchName)
                }
                steps {
                    shell("sh ./cassandra-builds/docker/jenkins/jenkinscommand.sh apache ${branchName} https://github.com/apache/cassandra-dtest.git master ${buildsRepo} ${buildsBranch} ${dtestDockerImage} ${targetName} \${split}/${splits}")
                }
            }
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
            numToKeep(30)
            artifactNumToKeep(10)
        }
        properties {
            githubProjectUrl(githubRepo)
            priority(1)
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
matrixJob('Cassandra-devbranch-artifacts') {
    description(jobDescription)
    concurrentBuild()
    axes {
        jdk('JDK 1.8 (latest)','JDK 11 (latest)')
        label('label', slaveLabel)
    }
    compressBuildLog()
    logRotator {
        numToKeep(10)
        artifactNumToKeep(10)
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
        priority(1)
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
        shell("git clean -xdff ; git clone --depth 1 --single-branch -b ${buildsBranch} ${buildsRepo}")
        shell('./cassandra-builds/build-scripts/cassandra-artifacts.sh')
    }
    publishers {
        postBuildTask {
            task('.', """
                echo "Cleaning project…"; git clean -xdff ;
                echo "Pruning docker…" ; docker system prune -f --filter "until=${maxJobHours}h"  ;
                echo "Reporting disk usage…"; df -h ; du -hs ../* ; du -hs ../../* ;
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

    job("Cassandra-devbranch-${targetName}") {
        description(jobDescription)
        concurrentBuild()
        jdk(jdkLabel)
        label(slaveLabel)
        compressBuildLog()
        logRotator {
            numToKeep(10)
            artifactNumToKeep(10)
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
        }
        properties {
            githubProjectUrl(githubRepo)
            priority(3)
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
            shell("git clean -xdff ; git clone --depth 1 --single-branch -b ${buildsBranch} ${buildsRepo}")
            shell("./cassandra-builds/build-scripts/cassandra-test.sh ${targetName}")
        }
        publishers {
            archiveArtifacts {
                pattern('build/test/**/TEST-*.xml,build/**/eclipse_compiler_checks.txt')
                allowEmpty()
                fingerprint()
            }
            archiveJunit('build/test/**/TEST-*.xml') {
                allowEmptyResults()
            }
            postBuildTask {
                task('.', """
                    echo "Finding job process orphans…"; if pgrep -af "${JOB_BASE_NAME}"; then pkill -9 -f "${JOB_BASE_NAME}"; fi;
                    echo "Cleaning project…"; git clean -xdff ;
                    echo "Pruning docker…" ; docker system prune -f --filter "until=${maxJobHours}h"  ;
                    echo "Reporting disk usage…"; df -h ; du -hs ../* ; du -hs ../../* ;
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
dtestTargets.each {
    def targetName = it

    job("Cassandra-devbranch-${targetName}") {
        description(jobDescription)
        concurrentBuild()
        jdk(jdkLabel)
        if (targetName == 'dtest-large') {
            label(largeSlaveLabel)
        } else {
            label(slaveLabel)
        }
        compressBuildLog()
        logRotator {
            numToKeep(10)
            artifactNumToKeep(10)
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
            stringParam('DTEST_BRANCH', 'master', 'The branch of cassandra-dtest to checkout')
            stringParam('DOCKER_IMAGE', "${dtestDockerImage}", 'Docker image for running dtests')
        }
        properties {
            githubProjectUrl(githubRepo)
            priority(5)
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
            shell("git clean -xdff ; git clone --depth 1 --single-branch -b ${buildsBranch} ${buildsRepo}")
            shell("sh ./cassandra-builds/docker/jenkins/jenkinscommand.sh \$REPO \$BRANCH \$DTEST_REPO \$DTEST_BRANCH ${buildsRepo} ${buildsBranch} \$DOCKER_IMAGE  ${targetName}")
        }
        publishers {
            archiveArtifacts {
                pattern('**/test_stdout.txt,**/nosetests.xml,**/ccm_logs.tar.xz')
                allowEmpty()
                fingerprint()
            }
            archiveJunit('nosetests.xml')
            postBuildTask {
                task('.', """
                    echo "Cleaning project…" ; git clean -xdff ;
                    echo "Pruning docker…" ; if pgrep -af jenkinscommand.sh; then system prune -f --filter "until=${maxJobHours}h"; else docker system prune -f --volumes ; fi;
                    echo "Reporting disk usage…"; df -h ; du -hs ../* ; du -hs ../../* ;
                    echo "Cleaning tmp…";
                    find . -type d -name tmp -delete 2>/dev/null ;
                    find /tmp -type f -atime +2 -user jenkins -and -not -exec fuser -s {} ';' -and -delete 2>/dev/null
                """)
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
        numToKeep(10)
        artifactNumToKeep(10)
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
        stringParam('DTEST_BRANCH', 'master', 'The branch of cassandra-dtest to checkout')
    }
    axes {
        text('cython', 'yes', 'no')
        jdk(jdkLabel)
        label('label', slaveLabel)
    }
    // this should prevent long path expansion from the axis definitions
    childCustomWorkspace('.')
    properties {
        githubProjectUrl(githubRepo)
        priority(3)
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
        shell("git clean -xdff")
        shell('./pylib/cassandra-cqlsh-tests.sh $WORKSPACE')
    }
    publishers {
        archiveArtifacts {
            pattern('**/cqlshlib.xml,**/nosetests.xml')
            allowEmpty()
            fingerprint()
        }
        archiveJunit('**/cqlshlib.xml,**/nosetests.xml')
        postBuildTask {
            task('.', """
                echo "Finding job process orphans…"; if pgrep -af "${JOB_BASE_NAME}"; then pkill -9 -f "${JOB_BASE_NAME}"; fi;
                echo "Cleaning project…"; git clean -xdff ;
                echo "Pruning docker…" ; docker system prune -f --filter "until=${maxJobHours}h" ;
                echo "Reporting disk usage…"; df -h ; du -hs ../* ; du -hs ../../* ;
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
    compressBuildLog()
    logRotator {
        numToKeep(30)
        artifactNumToKeep(10)
    }
    parameters {
        stringParam('REPO', 'apache', 'The github user/org to clone cassandra repo from')
        stringParam('BRANCH', 'trunk', 'The branch of cassandra to checkout')
        stringParam('DTEST_REPO', "${dtestRepo}", 'The cassandra-dtest repo URL')
        stringParam('DTEST_BRANCH', 'master', 'The branch of cassandra-dtest to checkout')
        stringParam('DOCKER_IMAGE', "${dtestDockerImage}", 'Docker image for running dtests')
    }
    properties {
        githubProjectUrl(githubRepo)
        priority(1)
    }
    definition {
        cps {
            // Cassandra-devbranch still needs custom Jenkinsfile because of the parameters passed into the build jobs.
            script(readFileFromWorkspace('Cassandra-Job-DSL', 'jenkins-dsl/cassandra_pipeline.groovy'))
        }
    }
}
