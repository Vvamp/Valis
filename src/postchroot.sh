#!/bin/sh
# Settings
LOG_FILE="/var/log/vincent_postchroot_installer.log"

# Colors
GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Global Vars
target_disk=''
USER=''
HOST=''
ROOTPWD=''
USERPWD=''
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd ) # From https://stackoverflow.com/a/246128/7170105


# Functions
ok() {
    echo -e "[  ${GREEN}OK${RESET}  ] $1"
}

info() {
    echo -e "         $1"
}

fail() {
    echo -e "[ ${RED}FAIL${RESET} ] $1"
}

check_error() {
    if [ $? -ne 0 ]; then
        fail "A fatal error occurred. Aborting..."
        exit 1
    fi
}


setup_time_localization(){
    info "Setting timezone."
    ln -sf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime >>$LOG_FILE 2>>$LOG_FILE
    check_error
    hwclock --systohc >>$LOG_FILE 2>>$LOG_FILE
    check_error
    ok "Set timezone to Europe/Amsterdam."
    info "Setting up locale"
    sed -i 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen 
    check_error
    locale-gen >>$LOG_FILE 2>>$LOG_FILE
    check_error
    ok "Generated locale successfully."
    echo "LANG=en_US.UTF-8" > /etc/locale.conf 
    echo "${HOST}" > /etc/hostname 
    ok "Applied configs."    
}

setup_initramfs(){
    info "Creating initramfs..."
    mkinitcpio -P >>$LOG_FILE 2>>$LOG_FILE
    check_error
    ok "Initramfs successfully generated."
    echo "root:${ROOTPWD}" | chpasswd
    #echo "${ROOTPWD}" | passwd root
    ok "Root password has been set."
}

setup_bootloader(){
    info "Setting up GRUB as bootloader..."
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB >>$LOG_FILE 2>>$LOG_FILE
    check_error
    ok "Grub has been installed successfully."
    grub-mkconfig -o /boot/grub/grub.cfg >>$LOG_FILE 2>>$LOG_FILE
    check_error
    ok "Grub has been configured successfully."
    ok "Grub has been set up!"

}

setup_users(){
    info "Initializing user $USER..."
    useradd -mG wheel -s /bin/bash $USER 
    ok "Added user $USER."
    echo "${USER}:${USERPWD}" | chpasswd
    # echo "${USERPWD}" | passwd $USER 
    ok "Set password for $USER."
    ok "User $USER initialized."
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    if visudo -c; then
    ok "Added 'wheel' group to sudoers file."
    else 
        error "Error in sudoers file."
        exit 1
    fi

}

prompt_info(){
    # Request the root password
    read -sp "Enter a root password: " ROOTPWD
    echo  # Move to a new line after the password input

    # Request the hostname
    read -p "Enter the desired device's hostname: " HOST

    # Request the username
    read -p "Enter user's username: " USER

    # Request the user password
    read -sp "Enter the user password: " USERPWD
    echo  # Move to a new line after the password input

}

finalize(){
    info "Finalizing post-chroot configurations..."
    systemctl enable sddm.service
    check_error
    ok "Enabled sddm display manager service."
    systemctl enable NetworkManager.service
    check_error
    ok "Enabled network manager service."

    ## Pacman settings
    # Enable Multilib
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /etc/pacman.conf
    # Enable Color
    sed -i 's/#Color/Color/' /etc/pacman.conf
    # Enable 5 Parallel Downloads
    sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
    pacman -Syy --noconfirm
    check_error
    ok "Configurated pacman."
}

setup_paru(){
    info "Setting up paru AUR helper"
    git clone https://aur.archlinux.org/paru.git paru
    check_error
    ok "Cloned repository."
    chown -R $USER paru
    check_error
    ok "Set ownership of paru source folder to $USER"
    cd paru 
    check_error
    ok "Switched directory to paru source"
    sudo -u $USER makepkg -si # TODO: Automatically send passwd and no-confirm????
    check_error
    ok "Built paru"
    cd .. 
    check_error
    ok "Switched directory back"
    rm -rf paru
    check_error
    ok "Removed paru source"
    ok "Set up paru"

}

cleanup(){
    info "Cleaning up post-chroot files"
    rm $LOG_FILE
    rm -f /mnt/bin/postchroot.sh 
    ok "Clean!"

}

# Main
ok "Entered chrooted system."
prompt_info
setup_time_localization
setup_initramfs
setup_bootloader
setup_users
setup_paru
finalize
cleanup