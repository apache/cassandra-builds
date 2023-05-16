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
              script {
                  currentBuild.result='SUCCESS'
              }
              sh "git clone --depth 1 --single-branch -b ${BRANCH} https://github.com/${REPO}/cassandra.git"
              sh "test -f cassandra/.jenkins/Jenkinsfile"
              sh "git clone --depth 1 --single-branch -b ${DTEST_BRANCH} ${DTEST_REPO}"
              sh "test -f cassandra-dtest/requirements.txt"
              sh "docker pull ${DOCKER_IMAGE}"
          }
      }
      stage('Build') {
        steps {
          script {
            def attempt = 1
            retry(2) {
              if (attempt > 1) {
                sleep(60 * attempt)
              }
              attempt = attempt + 1
              build job: "${env.JOB_NAME}-artifacts", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
            }
          }
        }
      }
      stage('Test') {
          parallel {
            stage('stress') {
              steps {
                script {
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    stress = build job: "${env.JOB_NAME}-stress-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                    if (stress.result != 'FAILURE') break
                  }
                  if (stress.result != 'SUCCESS') unstable('stress test failures')
                  if (stress.result == 'FAILURE')  currentBuild.result='FAILURE'
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
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    fqltool = build job: "${env.JOB_NAME}-fqltool-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                    if (fqltool.result != 'FAILURE') break
                  }
                  if (fqltool.result != 'SUCCESS') unstable('fqltool test failures')
                  if (fqltool.result == 'FAILURE')  currentBuild.result='FAILURE'
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
            stage('units') {
              steps {
                script {
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    test = build job: "${env.JOB_NAME}-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                    if (test.result != 'FAILURE') break
                  }
                  if (test.result != 'SUCCESS') unstable('unit test failures')
                  if (test.result == 'FAILURE')  currentBuild.result='FAILURE'
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
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    long_test = build job: "${env.JOB_NAME}-long-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                    if (long_test.result != 'FAILURE') break
                  }
                  if (long_test.result != 'SUCCESS') unstable('long unit test failures')
                  if (long_test.result == 'FAILURE') currentBuild.result='FAILURE'
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
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    burn = build job: "${env.JOB_NAME}-test-burn", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                    if (burn.result != 'FAILURE') break
                  }
                  if (burn.result != 'SUCCESS') unstable('burn test failures')
                  if (burn.result == 'FAILURE')  currentBuild.result='FAILURE'
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
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    cdc = build job: "${env.JOB_NAME}-test-cdc", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                    if (cdc.result != 'FAILURE') break
                  }
                  if (cdc.result != 'SUCCESS') unstable('cdc failures')
                  if (cdc.result == 'FAILURE')  currentBuild.result='FAILURE'
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
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    compression = build job: "${env.JOB_NAME}-test-compression", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                    if (compression.result != 'FAILURE') break
                  }
                  if (compression.result != 'SUCCESS') unstable('compression failures')
                  if (compression.result == 'FAILURE')  currentBuild.result='FAILURE'
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
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    cqlsh = build job: "${env.JOB_NAME}-cqlsh-tests", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH), string(name: 'DTEST_REPO', value: params.DTEST_REPO), string(name: 'DTEST_BRANCH', value: params.DTEST_BRANCH)], propagate: false
                    if (cqlsh.result != 'FAILURE') break
                  }
                  if (cqlsh.result != 'SUCCESS') unstable('cqlsh failures')
                  if (cqlsh.result == 'FAILURE') currentBuild.result='FAILURE'
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
          stage('jvm-dtest') {
            steps {
              script {
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    jvm_dtest = build job: "${env.JOB_NAME}-jvm-dtest", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                    if (jvm_dtest.result != 'FAILURE') break
                  }
                if (jvm_dtest.result != 'SUCCESS') unstable('jvm-dtest failures')
                if (jvm_dtest.result == 'FAILURE')  currentBuild.result='FAILURE'
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
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    jvm_dtest_upgrade = build job: "${env.JOB_NAME}-jvm-dtest-upgrade", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)], propagate: false
                    if (jvm_dtest_upgrade.result != 'FAILURE') break
                  }
                if (jvm_dtest_upgrade.result != 'SUCCESS') unstable('jvm-dtest-upgrade failures')
                if (jvm_dtest_upgrade.result == 'FAILURE') currentBuild.result='FAILURE'
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
          stage('dtest') {
            steps {
              script {
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    dtest = build job: "${env.JOB_NAME}-dtest", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH), string(name: 'DTEST_REPO', value: params.DTEST_REPO), string(name: 'DTEST_BRANCH', value: params.DTEST_BRANCH), string(name: 'DOCKER_IMAGE', value: params.DOCKER_IMAGE)], propagate: false
                    if (dtest.result != 'FAILURE') break
                  }
                if (dtest.result != 'SUCCESS') unstable('dtest failures')
                if (dtest.result == 'FAILURE') currentBuild.result='FAILURE'
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
          stage('dtest-large') {
            steps {
              script {
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    dtest_large = build job: "${env.JOB_NAME}-dtest-large", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH), string(name: 'DTEST_REPO', value: params.DTEST_REPO), string(name: 'DTEST_BRANCH', value: params.DTEST_BRANCH), string(name: 'DOCKER_IMAGE', value: params.DOCKER_IMAGE)], propagate: false
                    if (dtest_large.result != 'FAILURE') break
                  }
                if (dtest_large.result != 'SUCCESS') unstable('dtest-large failures')
                if (dtest_large.result == 'FAILURE') currentBuild.result='FAILURE'
              }
            }
            post {
              always {
                warnError('missing test xml files') {
                    script {
                        copyTestResults('dtest-large', dtest_large.getNumber())
                    }
                }
              }
            }
          }
          stage('dtest-novnode') {
            steps {
              script {
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    dtest_novnode = build job: "${env.JOB_NAME}-dtest-novnode", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH), string(name: 'DTEST_REPO', value: params.DTEST_REPO), string(name: 'DTEST_BRANCH', value: params.DTEST_BRANCH), string(name: 'DOCKER_IMAGE', value: params.DOCKER_IMAGE)], propagate: false
                    if (dtest_novnode.result != 'FAILURE') break
                  }
                if (dtest_novnode.result != 'SUCCESS') unstable('dtest-novnode failures')
                if (dtest_novnode.result == 'FAILURE') currentBuild.result='FAILURE'
              }
            }
            post {
              always {
                warnError('missing test xml files') {
                    script {
                        copyTestResults('dtest-novnode', dtest_novnode.getNumber())
                    }
                }
              }
            }
          }
          stage('dtest-large-novnode') {
            steps {
              script {
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    dtest_large_novnode = build job: "${env.JOB_NAME}-dtest-large-novnode", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH), string(name: 'DTEST_REPO', value: params.DTEST_REPO), string(name: 'DTEST_BRANCH', value: params.DTEST_BRANCH), string(name: 'DOCKER_IMAGE', value: params.DOCKER_IMAGE)], propagate: false
                    if (dtest_large_novnode.result != 'FAILURE') break
                  }
                if (dtest_large_novnode.result != 'SUCCESS') unstable('dtest-large-novnode failures')
                if (dtest_large_novnode.result == 'FAILURE') currentBuild.result='FAILURE'
              }
            }
            post {
              always {
                warnError('missing test xml files') {
                    script {
                        copyTestResults('dtest-large-novnode', dtest_large_novnode.getNumber())
                    }
                }
              }
            }
          }
          stage('dtest-upgrade') {
            steps {
              script {
                  def attempt = 1
                  while (attempt <=2) {
                    if (attempt > 1) {
                      sleep(60 * attempt)
                    }
                    attempt = attempt + 1
                    dtest_upgrade = build job: "${env.JOB_NAME}-dtest-upgrade", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH), string(name: 'DTEST_REPO', value: params.DTEST_REPO), string(name: 'DTEST_BRANCH', value: params.DTEST_BRANCH), string(name: 'DOCKER_IMAGE', value: params.DOCKER_IMAGE)], propagate: false
                    if (dtest_upgrade.result != 'FAILURE') break
                  }
                if (dtest_upgrade.result != 'SUCCESS') unstable('dtest-upgrade failures')
                if (dtest_upgrade.result == 'FAILURE') currentBuild.result='FAILURE'
              }
            }
            post {
              always {
                  warnError('missing test xml files') {
                      script {
                          copyTestResults('dtest-upgrade', dtest_upgrade.getNumber())
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
              commit_head_sha = sh(returnStdout: true, script:"(git -C cassandra log -1 --no-merges --pretty=format:'%H')").trim()
              commit_head_msg = sh(returnStdout: true, script:"(git -C cassandra log -1 --no-merges --pretty=format:'%an %ad %s')").trim()
              echo "sha: ${commit_head_sha}; msg: ${commit_head_msg}"
            }
            slackSend channel: '#cassandra-builds-patches', message: ":apache: <${env.BUILD_URL}|${currentBuild.fullDisplayName}> completed: ${currentBuild.result}. <https://github.com/${REPO}/cassandra/commit/${commit_head_sha}|${REPO} ${commit_head_sha}>\n${commit_head_msg}"
            sh "echo \"summary) cassandra-builds: `git -C cassandra-builds log -1 --pretty=format:'%H %an %ad %s'`\" > builds.head"
            sh "./cassandra-builds/jenkins-dsl/print-shas.sh"
            sh "xz TESTS-TestSuites.xml"
            sh "wget --retry-connrefused --waitretry=1 \"\${BUILD_URL}/timestamps/?time=HH:mm:ss&timeZone=UTC&appendLog\" -qO - > console.log || echo wget failed"
            sh "xz console.log"
            sh "echo \"For test report and logs see https://nightlies.apache.org/cassandra/devbranch/${JOB_NAME}/${BUILD_NUMBER}/\""
        }
        post {
            always {
                sshPublisher(publishers: [sshPublisherDesc(configName: 'Nightlies', transfers: [sshTransfer(remoteDirectory: 'cassandra/devbranch/${JOB_NAME}/${BUILD_NUMBER}/', sourceFiles: 'TESTS-TestSuites.xml.xz')])])
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
