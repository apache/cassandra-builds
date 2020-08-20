// Cassandra-devbranch needs custom Jenkinsfile because of the parameters passed into the build jobs.
//
// When updating this file you will need to go to https://ci-cassandra.apache.org/scriptApproval/
//  and approve the change.
//
// Validate/lint this file using the following command
// `curl -X POST  -F "jenkinsfile=<jenkins-dsl/cassandra_pipeline.groovy" https://ci-cassandra.apache.org/pipeline-model-converter/validate`

pipeline {
  agent { label 'cassandra' }
  stages {
      stage('Init') {
          steps {
              cleanWs()
              sh "git clone --depth 1 --single-branch -b ${BRANCH} https://github.com/${REPO}/cassandra.git"
              sh "test -f cassandra/.jenkins/Jenkinsfile"
              sh "git clone --depth 1 --single-branch -b ${DTEST_BRANCH} ${DTEST_REPO}"
              sh "test -f cassandra-dtest/requirements.txt"
              sh "docker pull ${DOCKER_IMAGE}"
          }
      }
      stage('Build') {
        steps {
            build job: "${env.JOB_NAME}-artifacts", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
        }
      }
      stage('Test') {
          parallel {
            stage('stress') {
              steps {
                script {
                  stress = build job: "${env.JOB_NAME}-stress-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                  if (stress.result != 'SUCCESS') unstable('stress test failures')
                }
              }
              post {
                always {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('stress-test', stress.getNumber())
                        }
                    }
                }
              }
            }
            stage('fqltool') {
              steps {
                script {
                  fqltool = build job: "${env.JOB_NAME}-fqltool-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                  if (fqltool.result != 'SUCCESS') unstable('fqltool test failures')
                }
              }
              post {
                always {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('fqltool-test', fqltool.getNumber())
                        }
                    }
                }
              }
            }
            stage('jvm-dtest') {
              steps {
                script {
                  jvm_dtest = build job: "${env.JOB_NAME}-jvm-dtest", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                  if (jvm_dtest.result != 'SUCCESS') unstable('jvm-dtest failures')
                }
              }
              post {
                always {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('jvm-dtest', jvm_dtest.getNumber())
                        }
                    }
                }
              }
            }
            stage('jvm-dtest-upgrade') {
              steps {
                script {
                  jvm_dtest_upgrade = build job: "${env.JOB_NAME}-jvm-dtest-upgrade", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                  if (jvm_dtest_upgrade.result != 'SUCCESS') unstable('jvm-dtest-upgrade failures')
                }
              }
              post {
                always {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('jvm-dtest-upgrade', jvm_dtest_upgrade.getNumber())
                        }
                    }
                }
              }
            }
            stage('units') {
              steps {
                script {
                  test = build job: "${env.JOB_NAME}-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                  if (test.result != 'SUCCESS') unstable('unit test failures')
                }
              }
              post {
                always {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test', test.getNumber())
                        }
                    }
                }
              }
            }
            stage('long units') {
              steps {
                script {
                  long_test = build job: "${env.JOB_NAME}-long-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                  if (long_test.result != 'SUCCESS') unstable('long unit test failures')
                }
              }
              post {
                always {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('long-test', long_test.getNumber())
                        }
                    }
                }
              }
            }
            stage('burn') {
              steps {
                script {
                  burn = build job: "${env.JOB_NAME}-test-burn", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                  if (burn.result != 'SUCCESS') unstable('burn test failures')
                }
              }
              post {
                always {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-burn', burn.getNumber())
                        }
                    }
                }
              }
            }
            stage('cdc') {
              steps {
                script {
                  cdc = build job: "${env.JOB_NAME}-test-cdc", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                  if (cdc.result != 'SUCCESS') unstable('cdc failures')
                }
              }
              post {
                always {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-cdc', cdc.getNumber())
                        }
                    }
                }
              }
            }
            stage('compression') {
              steps {
                script {
                  compression = build job: "${env.JOB_NAME}-test-compression", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                  if (compression.result != 'SUCCESS') unstable('compression failures')
                }
              }
              post {
                always {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-compression', compression.getNumber())
                        }
                    }
                }
              }
            }
            stage('cqlsh') {
              steps {
                script {
                  cqlsh = build job: "${env.JOB_NAME}-cqlsh-tests", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH), string(name: 'DTEST_REPO', value: params.DTEST_REPO), string(name: 'DTEST_BRANCH', value: params.DTEST_BRANCH)], propagate: false
                  if (cqlsh.result != 'SUCCESS') unstable('cqlsh failures')
                }
              }
              post {
                always {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('cqlsh-tests', cqlsh.getNumber())
                        }
                    }
                }
              }
            }
          }
      }
      stage('Distributed Test') {
          parallel {
            stage('dtest') {
              steps {
                script {
                  dtest = build job: "${env.JOB_NAME}-dtest", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH), string(name: 'DTEST_REPO', value: params.DTEST_REPO), string(name: 'DTEST_BRANCH', value: params.DTEST_BRANCH), string(name: 'DOCKER_IMAGE', value: params.DOCKER_IMAGE)], propagate: false
                  if (dtest.result != 'SUCCESS') unstable('dtest failures')
                }
              }
              post {
                always {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('dtest', dtest.getNumber())
                        }
                    }
                }
              }
            }
          }
      }
      stage('Summary') {
        steps {
            sh "rm -fR cassandra-builds"
            sh "git clone --depth 1 --single-branch https://gitbox.apache.org/repos/asf/cassandra-builds.git"
            sh "./cassandra-builds/build-scripts/cassandra-test-report.sh"
            junit '**/build/test/**/TEST*.xml,**/cqlshlib.xml,**/nosetests.xml'
            script {
              // env.GIT_COMMIT or changeLogSets is not defined by parameterised manual builds
              commit_head_sha = sh(returnStdout: true, script:"(git -C cassandra log -1 --no-merges --pretty=format:'%h')").trim()
              commit_head_msg = sh(returnStdout: true, script:"(git -C cassandra log -1 --no-merges --pretty=format:'%an %ad %s')").trim()
              echo "sha: ${commit_head_sha}; msg: ${commit_head_msg}"
            }
            slackSend channel: '#cassandra-builds-patches', message: ":apache: <${env.BUILD_URL}|${currentBuild.fullDisplayName}> completed: ${currentBuild.result}. <https://github.com/${REPO}/cassandra/commit/${commit_head_sha}|${REPO} ${commit_head_sha}>\n${commit_head_msg}"
        }
        post {
            always {
                archiveArtifacts artifacts: 'cassandra-test-report.txt', fingerprint: true
            }
        }
      }
  }
}

def copyTestResults(target, build_number) {
    step([$class: 'CopyArtifact',
            projectName: "${env.JOB_NAME}-${target}",
            optional: true,
            fingerprintArtifacts: true,
            selector: specific("${build_number}"),
            target: target]);
}
