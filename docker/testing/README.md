# Docker CI Testing

Docker files in this directory are used to build images used by ci-cassandra.apache.org and CircleCI. These are directly referenced in the `cassandra_job_dsl_seed.groovy` and `.circleci/config*.yml` files, after publishing to dockerhub. There are two types of images:

* Base image for Linux distribution to use for testing (e.g. `ubuntu1910_j11.docker`)
* Caching image that contains git sources, maven and ccm dependencies

## Preparing Multi-Architecture Building

    docker buildx create --name mybuilder
    docker buildx use mybuilder
    docker buildx inspect
    

This is based on the documentation found [here](https://www.docker.com/blog/multi-arch-images/).

## Building and Publishing Images

Build images from the parent directory using the following commands. Change tag (`-t`) as needed (prefix and current date):

Base image:

    docker buildx build --platform linux/amd64,linux/arm64 -t apache/cassandra-testing-ubuntu2004-java11:$(date +"%Y%m%d") -t apache/cassandra-testing-ubuntu2004-java11:latest -f ubuntu2004_j11.docker --push .

Caching image:

    docker buildx build --platform linux/amd64,linux/arm64  --no-cache -t apache/cassandra-testing-ubuntu2004-java11-w-dependencies:$(date +"%Y%m%d") -t apache/cassandra-testing-ubuntu2004-java11-w-dependencies:latest -f ubuntu2004_j11_w_dependencies.docker --push .

Please make sure to always tag also by date, so we can go back to that version in case anything breaks after the next update!

We are using Docker Hub for storing published images. See [Quick Start Guide](https://docs.docker.com/docker-hub/) on how to setup docker.
To push the image you will need to use your own Docker Hub account and open an Apache Jira ticket to Infra to add your account to the apache organization.

## Updating circleci.yml

Check if the correct image is used in `cassandra_job_dsl_seed.groovy` and `.circleci/config*.yml`. It should either be set to the date derived tag created above, or `:latest`.
