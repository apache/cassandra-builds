# Docker CI Testing

Docker files in this directory are used to build images used by ci-cassandra.apache.org and CircleCI. These are directly referenced in the `cassandra_job_dsl_seed.groovy` and `.circleci/config*.yml` files, after publishing to dockerhub. There are two types of images:

* Base image for Linux distribution to use for testing (e.g. `ubuntu1910_j11.docker`)
* Caching image that contains git sources, maven and ccm dependencies

## Building Images

Build images from the parent directory using the following commands. Change tag (`-t`) as needed (prefix and current date):

Base image:

`docker build -t apache/cassandra-testing-ubuntu2004-java11:$(date +"%Y%m%d") -t apache/cassandra-testing-ubuntu2004-java11:latest -f ubuntu2004_j11.docker .`

Caching image:

`docker build  --no-cache -t apache/cassandra-testing-ubuntu2004-java11-w-dependencies:$(date +"%Y%m%d") -t apache/cassandra-testing-ubuntu2004-java11-w-dependencies:latest -f ubuntu2004_j11_w_dependencies.docker .`

Please make sure to always tag also by date, so we can go back to that version in case anything breaks after the next update!

## Publishing Images

We are using Docker Hub for storing published images. See [Quick Start Guide](https://docs.docker.com/docker-hub/) on how to setup docker.

Push both image references:

```
docker push apache/cassandra-testing-ubuntu2004-java11:$(date +"%Y%m%d")
docker push apache/cassandra-testing-ubuntu2004-java11:latest
docker push apache/cassandra-testing-ubuntu2004-java11-w-dependencies:$(date +"%Y%m%d")
docker push apache/cassandra-testing-ubuntu2004-java11-w-dependencies:latest
```

## Updating circleci.yml

Check if the correct image is used in `cassandra_job_dsl_seed.groovy` and `.circleci/config*.yml`. It should either be set to the date dervived tag created above, or `:latest`.
