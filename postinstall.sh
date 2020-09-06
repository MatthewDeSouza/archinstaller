
setup_post() {
    set_time_zone
    set_locale
    set_keymap
    set_hostname
    set_root_password
    set_user_password
    install_bootloader
    install_yay
    set_drivers
    install_packages
    setup_dotfiles
}

set_time_zone() {
    # Generate /etc/localtime
    ln -sf /usr/share/zoneinfo/${TIME_ZONE} /etc/localtime

    # Generate /etc/adjtime
    hwclock --systohc
}

set_locale() {
    echo "export LC_CTYPE=en_US.UTF-8" >> /home/$USER_NAME/.zshrc
    echo "export LC_ALL=en_US.UTF-8" >> /home/$USER_NAME/.zshrc
    echo "en_US.UTF-8 UTF-8"  >> /etc/locale.gen
    echo 'LANG="en_US.UTF-8"' >> /etc/locale.conf
    locale-gen
}

set_keymap() {
    echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
}

set_hostname() {
    echo ${HOSTNAME} > /etc/hostname
    cat > /etc/hosts <<EOF
127.0.0.1   localhost.localdomain localhost ${1}
::1         localhost.localdomain localhost ${1}
EOF
}

set_root_password() {
    printf "Enter the root password:\n"
    passwd
}

set_user_password() {
    useradd -m ${USER_NAME}
    usermod -aG sudo ${USER_NAME}
    printf "Enter ${USER_NAME}'s password:\n"
    passwd ${USER_NAME}
}

install_bootloader() {
    pacman -Sy --noconfirm grub efibootmgr

    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

    # Uncomment below if you are dual-booting an existing copy of Windows
    #pacman -Sy --noconfirm os-prober && os-prober
}

install_yay() {
    pacman -Sy --noconfirm git go

    mkdir /hello
    cd /hello

    git clone https://aur.archlinux.org/yay.git && cd yay
    makepkg -si --noconfirm

    cd /
    rm -rf /hello # Goodbye :/
}

set_drivers() {
    ## Choose processor ucode package
    PS3='Which processor do you use? '
    options=("INTEL" "AMD")
    select PROCESSOR in "${options[@]}"
    do
        case $PROCESSOR in
            "INTEL") PROCESSOR='intel-ucode ' && break  ;;
            "AMD")   PROCESSOR='amd-ucode '   && break  ;;
        esac
    done

    PS3='Which graphics driver would you like to use? '
    options=("NVIDIA -- Proprietary" "NVIDIA -- Legacy" "NVIDIA -- Open Source" "AMD -- AMDGPU" "AMD -- ATI" "Intel")
    select GFXDRV in "${options[@]}"
    do
        case $GFXDRV in
            "NVIDIA -- Proprietary")    GFXDRV="nvidia nvidia-settings nvidia-utils " && break  ;;
            "NVIDIA -- Legacy")         GFXDRV="nvidia-390xx nvidia-390xx-utils "     && break  ;;
            "NVIDIA -- Open Source")    GFXDRV="xf86-video-nouveau mesa "             && break  ;;
            "AMD -- AMDGPU")            GFXDRV="xf86-video-amdgpu mesa "              && break  ;;
            "AMD -- ATI")               GFXDRV="xf86-video-ati mesa "                 && break  ;;
            "Intel")                    GFXDRV="xf86-video-intel mesa "               && break  ;;
            *)                                                                           break  ;;
        esac
    done
}

install_packages() {
    ### This is my personal package list. There is some customization during the script, but it is recommended you
    ### go through each section yourself to better fit your needs.

    # Essential packages.
    local PACKAGE="arch-install-scripts bind-tools broadcom-wl btrfs-progs dhcpcd dialog diffutils dosfstools ethtool exfat-utils gpm gptfdisk hdparm logrotate lvm2 mtools nano netctl nfs-utils ntfs-3g ntp openvpn openssh parted rsync sudo tcpdump usb_modeswitch usbutils wget wireless-regdb wireless_tools wpa_supplicant "

    # Intel or AMD microcode
    PACKAGE+=$PROCESSOR

    # Xorg
    PACKAGE+="xorg-server xorg-xinit "

    # Video
    PACKAGE+="xf86-input-evdev xf86-input-libinput xf86-input-void "

    # Video hardware driver
    PACKAGE+=$GFXDRV

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
    PACKAGE+="jre-openjdk python python2 cmake "

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

    #Configure GRUB if microcode is installed
    [ -z "$PROCESSOR" ] || grub-mkconfig -o /boot/grub/grub.cfg
}

setup_dotfiles() {
    su ${USER_NAME}
    cd /home/${USER_NAME}
    chsh -s $(which zsh)
    mkdir hello && cd /home/$USER_NAME/hello
    git clone https://github.com/MatthewDeSouza/dotfiles.git
    cp -a dotfiles-master/. .. && cd ..
    rm -rf hello # Goodbye :/
}