# Apache Cassandra Build Tools

* Jenkins Job DSL scripts to create CI jobs:
    * `jenkins-dsl/`
* Jenkins Job build/test runtime scripts:
    * `build-scripts/`
* Apache Cassandra packaging utilities:
    * `cassandra-release/`
    * `docker/`

## Building packages

1. Create build images containing the build tool-chain, Java and an Apache Cassandra git working directory
   * Debian:
   ```docker build -f docker/jessie-image.docker docker/```
   * RPM:
   ```docker build -f docker/centos7-image.docker docker/```
2. Run build script through docker (specify branch, e.g. cassandra-3.0 and version, e.g. 3.0.11):
   * Debian:
    ```docker run -v `pwd`/dist:/dist `docker images -f label=org.cassandra.buildenv=jessie -q` /home/build/build-debs.sh <branch>```
   * RPM:
    ```docker run -v `pwd`/dist:/dist `docker images -f label=org.cassandra.buildenv=centos -q` /home/build/build-rpms.sh <branch> <version>```

You should find newly created Debian and RPM packages in the `dist` directory.

## Publishing packages

TODO
