#!/bin/sh

RED='\033[0;31m'
NC='\033[0m'
environment=$1
cluster=$2
app=$3
kubectl_expected_namespace=$4
kubectl_expected_context=$5

helm_remote="INVALID"
helm_branch="INVALID"

app_config='{ 
                "devspace": { 
                                "helm_repo": "https://github.com/argonautdev/charts.git",
                                "helm_branch": "v0.5.0"
                            }
            }'

load_devspace_helm_charts() {
    if [[ -d '.devspace/chart-repo/.git' ]]; then 
        cd .devspace/chart-repo
        current_remote=`git config --get remote.origin.url`
        if [[ `echo $?` != 0 ]]; then
            exit 1 
        fi

        current_branch=`git rev-parse --abbrev-ref HEAD`
        if [[ `echo $?` != 0 ]]; then
            exit 1 
        fi

        if [[ $current_remote == $1 && $current_branch == $2 ]]; then
            git pull origin $2
        else 
            echo "current branch is not same required. Resetting local repo...."
            cd ../../
            rm -rf .devspace/chart-repo
            mkdir -p .devspace/chart-repo
            git clone --single-branch --branch $2 $1 .devspace/chart-repo
        fi
    else 
        echo "Local Repo not found. Pulling fresh local repo...."
        mkdir -p .devspace/chart-repo
        git clone --single-branch --branch $2 $1 .devspace/chart-repo
    fi
}


load_devspace_helm_details() {
    app_config=`art server-config --env $environment --cluster $cluster --app $app`
    if [[ `echo $?` != 0 ]]; then
        exit 1
    fi

    ## Parsing server config json to extract helm chart repo details

    helm_remote=`echo $app_config | grep -Eo '"helm_repo"[^,}]*' | grep -Eo ':.*$' | tr -d '[:space:]' | sed "s/^://" | tr -d '"'`
    if [[ `echo $?` != 0 ]]; then
        exit 1 
    fi

    helm_branch=`echo $app_config | grep -Eo '"helm_branch"[^,}]*' | grep -Eo '[^:]*$' | tr -d '[:space:]' | tr -d '"'`
    if [[ `echo $?` != 0 ]]; then
        exit 1 
    fi
}


check_devspace_context() {
    kubectl_current_context=`kubectl config current-context`
    if [[ `echo $?` != 0 ]]; then
        exit 1 
    fi
    kubectl_current_namespace=`kubectl config view --minify -o jsonpath='{..namespace}'`
    if [[ `echo $?` != 0 ]]; then
        exit 1 
    fi
    if [[ $1 != $kubectl_current_context || $2 != $kubectl_current_namespace ]]; then
        echo "${RED} Devspace Deployment Context seems to be set incorrectly, Do you still wish to continue with deployment(y/n) : ${NC}"
        read -n 1 -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1  # handle exits from shell or function but don't exit interactive shell
        fi
    fi
}

check_devspace_context $kubectl_expected_context $kubectl_expected_namespace

load_devspace_helm_details

echo $helm_remote $helm_branch

load_devspace_helm_charts $helm_remote $helm_branch

