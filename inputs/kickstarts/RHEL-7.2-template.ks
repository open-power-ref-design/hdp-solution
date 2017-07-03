# ===============================================================================================================================
# kickstart file for RHEL 7.2+
# ===============================================================================================================================
# ===============================================================================================================================
# options
# ===============================================================================================================================
# 2017-05-05 - Initial input - woodbury
# cmdline

# set the language
# lang en_US
lang en_US.UTF-8

# network --onboot=yes --bootproto=dhcp --device=0c:c4:7a:87:01:78

# include the url statement, generated in %pre
# %include /tmp/repos # note: cannot use this method; it may be incompatible with the dd.iso and patched kernel
url --url=http://$http_server/$distro/

# device ethernet e100
# keyboard "us"
keyboard --vckeymap=us --xlayouts='us'

# clear the MBR
zerombr

# clear any existing partitioning
clearpart --all --initlabel
# clearpart --linux

# include partitioning scheme via file, generated in %pre section
# ...includes the bootloader statement as the partitioning script detects the proper boot disk to use
# ...this ignores the disk indicated in the config.yml
# example:
#   part None --fstype "PPC PReP Boot" --ondisk /dev/sdc --size 8
#   bootloader --boot-drive=/dev/sdc --driveorder=/dev/sdc
#   clearpart --all --initlabel
#   part swap       --size 12288   --ondisk /dev/sdc
#   part /          --size 1 --grow   --ondisk /dev/sdc --fstype ext4
#   part /boot      --size 1008   --ondisk /dev/sdc --fstype ext4
#   part /var       --size 409600    --ondisk /dev/sdc --fstype ext4
#   part /tmp       --size 409600    --ondisk /dev/sdc --fstype ext4
%include /tmp/partitionfile

# set the bootloader config
# --append <args>
# --useLilo
# --md5pass <crypted MD5 password for GRUB>
#
# The bootloader config is included in the partitionfile above which is generated by the %pre section scripts
# bootloader...

# do an install (vs. upgrade)
install

# do text mode install (default is graphical)
text

# disable firewall
firewall --disabled

# set the timezone
# add the --utc switch since the hardware clock is set to GMT
timezone --utc "America/Chicago"

# do not configure X
skipx

# set the root password
rootpw --plaintext passw0rd

# create additional users
user --name=user --groups=wheel $SNIPPET('password')

#
# NIS setup: auth --enablenis --nisdomain sensenet
# --nisserver neptune --useshadow --enablemd5
#
# OR
auth --useshadow --enablemd5

# disable SE Linux
selinux --disabled

# reboot after installation
reboot


# ===============================================================================================================================
# packages
# ===============================================================================================================================
%packages
# ensure there is a space between @ and group name
@core
bridge-utils
vim
wget
ftp
ntp
nfs-utils
net-snmp
rsync
yp-tools
openssh-server
util-linux
net-tools
#KWR: added the following
bind-utils
java-1.8.0-openjdk
java-1.8.0-openjdk-devel
java-1.8.0-openjdk-headless
%end


# ===============================================================================================================================
# pre
# ===============================================================================================================================
%pre
#raw
{
echo "============================================================="
echo "Begin Kickstart PRE-Installation Script..."
echo "============================================================="

# log the date, e.g. 2017-05-25 11:54:34 CDT
echo $(date +%F" "%T" "%Z)" (start time)"

shopt -s nullglob

# -------------------------------------------------------------------------------------------------------------------------------
# load and run the partitioning script
# -------------------------------------------------------------------------------------------------------------------------------
# rm -rf /tmp/partitionfile
# python -c 'import base64; print base64.b64decode(open("/tmp/partscript.enc","rb").read())' >/tmp/partscript
# chmod 755 /tmp/partscript
# /tmp/partscript

# cobbler form
rm -rf /tmp/partitionfile
#end raw

# point to the deployer node - used within the partitioning script
export COBBLERMASTER=$http_server
# indicate cobbler as the provisioning utility on the provisioning server - used within the partitioning script
export CONTEXT="cobbler"

# NOTE: The following code is very fragile -- determining node_type from the system_name.  Rework to use a better method.
part_script_remote=""
node_type=`echo "$system_name" | cut -b 1-2`
cobbler_http_server="$http_server"
echo "kickstart.%pre: system_name=\"$system_name\""
echo "kickstart.%pre: node_type=\"$node_type\""
echo "kickstart.%pre: cobbler_http_server=\"$cobbler_http_server\""

system_name_saved="$system_name"

#raw
# use the system name to infer the node role...
if [ $node_type = "mn" ]; then
    part_script_remote="part_Stratton_raid10.sh"
elif [ $node_type = "en" ]; then
    part_script_remote="part_Stratton_raid10.sh"
elif [ $node_type = "wn" ]; then
#    part_script_remote="part_Briggs_8jbods.sh"
    part_script_remote="part_Briggs_storcli64_allraid0.sh"
else
    echo "kickstart.%pre: ERROR in kickstart file.  Unrecognized node_type \"$node_type\""
fi

echo "kickstart.%pre: part_script_remote=\"$part_script_remote\""

# retrieve the partion script from the provisioning server
# wget -O /tmp/partscript http://$http_server/install/custom/partition/part_Stratton_raid10.sh
wget -O /tmp/partscript http://$cobbler_http_server/install/custom/partition/$part_script_remote

# run the partitioning script
chmod 755 /tmp/partscript
/tmp/partscript

# -------------------------------------------------------------------------------------------------------------------------------
# save the content of /tmp/partitionfile
# -------------------------------------------------------------------------------------------------------------------------------
#save the content of /tmp/partitionfile in /var/log/xcat/xcat.log
#so that we can inspect the partition scheme after installation
echo "=================The Partition Scheme================"
cat /tmp/partitionfile
echo "====================================================="

echo "============================================================="
echo "End Kickstart Pre-Installation Script..."
echo "============================================================="

} >>/tmp/pre-install.log 2>&1

#end raw
%end


# ===============================================================================================================================
# post
# ===============================================================================================================================
%post
{
echo "============================================================="
echo "Begin Kickstart POST-Installation Script..."
echo "============================================================="

date
echo $0

# Add yum sources
# Add ssh keys to root
mkdir /root/.ssh
chmod 700 /root/.ssh
wget http://$http_server/authorized_keys -O /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
# Add ssh keys to user
mkdir /home/user/.ssh
chown user:user /home/user/.ssh
chmod 700 /home/user/.ssh
wget http://$http_server/authorized_keys -O /home/user/.ssh/authorized_keys
chown user:user /home/user/.ssh/authorized_keys
chmod 600 /home/user/.ssh/authorized_keys
# Enable passwordless sudo for user
echo -e "user\tALL=NOPASSWD: ALL" > /etc/sudoers.d/user
echo -e "[$distro]" > /etc/yum.repos.d/$(distro).repo
echo -e "name=$distro" >> /etc/yum.repos.d/$(distro).repo
echo -e "baseurl=http://$http_server/$distro/" >> /etc/yum.repos.d/$(distro).repo
echo -e "enabled=1" >> /etc/yum.repos.d/$(distro).repo
echo -e "gpgcheck=0" >> /etc/yum.repos.d/$(distro).repo
$SNIPPET('kickstart_done')

echo "============================================================="
echo "End Kickstart POST-Installation Script..."
echo "============================================================="

system_name_saved="$system_name"

} >>/tmp/post-install.log 2>&1

%end
