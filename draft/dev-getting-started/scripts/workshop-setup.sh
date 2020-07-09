#!/bin/sh

original_dir=$PWD

set -e
set -x

#
# Execution parameters
#

appsody_repo=workshop-prep
workshop_dir=$(echo ~)"/workspace/kabanero-workshop"
workshop_collection=nodejs

#
# Usage statement
#
function usage() {
    echo "Prepares the workshop environment."
    echo ""
    echo "Usage: $scriptname [OPTIONS]...[ARGS]"
    echo
    echo "  -p  | --check-prereqs"
    echo "                     Verifies the presence and correct versions of workshop"
    echo "                     prerequisites."
    echo "  -c  | --cache-prereqs"
    echo "                     Downloads pre-requisite images and pre-builds local stacks."
    echo "  -l  | --language   Workshop programming language. Accepted value is \"nodejs\""
    echo "                     The default programming language is ${workshop_collection}."
    echo ""
    echo "  -v  | --verbose    Prints extra information about each command."
    echo "  -h  | --help       Output this usage statement."
}


#
# Ensures the Appsody stacks repo is cloned and up-to-date
#
function gitCloneStack {
    if [ ! -e "${stacks_dir}" ]; then
        mkdir -p "${stacks_dir}"
        cd "${stacks_dir}"
        appsody stack create ${collection_name} --copy ${collection_index}/${source_collection_name}
    fi
}


#
#
#
function cacheDockerImages {
    echo
    echo "INFO: Creating base docker image: openjdk8-openj9-local"
    echo "INFO: The image caches dependencies to preserve network bandwidth during the workshop."
    echo
    gitCloneStack

    local result=0

    mkdir -p ~/.m2/repository

    app_temp_dir="${app_dir}-temp"
    rm -rf ${app_temp_dir}
    mkdir -p ${app_temp_dir}
    cd ${app_temp_dir}
    if [ ${cygwin} -eq 1 ]; then 
        cmd /c 'appsody init incubator/java-microprofile'
    else
        appsody init incubator/java-microprofile
    fi
    opendjk_local_docker_context_dir="${app_temp_dir}/tmp"
    if [ ${cygwin} -eq 1 ]; then 
        cmd /c "appsody extract --target-dir tmp"
    else
        appsody extract --target-dir "${opendjk_local_docker_context_dir}"
    fi

    cp "${workshop_dir}/${stacks_subdir}/${collection_path}/image/project/pom-dev.xml" "${opendjk_local_docker_context_dir}"

    opendjk_local_dockerfile="${opendjk_local_docker_context_dir}/Dockerfile"
    cat > "${opendjk_local_dockerfile}" <<EOF
FROM adoptopenjdk/openjdk8-openj9

COPY pom.xml /project/ 
COPY pom-dev.xml /project/ 
COPY user-app/pom.xml /project/user-app/

RUN apt-get update && \
apt-get install -y maven unzip && \
sed -i "s|19.0.0.8|19.0.0.7|g" /project/pom.xml && \
mvn -q -B -f /project/pom.xml install dependency:go-offline && \
mvn -q -B -f /project/user-app/pom.xml checkstyle:checkstyle install dependency:go-offline && \
mvn -q -B -f /project/pom-dev.xml checkstyle:checkstyle install dependency:go-offline && \
sed -i "s|19.0.0.7|19.0.0.8|g" /project/pom.xml && \
mvn -q -B -f /project/pom.xml install dependency:go-offline && \
mvn -q -B -f /project/user-app/pom.xml dependency:go-offline && \
rm -rf /project
EOF

    cd "${opendjk_local_docker_context_dir}"
    docker build . --tag openjdk8-openj9-local && \
    docker image ls openjdk8-openj9-local
    local result=$?

    rm -rf "${app_temp_dir}"
    result=$?

    echo
    echo "INFO: Caching additional docker images to be used in examples."
    echo
    docker pull postgres

    return ${result}
}


