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
# This is an xCAT partition script for Straton servers.  This output from
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
#   1. Server access HDD/SDD drives va MegaRaid adapter.
#   2. All HDDs will be put into RAID10 parition.
#   3. At least 3 HDDs are available
#
#  This is the drive slot numbering the storcli64 program uses.
#  SSDs and HDDs can be in any slot. HDDs can be SATA or 
#  SAS (preferred for HDP).
#
#       +-----------------------+
#       |  0  |  1  |  2  |  3  |
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
#
#   1. Create a RAID10 group using slots 0 and up to at MOST 4 driveso to install the OS.
#   2. Begin by removing any existing virtual disks which
#   3. use the disks in slots 0 thru 3
#   4. Use slots 0 thru 3 to create a RAID10 group IF at least 4 drives are avaiable.
#   5. Create a RAID0 disk on disk 0 IF less than 4 drives are available.
#   5. Use newly-created drive for the OS installation.
#-------------------------------------------------------------
declare -r PARTF="/tmp/partitionfile"
declare -r BOOTFSTYPE="ext4"
declare -r FSTYPEOS="ext4"
declare -r SWAP_SP_SIZE="--size 12288"          #  12GB
declare -r ROOT_FS_SIZE="--size 1 --grow"       # Remaining free space
declare -r BOOT_FS_SIZE="--size 1008"           #   1GB
declare -r VAR_FS_SIZE="--size 409600"          # 400GB
declare -r TMP_FS_SIZE="--size 409600"          # 400GB

# Mount /install/custom/storcli64
XCATMASTER=#XCATVAR:XCATMASTER#
echo "#############################################################"
env|sort
echo "#############################################################"
# XCATMASTER=172.19.88.20
echo "$XCATMASTER" | grep -sq XCATVAR && XCATMASTER=127.0.0.1

mkdir -p /tmp/storcli64
if [ $CONTEXT = "cobbler" ];  then # if we are running in a cobbler context,
    # COBBLERMASTER is set as an environment variable pointing to the deployer node
    echo "part_Stratton_raid10: Running in a cobbler context"
    wget -O /tmp/storcli64/storcli64 http://$COBBLERMASTER/install/custom/storcli64/storcli64
    chmod +x /tmp/storcli64/storcli64
else # else, we are running in an xcat context
    echo "part_Stratton_raid10: Running in an xcat context"
    mount -o nolock $XCATMASTER:/install/custom/storcli64 /tmp/storcli64
fi

STORCLI64="/tmp/storcli64/storcli64"
/tmp/storcli64/storcli64 /c0 show


# Create a RAID10 virtual drive using the disks on slots 0 thru 3
# Assume there is only 1 controller (0) and 1 enclosure.
# First, we need to discover the enclosure ID.
#
# [root@st02 ~]# ./storcli64 /c0/eall show 
# Controller = 0
# Status = Success
# Description = None
# 
# 
# Properties :
# ==========
# 
# -----------------------------------------------------------------------
# EID State Slots PD PS Fans TSs Alms SIM Port#    ProdID VendorSpecific 
# -----------------------------------------------------------------------
# 252 OK        8  4  0    0   0    0   1 Internal SGPIO                 
# -----------------------------------------------------------------------
# 
# EID-Enclosure Device ID |PD-Physical drive count |PS-Power Supply count|
# TSs-Temperature sensor count |Alms-Alarm count |SIM-SIM Count 

eid=$(/tmp/storcli64/storcli64 /c0/eall show | grep -A 2 "^EID " | tail -1 | awk '{print $1}')

PDC=$( $STORCLI64 /c0/eall show|awk '/EID State/{getline;getline;print $4;}' )
MAXSLOT=$(( PDC - 1 ))
echo "Delete existing virtual disks using slots 0 thru $MAXSLOT"

