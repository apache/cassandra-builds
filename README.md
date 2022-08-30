# Apache Cassandra Build Tools

* Jenkins Job DSL scripts to create CI jobs:
    * `jenkins-dsl/`
* Jenkins Job build/test runtime scripts:
    * `build-scripts/`
* Apache Cassandra packaging utilities:
    * `cassandra-release/`
    * `docker/`

## Releasing Cassanda

Please refer to the following documents for more details about releases:

  * [Release Process](https://cassandra.apache.org/doc/latest/development/release_process.html)
  * [Release Managers Onboarding](https://cwiki.apache.org/confluence/display/CASSANDRA/Release+Managers+Onboarding)

Prior to release, make sure to edit:
  * `cassandra-release/finish_release.sh` to set `ARTIFACTORY_API_KEY`
  * `cassandra-release/prepare_release.sh` to set `gpg_key`

## Building packages

1. Create build images containing the build tool-chain, Java and an Apache Cassandra git working directory
   * Debian:
   ```docker build -t cass-build-debs -f docker/jessie-image.docker docker/```
   * RPM:
   ```docker build -t cass-build-rpms -f docker/almalinux-image.docker docker/```
   The image will contain a clone of the Apache git repository by default. Using a different repository is possible by adding the `--build-arg CASSANDRA_GIT_URL=https://github.com/myuser/cassandra.git` parameter. All successive builds will be executed based on the repository cloned during docker image creation.
2. Run build script through docker (specify branch, e.g. cassandra-3.0 and version, e.g. 3.0.11):
   * Debian Bullseye
    ```docker run --rm -v `pwd`/dist:/dist `docker images -f label=org.cassandra.buildenv=bullseye -q` /home/build/build-debs.sh <branch/tag>```
   * RPM:
    ```docker run --rm -v `pwd`/dist:/dist `docker images -f label=org.cassandra.buildenv=almalinux -q` /home/build/build-rpms.sh <branch/tag>```

For the build by Debian Bullseye, you have the possibility to build Cassandra either by Java 8 (default) or by Java 11. You control the Java version like following. If you want to build with Java 8, just omit that last option.

```docker run --rm -v `pwd`/dist:/dist `docker images -f label=org.cassandra.buildenv=bullseye -q` /home/build/build-debs.sh <branch/tag> 11```

You should find newly created Debian and RPM packages in the `dist` directory.

### Note about versioning

Packages for official releases can only be build from tags. In this case, the tag must match the known versioning scheme. A number of sanity checks will be run to make sure the version matches any version defined in `build.xml` and `debian/changes`. But you'll have to manually keep these values in sync for every release.

Builds based on any branch will use the version defined in either `build.xml` (RPM) or `debian/changes` (deb). Afterwards a snapshot indicator will be appended.

##  Signing packages

### RPM

Signatures can be used for both yum repository integrity protection and end-to-end package verification.

Providing a signature ([repomd.xml.asc](https://www.apache.org/dist/cassandra/redhat/311x/repodata/repomd.xml.asc)) for [repomd.xml](https://www.apache.org/dist/cassandra/redhat/311x/repodata/repomd.xml) allows clients to verify the repository's meta-data, as enabled by `repo_gpgcheck=1` in the yum config.

Individual package files can also contain a signature in the RPM header. This can be done either during the build process (`rpmbuild --sign`) or afterwards on the final artifact. As the RPMs should be build using docker without any user intervention, we have to go with the later option here. One solution for this is to use the rpmsign wrapper (`yum install rpm-sign`) and use it on the package, e.g.:
```rpmsign -D '%_gpg_name MyAlias' --addsign cassandra-3.0.13-1.noarch.rpm```

Verifying package signatures requires to import the public keys first:

```
rpm --import https://www.apache.org/dist/cassandra/KEYS
```

Afterwards the following command should report "OK" for included hashes and gpg signatures:

```
rpm -K cassandra-3.0.13-1.noarch.rpm
```

Once the RPM is signed, both the import key and verification steps should take place automatically during installation from the yum repo (see `gpgcheck=1`).

### Debian

See use of `debsign` in `cassandra-release/prepare_release.sh`.

## Updating package repositories

### Prerequisites

Artifacts for RPM and Debian package repositories, as well as tar archives, are keept in a single SVN repository. You need to have your own local copy for adding new packages:

```
svn co --config-option 'config:miscellany:use-commit-times=yes' https://dist.apache.org/repos/dist/release/cassandra
```

(you may also want to set `use-commit-times = yes` in your local svn config)

We'll further refer to the local directory created by the svn command as `$artifacts_svn_dir`.

Required build tools:
* [createrepo](https://packages.ubuntu.com/bionic/createrepo) (RPMs)
* [reprepro](https://packages.ubuntu.com/bionic/reprepro) (Debian)

### RPM

Adding new packages to the official repository starts by copying the RPMs to `$artifacts_svn_dir/redhat/<version>`. Afterwards, recreate the metadata by executing `createrepo -v .` in that directory. Finally, sign the generated meta data files in the `repodata` sub-directory:

```
for i in `ls *.bz2 *.gz *.xml`; do gpg -sba --local-user MyAlias $i; done;
```

### Debian

See `finish_release.sh`