#
# Executes the first workshop steps once to trigger caching of docker images and other 
# dependencies.
#
function cacheStacks {
    echo
    echo "INFO: Pre-building local stack clone"
    echo
    gitCloneStack

    [ ${is_java} -eq 1 ] && mkdir -p ~/.m2
    cd ${stacks_dir}
    if [ ${is_java} -eq 1 ]; then
        CODEWIND_INDEX=false ./ci/build.sh . ${collection_path}
    else
        cd ${collection_name}
        [[ $(appsody list | grep dev.local) ]] && appsody repo remove dev.local
        IMAGE_REGISTRY_ORG=kabanero CODEWIND_INDEX=false appsody stack package
        return
    fi

    [[ $(appsody list | grep ${appsody_repo}) ]] && appsody repo remove ${appsody_repo}
    if [ ${cygwin} -eq 1 ]; then 
        win_assets_dir=$(cygpath -w "${workshop_dir}/${stacks_subdir}/ci/assets" | sed 's|\\|\/|g')
        cmd /c "appsody repo add ${appsody_repo} file:///${win_assets_dir}/${collection_index}-index-local.yaml"
    else
        appsody repo add ${appsody_repo} file://${workshop_dir}/${stacks_subdir}/ci/assets/${collection_index}-index-local.yaml
    fi

    echo
    echo "INFO: Prime cache for appsody build"
    echo        
    rm -rf ${app_dir}
    

    if [ ${cygwin} -eq 1 ]; then 
        # On Windows, the folder needs to be created
        # by Windows in order to ensure proper inheritance
        # of parent folder permissions
        cd ${workshop_dir}
        cmd /c "mkdir ${app_name}"
    else
        mkdir -p ${app_dir}
    fi

    cd ${app_dir}
    appsody init ${appsody_repo}/${collection_name}
    appsody build

    echo
    echo "INFO: Prime cache for appsody run"
    echo
    sleepTime=30
    [ ${is_java} -eq 1 ] && sleepTime=180
    (appsody run --name workshop_prep_container) & sleep ${sleepTime} ; kill -9 $!
    appsody stop --name workshop_prep_container

    cd ${original_dir}
    rm -rf ${app_dir}
    docker rmi ${app_name}:latest

    echo "INFO: Clearing all temporary content"
    appsody repo remove ${appsody_repo}
}


#
# https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
#
function vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}


