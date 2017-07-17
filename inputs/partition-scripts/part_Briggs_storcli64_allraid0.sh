#!/bin/bash
#
#-------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) COPYRIGHT International Business Machines Corp. 2014
# All Rights Reserved
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an xCAT and Genesis disk partitioning script for worker nodes.
# This script assumes the controller is MegaRAID.
#
#-------------------------------------------------------------
# 2017.06.19    kurtis@us.ibm.com
#-------------------------------------------------------------
declare -r YES="1"
declare -r NO="0"

declare -A SLOT_2_EID
declare -A SLOT_2_EID_DETAIL
SLOT_2_EID_KEYS=""
SLOT_2_EID_KEYS_SORTED=""

declare -A SCSI_NAA_ID_2_SLOT=""
declare -A SCSI_NAA_ID_2_SLOT_DETAIL=""
SCSI_NAA_ID_2_SLOT_KEYS=""
SCSI_NAA_ID_2_SLOT_KEYS_SORTED=""

declare -A SLOT_2_DEV=""
SLOT_2_DEV_KEYS=""
SLOT_2_DEV_KEYS_SORTED=""

declare -r XCAT_STORCLI_DIR="/install/custom/raidtools"
declare -r GEN_STORCLI_PATH="/install/custom/storcli64/storcli64"
declare -r LOCL_STORCLI_PATH="/root/ibmlbs/bin/storcli64"
declare -r UTILDIR="/tmp/raidtools"
declare -r STORCLI64="${UTILDIR}/storcli64"
declare -r HDD_ONLY="${YES}"
RUN_PART_SCRIPT="${YES}"
OSDEV=""
OSSLOT=""
FILTERED_SLOTS=""

declare -r PARTF="/tmp/partitionfile"
declare -r BOOT_FS_TYPE="ext4"
declare -r GRID_FS_TYPE="ext4"
declare -r OS_FS_TYPE="ext4"

declare -r SWAP_SP_SIZE="--size 12288"
declare -r ROOT_FS_SIZE="--size 131072"
declare -r BOOT_FS_SIZE="--size 1024"
declare -r GRID0_FS_SIZE="--size 1 --grow"
declare -r GRID0_FS="/grid/0"
declare -r GRID_FS_PRE="/grid/"

#--------------------------------------------
function __dumpAssociativeArray1()
{
    
    local KEY=""; local VAL=""
    echo -e "\nDumping array: SLOT_2_EID_DETAIL with keys: <{SLOT_2_EID_KEYS_SORTED}>"
    for KEY in $(echo "${SLOT_2_EID_KEYS_SORTED}"|tr " " "\n"); do
        VAL="${SLOT_2_EID_DETAIL[$KEY]}"
        echo "    <KEY=${KEY}> <VAL=${VAL}>"
    done
    echo -e ">>> end of array dump\n"
    
    return
}   # __dumpAssociativeArray1()
#--------------------------------------------
function __dumpAssociativeArray2()
{
    
    local KEY=""; local VAL=""
    echo -e "\nDumping array: SCSI_NAA_ID_2_SLOT with keys: <${SCSI_NAA_ID_2_SLOT_SORTED_KEYS}>"
    for KEY in $(echo "${SCSI_NAA_ID_2_SLOT_SORTED_KEYS}"|tr " " "\n"); do
        VAL="${SCSI_NAA_ID_2_SLOT_DETAIL[$KEY]}"
        echo "    <KEY=${KEY}> <VAL=${VAL}>"
    done
    echo -e ">>> end of array dump\n"
    
    return
}   # __dumpAssociativeArray2()
#--------------------------------------------
function __dumpAssociativeArray3()
{
    
    local KEY=""; local VAL=""
    echo -e "\nDumping array: SLOT_2_DEV with keys: <${SLOT_2_DEV_KEYS_SORTED}>"
    for KEY in $(echo "${SLOT_2_DEV_KEYS_SORTED}"|tr " " "\n"); do
        VAL="${SLOT_2_DEV[$KEY]}"
        echo "    <KEY=${KEY}> <VAL=${VAL}>"
    done
    echo -e ">>> end of array dump\n"
    
    return
}   # __dumpAssociativeArray3()
#--------------------------------------------
function __mklookup1()
{
    local OUT=$( ${STORCLI64} /c0/eall/sall show|awk \
    'BEGIN{k=0;}\
    /^EID:Slt/{getline;getline;k=1;}\
    /^-------/{k=0;}\
    {if (k==1) {\
        i=index($1,":");\
        eid=substr($1,1,i-1);\
        slot=substr($1,i+1);\
        stat=$3;\
        size=$5$6;\
        iface=$7;\
        media=$8;\
        model=$12;\
        model="";\
        for(i=12;i<NF;i++)\
            {model=" "$i};\
        model=substr(model,2);
        spin=$NF;\
        printf("%s,%s,%s,%s,%s,%s,%s,%s\n",slot,eid,stat,size,iface,media,model,spin);}
     }' )
    
    # The following is an example of the output from the previous pipe.
    #0        1  2     3  4     5  6    7    8  9  0    1       
    #8:0      19 UGood -  3.492 TB SATA SSD N   N  512B SAMSUNG MZ7LM3T8HCJM-00005 D
    #8:1      20 UGood -  3.492 TB SATA SSD N   N  512B SAMSUNG MZ7LM3T8HCJM-00005 D
    #8:2      18 Onln  0  7.276 TB SAS  HDD N   N  512B ST8000NM0075               U
    #8:3      10 UGood -  7.276 TB SAS  HDD N   N  512B ST8000NM0075               D
    #8:4      12 UGood -  7.276 TB SAS  HDD N   N  512B ST8000NM0075               D
    #8:5      15 UGood -  7.276 TB SAS  HDD N   N  512B ST8000NM0075               D
    #8:6      11 UGood -  7.276 TB SAS  HDD N   N  512B ST8000NM0075               D
    #8:7      13 UGood -  7.276 TB SAS  HDD N   N  512B ST8000NM0075               D
    #8:8      14 UGood -  7.276 TB SAS  HDD N   N  512B ST8000NM0075               D
    #8:9      16 UGood -  7.276 TB SAS  HDD N   N  512B ST8000NM0075               D
    #8:10     17 UGood -  7.276 TB SAS  HDD N   N  512B ST8000NM0075               D
    #8:11      9 UGood -  7.276 TB SAS  HDD N   N  512B ST8000NM0075               D
    
    local LINE=""
    local J=0
    local SLOT=""; local EID=""
    local OUTA
    for LINE in ${OUT}; do
