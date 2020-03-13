// Cassandra-devbranch needs custom Jenkinsfile because of the parameters passed into the build jobs.
pipeline {
  agent any
  stages {
      stage('Init') {
        steps {
            cleanWs()
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
                            copyTestResults('test-jvm-dtest-forking')
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('test-jvm-dtest-forking')
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
                            copyTestResults('cqlsh-test')
                        }
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        script {
                            copyTestResults('cqlsh-test')
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
            junit '**/TEST*.xml,**/cqlshlib.xml,**/nosetests.xml'
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