#
# Ensures that all required prerequisites for the workshop are installed and running.
#
function checksPrereqs {
    local prereqFailed=0

    echo
    echo "INFO: Starting prerequisite checking..."
    echo

    appsodyPrereqFailed=0
    which appsody &> /dev/null || appsodyPrereqFailed=1
    if [ ${appsodyPrereqFailed} -eq 1 ]; then
        echo "ERROR: appsody CLI cannot be found in the PATH environment variable. Refer to https://appsody.dev/docs/getting-started/installation for instructions"
        prereqFailed=1
    else
        echo "INFO: appsody CLI installed: $(appsody version)"
    fi

    appsodyVersionPrereqFailed=0
    appsody_min_version="0.4.8"
    appsody_version=$(appsody version | cut -d " " -f 2) 
    $(vercomp ${appsody_version} ${appsody_min_version}) || appsodyVersionPrereqFailed=$?
    if [ ${appsodyVersionPrereqFailed} -eq 2 ]; then
        echo "ERROR: appsody CLI version must be ${appsody_min_version} or higher."
        prereqFailed=1
    else
        echo "INFO: appsody CLI version [${appsody_version}] meets minimum requirements."
    fi

    gitPrereqFailed=0
    which git &> /dev/null || gitPrereqFailed=1
    if [ ${gitPrereqFailed} -eq 1 ]; then
        echo "ERROR: git CLI cannot be found."
        prereqFailed=1
    else
        echo "INFO: git CLI installed: $(git version)"
    fi

    gitVersionPrereqFailed=0
    git_min_version="2.12"
    git_version=$(git version | cut -d " " -f 3) 
    $(vercomp ${git_version} ${git_min_version}) || gitVersionPrereqFailed=$?
    if [ ${gitVersionPrereqFailed} -eq 2 ]; then
        echo "ERROR: git CLI version must be ${git_min_version} or higher."
        prereqFailed=1
    else
        echo "INFO: git CLI version [${git_version}] meets minimum requirements."
    fi

    if [ ${is_java} -eq 1 ]; then
        python3PrereqFailed=0
        which python3 &> /dev/null || python3PrereqFailed=1
        if [ ${python3PrereqFailed} -eq 1 ]; then
            echo "ERROR: python3 cannot be found."
            prereqFailed=1
        else
            echo "INFO: python3 CLI installed: $(python3 --version)"
        fi

        pipPrereqFailed=1
        pip -V > /dev/null 2>&1 && pipPrereqFailed=0
        pip3 -V > /dev/null 2>&1 && pipPrereqFailed=0
        if [ ${pipPrereqFailed} -eq 1 ]; then
            echo "ERROR: pip cannot be found."
            prereqFailed=1
        else
            echo "INFO: pip CLI installed"
        fi
    fi

    dockerPrereqFailed=0
    which docker &> /dev/null || dockerPrereqFailed=1
    if [ ${dockerPrereqFailed} -eq 1 ]; then
        if [ "$(uname)" == "Darwin" ]; then 
            echo "ERROR: docker CLI cannot be found in the PATH environment variable. Refer to https://docs.docker.com/docker-for-mac/ for installation instructions"
        else
            echo "ERROR: docker CLI cannot be found. Refer to https://docs.docker.com/install/overview/ for installation instructions"
        fi
        prereqFailed=1
    else
        echo "INFO: docker CLI installed" 
    fi

    dockerRunningPrereqFailed=0
    docker ps &> /dev/null || dockerRunningPrereqFailed=1
    if [ ${dockerRunningPrereqFailed} -eq 1 ]; then
        echo "ERROR: docker daemon is not running."
        prereqFailed=1
    else
        echo "INFO: docker daemon is running"
    fi

    if [ ${dockerPrereqFailed} -eq 0 ]; then
        docker_major_version=$(docker -v | cut -d " " -f 3 | cut -d "." -f 1)
        if [[ "${docker_major_version}" <  "19" ]]; then
            echo "ERROR: docker version [$(docker -v)] does not support built-in kubernetes. Minimum is version 18.06."
            prereqFailed=1
        else
            echo "INFO: docker version [$(docker -v | cut -d ' ' -f 3 | cut -d ',' -f 1)] meets minimum requirements."
        fi
    fi

    kubectlPrereqFailed=0
    which kubectl &> /dev/null || kubectlPrereqFailed=1
    if [ ${kubectlPrereqFailed} -eq 1 ]; then
        echo "ERROR: kubectl CLI cannot be found in the PATH environment variable."
        prereqFailed=1
    else
        echo "INFO: kubectl CLI installed: $(kubectl version --short=true 2> /dev/null | tr -s '\n' ' ')"
    fi

    if [ ${kubectlPrereqFailed} -eq 0 ]; then
        kubectlContextPrereqFailed=0
        kubectl_current_context=$(kubectl config current-context)
        if [ ! "${kubectl_current_context}" == "docker-desktop" ] &&
        [ ! "${kubectl_current_context}" == "docker-for-desktop" ]; then
            echo "ERROR: kubectl CLI context is not set to \"docker-desktop\""
            echo "ERROR: This workshop has been tested with the Kubernetes cluster built into docker-destop."
            echo "ERROR: Set kubectl to the \"docker-desktop\" context by running: \"kubectl config set-context docker-desktop\""
            prereqFailed=1
        else
            echo "INFO: kubectl context for workshop is correct: ${kubectl_current_context}"
        fi

        local kubectlRunningClusterPrereqFailed=0
        kubectl cluster-info &> /dev/null || kubectlRunningClusterPrereqFailed=1
        if [ ${kubectlRunningClusterPrereqFailed} -eq 1 ]; then
            echo "ERROR: kubernetes cluster information is not available. Please check whether the cluster is running with \"kubectl cluster-info\"."
            prereqFailed=1
        else
            echo "INFO: kubernetes cluster is available."
            kubectl cluster-info | grep -i running
        fi

        kubectl_client_version=$(kubectl version --short=true | grep Client | cut -d ' ' -f 3 | cut -d "." -f 1-2)
        if [[ "${kubectl_client_version}" <  "v1.14" ]]; then
            echo "ERROR: kubectl client version [$(kubectl version --short=true | grep Client | cut -d ' ' -f 3)] does not support Appsody. Minimum is 1.15"
            prereqFailed=1
        else
            echo "INFO: kubectl client version [$(kubectl version --short=true | grep Client | cut -d ' ' -f 3)] meets minimum requirements."
        fi
    fi

    if [ ${prereqFailed} -eq 0 ]; then
        echo "INFO: All prerequisites verified."
    else
        echo "ERROR: Workshop prerequisites are not met, please review earlier messages."
    fi

    return ${prereqFailed}
}


