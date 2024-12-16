#!/bin/bash

vmid=$1

C='\033[0;94m'
G='\033[0;32m'
L='\033[38;5;135m'
NC='\033[0m'

if [ -z "$vmid" ]; then
    echo -e "${R}Error: VM-ID was left empty!${NC}"
    exit 1
fi

if [[ $(df -T / | awk 'NR==2 {print $2}') == "zfs" ]]; then
    img_dir="/dev/zvol/rpool/data"
    if ! ls "$img_dir" | grep -q "^vm-${vmid}-disk-"; then
        echo -e "${R}Error: Router $vmid does not exist!${NC}"
        exit 1
    fi
    echo -e "${C}Deleting ALL existing backups${NC}"
    if [[ -d "/var/lib/vz/dump" ]]; then
        sudo rm -rf /var/lib/vz/dump
    fi
	sudo mkdir -p /var/lib/vz/dump	
    echo -e "${C}Backing up router $vmid${NC}"
    sudo vzdump $vmid --dumpdir /var/lib/vz/dump --mode snapshot --compress 0
else
	img_dir="/var/lib/pve/local-btrfs/images"
	if ! ls "$img_dir" | grep -q "^${vmid}.*"; then
		echo -e "${R}Error: Router $vmid does not exist!${NC}"
		exit 1
	fi
    echo -e "${C}Deleting ALL existing backups${NC}"
    if [[ -d "/var/lib/pve/local-btrfs/dump" ]]; then
        sudo rm -rf /var/lib/pve/local-btrfs/dump
    fi
	sudo mkdir -p /var/lib/pve/local-btrfs/dump
    echo -e "${C}Backing up router $vmid${NC}"
	sudo vzdump $vmid --dumpdir /var/lib/pve/local-btrfs/dump --mode snapshot --compress 0
fi

echo -e "${G}Deletion of ALL existing backups and backup of VM ${L}$vmid${G} executed successfully!${NC}"
