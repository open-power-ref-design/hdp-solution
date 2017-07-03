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

set -e
PWD=$(pwd)
cd $(dirname $0)/..
PARENT_DIR=$(pwd)
cd - # go back

HDP_SOLUTION_HOME=${PWD}
HDP_SOLUTION_INPUTS_HOME="${PARENT_DIR}/hdp-solution-inputs"

ISO=""
INITRD=""

while true; do
  case "$1" in
    --iso ) ISO="$2"; shift; shift ;;
    --initrd ) INITRD="$2"; shift; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [[ -z "${ISO}" && -n "${INITRD}" ]]; then # if an iso is not specified and the initrd is specified,
  echo "Error: --iso parameter is required when --initrd is specified"
  exit 1
fi


echo ISO=$ISO
echo INITRD=$INITRD
echo PARENT_DIR=$PARENT_DIR
echo HDP_SOLUTION_INPUTS_HOME=$HDP_SOLUTION_INPUTS_HOME


DISTRO_NAME=$( sed 's/.iso$//' <<< $ISO ) # strip .iso from the end
DISTRO_NAME=$( sed 's/.*\///' <<< $DISTRO_NAME ) # strip the path
echo DISTRO_NAME=$DISTRO_NAME

mkdir -p ${HDP_SOLUTION_INPUTS_HOME} # create the inputs directory if it does not exist

if [ -n "${ISO}" ]; then # if an iso is specified, 

    DISTRO_INPUTS_HOME=${HDP_SOLUTION_INPUTS_HOME}/distros/${DISTRO_NAME}
    mkdir -p ${DISTRO_INPUTS_HOME} # create the directory for the distro if it does not exist
    cp -p "${ISO}" "${DISTRO_INPUTS_HOME}/"
    echo "Info: iso ${ISO} added to inputs folder."

    if [ -n "${INITRD}" ]; then # if an initrd is specified,
        cp -p "${INITRD}" "${DISTRO_INPUTS_HOME}/" # copy it into the distro directory;  note the initrd must be associated with a distro to be handled correctly later     
        echo "Info: initrd ${INITRD} added to inputs folder."
    fi

    KICKSTART_TEMPLATE=${HDP_SOLUTION_HOME}/inputs/kickstarts/RHEL-7.2-template.ks
    KICKSTART=${DISTRO_INPUTS_HOME}/${DISTRO_NAME}.ks
    if [ -e $KICKSTART ]; then
        echo "Info: Kickstart file ${DISTRO_NAME}.ks exists in inputs folder.  Existing kickstart file not changed."
    else
        cp -p ${KICKSTART_TEMPLATE} ${KICKSTART}
        echo "Info: Kickstart file ${DISTRO_NAME}.ks created from template and added to inputs folder."
    fi

    CONFIG_TEMPLATE=${HDP_SOLUTION_HOME}/inputs/configs/config-template.yml
    CONFIG=${HDP_SOLUTION_INPUTS_HOME}/config.yml
    if [ -e $CONFIG ]; then
        echo "Info: config.yml file exists in inputs folder.  Existing config.yml file not changed."
    else
        sed 's/{{ DISTRO_NAME }}/'${DISTRO_NAME}'/' ${CONFIG_TEMPLATE} > ${CONFIG}
        echo "Info: config.yml created from template and added to inputs folder."
    fi

fi


PARTITION_SCRIPTS_HOME=${HDP_SOLUTION_INPUTS_HOME}/partition-scripts
mkdir -p ${PARTITION_SCRIPTS_HOME} # create the partition scripts directory if it does not exist

PARTITION_SCRIPTS_TEMPLATE_HOME=${HDP_SOLUTION_HOME}/inputs/partition-scripts
FILES=${PARTITION_SCRIPTS_TEMPLATE_HOME}/*
for FILE in $FILES
do
    FILE_NAME=$( sed 's/.*\///' <<< $FILE ) # strip the path
    TARGET_FILE=${PARTITION_SCRIPTS_HOME}/${FILE_NAME}

    if [ -e ${TARGET_FILE} ]; then
        echo "Info: Partition script \"${FILE_NAME}\" exists in inputs folder.  Existing partition script not changed." 
    else
        cp -p ${FILE} ${TARGET_FILE}
        echo "Info: Partition script \"${FILE_NAME}\" added to inputs folder."
    fi
done


STORCLI64_HOME=${HDP_SOLUTION_INPUTS_HOME}/storcli64
mkdir -p ${STORCLI64_HOME} # create the storclie64 directory if it does not exist

STORCLI64_TEMPLATE_HOME=${HDP_SOLUTION_HOME}/inputs/storcli64
FILES=${STORCLI64_TEMPLATE_HOME}/*
for FILE in $FILES
do
    FILE_NAME=$( sed 's/.*\///' <<< $FILE ) # strip the path
    TARGET_FILE=${STORCLI64_HOME}/${FILE_NAME}

    if [ -e ${TARGET_FILE} ]; then
        echo "Info: storcli64 utility \"${FILE_NAME}\" exists in inputs folder.  Existing utility not changed."
    else
        cp -p ${FILE} ${TARGET_FILE}
        echo "Info: storcli64 utility \"${FILE_NAME}\" added to inputs folder."
    fi
done


PLAYBOOKS_HOME=${HDP_SOLUTION_INPUTS_HOME}/playbooks
mkdir -p ${PLAYBOOKS_HOME} # create the playbooks directory if it does not exist

PLAYBOOKS_TEMPLATE_HOME=${HDP_SOLUTION_HOME}/inputs/playbooks
FILES=${PLAYBOOKS_TEMPLATE_HOME}/*
for FILE in $FILES
do
    FILE_NAME=$( sed 's/.*\///' <<< $FILE ) # strip the path
    TARGET_FILE=${PLAYBOOKS_HOME}/${FILE_NAME}

    if [ -e ${TARGET_FILE} ]; then
        echo "Info: Playbook \"${FILE_NAME}\" exists in inputs folder.  Existing file not changed."
    else
        cp -p ${FILE} ${TARGET_FILE}
        echo "Info: Playbook \"${FILE_NAME}\" added to inputs folder."
    fi
done

exit 0
