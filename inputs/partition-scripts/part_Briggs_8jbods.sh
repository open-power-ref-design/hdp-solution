#!/bin/sh
#-------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) COPYRIGHT International Business Machines Corp. 2016
# All Rights Reserved
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an xCAT partition script for Briggs servers.  This output from
# this script is a file that will be called by an anaconda kickstart to
# configure ALL HDDs for use by Hortonworks installation.
#  
# The MegaRaid adapter does not recognize storage until it is initialized
# by a ppc binary storcli64.  This is normally performed on x86 hardware
# via an integrated BIOS utility.  The storcli64 program must be remotely
# copied and this script performs this capability via xCAT.  storcli64 is
# key to the excution of this script.
#
#
# Assumptions:
#   1. Server access HDD/SDD/NVMe drives va MegaRaid adapter.
#   2. System as at least 1 HDD for OS.
#   3. All additional HDDs beyond OS HDD will be used for HDFS.
#   3. SSDs and NVMe SSDs are not used.
#   4. OS HDD is not in a RAID array.
#   5. 350GB partition of OS disk will be for OS.
#   6. Separate disk partition on OS disk will be for HDFS.
#
#
#  This is the drive slot numbering the storcli64 program uses.
#  SSDs and HDDs can be in any slot, NVMe SSDs can only be in slots
#  8 through 11.  HDDs can be SATA or SAS (preferred for HDP).
#
#       +-----------------------+
#       |  2  |  5  |  8  | 11  |
#       |-----------------------|
#       |  1  |  4  |  7  | 10  |
#       |-----------------------|
#       |  0  |  3  |  6  |  9  |
#       +-----------------------+
#
# HDP recommended partition sizes:
# 
#   /           50GB                51200 MB
#   /dev        32GB                32768 MB  IGNORE: Cannot be sparate MP.
#   /boot     1008MB                 1008 MB
#   /opt        10GB                10240 MB  
#   /var       200GB               204800 MB
#   /tmp       200GB+              204800 MB
#   /usr/hdp   100GB               102400 MB 
#   /grid/0   <remaining free space
#
# Actions performed by this script.
#   1. Remote mount xCAT directory to copy storcli64 binary.
#   2. Delete all virtual disks adapter controls.
#   3. Make all drives into JBOD mode.
#   4. Locate drive in slot 0 for OS.
#   5. Generate anaconda partition info to file for OS drive.
#   6. Iterate remaining HDD in slot order for HDFS output anaconda
#      partition configuration.
#
#-------------------------------------------------------------
declare -r PARTF="/tmp/partitionfile"
declare -r BOOTFSTYPE="ext4"
declare -r FSTYPEGRID="ext4"
declare -r FSTYPEOS="ext4"
declare -r PLF1="/tmp/partlist1.txt"
declare -r PLF2="/tmp/partlist2.txt"
declare -r UTILDIR="/tmp/storcli64"

declare -r SWAP_SP_SIZE="--size 12288"
declare -r ROOT_FS_SIZE="--size 102400"
declare -r DEV_FS_SIZE="--size 32768"
# UPDATE:
declare -r BOOT_FS_SIZE="--size 1024"
declare -r OPT_FS_SIZE="--size 10240"
declare -r VAR_FS_SIZE="--size 204800"
declare -r TMP_FS_SIZE="--size 204800"
declare -r USRHDP_FS_SIZE="--size 102400"
declare -r GRID0_FS_SIZE="--size 1 --grow"
declare -r GRID0_FS="/grid/0"
declare -r GRID_FS_PRE="/grid/"

declare -r STORCLI64="${UTILDIR}/storcli64"
declare -r TMPF1="/tmp/sn2slot.txt"
declare -r TMPF2="/tmp/sn2dev.txt"
declare -r SLEEPTIME="15"

# declare -r MKFSOPTIONS="\"-c\""
# declare -r MKFSOPTIONS="\"-E nodiscard\""
declare -r MKFSOPTIONS="\"-E lazy_journal_init=0,nodiscard\""
# declare -r MKFSOPTIONS="\"-E lazy_itable_init=0,lazy_journal_init=0,nodiscard\""
# declare -r MKFSOPTIONS="\"-E lazy_itable_init=0,nodiscard\"" # disable lazy itable initialization, do not depend upon discards to zero data
# declare -r MKFSOPTIONS=""

