#!/bin/bash

# Copyright 2025 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

# Source version configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/terraform_versions.env"

GO_LDFLAGS="-s -w"
# Allow override of installation paths via environment variables
TF_INSTALL_DIR="${TF_INSTALL_DIR:-/usr/local/bin}"
TF_PLUGIN_PATH="${TF_PLUGIN_PATH:-$HOME/.terraform.d/plugins/registry.terraform.io}"

install_terraform(){
    if [[ ! -z $(command -v terraform) ]]; then
        echo "terraform already present"
    else
        cd /tmp
        curl -fsSL https://github.com/hashicorp/terraform/archive/refs/tags/v${TF_VERSION}.zip -o ./terraform.zip
        unzip -o ./terraform.zip  >/dev/null 2>&1
        rm -f ./terraform.zip
        cd terraform-${TF_VERSION}
        go build -ldflags="${GO_LDFLAGS}" .
        mkdir -p "${TF_INSTALL_DIR}"
        cp terraform "${TF_INSTALL_DIR}/"
    fi
}

install_terraform_x86(){
    if [[ ! -z $(command -v terraform) ]]; then
        echo "terraform already present"
    else
        cd /tmp
        curl -fsSL https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip -o ./terraform.zip
        unzip -o ./terraform.zip  >/dev/null 2>&1
        rm -f ./terraform.zip
        mkdir -p "${TF_INSTALL_DIR}"
        cp terraform "${TF_INSTALL_DIR}/"
    fi
}

build_provider(){
    local PROVIDER_NAME=$1
    local PROVIDER_VERSION=$2
    local PROVIDER_REPO=$3
    
    VERSIONED_NAME="terraform-provider-${PROVIDER_NAME}-v${PROVIDER_VERSION}"
    
    if [[ -f "${TF_PLUGIN_PATH}/${VERSIONED_NAME}" ]]; then
        echo "Provider ${PROVIDER_NAME} already exists at ${TF_PLUGIN_PATH}/${VERSIONED_NAME}"
        return
    fi
    
    echo "Building ${PROVIDER_NAME} provider v${PROVIDER_VERSION}..."
    cd /tmp
    curl -fsSL ${PROVIDER_REPO}/archive/refs/tags/v${PROVIDER_VERSION}.zip -o ./terraform-provider-${PROVIDER_NAME}.zip
    unzip -o ./terraform-provider-${PROVIDER_NAME}.zip >/dev/null 2>&1
    rm -f ./terraform-provider-${PROVIDER_NAME}.zip
    cd terraform-provider-${PROVIDER_NAME}-${PROVIDER_VERSION}
    go build -ldflags="${GO_LDFLAGS}" .
    mkdir -p "${TF_PLUGIN_PATH}"
    cp -f terraform-provider-${PROVIDER_NAME} ${TF_PLUGIN_PATH}/${VERSIONED_NAME}
    echo "Built ${VERSIONED_NAME}"
}

ARCH=$(uname -m)

if [[ "${ARCH}" == "ppc64le" || "${ARCH}" == "s390x" ]]; then
    install_terraform
    build_provider "ibm" "${TERRAFORM_PROVIDER_IBM_VERSION}" "https://github.com/IBM-Cloud/terraform-provider-ibm"
    build_provider "null" "${TERRAFORM_PROVIDER_NULL_VERSION}" "https://github.com/hashicorp/terraform-provider-null"
elif [[ "${ARCH}" == "x86_64" ]]; then
    install_terraform_x86
fi
