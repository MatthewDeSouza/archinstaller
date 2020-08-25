#!/bin/bash
# MIT LICENSE
# Have fun using arch!
source ./functions.sh

echo 'Arch install script'
echo 'Make sure to clear the device desired for the arch install.'
echo 'By Matthew DeSouza -- mdesouza01@manhattan.edu'

update_mirrors
device_prep
set_partition_sizes
confirm_format
partition
format_partitions $DEVICE
mount_partitions $DEVICE

## Find which Kernel version is desired
PS3='Which Linux kernel version would you like to install?\n'
options=("linux" "linux-hardened" "linux-lts" "linux-zen")
select KERNELVER in "${options[@]}"
do
    case $KERNELVER in
        "linux") KERNELVER=0 ;;
        "linux-hardened") KERNELVER=1    ;;
        "linux-lts") KERNELVER=2 ;;
        "linux-zen") KERNELVER=3 ;;
        *) echo "Invalid input, assuming option 0" && KERNELVER=0   ;;
    esac
done

install_essentials $KERNELVER
generate_fstab
change_root
set_time_zone $TIME_ZONE
set_locale
set_keymap $KEYMAP
set_hostname $HOSTNAME
read -p "Enter the root password: " ROOT_PASSWD
set_root_password $ROOT_PASSWD

PS3='Would you like to use the same password for root and wheel account? '
options=("yes" "no")
select USE_SAME_PASSWD in "${options[@]}"
do
    case $USE_SAME_PASSWD in
        "no") read -p "Enter the user password: " ROOT_PASSWD ;;
        "yes") break    ;;
        *) echo "Invalid input, assuming no" && read -p "Enter the user password: " ROOT_PASSWD    ;;
    esac
done

set_user_password $USER_NAME $ROOT_PASSWD
install_bootloader $DEVICE
install_yay

## Choose graphics driver
PS3='Which processor do you use? Enter 3 to skip '
options=("INTEL" "AMD")
select $PROCESSOR in "${options[@]}"
do
    case $PROCESSOR in
        "INTEL") PROCESSOR=0    ;;
        "AMD") PROCESSOR=1  ;;
        *) PROCESSOR=2  ;;
    esac
done

PS3='Which graphics driver would you like to use? '
options=("NVIDIA -- Proprietary" "NVIDIA -- Legacy" "NVIDIA -- Open Source" "AMD -- AMDGPU" "AMD -- ATI" "Intel")
select $GFXDRV in "${options[@]}"
do
    case $GFXDRV in
        "NVIDIA -- Proprietary")    GFXDRV=0    ;;
        "NVIDIA -- Legacy")         GFXDRV=1    ;;
        "NVIDIA -- Open Source")    GFXDRV=2    ;;
        "AMD -- AMDGPU")            GFXDRV=3    ;;
        "AMD -- ATI")               GFXDRV=4    ;;
        "Intel")                    GFXDRV=5    ;;
    esac
done

install_packages $PROCESSOR $GFXDRV

setup_dotfiles