GNT=0
for slot in $( seq 0 $MAXSLOT ); do
    dg=$(/tmp/storcli64/storcli64 /c0/e${eid}/s${slot} show all | grep "DriveGroup:" | cut -f2 -d':' | cut -f1 -d',')
    if [[ -z "$dg" ]]
    then
        echo "The drive in slot ${slot} does not belong to any drive group"
        virtual_drives=0
    else
        echo "The drive in slot ${slot} belongs to drive group ${dg}"
        virtual_drives=$(/tmp/storcli64/storcli64 /c0/d${dg} show all | grep "Total VD Count" | awk -F '=' '{print substr($2,2)}')
        echo "Drive group ${dg} currently has ${virtual_drives} virtual drives"
    fi

    if [[ "${virtual_drives}" -gt 0 ]]
    then

        let grepcnt=virtual_drives+1
        for vd in $(/tmp/storcli64/storcli64 /c0/d${dg} show all | grep -A $grepcnt "DG/VD" | tail -$((grepcnt-1)) | cut -f1 -d ' ' | cut -f2 -d'/')
        do
            echo "Delete virtual drive ${vd}"
            /tmp/storcli64/storcli64 /c0/v${vd} del force
        done
    fi

    # Check the state of each drive. If the state is
    # not "UGood", then set the state to good.
    good=$(/tmp/storcli64/storcli64 /c0/e${eid}/s${slot} show | grep "${eid}:${slot}.*UGood")
    if [[ -z "${good}" ]]
    then
        echo "Set disk on slot ${slot} state to good"
        /tmp/storcli64/storcli64 /c0/e${eid}/s${slot} set good force || \
        { echo "Could not set slot ${slot} to good"; exit 1; }
	(( GCNT++ ))
    else
        echo "Disk state on slot ${slot} is already UGood"
	(( GCNT++ ))
    fi

done  # End for each slot

# Create the RAID10 virtual disk on slots 0 and up to at most 3 of the discovered enclosure.
# Exit if this operation fails.
# Note that there may be a timing condition where the controller has
# created the RAID10 group, but the OS has not yet added it. Record here
# the number of scsi block devices known to the system prior to creating
# the RAID10.
#
# KWR: The following command will only return the number of SATADOM drives.
#      Not going to use this command.  Use GCNT which is count of GOOD drives found.
#       drivecnt=`lsblk --scsi | grep -v "^NAME" | wc -l`
echo "There are currently ${GCNT} drives"

(( GCNT == 0 )) && \
    { echo ">>>ERROR: No drives found. Can't do an install with no drives."; exit 1; }
(( GCNT < 4 )) && \
    { echo ">>>WARNING: Only found $GNT drives.  RAID10 needs at least 4 drives. Defaulting to single drive with RAID0."; GCNT=1; }
    
if (( GCNT  == 1 )); then
    # There is only one drive.  Wonder if raid0 works?
    echo ">>> /tmp/storcli64/storcli64 /c0 add vd raid0 drives=${eid}:0"
    /tmp/storcli64/storcli64 /c0 add vd raid0 drives=${eid}:0 || \
    { echo ">>>ERROR: Could not create a RAID10 array"; exit 2; }
else
    lastdrive=$(( GCNT - 1 ))
    (( lastdrive > 4 )) && lastdrive=3
    echo "Creating RAID10 array on slots 0 to ${lastdrive}"
    echo ">>> /tmp/storcli64/storcli64 /c0 add vd raid10 drives=${eid}:0-$lastdrive pdperarray=2"
    /tmp/storcli64/storcli64 /c0 add vd raid10 drives=${eid}:0-$lastdrive pdperarray=2|| \
    { echo ">>>ERROR: Could not create a RAID10 array"; exit 3; }
fi

# Find the identifier for this new virtual drive in order to match
# it to the drive the OS sees. First, find the drive group and
# virtual drive number of the newly-created drive
#
# The "SCSI NAA Id" line looks like this:
#
# SCSI NAA Id = 600605b00ba736c0ff003df1b15a109d
dg=$(/tmp/storcli64/storcli64 /c0/e${eid}/s0 show all | grep "DriveGroup:" | cut -f2 -d':' | cut -f1 -d',')
vd=$(/tmp/storcli64/storcli64 /c0/d${dg} show all | grep -A 2 "DG/VD" | tail -1 | cut -f1 -d ' ' | cut -f2 -d'/')
echo "The new virtual disk has ID ${vd} in drive group ${dg}"
scsi_id=$(/tmp/storcli64/storcli64 /c0/v${vd} show all | grep "SCSI NAA Id" | awk -F '=' '{print substr($2,2)}')


