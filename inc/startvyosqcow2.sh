#!/bin/bash

vm_user=$1
vm_ip=$2
pve_ip=$3
version_no=$4
pve_user=$(whoami)

if [ -z "$vm_user" ] || [ -z "$vm_ip" ] || [ -z "$pve_ip" ] || [ -z "$version_no" ]; then
    echo "Error: At least one variable empty!"
    exit 1
fi

sudo rm -rf /home/${pve_user}/inc/create-vms/create-vms-vyos/vyos-${version_no}-cloud-init-10G-qemu.qcow2

#ssh-keygen -f "/home/${pve_user}/.ssh/known_hosts" -R "$vm_ip"

scp vyos_qcow2.sh ${vm_user}@${vm_ip}:/home/${vm_user}

ssh ${vm_user}@${vm_ip} "export SUDO_ASKPASS=/home/${vm_user}/askpass_script.sh && bash /home/${vm_user}/vyos_qcow2.sh $vm_user $pve_user $pve_ip $version_no"


