#!/usr/bin/env bash
# build-containers
#
# Automate the building of Bactopia related containers
VERSION=1.3.1

function singularity_build {
    recipe=$1
    name=$2
    image=$3
    version=$4
    latest=${5:-0}

    echo "Working on ${recipe}"
    singularity build -F --fakeroot ${image} ${recipe}
    singularity sign ${image}
    singularity push ${image} library://rpetit3/bactopia/${name}:${version}

    if [[ "${latest}" == "1" ]]; then
        singularity push ${image} library://rpetit3/bactopia/${name}:latest
    fi
}

function docker_build {
    recipe=$1
    image=$2
    latest=${3:-0}

    echo "Working on ${recipe}"
    docker build --rm -t ${image} -f ${recipe} .
    docker push ${image}

    if [[ "${latest}" != "0" ]]; then
        docker tag ${image} ${latest}
        docker push ${latest}
    fi
}


if [[ $# == 0 ]]; then
    echo ""
    echo "build-containers.sh BACTOPIA_DIR OUTPUT_DIR"
    echo ""
    echo "Example Command"
    echo "build-containers.sh /home/bactopia/bactopia container-images/ "
    echo ""
    exit
fi

BACTOPIA_DIR=$1
OUTPUT_DIR=${2:-"./"}
if [ -z  ${BACTOPIA_DIR} ]; then
    echo "Got ${#} arguement"
    echo "Must give the path to Bactopia repository"
    exit 1
fi

mkdir -p ${OUTPUT_DIR}

# Build Singularity
singularity_build Singularity bactopia ${OUTPUT_DIR}/bactopia-${VERSION}.simg ${VERSION} 1
for recipe in $(ls "${BACTOPIA_DIR}/containers/singularity" | grep ".Singularity"); do
    recipe_path="${BACTOPIA_DIR}/containers/singularity/${recipe}"
    recipe_name=$(echo ${recipe} | sed 's/.Singularity//')
    recipe_image="${OUTPUT_DIR}/${recipe_name}-${VERSION}.simg"
    singularity_build ${recipe_path} ${recipe_name} ${recipe_image} ${VERSION}
done

# Build Docker
docker_build Dockerfile bactopia/bactopia:${VERSION} bactopia/bactopia:latest
for recipe in $(ls "${BACTOPIA_DIR}/containers/docker" | grep ".Dockerfile"); do
    recipe_path="${BACTOPIA_DIR}/containers/docker/${recipe}"
    recipe_name=$(echo ${recipe} | sed 's/.Dockerfile//')
    recipe_image="bactopia/${recipe_name}:${VERSION}"
    docker_build ${recipe_path} ${recipe_image}
done

# Build Bactopia Tools containers
for tool in $(ls "${BACTOPIA_DIR}/tools"); do
    recipe_path="${BACTOPIA_DIR}/tools/${tool}"
    docker_file="${recipe_path}/Dockerfile"
    docker_image="bactopia/tools-${tool}:${VERSION}"
    docker_build ${docker_file} ${docker_image}

    singularity_file="${recipe_path}/Singularity"
    singularity_image="${OUTPUT_DIR}/tools-${tool}-${VERSION}.simg"
    singularity_build ${singularity_file} "tools-${tool}" ${singularity_image} ${VERSION}
done
