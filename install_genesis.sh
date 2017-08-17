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
# install_genesis.sh
#
# This top level script downloads, installs, and configures genesis.  All inputs
# must be in place in the "hdp-solution-inputs" directory prior to running this
# script.  After this scripts completes, the automated deloy process 
# ('gen deploy') may be run.
# ------------------------------------------------------------------------------
# 2017-08-16 woodbury - added check and correction of network file
# ------------------------------------------------------------------------------

set -e

# check for left-overs from a previous failed install attempt and offer to delete them
shopt -s nullglob
IFCFGS="/etc/sysconfig/network-scripts/ifcfg-.*"
for IFCFG in $IFCFGS
do
    echo "WARNING: A network config file, \"$IFCFG\", was found that appears to be invalid:"
    read -p "Delete file \"$IFCFG\" ? (y/n) " resp
    if [ $resp == "y" ]; then
        sudo rm $IFCFG
    fi
done

# 1) download genesis base code and files (from git)
# 2) apply initial patches
# 3) run the genesis install.sh
./install_genesis_base.sh

# do the majority of genesis updates for this solution; these must be done after the genesis install.sh
./update_genesis.sh

# some additional genesis configuration is also done during the 'gen deploy' step