#-------------------------------------------
function downloadStorcli64()
{
    # Mount /install/custom/storcli64
    XCATMASTER=#XCATVAR:XCATMASTER#
    echo "$XCATMASTER" | grep -sq XCATVAR && XCATMASTER=127.0.0.1

    mkdir -p $UTILDIR
    if [ $CONTEXT = "cobbler" ];  then # if we are running in a cobbler context,
        # COBBLERMASTER is set as an environment variable pointing to the deployer node
        echo "part_Briggs_8jbods: Running in a cobbler context"
        wget -O $STORCLI64 http://$COBBLERMASTER/install/custom/storcli64/storcli64
        chmod +x $STORCLI64 
    else # else, we are running in an xcat context
        echo "part_Briggs_8jbods: Running in an xcat context"
        mount -o nolock $XCATMASTER:/install/custom/storcli64 $UTILDIR
    fi

    echo "Here is the contents of <UTILDIR=${UTILDIR}>:"
    ls -l $UTILDIR
    echo

    return 0
}   # downloadStorcli64()
#-------------------------------------------
function findOSDev()
{
   echo -e "\nSLOT# to SN  mapping  via storcli64:"
   $STORCLI64 /c0/eall/sall show all| \
   awk '/^EID:Slt/{getline;getline;i=index($1,":");SLOT=substr($1,i+1);EIDS=$1;DID=$2;STATE=$3;DG=$4;SIZE=$5;INTF=$7;MED=$8;SED=$9;PI=$10;SESZ=$11;MODEL=$12;SPUN=$13;} \
    /^SN = /{SN=$3;printf("%s,%s,%s,%s\n",SLOT,SN,INTF,MED);}'|grep "HDD"|sort -g | tee $TMPF1

   # Can we use just awk command and exit after first print?
   __OSSN=$( head -n 1 $TMPF1 | awk -F "," '{print $2}' )
   echo "<__OSSN=${__OSSN}>"

   echo -e "\nSN to disk device via smartctl"
   __OSDEV=""
   rm -f $TMPF2 >/dev/null 2>&1
   touch $TMPF2

   local DEVLIST=$( lsblk|grep disk|awk '{printf("/dev/%s\n",$1);}' )
   echo "1111---- DEVLIST=$DEVLIST"

   local SN=""; local DEV=""; local RC=0
   for DEV in $DEVLIST; do

        echo "2222---- DEV=$DEV"
        RESULT=$( smartctl -i $DEV ) 
        echo "3333---- smartctl -i $DEV :"
        echo $RESULT

        # smartctl is on RHEL 7.2+ install media.  Use it to get REAL serial number.
        SN=$( smartctl -i $DEV | awk '/^Serial number:/{print $3;}' )
        
        echo "4444---- SN=$SN"

        # Looks like SATADOM devices have no serial number??
        [[ -z $SN ]] && continue

        # This device has a serial number.
        echo "${SN},${DEV}"|tee -a $TMPF2

        # Check current SN to SN storcli64.  Must iterate through all devices
        #    because temp file is used later to create HDFS mounts.
        [[ "${__OSSN}" == "${SN}" ]] && __OSDEV=$DEV

   done
   echo

   [[ -n $__OSDEV ]] && RC=0 || RC=1

   return $RC
}   # findOSDev()
#-------------------------------------------
function checkHDDs()
{
    # Create and array of all disk infor from storcli64
    local DISKINFO=( $( $STORCLI64 /c0 show | \
    awk 'BEGIN{OK=0;} \
        /^EID:Slt DID State/{getline;getline;OK=1;} \
        /^--/{OK=0} \
        {if (OK == 0) {next;};es=$1;did=$2;stat=$3;intf=$7;med=$8;printf("%s,%s,%s,%s,%s\n",es,did,stat,intf,med);}' ) )

    local ECNT=${#DISKINFO[@]}
    local INFO; local A; local ES; local DID; local STAT; local INTF; local MED
    local EID; local SLOT; local B; local RC=0; local N=0; local I=0
    local ONL=0; local GONL=$ECNT; local NG=0; local GNG=$ECNT

    echo "<ECNT=${ECNT}>"
    while (( I < ECNT)); do

        INFO="${DISKINFO[$I]}"
        A=( $( echo "${INFO}" | awk -F "," '{for (i=1;i<=NF;i++) printf("%s\n",$i);}' ) )
        ES=${A[0]}; DID=${A[1]}; STAT=${A[2]}; INTF=${A[3]}; MED=${A[4]};

        B=( $( echo "${ES}" | awk -F ":" '{for (i=1;i<=NF;i++) printf("%s\n",$i);}'  ) )
        EID=${B[0]}; SLOT=${B[1]}

echo ">>> <INFO=${INFO}> <ES=${ES}> <DID=${DID}> <STAT=${STAT}> <INTF=${INTF}> <MED=${MED}>"
echo ">>> <EID=${EID}> <SLOT=${SLOT}>"

        # Not sure but status is JBOD even if JBOD is set off globably.
        #   There is not error in status so continue checking.
        [[ "${STAT}" == "${JBOD}" ]] && continue
        
        if [[ "${STAT}" == "Offln" ]]; then
            echo "OFF-ONLINE: <INFO=${INFO}>"
echo ">>> ${STORCLI64} /c0/e${EID}/s${SLOT} set online"                
            ${STORCLI64} /c0/e${EID}/s${SLOT} set online; RC=$?
            echo "  ${STORCLI64} RETURN CODE=${RC}"
            (( RC == 0 )) || (( GONL=GOLN+1 ))
            (( ONL=ONL+1 ))
        elif [[ "${STAT}" != "UGood" ]]; then        
            echo "NOT UGOOD: <INFO=${INFO}>"
echo ">>> ${STORCLI64} /c0/e${EID}/s${SLOT} set good force"          
            ${STORCLI64} /c0/e${EID}/s${SLOT} set good force; RC=$?
            echo "  ${STORCLI64} RETURN CODE=${RC}"
            (( RC == 0 )) || (( GNG=GNG-1 ))
            (( NG=NG+1 ))
        fi

        (( N=N+1 ))
        (( I=I+1 ))
    done

    echo "Total drives found: ${N}"
    echo "Off line drives found: ${ONL}  drives now online: ${GONL}"
    echo "Drives not UGood:      ${NG}  drives now UGood:  ${GNG}"

    return 0
}   # checkHDDs()
#-------------------------------------------
function genAnacondaPartInfoOS()
{
    local OSDEV=$1
    
cat > $PARTF  <<EOF
part None --fstype "PPC PReP Boot" --ondisk '$OSDEV' --size 8
bootloader --boot-drive=$OSDEV --driveorder=$OSDEV
clearpart --all --initlabel

part swap       ${SWAP_SP_SIZE}   --ondisk ${OSDEV}
part /var       ${VAR_FS_SIZE}    --ondisk ${OSDEV} --fstype ${FSTYPEOS}   --mkfsoptions ${MKFSOPTIONS}
part /boot      ${BOOT_FS_SIZE}   --ondisk ${OSDEV} --fstype ${BOOTFSTYPE} --mkfsoptions ${MKFSOPTIONS}
part /opt       ${OPT_FS_SIZE}    --ondisk ${OSDEV} --fstype ${FSTYPEOS}   --mkfsoptions ${MKFSOPTIONS}
part /tmp       ${TMP_FS_SIZE}    --ondisk ${OSDEV} --fstype ${FSTYPEOS}   --mkfsoptions ${MKFSOPTIONS}
part /usr/hdp   ${USRHDP_FS_SIZE} --ondisk ${OSDEV} --fstype ${FSTYPEOS}   --mkfsoptions ${MKFSOPTIONS}
part /          ${ROOT_FS_SIZE}   --ondisk ${OSDEV} --fstype ${FSTYPEOS}   --mkfsoptions ${MKFSOPTIONS}
part ${GRID0_FS} ${GRID0_FS_SIZE} --ondisk ${OSDEV} --fstype ${FSTYPEGRID} --mkfsoptions ${MKFSOPTIONS}

# part swap       ${SWAP_SP_SIZE}   --ondisk ${OSDEV}
# part /var       ${VAR_FS_SIZE}    --ondisk ${OSDEV} --fstype ${FSTYPEOS}    
# part /boot      ${BOOT_FS_SIZE}   --ondisk ${OSDEV} --fstype ${BOOTFSTYPE} 
# part /opt       ${OPT_FS_SIZE}    --ondisk ${OSDEV} --fstype ${FSTYPEOS}   
# part /tmp       ${TMP_FS_SIZE}    --ondisk ${OSDEV} --fstype ${FSTYPEOS}   
# part /usr/hdp   ${USRHDP_FS_SIZE} --ondisk ${OSDEV} --fstype ${FSTYPEOS}   
# part /          ${ROOT_FS_SIZE}   --ondisk ${OSDEV} --fstype ${FSTYPEOS}   
# part ${GRID0_FS} ${GRID0_FS_SIZE} --ondisk ${OSDEV} --fstype ${FSTYPEGRID} 
EOF

    return 0
}   # genAnacondaPartInfoOS()
#-------------------------------------------
function genAnacondaPartInfoHDFS()
{

    local SN; local I=1; local DEV=""
    # Recall TMPF1 looks like:
    # 2,ZA12TDZH0000R648BLAB,SAS,HDD
    # 3,ZA12QLBR0000R647VM1F,SAS,HDD

    local NEWSNS=$( awk -F "," '{print $2;}' $TMPF1 )
    for SN in $NEWSNS; do

        # Lookup the Linux device for the SN
        DEV=$( grep "${SN}" $TMPF2 | head -n 1| awk -F "," '{print $2;}'  )
        if [[ -z $DEV ]]; then
            echo "OOPs, <SN=${SN}> not found in file <TMPF2=${TMPF2}>"
            continue
        fi

        # Skip the OS device.
        [[ "${DEV}" == "${__OSDEV}" ]] && continue

        echo "part ${GRID_FS_PRE}${I} --size 1 --grow   --ondisk ${DEV} --fstype ${FSTYPEGRID} --mkfsoptions ${MKFSOPTIONS}" >> $PARTF
#        echo "part ${GRID_FS_PRE}${I} --size 1 --grow   --ondisk ${DEV} --fstype ${FSTYPEGRID}" >> $PARTF
        (( I=I+1 ))

    done

    (( I=I-1 ))
    echo "Created <I=${I}> /hdfs/driveX partitions"

    return 0
}   # genAnacondaPartInfoHDFS()
#-------------------------------------------
function MAIN()
{
    downloadStorcli64

    $STORCLI64 /c0 show

    # Delete all foreign ??
    echo -e "\n>>>Deleting ALL foreign configs"
    $STORCLI64 /c0/fall delete

    # Delete all virtual drives
    echo -e "\n>>>Deleting ALL virtual drives"
    $STORCLI64 /c0/vall del force

    # Turn off JBOD so we can set it back on?
    echo -e "\n>>>Turning off JBOD mode"
    $STORCLI64 /c0 set jbod=off force
    RC=$?
    echo -e "\"$STORCLI64 /c0 set jbod=off force\" ...RC=$RC"

    echo -e "\n>>>Checking HDDs"
    checkHDDs

    echo -e "\n>>>Here is partition config BEFORE setting JBOD on:"
    lsblk|grep disk|awk '{printf("/dev/%s\n",$1);}'| tee $PFL1
    echo -e "\n>>>Another view partition config BEFORE setting JBOD on:"
    lsblk

    # Turn on jbod for ALL drives
    echo -e "\n>>>Turning ON JBOD"
    $STORCLI64 /c0 set jbod=on force
    RC=$?
    echo -e "\"$STORCLI64 /c0 set jbod=on force\" ...RC=$RC"

    # Need to sleep to let Linux kernel discover new drives.
    echo -e "\n>>>Sleeping <SLEEPTIME=${SLEEPTIME}> seconds for kernel to get updates"
    sleep $SLEEPTIME

    echo -e "\n>>>Here is partition figureation AFTER setting JBOD on:"
    lsblk|grep disk|awk '{printf("/dev/%s\n",$1);}' | tee $PFL2
    echo -e "\n>>>Another view partition config AFTER setting JBOD on:"
    lsblk

    for i in {1..20}
    do  
      echo "----------------------"
      echo "Looking for OS Drive.  Pass $i :"
      findOSDev; RC=$?
      if (( RC == 0 )); then
        echo "Found the OS Drive... continuing..."
        break
      fi
    done

    if (( RC != 0 )); then
        echo -e "\n>>>Unable to locate disk for OS installation <__OSSN=${__OSSN}>.  Aborting script."
        exit 100
    fi
    echo -e "\n>>>Here is the device to use for OS install <__OSDEV=${__OSDEV}>"

    rm -f $PARTF
    genAnacondaPartInfoOS   "${__OSDEV}"
    genAnacondaPartInfoHDFS

    echo -e "\n>>>Contents of <PARTF=${PARTF}>:"
    cat $PARTF

    return 0
}   # MAIN()
#-------------------------------------------
#-------------------------------------------
#-------------------------------------------

__THIS_SCRIPT=${0##*/}
echo -e "\n>>>Staring script: ${__THIS_SCRIPT}"

MAIN
echo -e "\n>>>Completed script: ${__THIS_SCRIPT}\n"

exit 0


