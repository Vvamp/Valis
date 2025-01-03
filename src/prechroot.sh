#!/bin/sh
# Settings
PING_ADDRESS="8.8.8.8"
PING_COUNT=2
PING_TIMEOUT=5
LOG_FILE="/var/log/vincent_prechroot_installer.log"

# Colors
GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Global Vars
target_disk=''
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

# Function to get user input with a default value
get_input_with_default() {
    local default_value="$1"
    local prompt_message="$2"
    local user_input
    
    read -p "> ${prompt_message} (default: ${default_value}): " user_input
    
    # Use default value if input is empty
    if [[ -z "$user_input" ]]; then
        echo "${default_value,,}"
    else
        echo "${user_input,,}"
    fi
}

check_part_error() {
    if [ $? -ne 0 ]; then
        fail "An error occurred. Falling back to interactive fdisk."
        fdisk $target_disk
        exit 1
    fi
}

check_error() {
    if [ $? -ne 0 ]; then
        fail "A fatal error occurred. Aborting..."
        exit 1
    fi
}




# Code
# Verify UEFI mode
verify_uefi(){
    info "Verifying boot mode"
    if [[ $(cat /sys/firmware/efi/fw_platform_size 2>/dev/null) == 64 ]]; then
        ok "64-bit UEFI mode verified."
    else
        fail "Failed to verify 64-bit UEFI mode."
        exit 1
    fi
}


# Verify internet with ping
verify_internet(){
    info "Pinging $PING_ADDRESS to verify network connection..."
    if [[ $(ping -c $PING_COUNT -W $PING_TIMEOUT -q -n $PING_ADDRESS | grep -oP "\d+ received" | awk '{print $1}') == $PING_COUNT ]]; then
        ok "Internet connection established."
    else
        fail "Internet connection failed to establish."
        exit 1
    fi
}

disk_format(){
    # List all available disks
    info "Available disks:"
    lsblk -d -o NAME,SIZE,TYPE
    echo ""
    
    # Ask which disk to install to
    read -p "> Enter the disk to install to (e.g., /dev/sda): " target_disk
    
    
    # Validate disk selection
    if [[ ! -b $target_disk ]]; then
        fail "Invalid disk. Exiting."
        exit 1
    fi
    
    ok "Selected $target_disk for installation."
    
    manual_format=$(get_input_with_default "n" "Manually format disk with fdisk? (y/N)")
    if [[ $manual_format == 'y' ]]; then
        fdisk $target_disk
    else
        # Ask for partition sizes
        
        part_size_efi=$(get_input_with_default "1G" "Enter the size of the EFI partition (e.g., 1G)")
        part_size_efi=${part_size_efi^^}
        read -p "> Enter the size of the root partition (e.g., 20G): " part_size_root
        # read -p "Enter the size of the home partition (e.g., 40G. Typically the rest of your disk): " part_size_home
        
        # Default swap size is twice the RAM size or 4GB, whichever is smaller
        default_swap=$(awk '/MemTotal/ { printf "%.0f\n", ($2 / 1024 / 1024 < 4 ? $2 / 1024 / 1024 : 4) }' /proc/meminfo)
        part_size_swap=$(get_input_with_default "$default_swap" "Enter the size of the swap partition")
        
        # info "EFI partition size: $part_size_efi"
        # info "Swap partition size: $part_size_swap G"
        # info "Root partition size: $part_size_root"
        # # info "Home partition size: $part_size_home"
        # info "Home partition size: <REST OF DISK>"
        
        
        # Unmount the disk just in case
        info "Unmounting target disk..."
        umount ${target_disk}* >/dev/null 2>>$LOG_FILE
        # check_part_error
        
        # Create a new GPT partition table
        info "Creating gpt partition table..."
        echo "label: gpt" | sfdisk $target_disk >>$LOG_FILE 2>>$LOG_FILE
        check_part_error
        ok "GPT Partition tabled created successfully."
        
        # Create partitions
        info "Creating partitions..."
        echo -e ",${part_size_efi^^},U,*\n,${part_size_swap^^}G,S\n,${part_size_root^^},L\n,," | sfdisk --append $target_disk >>$LOG_FILE 2>>$LOG_FILE
        check_part_error
        ok "Partitions initialized."
        
        # Refresh partition table
        info "Refreshing partition table..."
        partprobe $target_disk >>$LOG_FILE 2>>$LOG_FILE
        check_part_error
        ok "Partitions refreshed."
        
        # Format the partitions
        info "Formatting disk $target_disk..."
        mkfs.fat -F32 ${target_disk}1 >>$LOG_FILE 2>>$LOG_FILE
        check_part_error
        mkswap ${target_disk}2 >>$LOG_FILE 2>>$LOG_FILE
        check_part_error
        swapon ${target_disk}2 >>$LOG_FILE 2>>$LOG_FILE
        check_part_error
        mkfs.ext4 ${target_disk}3 >>$LOG_FILE 2>>$LOG_FILE
        check_part_error
        mkfs.ext4 ${target_disk}4 >>$LOG_FILE 2>>$LOG_FILE
        check_part_error
        ok "Disk formatted successfully."
        
        # Output the final partition layout
        ok "Disk partitioning complete!"
        echo ""
        info "Final partition layout:"
        lsblk $target_disk
    fi
}

