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
   The image will contain a clone of the Apache git repository by default. Using a different repository is possible by adding the `--build-arg CASSANDRA_GIT_URL=https://github.com/myuser/cassandra.git` parameter. All successive builds will be executed based on the repository cloned during docker image creation.
2. Run build script through docker (specify branch, e.g. cassandra-3.0 and version, e.g. 3.0.11):
   * Debian:
    ```docker run --rm -v `pwd`/dist:/dist `docker images -f label=org.cassandra.buildenv=jessie -q` /home/build/build-debs.sh <branch/tag>```
   * RPM:
    ```docker run --rm -v `pwd`/dist:/dist `docker images -f label=org.cassandra.buildenv=centos -q` /home/build/build-rpms.sh <branch/tag>```

You should find newly created Debian and RPM packages in the `dist` directory.

### Note about versioning

Packages for official releases can only be build from tags. In this case, the tag must match the known versioning scheme. A number of sanity checks will be run to make sure the version matches any version defined in `build.xml` and `debian/changes`. But you'll have to manually keep these values in sync for every release.

Builds based on any branch will use the version defined in either `build.xml` (RPM) or `debian/changes` (deb). Afterwards a snapshot indicator will be appended.

## Publishing packages

TODO
