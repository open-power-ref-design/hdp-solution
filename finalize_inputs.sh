#!/bin/bash
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
# finalize_inputs.sh
#
# This script finalizes the inputs in preparation for the automated deploy.  It 
# accomplishes some validation and reconciliation of the inputs to help ensure 
# the deploy process runs properly.
#
# All inputs to the automation process are staged and updated in the 
# "hdp-solution-inputs" directory.  Any manual updates to these inputs should be 
# accomplished prior to running this script.
# ------------------------------------------------------------------------------

set -e
PWD=$(pwd)
cd $(dirname $0)/..
PARENT_DIR=$(pwd)
cd - # go back

HDP_SOLUTION_HOME=${PWD}
HDP_SOLUTION_INPUTS_HOME="${PARENT_DIR}/hdp-solution-inputs"
DISTROS_HOME="${HDP_SOLUTION_INPUTS_HOME}/distros/"

CONFIG_FILE=${HDP_SOLUTION_INPUTS_HOME}/config.yml

# echo PARENT_DIR=$PARENT_DIR
# echo HDP_SOLUTION_INPUTS_HOME=$HDP_SOLUTION_INPUTS_HOME
# echo CONFIG_FILE=$CONFIG_FILE
# echo DISTROS_HOME=$DISTROS_HOME 

# propagate hostname stems
# The hostname stems are provided by the user in the config.yml under the node templates.
# These must be propagated to the kickstart file for use by the deploy process to properly 
# configure the nodes based upon their particular type.
python finalize_inputs_hostnames.py $CONFIG_FILE $DISTROS_HOME

exit $?
