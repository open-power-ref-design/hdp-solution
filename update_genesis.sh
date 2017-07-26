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
# update_genesis.sh
#
# This script updates the genesis installation to customize it to be suitable
# for the hdp-solution.
# ------------------------------------------------------------------------------

set -e
PWD=$(pwd)
cd $(dirname $0)/..
PARENT_DIR=$(pwd)
cd - # go back

HDP_SOLUTION_HOME=${PWD}
HDP_SOLUTION_INPUTS_HOME="${PARENT_DIR}/hdp-solution-inputs"
GENESIS_HOME="${PARENT_DIR}/cluster-genesis"

echo PARENT_DIR=$PARENT_DIR
echo HDP_SOLUTION_INPUTS_HOME=$HDP_SOLUTION_INPUTS_HOME

# config.yml
SRC_FILE=${HDP_SOLUTION_INPUTS_HOME}/config.yml
DST_FILE=${GENESIS_HOME}/

cp -p ${SRC_FILE} ${DST_FILE}
echo "Info: Copied config.yml into cluster-genesis"

# create update directories
mkdir -p ${GENESIS_HOME}/hdp_solution_updates/i40e
mkdir -p ${GENESIS_HOME}/hdp_solution_updates/partition
mkdir -p ${GENESIS_HOME}/hdp_solution_updates/storcli64


# RHEL*.iso
# RHEL*.ks
DISTROS_HOME=${HDP_SOLUTION_INPUTS_HOME}/distros
DISTROS=${DISTROS_HOME}/*
for DISTRO in $DISTROS
do
    DISTRO_NAME=$( sed 's/.*\///' <<< $DISTRO ) # strip the path
    SRC_FILE=${DISTRO}/${DISTRO_NAME}.iso
    DST_DIR=${GENESIS_HOME}/os_images/

    cp -p ${SRC_FILE} ${DST_DIR}
    echo "Info: Copied ${DISTRO_NAME}.iso into cluster-genesis (iso)"

    SRC_FILE=${DISTRO}/${DISTRO_NAME}.ks
    DST_DIR=${GENESIS_HOME}/os_images/config/

    cp -p ${SRC_FILE} ${DST_DIR}
    echo "Info: Copied ${DISTRO_NAME}.ks into cluster-genesis (kickstart)"

    # i40e patch - initrd.img
    FILES=${DISTRO}/initrd*.img
    for FILE in $FILES
    do
        FILE_NAME=$( sed 's/.*\///' <<< $FILE ) # strip the path
        SRC_FILE=$FILE
        DST_DIR=${GENESIS_HOME}/hdp_solution_updates/i40e/${DISTRO_NAME}/
        mkdir -p ${DST_DIR}
 
        cp -p ${SRC_FILE} ${DST_DIR}
        echo "Info: Copied ${FILE_NAME} into cluster-genesis (i40e patch)"
    done

done


# partition scripts
FILES=${HDP_SOLUTION_INPUTS_HOME}/partition-scripts/*
for FILE in $FILES
do
    FILE_NAME=$( sed 's/.*\///' <<< $FILE ) # strip the path
    SRC_FILE=$FILE
    DST_DIR=${GENESIS_HOME}/hdp_solution_updates/partition/

    cp -p ${SRC_FILE} ${DST_DIR}
    echo "Info: Copied ${FILE_NAME} into cluster-genesis (partition script)"
done

# storcli64 utilities
FILES=${HDP_SOLUTION_INPUTS_HOME}/storcli64/*
for FILE in $FILES
do
    FILE_NAME=$( sed 's/.*\///' <<< $FILE ) # strip the path
    SRC_FILE=$FILE
    DST_DIR=${GENESIS_HOME}/hdp_solution_updates/storcli64/

    cp -p ${SRC_FILE} ${DST_DIR}
    echo "Info: Copied ${FILE_NAME} into cluster-genesis (storcli64 utility)"
done

# playbooks
FILES=${HDP_SOLUTION_INPUTS_HOME}/playbooks/*
for FILE in $FILES
do
    FILE_NAME=$( sed 's/.*\///' <<< $FILE ) # strip the path
    SRC_FILE=$FILE
    DST_DIR=${GENESIS_HOME}/playbooks/

    cp -p ${SRC_FILE} ${DST_DIR}
    echo "Info: Copied ${FILE_NAME} into cluster-genesis (playbook update)"
done


exit 0

