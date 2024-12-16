#!/bin/bash

export ANSIBLE_HOST_KEY_CHECKING=False

provider=$1
first_router=$2
last_router=$3

image_dir="${HOME}/inc/ansible/vyos-images"

limit_elements=""
for e in $(seq $first_router $last_router); do
    limit_elements+="p${provider}r${e}v,"
done
limit_elements=${limit_elements%,}
vyos_ansible_limit="-l $limit_elements"

C='\033[0;94m'
G='\033[0;32m'
L='\033[38;5;135m'
R='\033[91m'
NC='\033[0m'

sleeping () {
    for r in $(seq "$2" "$3"); do
        while true; do
            sleep 1
            if ansible -i "${HOME}/inc/ansible/inventories/inventory${provider}.yaml" "p${provider}r${r}v" -m ping -u vyos | grep -q pong; then
                break
            fi
        done
        echo -e "${C}Router ${r} is running${NC}"
    done
}

if [ -z "$provider" ] || [ -z "$first_router" ] || [ -z "$last_router" ]; then
    echo -e "${R}Error: At least one variable empty!${NC}"
    exit 1
fi

# Destroy and create vms
cd ${HOME}/inc/create-vms/create-vms-vyos/

for r in $(seq $first_router $last_router); do
	if [[ $(df -T / | awk 'NR==2 {print $2}') == "zfs" ]]; then		
	sudo bash create-vm-vyos_zfs.sh -p ${provider} -r $r
    else
	sudo bash create-vm-vyos_btrfs.sh -p ${provider} -r $r
    fi
done

# Start and update ssh known hosts
echo -e "${C}Starting router$([[ $first_router != $last_router ]] && echo s) and updating SSH known hosts${NC}"
for r in $(seq $first_router $last_router); do
    sudo qm start ${provider}0${provider}00${r}
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "10.20.30.${provider}${r}"
done

# Sleeping
echo -e "${C}Waiting for first boot${NC}"
sleeping $provider $first_router $last_router

# Download latest vyos image and upgrade
cd ${HOME}/inc/ansible
echo -e "${C}Downloading latest Vyos image (if necessary) and system upgrade$([[ $first_router != $last_router ]] && echo s)${NC}"
ansible-playbook -i inventories/inventory${provider}.yaml vyos_upgrade.yml "$vyos_ansible_limit"

# Delete old image in vyos-images
cd $image_dir || { echo -e "${R}Directory not found${NC}"; exit 1; }
image_count=$(ls -1 vyos-*.iso | wc -l)

if [ "$image_count" -gt 1 ]; then
latest_image=$(ls -t vyos-*.iso | head -n 1)

for image in $(ls -1 vyos-*.iso); do
if [ "$image" != "$latest_image" ]; then
    rm -f "$image"
    echo -e "${C}Deleted from folder vyos-images: $image${NC}"
fi
done
else
    echo -e "${C}Only one image found in folder vyos-images, no deletion needed.${NC}"
fi

# Reboot
echo -e "${C}Reboot${NC}"
cd ${HOME}/inc/ansible
ansible-playbook -i inventories/inventory${provider}.yaml vyos_reboot.yml "$vyos_ansible_limit"

# Sleeping
echo -e "${C}Waiting for second boot${NC}"
sleeping $provider $first_router $last_router

# Remove old images from routers
cd ${HOME}/inc/ansible
echo -e "${C}Removing old images from router$([[ $first_router != $last_router ]] && echo s)${NC}"
ansible-playbook -i inventories/inventory${provider}.yaml vyos_remove_images.yml "$vyos_ansible_limit"

# Show remaining image
echo -e "${C}Remaining image on router$([[ $first_router != $last_router ]] && echo s):${NC}"
ansible-playbook -i inventories/inventory${provider}.yaml vyos_show_image.yml "$vyos_ansible_limit"

# Configuring
echo -e "${C}Configuring network${NC}"
ansible-playbook -i inventories/inventory${provider}.yaml setup.yml "$vyos_ansible_limit"

# Delete cdrom(s)
echo -e "${C}Deleting cdrom$([[ $first_router != $last_router ]] && echo s)${NC}"
for r in $(seq $first_router $last_router); do
    sudo qm set ${provider}0${provider}00$r --delete ide2
done

# Reboot
echo -e "${C}Final reboot${NC}"
echo -e "${C}Shutting down router$([[ $first_router != $last_router ]] && echo s)${NC}"
sudo  bash ${HOME}/inc/general/shutdown.sh $provider $first_router $last_router
echo -e "${C}Final restart${NC}"
sudo  bash ${HOME}/inc/general/start.sh $provider $first_router $last_router 0

if [[ $first_router == $last_router ]]; then
	echo -e "${G}Creation of router ${L}p${provider}r${first_router}v${G} executed successfully!${NC}"
else
	echo -e "${G}Creation of routers ${L}p${provider}r${first_router}v${G} to ${L}p${provider}r${last_router}v${G} executed successfully!${NC}"
fi
echo -e "${C}Wait a minute until the network is running.${NC}"

