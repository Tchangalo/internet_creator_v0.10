#!/bin/bash

vmid=$1

C='\033[0;94m'
G='\033[0;32m'
L='\033[38;5;135m'
R='\033[91m'
NC='\033[0m'

if [ -z "$vmid" ]; then
    echo -e "${R}Error: VM-ID was left empty!${NC}"
    exit 1
fi

if [[ $(df -T / | awk 'NR==2 {print $2}') == "zfs" ]]; then
    img_dir="/dev/zvol/rpool/data"
    if ! ls "$img_dir" | grep -q "^vm-${vmid}-disk-"; then
        echo -e "${R}Error: VM $vmid does not exist!${NC}"
        exit 1
    fi
	echo -e "${C}Backing up VM $vmid${NC}"
    sudo vzdump $vmid --dumpdir /var/lib/vz/dump --mode snapshot --compress 0
else
	img_dir="/var/lib/pve/local-btrfs/images"
	if ! ls "$img_dir" | grep -q "^${vmid}.*"; then
		echo -e "${R}Error: VM $vmid does not exist!${NC}"
		exit 1
	fi
	echo -e "${C}Backing up VM $vmid${NC}"
	sudo vzdump $vmid --dumpdir /var/lib/pve/local-btrfs/dump --mode snapshot --compress 0
fi

echo -e "${G}Backup of VM ${L}$vmid${G} executed successfully!${NC}"
