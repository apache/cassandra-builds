////////////////////////////////////////////////////////////
//
// Common Vars and Branch List
//
////////////////////////////////////////////////////////////

def jobDescription = 'Apache Cassandra DSL-generated job - DSL git repo: <a href="https://git-wip-us.apache.org/repos/asf?p=cassandra-builds.git">cassandra-builds</a>'
def jdkLabel = 'jdk1.8.0_66-unlimited-security'
def slaveLabel = 'cassandra'
def mainRepo = 'https://git-wip-us.apache.org/repos/asf/cassandra.git'
def buildsRepo = 'https://git.apache.org/cassandra-builds.git'
def buildDescStr = 'REF = ${GIT_BRANCH} <br /> COMMIT = ${GIT_COMMIT}'
// Cassandra active branches
def cassandraBranches = ['cassandra-2.2', 'cassandra-3.0', 'cassandra-3.X', 'trunk']
// Ant test targets
def testTargets = ['test', 'test-all', 'test-burn', 'test-cdc', 'test-compression']

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
        numToKeep(10)
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
        shell("git clean -xdff ; git clone ${buildsRepo}")
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
        numToKeep(10)
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
        shell("git clean -xdff ; git clone ${buildsRepo}")
    }
    publishers {
        junit {
            testResults('**/TEST-*.xml')
            testDataPublishers {
                stabilityTestDataPublisher()
            }
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
        numToKeep(10)
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
        shell("git clean -xdff ; git clone ${buildsRepo}")
    }
    publishers {
        junit {
            testResults('nosetests.xml')
            testDataPublishers {
                stabilityTestDataPublisher()
            }
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

        job("${jobNamePrefix}-${targetName}") {
            disabled(false)
            using('Cassandra-template-test')
            configure { node ->
                node / scm / branches / 'hudson.plugins.git.BranchSpec' / name(branchName)
            }
            steps {
                shell("./cassandra-builds/build-scripts/cassandra-unittest.sh ${targetName}")
            }
        }
    }

//    /**
//     * Main branch dtest variation jobs
//     */
//    dtestTargets.each {
//        def targetName = it
//
//        job("${jobNamePrefix}-${targetName}") {
//            //disabled(false)
//            using('Cassandra-template-dtest')
//            configure { node ->
//                node / scm / branches / 'hudson.plugins.git.BranchSpec' / name(branchName)
//            }
//            steps {
//                shell("./cassandra-builds/build-scripts/cassandra-dtest.sh ${targetName}")
//            }
//        }
//    }




}
