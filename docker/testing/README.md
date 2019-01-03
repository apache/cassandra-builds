# Docker CI Testing

Docker files in this directory are used to build images used by CircleCI. These are directly referenced in the `circle.yml` after publishing to dockerhub. There are two types of images:

* Base image for Linux distribution to use for testing (e.g. `ubuntu1810_j11.docker`)
* Caching image that contains git sources, maven and ccm dependencies

## Building Images

Build images from the parent directory using the following commands. Change tag (`-t`) as needed (prefix and current date):

Base image:

`docker build -t spod/cassandra-testing-ubuntu1810:20180128 -t spod/cassandra-testing-ubuntu1810:latest -f testing/ubuntu1810_j11.docker testing/`

Caching image:

`docker build  --no-cache -t spod/cassandra-testing-ubuntu1810-java11-w-dependencies:20190306 -t spod/cassandra-testing-ubuntu1810-java11-w-dependencies:latest -f testing/ubuntu1810_j11_w_dependencies.docker testing/`

Please make sure to always tag also by date, so we can go back to that version in case anything breaks after the next update!

## Publishing Images

We are using Docker Hub for storing published images. See [Quick Start Guide](https://docs.docker.com/docker-hub/) on how to setup docker.

Push both image references:

```
docker push spod/cassandra-testing-ubuntu1810-java11-w-dependencies:20190306
docker push spod/cassandra-testing-ubuntu1810-java11-w-dependencies:latest
```

## Updating circleci.yml

Check if the correct image is used in `.circleci/config-2_1.yml` by looking for the `- image:` value. It should either be set to the date dervived tag created above, or `:latest`.