#        echo "<LINE=${LINE}>"
        OUTA=($( echo "${LINE}"|awk -F "," '{for(i=1;i<=NF;i++){print $i};}' ))
        J=0
        SLOT="${OUTA[$J]}";     (( J++ ))
        EID="${OUTA[$J]}";      (( J++ ))
        SLOT_2_EID[${SLOT}]="${EID}"
        SLOT_2_EID_DETAIL[${SLOT}]="${LINE}"
    done
    
    SLOT_2_EID_KEYS="${!SLOT_2_EID[@]}"
    SLOT_2_EID_KEYS_SORTED=$( echo "${SLOT_2_EID_KEYS}"|\
            awk '{for(i=1;i<=NF;i++) print $i;}'|sort -g|xargs )
    echo "<SLOT_2_EID_KEYS_SORTED=${SLOT_2_EID_KEYS_SORTED}>"
    __dumpAssociativeArray1
    return
}   # __mklookup()
#--------------------------------------------
function __mklookup2()
{
    local OUT=$( ${STORCLI64} /c0/vall show all|\
            awk 'BEGIN{x=0;}\
            /^\/c0\/v/{vdid=substr($1,6);}\
            /^DG\/VD/{getline;getline;dgvd=$1;type=$2;state=$3;access=$4;size=$9$10;}\
            /^EID:Slt/{getline;getline;i=index($1,":");eid=substr($1,1,i-1);slot=substr($1,i+1);\
                        intf=$7;med=$8;}\
            /^SCSI NAA Id = /{snid=$5;\
                printf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",\
                    dgvd,type,state,access,size,eid,slot,intf,med,snid);}')
                    
    # The following is an example of the output from the previous pipe.                    
    # 0   1     2    3  4       5 6 7   8   9
    # 0/0,RAID0,Optl,RW,7.276TB,8,2,SAS,HDD,600605b00ba75a50ff0004884554f07b
    local ID=""; local SLOT=0; local OUTA
    for LINE in ${OUT}; do
        OUTA=($( echo "${LINE}"|awk -F "," '{for(i=1;i<=NF;i++){print $i};}' ))
        ID="${OUTA[9]}"; SLOT="${OUTA[6]}"
        SCSI_NAA_ID_2_SLOT[${ID}]="${SLOT}"
        SCSI_NAA_ID_2_SLOT_DETAIL[${ID}]="${LINE}"
    done
    
    # Take note that the awk program pipe in the following system command will
    #   filter out index 0.  Not sure why this is. Must be required.    
    SCSI_NAA_ID_2_SLOT_KEYS=$( echo "${!SCSI_NAA_ID_2_SLOT[@]}" |\
            awk '{for(i=1;i<=NF;i++) {if($i != "0") print $i;}}')

    SCSI_NAA_ID_2_SLOT_SORTED_KEYS=$( echo "${SCSI_NAA_ID_2_SLOT_KEYS}"|\
            awk '{for(i=1;i<=NF;i++){print $i;}}'|sort -g|xargs )
            
    echo "<SCSI_NAA_ID_2_SLOT_SORTED_KEYS=${SCSI_NAA_ID_2_SLOT_SORTED_KEYS}>"

    __dumpAssociativeArray2

    return
}   # __mklookup2()
#--------------------------------------------
function __setup()
{
    __copyStorcli64
    __mklookup1
    
}   # __setup()
#--------------------------------------------
function __resetDiskConfig()
{

    local RC=0
    
    echo ">>> INFO: <cmd=pvdisplay>"
    pvdisplay; RC=$? 
    echo ">>> INFO: <RC=${RC}>"
    echo ">>> INFO: <cmd=vgdisplay>"
    vgdisplay; RC=$? 
    echo ">>> INFO: <RC=${RC}>"
    echo ">>> INFO: <cmd=lvdisplay>"
    lvdisplay; RC=$? 
    echo ">>> INFO: <RC=${RC}>"
    
    echo ">>> INFO: Removing all volume groups (vgremove)"
    vgdisplay | awk '/VG Name/{print $3;}'|xargs -I {} sh -c 'vgchange -a n {}; vgremove -f {};'
    
    echo ">>> INFO: Executing cmd 'cat /proc/mdstat'"
    cat /proc/mdstat; RC=$? 
    echo ">>> INFO: <RC=${RC}>"
    
    echo ">>> INFO: stop all md arrays"
    mdadm --detail --scan | awk '{print $2}' | while read mdarray; do mdadm --stop $mdarray; done
    
    echo -e "\n>>>Deleting ALL foreign configs"
    echo ">>> INFO: <cmd=${STORCLI64} /c0/fall delete>"
    $STORCLI64 /c0/fall delete; RC=$? 
    echo ">>> INFO: <RC=${RC}>"

    echo -e "\n>>>Deleting ALL virtual drives"
    echo ">>> INFO: <cmd=${STORCLI64} /c0/vall delete force>"
    $STORCLI64 /c0/vall delete force; RC=$? 
    echo ">>> INFO: <RC=${RC}>"
    
    echo ">>> INFO: <cmd=${STORCLI64} /c0/vall delete force>"
    $STORCLI64 /c0/vall delete force; RC=$? 
    echo ">>> INFO: <RC=${RC}>"

    echo -e "\n>>>Turning off JBOD mode"
    echo ">>> INFO: <cmd=${STORCLI64} /c0 set jbod=off force>"
    $STORCLI64 /c0 set jbod=off force; RC=$? 
    echo ">>> INFO: <RC=${RC}>"
    
}   # __resetDiskConfig()
#--------------------------------------------
function __copyStorcli64()
{
    echo ">>> Copying storcli64 from xCAT, cobbler or local"
    mkdir -p "${UTILDIR}"
 
    XCATMASTER_SAVED=$XCATMASTER   
    XCATMASTER=#XCATVAR:XCATMASTER#
    echo "<XCATMASTER=${XCATMASTER}> <COBBLERMASTER=${COBBLERMASTER}>"
             
    if [[ -n "${XCATMASTER_SAVED}" ]]; then
        # This is an xCAT provisioning script.
        echo "XCAT provisioning detected <XCATMASTER=${XCATMASTER}>"
        
        # Mount xCAT directory that contains storcli64 binary.
        echo "$XCATMASTER" | grep -sq XCATVAR && XCATMASTER=127.0.0.1
        mount -o nolock $XCATMASTER:${XCAT_STORCLI_DIR} $UTILDIR
  
    elif [[ -n "${COBBLERMASTER}" ]]; then
        # This Genesis
        echo "Genesis/cobbler provisioning detected <COBBLERMASTER=${COBBLERMASTER}>" 
        wget -O $STORCLI64 http://${COBBLERMASTER}/${GEN_STORCLI_PATH}
    else
        # Running from command-line
        cp "${LOCL_STORCLI_PATH}" "${STORCLI64}"
        RUN_PART_SCRIPT="${NO}"
    fi
    
    # Make sure the file is executeable
    chmod +x "${STORCLI64}"
    
    echo ">>> Here is the contents of <UTILDIR=${UTILDIR}>:"
    ls -l "${UTILDIR}"
    echo          
    
    return 0    
}   # __copyStorcli64()
#--------------------------------------------
function __createRaid0()
{
    echo ">>> Creating raid0 arrays"
    local SLOT=""; local INFO=""
    for SLOT in $(echo "${SLOT_2_EID_KEYS_SORTED}"|tr " " "\n"); do

        # 0    1   2    3    4     5     6     7
        # slot,eid,stat,size,iface,media,model,spin
        INFO="${SLOT_2_EID_DETAIL[$SLOT]}"
        if [[ -n "${INFO}" ]]; then
        
            # Parse the value stored in the lookup table.
            ARRAY=($( echo "${INFO}"|awk -F "," '{for(i=1;i<=NF;i++){print $i};}' ))
            J=1
            EID="${ARRAY[$J]}";        (( J++ ))
            STATUS="${ARRAY[$J]}";     (( J++ ))
            SIZE="${ARRAY[$J]}";       (( J++ ))
            IFACE="${ARRAY[$J]}";      (( J++ ))
            MEDIA="${ARRAY[$J]}";      (( J++ ))
            MODEL="${ARRAY[$J]}";      (( J++ ))
            SPIN="${ARRAY[$J]}";       (( J++ ))
            
            # Might need to filter only HDD drives.  Do this now.
            [[ "${HDD_ONLY}" == "${YES}" && "${MEDIA}" != "HDD" ]] && continue
            FILTERED_SLOTS="${FILTERED_SLOTS} ${SLOT}"
            
            # Have a storage device to create RAID0 array on.
            # /tmp/storcli64/storcli64 /c0 add vd raid0 drives=${eid}:0 
            PARMS="/c0 add vd raid0 name=drive${SLOT} drives=${EID}:${SLOT}"
            echo ">>> INFO: <cmd=${STORCLI64} ${PARMS}>"
            eval "${STORCLI64}" "${PARMS}"; RC=$?
            echo ">>> INFO: <RC=${RC}>"
        else
            # This should never happen?
            echo ">>> ERROR: <SLOT=${SLOT}> has no element in associative array SLOT_2_EID_DETAIL"
        fi
    done
    
    # Strip off leading blank.  This will be used later.
    FILTERED_SLOTS="${FILTERED_SLOTS:1}"    
    
    echo ">>> INFO: sleeping 30 seconds.  Let arrays get created."
    sleep 30
    
    return 0
}   # __createRaid0()
#--------------------------------------------
function __findOSdevice()
{
    # First thing to do is to build SCSI_NAA_ID_2_SLOT lookup table
    #   This must be AFTER all disks are created as RAID0.
    __mklookup2

    local RC=0

    # Generate a list of all sd* deviles.  Need to expand this to includ nvram drives.
    local OUT=$( lsblk|awk '/^sd/{print $1}' )
    local DEV=''; local SHORTDEV=""; local RESULT=""; local SLOT=""
    for DEV in ${OUT}; do
        SHORTSN=$( udevadm info /dev/${DEV}|grep "ID_SERIAL_SHORT="|\
                     awk -F "=" '{print $2;}')
        
        # Filter out devices with no short serial number.  
        #   Not sure why that would happen.
        if [[ -z "${SHORTSN}" ]]; then
            echo ">>> WARNING: <DEV=${DEV}> does not have an ID_SERIAL_SHORT attribute."
            continue
        fi
        
        RESULT="${SCSI_NAA_ID_2_SLOT_DETAIL[$SHORTSN]}"
        # No sense in going any further if there is no data in lookup table.
        [[ -z "${RESULT}" ]] && continue
        
        # Build another lookup table of with slot as index and value Linux device name
        SLOT=$( echo "${RESULT}" | awk -F "," '{print $7;}' )
        echo "<RESULT=${RESULT}> <SLOT=${SLOT}>"
        SLOT_2_DEV[${SLOT}]="${DEV}"
        
        if [[ -z "${OSDEV}" ]]; then
            OSDEV="${DEV}"
            OSSLOT="${SLOT}"
            echo ">>> INFO: Found drive for OS <OSDEV=${OSDEV}> <OSSLOT=${OSSLOT}>"
        else
            echo ">>> INFO: <DEV=${DEV}> not in SCSI_NAA_ID_2_SLOT_DETAIL associative array"
        fi
        
    done
    
    # Check to see if we found a suitable OS installable device.
    if [[ -z "${OSDEV}" ]]; then
        echo -e "\n>>>\n>>> ERROR: Cannot find a suitable device for OS.  Partitioning will fail.\n>>>\n"
        RC=11
    else
        echo ">>> INFO: Found OS disk device <OSDEV=${OSDEV}>"
    fi

    # Generate a blank delimited string of keys for slot-to-device associative array.
    SLOT_2_DEV_KEYS=$( echo "${!SLOT_2_DEV[@]}" |\
            awk '{for(i=1;i<=NF;i++) {if($i != "0") print $i;}}')

    SLOT_2_DEV_KEYS_SORTED=$( echo "${SLOT_2_DEV_KEYS}"|\
            awk '{for(i=1;i<=NF;i++){print $i;}}'|sort -g|xargs )

    return $RC
}   # __findOSdevice()
#--------------------------------------------
function __genAnacondaPartInfoOS()
{
   
    echo ">>> INFO: Generating OS partition info"
cat > ${PARTF}  <<EOF
part None --fstype "PPC PReP Boot" --ondisk '$OSDEV' --size 8
bootloader --boot-drive=$OSDEV --driveorder=$OSDEV
clearpart --all --initlabel
part swap       ${SWAP_SP_SIZE}   --ondisk ${OSDEV}
part /          ${ROOT_FS_SIZE}   --ondisk ${OSDEV} --fstype ${OS_FS_TYPE}
part /boot      ${BOOT_FS_SIZE}   --ondisk ${OSDEV} --fstype ${BOOT_FS_TYPE}
part ${GRID0_FS} ${GRID0_FS_SIZE} --ondisk ${OSDEV} --fstype ${GRID_FS_TYPE}
EOF

    echo ">>> INFO: Here is file <PARTF=${PARTF}>"
    cat "${PARTF}"
    echo
    return 0

}   # __genAnacondaPartInfoOS()
#--------------------------------------------
function __genAnacondaPartInfoHDFS()
{
    echo ">>> INFO: Generating HDFS partition info"
    
    __dumpAssociativeArray3
    
    local OUT=$( echo "${FILTERED_SLOTS}"|tr " " "\n" )
    local SLOT=''; local DEV=""; local N=1; local ECNT=0
    echo "<FILTERED_SLOTS=${FILTERED_SLOTS}> <OUT=${OUT}>"
    for SLOT in ${OUT}; do
        
        # Skip if this is the disk for the OS. Should not be in list
        #   by definition of how variable FILTERED_DEVS was created.
        [[ "${SLOT}" == "${OSSLOT}" ]] && continue
        
        DEV="${SLOT_2_DEV[$SLOT]}"
        if [[ -z "${DEV}" ]]; then
            # Could not find this device in lookup table
            echo ">>> ERROR: Cannot find device for slot <SLOT=${SLOT}> in associative array SLOT_2_DEV."
            (( ECNT ++ ))
        else
            echo "part ${GRID_FS_PRE}${N} --size 1 --grow   --ondisk ${DEV} --fstype ${GRID_FS_TYPE}" >> "${PARTF}"
        fi
        
        (( N++ ))
    done 
    
    # Check for no full disk grid partition 
    (( ECNT != 0 )) && echo "part FAIL! FAIL!1 FAIL1" >> "${PARTF}"
    
    return 0
}   # __genAnacondaPartInfoHDFS()
#--------------------------------------------
function __cleanup()
{
	local RC=0
	
    echo ">>> INFO: Final <PARTF=${PARTF}>"
    cat "${PARTF}"; RC=$?
    echo "<RC=${RC}>"
    echo
    
    echo ">>> INFO: lsblk"
    lsblk; RC=$?
    echo "<RC=${RC}>"
    echo
    
    echo ">>> INFO: parted -ls"
    parted -ls; RC=$?
    echo "<RC=${RC}>"
    echo
    
    echo ">>> INFO: ${STORCLI64} /c0/eall/sall show"
    ${STORCLI64} /c0/eall/sall show; RC=$?
    echo "<RC=${RC}>"

    echo ">>> INFO: ${STORCLI64} /c0/vall show all"
    ${STORCLI64} /c0/vall show all; RC=$?
    echo "<RC=${RC}>"
    
    return 0
}   # __cleanup()
#--------------------------------------------
function __MAIN()
{
    local RC=0
    
    __setup
    [[ "${RUN_PART_SCRIPT}" == "${YES}" ]] && __resetDiskConfig
    __createRaid0
    __findOSdevice; RC=$?
    (( RC == 0 )) && __genAnacondaPartInfoOS
    (( RC == 0 )) && __genAnacondaPartInfoHDFS    
    __cleanup
    return 0
}   # __MAIN()
#--------------------------------------------

__MAIN

exit 0