# Mount FS
mount_fs(){
    # Filesystem
    info "Mounting new filesystem for $target_disk..."
    mount ${target_disk}3 /mnt
    check_error
    mount --mkdir ${target_disk}4 /mnt/home
    check_error
    mount --mkdir ${target_disk}1 /mnt/boot
    check_error
    ok "Successfully mounted filesystem."
}

pacstrap_install(){
    info "Installing required packages..."
    # Modify as needed
    pacstrap -K /mnt base base-devel sudo linux linux-headers linux-firmware  man-db man-pages neovim networkmanager network-manager-applet nm-connection-editor plasma-nm wayland xorg-xwayland plasma sddm git firefox pipewire pipewire-pulse efibootmgr grub zip unzip unrar wget curl kitty >>$LOG_FILE 2>>$LOG_FILE

    check_error
    ok "Successfully installed packages using pacstrap."

}

configure_system(){
    info "Configuring system..."
    genfstab -U /mnt >> /mnt/etc/fstab 
    check_error
    ok "Successfully generated fstab."
}

chroot_setup(){
    info "Preparing chroot environment"
    cp ${SCRIPT_DIR}/postchroot.sh /mnt/bin/postchroot.sh 
    check_error
    ok "Successfully copied chrootscript."
    arch-chroot /mnt /bin/bash /bin/postchroot.sh
    check_error
    ok "Changed root to new filesystem."
    ok "Finished post-chroot script successfully."
    exit 
    check_error
    ok "Exited chroot environment."
    info "Unmounting filesystem..."
    umount -R /mnt 
    check_error
    ok "Successfully unmounted filesystem."
    info "Rebooting..."
    # reboot
}

cleanup(){
    info "Cleaning up..."
    rm $LOG_FILE
    ok "Clean!"
}

hello_art(){
    echo -e "${GREEN}"
    echo -e " ___      ___ ________  ___       ___  ________      "
    echo -e "|\  \    /  /|\   __  \|\  \     |\  \|\   ____\     "
    echo -e "\ \  \  /  / | \  \|\  \ \  \    \ \  \ \  \___|_    "
    echo -e " \ \  \/  / / \ \   __  \ \  \    \ \  \ \_____  \   "
    echo -e "  \ \    / /   \ \  \ \  \ \  \____\ \  \|____|\  \  "
    echo -e "   \ \__/ /     \ \__\ \__\ \_______\ \__\____\_\  \ "
    echo -e "    \|__|/       \|__|\|__|\|_______|\|__|\_________\\"
    echo -e "                                         \|_________|"
    echo ""                                                      
    echo -e "${RESET}"
    echo "Vvamp Arch Linux Install Script"
}

# Main
hello_art
verify_uefi
verify_internet
disk_format
mount_fs
#TODO: pacman mirror list
pacstrap_install
configure_system
chroot_setup
