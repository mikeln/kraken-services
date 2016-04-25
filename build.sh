#!/bin/bash

set -e
set -u

# env-injectable defaults
DOCKER_REPO=${DOCKER_REPO:-"quay.io/samsung_cnct"}
DOCKER_TAG=${DOCKER_TAG:-"latest"}
DOCKER_PUSH=${DOCKER_PUSH:-"false"}

# utilities
doit=""
print_usage_and_die() {
  echo "usage: $0 [--repo (default: quay.io/samsung_cnct)] [--tag (default: latest)] [--push] dir"
  exit 1
}

# parse args
while [[ $# > 1 ]]; do
  key="$1"
  shift # past key
  case $key in
    -r|--repo)
      DOCKER_REPO="$1"
      shift # past value
      ;;
    -t|--tag)
      DOCKER_TAG="$1"
      shift # past value
      ;;
    -p|--push)
      DOCKER_PUSH="true"
      ;;
    -n|--dryrun)
      doit="echo"
      ;;
    -h|*)
      print_usage_and_die
      ;;
  esac
done

if [[ $# < 1 ]] || [[ "$1" =~ ^- ]] || ![[ -d "$1" ]]; then
  print_usage_and_die
fi

dockerfiles_dir=$1

# locate dockerfiles
dockerfiles=$(find $dockerfiles_dir -type f -name Dockerfile | sed -e 's|^./||')

# pre-pull FROM images
for image in $(cat $dockerfiles | grep "^FROM" | sed -e 's/^FROM //' | grep -v '^scratch$' | sort | uniq); do
  ${doit} docker pull $image
done

# build images
for x in $dockerfiles; do
  dir=$(dirname $x)
  cd $dir

  repo=${DOCKER_REPO}
  name=$(basename $dir)
  tag=${DOCKER_TAG}
  image="${repo}/${name}:${tag}"

  echo
  echo "Building ${image}..."

  ${doit} docker build -t ${image} .

  if [ "${DOCKER_PUSH}" == "true" ]; then
    echo 
    echo "Pushing ${image}..."
    ${doit} docker push ${image}
  fi

  cd -
done
