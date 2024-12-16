#!/bin/bash

vm_user=$1
pve_user=$2
pve_ip=$3
version_no=$4

if [ -z "$vm_user" ] || [ -z "$pve_user" ] || [ -z "$pve_ip" ] || [ -z "$version_no" ]; then
    echo "Error: At least one variable empty!"
    exit 1
fi

sudo -A apt update && sudo -A apt upgrade -y
sudo -A apt install -y curl git jq ansible

git clone https://github.com/vyos/vyos-vm-images.git

curl -Lo /tmp/vyos.iso $(curl -s https://api.github.com/repos/vyos/vyos-nightly-build/releases/latest | jq -r '.assets[].browser_download_url' | grep -iE '.iso$')

sudo -A chown root:root /tmp/vyos.iso

cd vyos-vm-images
sudo -A ansible-playbook qemu.yml -e disk_size=10 -e iso_local=/tmp/vyos.iso -e grub_console=serial -e vyos_version=$version_no -e cloud_init=true -e cloud_init_ds=NoCloud

scp /tmp/vyos-${version_no}-cloud-init-10G-qemu.qcow2 ${pve_user}@${pve_ip}:/home/${pve_user}/inc/create-vms/create-vms-vyos

sudo -A rm -rf /tmp/vyos.iso /tmp/vyos-${version_no}-cloud-init-10G-qemu.qcow2 /home/${vm_user}/vyos-vm-images /home/${vm_user}/vyos_qcow2.sh

echo "Success! You can find the Vyos Cloud Init Image in /home/user/inc/create-vms/create-vms-vyos/"