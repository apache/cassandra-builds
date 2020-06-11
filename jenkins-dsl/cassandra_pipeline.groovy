// Cassandra-devbranch needs custom Jenkinsfile because of the parameters passed into the build jobs.
pipeline {
  agent { label 'cassandra' }
  stages {
      stage('Init') {
          steps {
              cleanWs()
              sh "git clone -b ${BRANCH} https://github.com/${REPO}/cassandra.git"
              sh "test -f cassandra/.jenkins/Jenkinsfile"
              sh "git clone -b ${DTEST_BRANCH} ${DTEST_REPO}"
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
                  warnError('Tests unstable') {
                      build job: "${env.JOB_NAME}-stress-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('stress-test')
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('stress-test')
                        }
                    }
                }
              }
            }
            stage('JVM DTests') {
              steps {
                  warnError('Tests unstable') {
                    build job: "${env.JOB_NAME}-jvm-dtest", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('jvm-dtest')
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('jvm-dtest')
                        }
                    }
                }
              }
            }
            stage('units') {
                steps {
                  warnError('Tests unstable') {
                    build job: "${env.JOB_NAME}-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
                }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test')
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test')
                        }
                    }
                }
              }
            }
            stage('long units') {
              steps {
                  warnError('Tests unstable') {
                      build job: "${env.JOB_NAME}-long-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('long-test')
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('long-test')
                        }
                    }
                }
              }
            }
            stage('burn') {
              steps {
                  warnError('Tests unstable') {
                    build job: "${env.JOB_NAME}-test-burn", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-burn')
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-burn')
                        }
                    }
                }
              }
            }
            stage('cdc') {
              steps {
                  warnError('Tests unstable') {
                      build job: "${env.JOB_NAME}-test-cdc", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-cdc')
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-cdc')
                        }
                    }
                }
              }
            }
            stage('compression') {
              steps {
                  warnError('Tests unstable') {
                    build job: "${env.JOB_NAME}-test-compression", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-compression')
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-compression')
                        }
                    }
                }
              }
            }
            stage('cqlsh') {
              steps {
                  warnError('Tests unstable') {
                    build job: "${env.JOB_NAME}-cqlsh-tests", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH), string(name: 'DTEST_REPO', value: params.DTEST_REPO), string(name: 'DTEST_BRANCH', value: params.DTEST_BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('cqlsh-tests')
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('cqlsh-tests')
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
                  warnError('Tests unstable') {
                    build job: "${env.JOB_NAME}-dtest", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH), string(name: 'DTEST_REPO', value: params.DTEST_REPO), string(name: 'DTEST_BRANCH', value: params.DTEST_BRANCH), string(name: 'DOCKER_IMAGE', value: params.DOCKER_IMAGE)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('dtest')
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('dtest')
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
            sh "git clone https://gitbox.apache.org/repos/asf/cassandra-builds.git"
            sh "./cassandra-builds/build-scripts/cassandra-test-report.sh"
            junit '**/build/test/**/TEST*.xml,**/cqlshlib.xml,**/nosetests.xml'
            script {
              // though this is not used in the devbranch pipeline, it exists here for testing the in-tree Jenkinsfile
              changes = formatChanges(currentBuild.changeSets)
              echo "changes: ${changes}"
            }
        }
        post {
            always {
                archiveArtifacts artifacts: 'cassandra-test-report.txt', fingerprint: true
            }
        }
      }
  }
}

def copyTestResults(target) {
    step([$class: 'CopyArtifact',
            projectName: "${env.JOB_NAME}-${target}",
            optional: true,
            fingerprintArtifacts: true,
            selector: [$class: 'StatusBuildSelector', stable: false],
            target: target]);
}

def formatChanges(changeLogSets) {
    def result = ''
    for (int i = 0; i < changeLogSets.size(); i++) {
        def entries = changeLogSets[i].items
        for (int j = 0; j < entries.length; j++) {
            def entry = entries[j]
            result = result + "${entry.commitId} by ${entry.author} on ${new Date(entry.timestamp)}: ${entry.msg}\n"
        }
    }
    return result
}
