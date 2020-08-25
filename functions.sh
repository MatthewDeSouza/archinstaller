#!/bin/bash

confirm_format() {
	read -r -n 1 -p "Is this correct? [y/N]" START_FORMAT
	case $START_FORMAT in
		[yY]) printf "\nContinuing script\n" ; break ;;
		*) printf "\nQuitting script\n" && exit ;;
	esac
}

device_prep() {
# Setting up device -- User Specific
read -p "Enter device: " DEVICE
printf "\n"

read -p "Enter hostname: " HOSTNAME
printf "\n"

read -p "Enter keymap: " KEYMAP
printf "\n"

read -p "Enter user account name: " USER_NAME
printf "\n"

read -p "Enter your timezone in this format -- COUNTRY/AREA: " TIMEZONE
printf "\n"

read -p "Enter name of wireless device: " WIRELESS_DEVICE
printf "\n"

printf "Device: $DEVICE\n\nHostname: $HOSTNAME\n\nKeymap: $KEYMAP\n\nUsername: $USER_NAME\n\nTimezone: $TIMEZONE\nInterent Device: $WIRELESS_DEVICE\n"

printf "Begin creating partitons for $DEVICE\n"
}

# Setting up device -- Declared by script writer/editor
update_mirrors() {
    pacman -Syy --noconfirm
}

set_partition_sizes() {
	read -p "Enter size of EFI partition: " EFI_SIZE

	read -p "Enter size of root partition: " ROOT_SIZE

	read -p "Enter size of linux swap: " SWAP_SIZE

	read -p "Enter size of home partition (leave blank to fill rest)" HOME_SIZE_CHECK

    printf "EFI size: $EFI_SIZE\nRoot size: $ROOT_SIZE\nSwap size: $SWAP_SIZE\nHome size: $HOME_SIZE\n"

    [ -z "$HOME_SIZE" ] || HOME_SIZE="+${HOME_SIZE}"
}

partition() {
    (
    	printf "g\n"				# Creates a new empty GPT partiton table
        printf "n\n"				# Create a new partition
        #printf "p\n"				# Type - primary
        printf "1\n"				# Partition number
        printf "\n"				# Default sector: from set_partiton_sizes
        printf "+${EFI_SIZE}\n"			# Last sector
        printf "t\n"				# Change type
        printf "1\n"				# EFI

        ## root
        printf "n\n"				# Create a new partiton
        #printf "p\n"				# Type - primary
        printf "2\n"				# Partiton number
        printf "\n"					# Default sector
        printf "+${ROOT_SIZE}\n"		# Last sector: from set_partiton_sizes
        printf "t\n"				# Change type
	printf "2\n"				# Partition number
        printf "24\n"				# Linux root (x86_64)

        ## swap
        printf "n\n"				# Create a new partition
        #printf "p\n"				# Type - primary
        printf "3\n"				# Partition number
        printf "\n"				# Default sector
        printf "+${SWAP_SIZE}\n"		# Last sector: from set_partiton_sizes
        printf "t\n"				# Change type
	printf "3\n"				# Partition number
        printf "19\n"				# Linux swap

        ## home
        printf "n\n"				# Create a new partiton
        #printf "p\n"				# Type - primary
        printf "4\n"				# Partition number
        printf "\n"				# Default sector
        printf "${HOME_SIZE}\n"			# Last sector: from set_partiton_sizes
        printf "t\n"				# Change type
	printf "4\n"				# Partition number
        printf "28\n"				# Linux home

	printf "w\n"				# Write changes

    ) | fdisk $DEVICE
}

format_partitions() {
    local dev=$1

    # Formatting first partition
    mkfs.fat -F 32 ${dev}1

    # Formatting second partition
    mkfs.btrfs -L root ${dev}2

    # Formatting third partition
    mkswap ${dev}3
    swaplabel ${dev}3 swap

    # Formatting fourth partition
    mkfs.btrfs -L home ${dev}4
}

mount_partitions() {
    local dev=$1

    # Mounting root partition
    mount ${dev}2 /mnt && echo "Root partition mounted successfully!"
    printf "\n\n"

    # Mounting EFI partition
    mkdir /mnt/boot
    mount ${dev}1 /mnt/boot && echo "Boot partition mounted successfully!"
    printf "\n\n"

    # Mounting swap partition
    swapon ${dev}3 && echo "Swap mounted successfully!"
    printf "\n\n"

    # Mounting home partition
    mkdir /mnt/home
    mount ${dev}4 /mnt/home && echo "Home partition mounted successfully!"
    printf "\n\n"
}

install_essential() {
    # Argument passes KERNELVER (0-3)
    case $1 in
        0) local linuxkern="linux"    ;;
        1) local linuxkern="linux-hardened"   ;;
        2) local linuxkern="linux-lts"    ;;
        3) local linuxkern="linux-zen"    ;;
    esac
    pacstrap /mnt base base-devel ${linuxkern} linux-firmware
}

generate_fstab() {
    # fstab is defined though UUID in this script
    genfstab -U /mnt >> /mnt/etc/fstab
}

change_root() {
    arch-chroot /mnt
}

set_time_zone() {
    ## Argument passed into command is TIME_ZONE

    # Generate /etc/localtime
    ln -sf /usr/share/zoneinfo/${1} /etc/localtime

    # Generate /etc/adjtime
    hwclock --systohc
}

set_locale() {
    # Hardcoded for English
    echo 'LANG="en_US.UTF-8"' >> /etc/locale.conf
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
}

set_keymap() {
    # Passed argument is KEYMAP
    echo "KEYMAP=${1}" > /etc/vconsole.conf
}

