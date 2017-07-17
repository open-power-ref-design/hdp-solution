# Copyright 2016 IBM Corp.
#
# All Rights Reserved.
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

set -e
PWD=$(pwd)
cd $(dirname $0)/..
PARENT_DIR=$(pwd)
cd - # go back

HDP_SOLUTION_HOME=${PWD}

#
#Cluster Genesis repository 
#
GENESIS_REMOTE="https://github.com/open-power-ref-design-toolkit/cluster-genesis.git"
GENESIS_LOCAL="${PARENT_DIR}/cluster-genesis"
GENESIS_COMMIT="582332e310170d1317edb5bf82b81d21b0628d4f"
GENESIS_VERSION="release-1.2"
GENESIS_FULL=$(pwd)/$GENESIS_LOCAL

#
#Operations Manager repository 
#
OPSMGR_REMOTE="https://github.com/open-power-ref-design-toolkit/opsmgr.git"
OPSMGR_LOCAL="$PARENT_DIR/opsmgr"
OPSMGR_COMMIT="f7449bc318325914b52a0624bfb7f01acd408f90" 
OPSMGR_VERSION="branch-v3"
OPSMGR_FULL=$(pwd)/$OPSMGR_LOCAL


HDP_SOLUTION_HOME=$(pwd)

#pull cluster-genesis into project directory
./setup_git_repo.sh "${GENESIS_REMOTE}" "${GENESIS_LOCAL}" "${GENESIS_COMMIT}"

#pull OpsMgr into project directory
./setup_git_repo.sh "${OPSMGR_REMOTE}" "${OPSMGR_LOCAL}" "${OPSMGR_COMMIT}"

#apply any patches to genesis.
# ./patch_source.sh "${GENESIS_LOCAL}"

#call cluster genesis install script
cd ${GENESIS_LOCAL}
scripts/install.sh
cd ..

source scripts/setup-env

