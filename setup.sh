#!/bin/bash

# Exit script on any error
set -e

USER="dzhi"
SHELL="zsh"
TZ="Europe/Belgrade"
LOCALE="en_US.UTF-8"
PKGS="base linux syslinux gptfdisk neovim git sudo openssh mdadm lvm2 terminus-font $SHELL"
HOSTNAME="arch"
GH_USER="pentago"

# Password Prompt
prompt_for_password() {
	read -rsp "$1: " PASSWORD
	echo "$PASSWORD"
}

# Stage 1: Bootstrapping
stage0() {
	echo "Running Stage 0: Bootstrapping"
	user_password=$(prompt_for_password "Enter root password")
	echo "root:$user_password" | chpasswd
	pacman -Sy
}

# Stage 1: Partitioning
stage1() {
	echo "Running Stage 1: Partitioning"
	DISK_SIZE=$(parted /dev/mapper/root print | grep "Disk /dev/mapper/root" | awk '{print $3}')
	ALIGNMENT=$((2048))
	END=$DISK_SIZE
	parted /dev/mapper/root mkpart primary ext4 "${ALIGNMENT}s" "${END}s"
}

# Stage 2: Base setup
stage2() {
	echo "Running Stage 2: Base Setup"
	pacstrap -K /mnt "$PKGS"
	genfstab -L /mnt >>/mnt/etc/fstab
	mdadm --detail --scan >>/mnt/etc/mdadm.conf
	cp /etc/systemd/network/*ethernet* /mnt/etc/systemd/network/
	cp "/etc/$SHELL/*" "/mnt/etc/$SHELL"
	cp "$0" /mnt
	arch-chroot /mnt "$SHELL"
}

# Stage 3: Configuration
stage3() {
	echo "Running Stage 3: Configuration"
	sed -i "/^#$LOCALE/s/^#//" /etc/locale.gen
	locale-gen
	echo "LANG=$LOCALE" >/etc/locale.conf
	echo "FONT=ter-u18b" >/etc/vconsole.conf
	ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
	hwclock --systohc
	echo "$HOSTNAME" >/etc/hostname
	systemctl enable systemd-networkd
	systemctl enable systemd-resolved
	systemctl enable systemd-timesyncd
	systemctl enable sshd
	sed -i 's/block filesystems/block encrypt filesystems/' /etc/mkinitcpio.conf
	mkinitcpio -P
	mkdir -p /boot/syslinux
	extlinux -i /boot/syslinux
	syslinux-install_update -iam
}

# Stage 4: User Setup
stage4() {
	echo "Running Stage 4: User Setup"
	useradd "$USER" -m -G wheel -s "/bin/$SHELL" -U
	user_password=$(prompt_for_password "Enter user password")
	echo "$USER:$user_password" | chpasswd
	mkdir --mode 700 "/home/$USER/.ssh"
	curl -L "https://github.com/$GH_USER.keys" >"/home/$USER/.ssh/authorized_keys"
	chown -R "$USER:$USER" "/home/$USER"
}

# Function to show usage
usage() {
	echo "Usage: $0 <stage>"
	echo "Available stages:"
	echo "  stage0 - Bootstrapping"
	echo "  stage1 - Partitioning"
	echo "  stage2 - Base Setup"
	echo "  stage3 - Configuration"
	echo "  stage4 - User Setup"
	exit 1
}

# Main script logic
if [[ $# -ne 1 ]]; then
	usage
fi

case "$1" in
stage0)
	stage0
	;;
stage1)
	stage1
	;;
stage2)
	stage2
	;;
stage3)
	stage3
	;;
stage4)
	stage4
	;;
*)
	echo "Error: Invalid stage '$1'"
	usage
	;;
esac