set_hostname() {
    # Passed argument is HOSTNAME
    echo ${1} > /etc/hostname
    cat > /etc/hosts <<EOF
127.0.0.1   localhost.localdomain localhost ${1}
::1         localhost.localdomain localhost ${1}
EOF
}

set_root_password() {
    # fist argument is ROOT_PASSWD
    echo 'root:${1}' | chpasswd
}

set_user_password() {
    # first argument is username
    # second argument is conditioinal
    useradd -m -G wheel -S /usr/bin/zsh ${1}
    echo '${1}:${2}' | chpasswd
}

install_bootloader() {
    # first argument is device
    pacman -Sy --noconfirm grub efibootmgr

    # Installing GRUB to /boot
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

    # Uncomment below if you are dual-booting an existing copy of Windows
    #pacman -Sy --noconfirm os-prober && os-prober
}

install_yay() {
    pacman -Sy --noconfirm git go

    mkdir /hello
    cd /hello

    git clone https://aur.archlinux.org/yay.git && cd
    makepkg -si --noconfirm --asroot

    cd /
    rm -rf /hello # Goodbye :/
}

install_packages() {
    ### This is my personal package list. There is some customization during the script, but it is recommended you
    ### go through each section yourself to better fit your needs.
    ## Argument 1       PROCESSOR   (0-1)
    ## Argument 2       GFXDRV      (0-5)

    # Essential packages.
    local PACKAGE="arch-install-scripts bind-tools broadcom-wl btrfs-progs dchpcd dialog diffutils dosfstools ethtool exfat-utils gpm gptfdisk hdparm logrogate lvm2 mtools nano netctl nfs-utils ntfs-3g ntp openvpn openssh parted rsync sudo tcpdump usb_modeswitch usbutils wget wireless-regdb wireless_tools wpa_supplicant "

    # Intel or AMD microcode
    case $1 in
        0) PACKAGE+="intel-ucode "  ;;  ## 0) Intel
        1) PACKAGE+="amd-ucode" ;;      ## 1) AMD
        *) break    ;;
    esac

    # Xorg
    PACKAGE+="xorg-server xorg-init "

    # Video
    PACKAGE+="xf86-input-evdev xf86-input-libinput xf86-input-void "

    # Video hardware driver
    case $2 in
        0) PACKAGE+="nvidia nvidia-settings nvidia-utils "  ;;  ## 0) NVIDIA -- Proprietary
        1) PACKAGE+="nvidia-390xx nvidia-390xx-utils "  ;;      ## 1) NVIDIA -- Legacy (AUR)
        2) PACKAGE+="xf86-video-nouveau mesa "  ;;              ## 2) NVIDIA -- Open Source
        3) PACKAGE+="xf86-video-amdgpu mesa "   ;;              ## 3) AMD -- AMDGPU
        4) PACKAGE+="xf86-video-ati mesa "  ;;                  ## 4) AMD -- ATI
        5) PACKAGE+="xf86-video-intel mesa " ;;                 ## 5) Intel
    esac

    # Virtualization
    PACKAGE+="qemu "

    # Audio
    PACKAGE+="alsa-plugins alsa-lib alsa-utils pulseaudio pulseaudio-alsa pavucontrol "

    # Bluetooth
    PACKAGE+="blueberry bluez bluez-lib bluez-utils pulseaudio-bluetooth "

    # Networking
    PACKAGE+="avahi nss-mdns networkmanager network-manager-applet networkmanager-openvpn "

    # File management
    PACKAGE+="gvfs gvfs-afc gvfs-gphoto2 gvfs-mtp gvfs-nfs gvfs-smb mtpfs udiskie udiskie2 xdg-user-dirs "

    # Printing
    PACKAGE+="cups cups-pdf ghostscript gsfonts system-config-printer "

    # System enhancements
    PACKAGE+="freetype2 libopenraw poppler-glib poppler-qt5 jq "

    # Programming
    PACKAGE+="jre-openjdk python python2 cmake gcc "

    # Applications
    PACKAGE+="chromium feh firefox gimp qbittorrent scrot vlc "

    # Fonts
    PACKAGE+="adobe-source-sans-pro-fonts awesome-terminal-fonts noto-fonts ttf-hack fake-ms-fonts ttf-roboto ttf-ubuntu-font-family "

    # Customization
    PACKAGE+="papirus-icon-theme arc-gtk-theme kvantum-qt5 "

    # Utilities
    PACKAGE+="bash-completion dconf-editor file-roller gnome-disk-utility gnome-keyring gparted hardinfo hunspell hunspell-en hyphen hyphen-en grsync intltool iw jsoncpp lsb-release oh-my-zsh-git p7zip playerctl polkit polkit-gnome python2-dbus qt5ct reflector rofi rxvt-unicode speedtest-cli youtube-dl tree unrar unzip wmctrl xapps xdo xdotool xdg-desktop-portal-gtk zenity zsh zsh-completions zsh-syntax-highlighting "

    # Display manager
    PACKAGE+="accountsservice lightdm "

    # Compositor
    PACKAGE+="picom "

    # Openbox window manager
    PACKAGE+="obkey obmenu3 obmenu-generator obconf openbox tint2 xcape "

    # Packages from XFCE
    PACKAGE+="exo thunar thunar-volman xfce4-settings xfconf ristretto thunar-archive-plugin thunar-media-tags-plugin xfce4-clipman-plugin xfce4-notifyd xfce4-screenshooter xfce4-taskmanager lxappearance "

    # Install previously listed packages
    yay -Sy --noconfirm $PACKAGE
}

setup_dotfiles() {
    chsh -s $(which zsh)
    mkdir /hello && cd
    git clone https://github.com/MatthewDeSouza/dotfiles.git
    cp -a /hello/dotfiles-master/. /home/$USER/
    rm -rf /hello/ # Goodbye :/
}
