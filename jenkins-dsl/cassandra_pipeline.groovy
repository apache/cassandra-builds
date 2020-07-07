// Cassandra-devbranch needs custom Jenkinsfile because of the parameters passed into the build jobs.
//
// Validate/lint this file using the following command
// `curl -X POST  -F "jenkinsfile=<jenkins-dsl/cassandra_pipeline.groovy" https://ci-cassandra.apache.org/pipeline-model-converter/validate`

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
                      script {
                        built = build job: "${env.JOB_NAME}-stress-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                      }
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('stress-test', built.getNumber())
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('stress-test', built.getNumber())
                        }
                    }
                }
              }
            }
            stage('JVM DTests') {
              steps {
                  warnError('Tests unstable') {
                      script {
                        built = build job: "${env.JOB_NAME}-jvm-dtest", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                      }
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('jvm-dtest', built.getNumber())
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('jvm-dtest', built.getNumber())
                        }
                    }
                }
              }
            }
            stage('units') {
                steps {
                  warnError('Tests unstable') {
                      script {
                        built = build job: "${env.JOB_NAME}-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                      }
                  }
                }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test', built.getNumber())
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test', built.getNumber())
                        }
                    }
                }
              }
            }
            stage('long units') {
              steps {
                  warnError('Tests unstable') {
                      script {
                        built = build job: "${env.JOB_NAME}-long-test", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                      }
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('long-test', built.getNumber())
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('long-test', built.getNumber())
                        }
                    }
                }
              }
            }
            stage('burn') {
              steps {
                  warnError('Tests unstable') {
                      script {
                        built = build job: "${env.JOB_NAME}-test-burn", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                      }
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-burn', built.getNumber())
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-burn', built.getNumber())
                        }
                    }
                }
              }
            }
            stage('cdc') {
              steps {
                  warnError('Tests unstable') {
                      script {
                        built = build job: "${env.JOB_NAME}-test-cdc", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                      }
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-cdc', built.getNumber())
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-cdc', built.getNumber())
                        }
                    }
                }
              }
            }
            stage('compression') {
              steps {
                  warnError('Tests unstable') {
                      script {
                        built = build job: "${env.JOB_NAME}-test-compression", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                      }
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-compression', built.getNumber())
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-compression', built.getNumber())
                        }
                    }
                }
              }
            }
            stage('cqlsh') {
              steps {
                  warnError('Tests unstable') {
                      script {
                        built = build job: "${env.JOB_NAME}-cqlsh-tests", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH), string(name: 'DTEST_REPO', value: params.DTEST_REPO), string(name: 'DTEST_BRANCH', value: params.DTEST_BRANCH)]
                      }
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('cqlsh-tests', built.getNumber())
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('cqlsh-tests', built.getNumber())
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
                      script {
                        built = build job: "${env.JOB_NAME}-dtest", parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH), string(name: 'DTEST_REPO', value: params.DTEST_REPO), string(name: 'DTEST_BRANCH', value: params.DTEST_BRANCH), string(name: 'DOCKER_IMAGE', value: params.DOCKER_IMAGE)]
                      }
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('dtest', built.getNumber())
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('dtest', built.getNumber())
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
