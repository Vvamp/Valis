<!-- Project Badges-->
![Contributors Badge](https://img.shields.io/github/contributors/Vvamp/Valis.svg?)
![Forks Badge](https://img.shields.io/github/forks/Vvamp/Valis.svg?)
![Stars Badge](https://img.shields.io/github/stars/Vvamp/Valis.svg?)
![Issues Badge](https://img.shields.io/github/issues/Vvamp/Valis.svg?)
![License Badge](https://img.shields.io/github/license/Vvamp/Valis.svg?)
# Valis

Hello there! Welcome to Valis, a simple Arch Linux install script.

## How to Use

**Prerequisites:**

This tool requires a recent Arch Linux ISO. No additional dependencies are needed.
You might want to use Git to download these scripts to the Arch Linux ISO, but you can also use a USB.

**Steps:**

1. Download or mount(via usb) the source code in this repository.
2. Make sure the install scripts have execute permissions `chmod +x /path/to/bash/scripts`.
3. Run the pre-chroot script `bash /path/to/bash/script`.
4. Follow the prompts, you can either configure the partitions manually or semi-automatically based on prompts.
5. Done! The script handles everything. If everything goes right, you should reboot into a working Arch Linux installation with KDE/Plasma.

## Disclaimer
The script is simple and is meant for personal use.
The script contains extremely destructive commands and will **wipe your disk** if used incorrectly.
It has no support for any kind of dual-booting at this time.
**DO NOT USE** this script if you don't know what you are doing.
If this is your first time installing Arch Linux, I recommend doing it manually with the [Arch Linux installation guide](https://wiki.archlinux.org/title/Installation_guide). 
It offers some basic knowledge and concepts that are useful to know as a new Linux user.

## Contribution

This script is mainly for personal use; it includes the arch system I want and like.
As such, I probably won't merge any PR(unless it cleans up code or performance within the script itself).
Feel free to use this script for yourself and modify it to your heart's desire.

## License

Valis is [Unlicensed](./LICENSE).