# Scan the drives known to the OS
# Make sure the new drive has been added
newdrivecnt=$(lsblk --scsi | grep -v "^NAME" | wc -l)
while [[ "$newdrivecnt" -eq "$drivecnt" ]]
do
    sleep 1
    newdrivecnt=$(lsblk --scsi | grep -v "^NAME" | wc -l)
done
echo "There are now ${newdrivecnt} drives"

echo "Sleeping for 10 seconds.  udev needs to do something."
sleep 10

for disk in $(lsblk|grep disk|awk '{print $1}')
do
    vdisk=$(udevadm info --query=property --path=/sys/class/block/"$disk" | grep "ID_SERIAL_SHORT=${scsi_id}")
    if [[ ! -z "$vdisk" ]]
    then
        echo "Use disk /dev/$disk for the installation"
        instdisk="/dev/$disk"
        break
    fi
done

if [[ -z "$instdisk" ]]
then
    echo "Could not find disk for OS installation."
    exit 1
fi

    #modprobe ext4 >& /dev/null
    #modprobe ext4dev >& /dev/null
    #if grep ext4dev /proc/filesystems > /dev/null; then
        #FSTYPE=ext3
    #elif grep ext4 /proc/filesystems > /dev/null; then
        #FSTYPE=ext4
    #else
        #FSTYPE=ext3
    #fi
    #BOOTFSTYPE=ext3
    #EFIFSTYPE=vfat
    #if uname -r|grep ^3.*el7 > /dev/null; then
        #FSTYPE=xfs
        #BOOTFSTYPE=xfs
        #EFIFSTYPE=efi
    #fi
    
    #if [ `uname -m` = "ppc64" -o `uname -m` = "ppc64le" ]; then
        #echo 'part None --fstype "PPC PReP Boot" --ondisk '$instdisk' --size 8' >> /tmp/partitionfile
    #fi
    #if [ -d /sys/firmware/efi ]; then
        #echo 'bootloader --driveorder='$instdisk >> /tmp/partitionfile
        #echo 'part /boot/efi --size 50 --ondisk '$instdisk' --fstype $EFIFSTYPE' >> /tmp/partitionfile
    #else
        #echo "bootloader --boot-drive=$instdisk --driveorder=$instdisk" >> /tmp/partitionfile
    #fi
    
    #echo "clearpart --all --initlabel" >> /tmp/partitionfile
    #echo "part swap  --size 12288 --ondisk $instdisk" >> /tmp/partitionfile
    #echo "part /boot --size 1024  --ondisk $instdisk --fstype $BOOTFSTYPE " >> /tmp/partitionfile
    #echo "part /var  --size 204800  --ondisk $instdisk --fstype $FSTYPE" >> /tmp/partitionfile
    #echo "part /     --size 1 --grow --ondisk $instdisk --fstype $FSTYPE" >> /tmp/partitionfile

cat > $PARTF  <<EOF
part None --fstype "PPC PReP Boot" --ondisk ${instdisk} --size 8
bootloader --boot-drive=${instdisk} --driveorder=${instdisk}
clearpart --all --initlabel
part swap       ${SWAP_SP_SIZE}   --ondisk ${instdisk}
part /          ${ROOT_FS_SIZE}   --ondisk ${instdisk} --fstype ${FSTYPEOS}
part /boot      ${BOOT_FS_SIZE}   --ondisk ${instdisk} --fstype ${BOOTFSTYPE}
part /var       ${VAR_FS_SIZE}    --ondisk ${instdisk} --fstype ${FSTYPEOS}
part /tmp       ${TMP_FS_SIZE}    --ondisk ${instdisk} --fstype ${FSTYPEOS}
EOF

exit 0
