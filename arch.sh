#!/bin/bash
# MIT LICENSE
# Have fun using arch!
# Default FS: btrfs
# Default locale: en_US.UTF-8 UTF-8
# Default partitioning scheme: GPT

setup_pre() {
    printf "\n\nArch install script\n\n"
    printf "Make sure to clear the device desired for the arch install.\n\n"
    printf "PARTITION SIGNATURES WILL BE REMOVED FROM INPUTTED DEVICE\n"
    update_mirrors
    device_prep
    set_partition_sizes
    confirm
    partition
    format_partitions
    mount_partitions
    select_kernel
    install_essential
    generate_fstab
    copy_post_install
    change_root
}

confirm() {
	read -r -n 1 -p "Is this correct? [y/N]" START
	case $START in
		[yY]) printf "\nContinuing script\n" && break ;;
		*)    printf "\nQuitting script\n"   && exit  ;;
	esac
}

device_prep() {
    # Check if time is correct
    timedatectl set-ntp true

    # Set variables
    read -p "Enter device: "                                       DEVICE
    printf "\n"

    read -p "Enter hostname: "                                     HOSTNAME
    printf "\n"

    read -p "Enter keymap: "                                       KEYMAP
    printf "\n"

    read -p "Enter user account name: "                            USER_NAME
    printf "\n"

    read -p "Enter your timezone in this format -- COUNTRY/AREA: " TIMEZONE
    printf "\n"

    printf "Device: $DEVICE\n\nHostname: $HOSTNAME\n\nKeymap: $KEYMAP\n\nUsername: $USER_NAME\n\nTimezone: $TIMEZONE\n\n"

    printf "Begin creating partitons for $DEVICE\n\n"
}

update_mirrors() {
    printf "\n"
    pacman -Syu --noconfirm
    printf "\n"
}

set_partition_sizes() {
	read -p "Enter size of EFI partition: "                             EFI_SIZE

	read -p "Enter size of root partition: "                            ROOT_SIZE

	read -p "Enter size of linux swap: "                                SWAP_SIZE

	read -p "Enter size of home partition (leave blank to fill rest): " HOME_SIZE

    printf "EFI size:  $EFI_SIZE\nRoot size: $ROOT_SIZE\nSwap size: $SWAP_SIZE\nHome size: $HOME_SIZE\n"

    [ -z "$HOME_SIZE" ] || HOME_SIZE="+${HOME_SIZE}" # Adds plus to $HOME_SIZE if not empty
}

partition() {
    wipefs --all --force $DEVICE
    (
    	printf "g\n"				# Creates a new empty GPT partiton table\

        printf "n\n"				# Create a new partition
        printf "1\n"				# Partition number
        printf "\n"				    # Default sector: from set_partiton_sizes
        printf "+${EFI_SIZE}\n"		# Last sector
        printf "t\n"				# Change type
        printf "1\n"				# EFI

        ## root
        printf "n\n"				# Create a new partiton
        printf "2\n"				# Partiton number
        printf "\n"					# Default sector
        printf "+${ROOT_SIZE}\n"	# Last sector: from set_partiton_sizes
        printf "t\n"				# Change type
	    printf "2\n"				# Partition number
        printf "24\n"				# Linux root (x86_64)

        ## swap
        printf "n\n"				# Create a new partition
        printf "3\n"				# Partition number
        printf "\n"				    # Default sector
        printf "+${SWAP_SIZE}\n"	# Last sector: from set_partiton_sizes
        printf "t\n"				# Change type
	    printf "3\n"				# Partition number
        printf "19\n"				# Linux swap

        ## home
        printf "n\n"				# Create a new partiton
        printf "4\n"				# Partition number
        printf "\n"				    # Default sector
        printf "${HOME_SIZE}\n"		# Last sector: from set_partiton_sizes
        printf "t\n"				# Change type
	    printf "4\n"				# Partition number
        printf "28\n"				# Linux home

	    printf "w\n"				# Write changes

    ) | fdisk $DEVICE
}

format_partitions() {
    # Formatting first partition
    mkfs.fat -F 32 ${DEVICE}1
    sleep 2

    # Formatting second partition
    mkfs.btrfs -L root ${DEVICE}2
    sleep 2

    # Formatting third partition
    mkswap ${DEVICE}3
    swaplabel ${DEVICE}3 swap
    sleep 2

    # Formatting fourth partition
    mkfs.btrfs -L home ${DEVICE}4
    sleep 2
}

mount_partitions() {
    # Mounting root partition
    mount ${DEVICE}2 /mnt       && echo "Root partition mounted successfully!"
    printf "\n\n"
    sleep 1.5

    # Mounting EFI partition
    mkdir /mnt/boot
    mount ${DEVICE}1 /mnt/boot  && echo "Boot partition mounted successfully!"
    printf "\n\n"
    sleep 1.5

    # Mounting swap partition
    swapon ${DEVICE}3           && echo "Swap mounted successfully!"
    printf "\n\n"
    sleep 1.5

    # Mounting home partition
    mkdir /mnt/home
    mount ${DEVICE}4 /mnt/home  && echo "Home partition mounted successfully!"
    printf "\n\n"
    sleep 1.5
}

select_kernel() {
    PS3='Linux kernel version: '
    options=("linux" "linux-hardened" "linux-lts" "linux-zen")
    select KERNELVER in "${options[@]}"
    do
        case $KERNELVER in
            "linux")          KERNELVER=${options[0]}   &&  break   ;;
            "linux-hardened") KERNELVER=${options[1]}   &&  break   ;;
            "linux-lts")      KERNELVER=${options[2]}   &&  break   ;;
            "linux-zen")      KERNELVER=${options[3]}   &&  break   ;;
        esac
    done
}

install_essential() {
    pacstrap /mnt base base-devel ${KERNELVER} linux-firmware
}

generate_fstab() {
    # fstab is defined though UUID in this script
    genfstab -U /mnt >> /mnt/etc/fstab
}

copy_post_install() {
    cp postinstall.sh /mnt/root/postinstall.sh
    printf "#!/bin/bash\nTIME_ZONE='{$TIME_ZONE}'\nKEYMAP='${KEYMAP}'\nHOSTNAME='${KEYMAP}'\nDEVICE='${DEVICE}'\n" | cat - /mnt/root/postinstall.sh > /mnt/root/temp && mv /mnt/root/temp /mnt/root/postinstall.sh
}

change_root() {
    chmod 755 /mnt/root/postinstall.sh
    arch-chroot /mnt /root/postinstall.sh
}

setup_pre