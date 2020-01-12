
pipeline {
  agent any
  stages {
      stage('Initialisation') {
        steps {
            cleanWs()
        }
      }
      stage('Testing') {
          parallel {
            stage('stress') {
              steps {
                  warnError('Tests unstable') {
                      build job: 'Cassandra-devbranch-stress-test', parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-stress-test', optional: true, target: 'stress-test', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-stress-test', optional: true, target: 'stress-test', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
              }
            }
            stage('fqltool') {
              steps {
                  warnError('Tests unstable') {
                      build job: 'Cassandra-devbranch-fqltool-test', parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-fqltool-test', optional: true, target: 'fqltool-test', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-fqltool-test', optional: true, target: 'fqltool-test', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
              }
            }
            stage('JVM forking') {
              steps {
                  warnError('Tests unstable') {
                    build job: 'Cassandra-devbranch-test-jvm-dtest-forking', parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-test-jvm-dtest-forking', optional: true, target: 'test-jvm-dtest-forking', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-test-jvm-dtest-forking', optional: true, target: 'test-jvm-dtest-forking', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
              }
            }
            stage('units') {
                steps {
                  warnError('Tests unstable') {
                    build job: 'Cassandra-devbranch-test', parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
                }
              post {
                success {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-test', optional: true, target: 'test', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-test', optional: true, target: 'test', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
              }
            }
            stage('long units') {
              steps {
                  warnError('Tests unstable') {
                      build job: 'Cassandra-devbranch-long-test', parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-test-long', optional: true, target: 'test-long', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-test-long', optional: true, target: 'test-long', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
              }
            }
            stage('burn') {
              steps {
                  warnError('Tests unstable') {
                    build job: 'Cassandra-devbranch-test-burn', parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-test-burn', optional: true, target: 'test-burn', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-test-burn', optional: true, target: 'test-burn', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
              }
            }
            stage('cdc') {
              steps {
                  warnError('Tests unstable') {
                      build job: 'Cassandra-devbranch-test-cdc', parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-test-cdc', optional: true, target: 'test-cdc', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-test-cdc', optional: true, target: 'test-cdc', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
              }
            }
            stage('compression') {
              steps {
                  warnError('Tests unstable') {
                    build job: 'Cassandra-devbranch-test-compression', parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-test-compression', optional: true, target: 'test-compression', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-test-compression', optional: true, target: 'test-compression', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
              }
            }
            stage('cqlsh') {
              steps {
                  warnError('Tests unstable') {
                    build job: 'Cassandra-devbranch-cqlsh-tests', parameters: [string(name: 'REPO', value: params.REPO), string(name: 'BRANCH', value: params.BRANCH)]
                  }
              }
              post {
                success {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-cqlsh-tests', optional: true, target: 'test-cqlsh', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
                unstable {
                    warnError('missing test xml files') {
                        copyArtifacts projectName: 'Cassandra-devbranch-cqlsh-tests', optional: true, target: 'test-cqlsh', fingerprintArtifacts: true, selector: lastSuccessful(stable: false)
                    }
                }
              }
            }
          }
      }
      stage('Summary') {
        steps {
            junit '**/TEST*.xml,**/cqlshlib.xml,**/nosetests.xml'

            slackSend channel: '#cassandra-builds', message: "${currentBuild.fullDisplayName} completed: ${currentBuild.result}. See ${env.BUILD_URL}"

            emailext to: 'builds@cassandra.apache.org', subject: "Build complete: ${currentBuild.fullDisplayName} [${currentBuild.result}]", body: '${CHANGES}<p>${JELLY_SCRIPT,template="text"}'
        }
      }
  }
}
