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
#
# ------------------------------------------------------------------------------
# install_genesis_base.sh
#
# This script accomplishes the download and base install of genesis.  Some of
# updates to the genesis installation are accomplished in this script, and some
# are accomplished in subsequent steps.  Additional update and configuration 
# is required before the automated deploy process can be run.
# ------------------------------------------------------------------------------

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
GENESIS_COMMIT="9bba99dd6dba8a49c96870d311bbbb400e8906f2"
GENESIS_VERSION="release-1.3"

# echo PARENT_DIR=${PARENT_DIR}
echo GENESIS_LOCAL=${GENESIS_LOCAL}

#pull cluster-genesis into project directory
./setup_git_repo.sh "${GENESIS_REMOTE}" "${GENESIS_LOCAL}" "${GENESIS_COMMIT}"

#apply any patches to genesis.
# ./patch_source.sh "${GENESIS_LOCAL}"

# patches
# change to upgrade virtualenv to later level
sed -i 's/sudo -E -H pip install virtualenv/sudo -E -H pip install --upgrade virtualenv/g' ${GENESIS_LOCAL}/scripts/install.sh
# change to not use key for authentication to the switches
sed -i 's/look_for_keys=True/look_for_keys=False/g' ${GENESIS_LOCAL}/scripts/python/lib/ssh.py

#call cluster genesis install script
cd ${GENESIS_LOCAL}
scripts/install.sh
source scripts/setup-env
cd -

# reload bash profile to pick-up path updates from the genesis install
. ~/.bashrc

