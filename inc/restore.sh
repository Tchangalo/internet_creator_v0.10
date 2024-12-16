#!/bin/bash

provider=$1
first_router=$2
last_router=$3
start_delay=$4

C='\033[0;94m'
G='\033[0;32m'
L='\033[38;5;135m'
R='\033[91m'
NC='\033[0m'

if [[ $(df -T / | awk 'NR==2 {print $2}') == "zfs" ]]; then
        dump_dir="/var/lib/vz/dump"
    else
        dump_dir="/var/lib/pve/local-btrfs/dump"
fi 

if [ -z "$provider" ] || [ -z "$first_router" ] || [ -z "$last_router" ] || [ -z "$start_delay" ]; then
    echo -e "${R}Error: At least one variable is empty!${NC}"
    exit 1
fi

## Uncomment the lines below, if the VMs should be destroyed before the restore process:
# echo -e "${C}Destroying VM$([[ $first_router != $last_router ]] && echo s)${NC}"
for i in $(seq $first_router $last_router); do 
    sudo qm stop ${provider}0${provider}00$i 
    # sudo qm destroy ${provider}0${provider}00$i
    done

# Check if the dump directory exists
if [ ! -d "$dump_dir" ]; then
    echo -e "${R}Error: Directory $dump_dir does not exist.${NC}"
    exit 1
fi

# Create an associative array to store the latest backup for each router
declare -A latest_backups

# Iterate over all .vma-files in the dump directory
for vma_file in "$dump_dir"/*.vma; do
    # Extract the VMID and timestamp from the filename
    vm_id=$(basename "$vma_file" | grep -oP '(?<=vzdump-qemu-)\d+')
    timestamp=$(basename "$vma_file" | grep -oP '\d{4}_\d{2}_\d{2}-\d{2}_\d{2}_\d{2}')

    # Check if the VMID and timestamp were extracted
    if [ -z "$vm_id" ] || [ -z "$timestamp" ]; then
        echo -e "${R}Error: Could not extract VMID or timestamp from $vma_file.${NC}"
        exit 1
    fi

    # Check if the VMID belongs to a router within the range from first_router to last_router
    for r in $(seq $first_router $last_router); do
        router_vm_id="${provider}0${provider}00$r"
        if [[ "$vm_id" == "$router_vm_id" ]]; then
            # Store the latest backup based on the timestamp
            if [[ "$timestamp" > "$(basename "${latest_backups[$vm_id]}" | grep -oP '\d{4}_\d{2}_\d{2}-\d{2}_\d{2}_\d{2}')" ]]; then
                latest_backups[$vm_id]="$vma_file"
            fi
            break
        fi
    done
done

# The associative array (@) has the following structure:
# latest_backups=(
#     [vm_id1, e.g. 101]="/path/to/backup1.vma"
#     [vm_id2, e.g. 102]="/path/to/backup2.vma"
# )
# Retrieve all the keys (!) - here the vm_ids - of the array (@), 
# print them as strings (%s) and
# sort these strings interpreted as numeric values (-n) in ascending order
for vm_id in $(printf "%s\n" "${!latest_backups[@]}" | sort -n); do
    # Restore the latest backup(s) only if they exist
    if [ -n "${latest_backups[$vm_id]}" ]; then
        latest_vma_file="${latest_backups[$vm_id]}"
        echo -e "${C}Restoring router $vm_id from $latest_vma_file${NC}"
        # Restore the latest backup(s) in the (ascending) order of vm_ids
        sudo qmrestore "$latest_vma_file" "$vm_id" --force
    else
        echo -e "${R}Error: No backup found for VM ID $vm_id. Exiting.${NC}"
        exit 1
    fi
done

# Start the routers only if backups were successfully restored
for r in $(seq $first_router $last_router); do
    vm_id="${provider}0${provider}00${r}"
    if [ -n "${latest_backups[$vm_id]}" ]; then
        echo -e "${C}Starting router $vm_id${NC}"
        sudo qm start "$vm_id"
        sleep $start_delay
    else
        echo -e "${R}Error: No backup found for router $vm_id, that could be restored!${NC}"
        exit 1
    fi
done

if [[ $first_router == $last_router ]]; then
    echo -e "${G}Restore of router ${L}p${provider}r${first_router}v${G} executed successfully!${NC}"
else
    echo -e "${G}Restore of routers ${L}p${provider}r${first_router}v${G} to ${L}p${provider}r${last_router}v${G} executed successfully!${NC}"
fi
echo -e "${C}Wait a minute until the network is running.${NC}"