function cleanWorkshop() {
    [[ $(appsody list | grep workshop) ]] && appsody repo remove workshop
    [[ $(docker images appsody/* -q | wc -l) -gt 0 ]] && docker rmi $(docker images appsody/* -q | sort | uniq) -f
    [[ $(docker images postgres -q | wc -l) -gt 0 ]] && docker rmi postgres
    docker rmi openjdk8-openj9-local
}


# OS specific support. $var _must_ be set to either true or false.
cygwin=0;
case "`uname`" in
  CYGWIN*) cygwin=1;;
esac


check=0
cache=0
while [[ $# > 0 ]]
do
key="$1"
shift
case $key in
    -p|--check-prereqs)
    check=1
    ;;
    -c|--cache-prereqs)
    cache=1
    ;;
    -l|--language)
    workshop_collection=$1
    shift
    ;;
    -h|--help)
    usage
    exit
    ;;
    -v|--verbose)
    verbose=1
    ;;
    *)
    echo "Unrecognized parameter: $key"
    usage
    exit 1
esac
done

echo
echo "INFO: Workshop preparation starting..."
echo

is_java=0
is_node=1
app_name=java-example
app_dir=${workshop_dir}/${app_name}
stacks_subdir=stacks
stacks_dir=${workshop_dir}/${stacks_subdir}
git_repo_stacks=https://github.com/gcharters/stacks.git
source_collection_name=nodejs-express
collection_name=java-microprofile-dev-mode
collection_index=experimental
collection_path=${collection_index}/${collection_name}
case ${workshop_collection} in
  java) 
  ;;
  nodejs)
  is_java=0
  is_node=1
  app_name=nodejs-example
  app_dir=${workshop_dir}/${app_name}
  git_repo_stacks=https://github.com/kabanero-io/collections.git
  collection_name=my-${source_collection_name}-stack
  collection_index=incubator
  collection_path=incubator/${collection_name}
  ;;
  *)
  echo "INFO: No workshop collection specified, defaulting to ${workshop_collection}"
esac


result=0
if [ ${check} -eq 1 ]; then
    checksPrereqs
    result=$?
fi

if [ ${cache} -eq 1 ] && [ ${is_java} -eq 1 ] && [ ${result} -eq 0 ]; then
    echo
    cacheDockerImages
    result=$?
fi

if [ ${cache} -eq 1 ] && [ ${result} -eq 0 ]; then
    echo
    cacheStacks
    result=$?
fi


if [ ${result} -eq 0 ]; then
    #
    # Environment settings
    #
    mkdir -p "${workshop_dir}"
    env_file="${workshop_dir}/env.sh"
    cat > "${env_file}" << EOF
export IMAGE_REGISTRY_ORG=kabanero
export CODEWIND_INDEX=false
export WORKSHOP_DIR=${workshop_dir}
export workshop_dir=${workshop_dir}
EOF
    chmod u+x "${env_file}"

    echo
    echo "INFO: Workshop preparation ready at ${workshop_dir}"
    echo
    if [ ${cygwin} -eq 1 ]; then 
        env_win_file="${workshop_dir}/env.bat"
        workshop_win_dir=$(cygpath -w ${workshop_dir})
        cat > "${env_win_file}" << EOF
set IMAGE_REGISTRY_ORG=kabanero
set CODEWIND_INDEX=false
set WORKSHOP_DIR=${workshop_win_dir}
set workshop_dir=${workshop_win_dir}
set workshop_url_dir=$(echo "${workshop_win_dir}" | sed 's|\\|\/|g')
EOF

        echo "INFO: Execute the following line in Windows Command Prompt to configure environment variables referenced in workshop instructions:"
        echo "$(cygpath -w ${env_win_file})"
        echo
        echo "INFO: Execute the following line in Cygwin shells to configure environment variables referenced in workshop instructions:"
    else
        echo "INFO: Execute the following line to configure environment variables referenced in workshop instructions:"
    fi
    echo "eval \$(cat ${workshop_dir}/env.sh)"
    echo
fi

exit ${result}
