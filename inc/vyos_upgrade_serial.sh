#!/bin/bash

provider=$1
first_router=$2
last_router=$3
start_delay=$4

image_dir="${HOME}/inc/ansible/vyos-images"

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

if [ -z "$provider" ] || [ -z "$first_router" ] || [ -z "$last_router" ] || [ -z "$start_delay" ]; then
    echo -e "${R}Error: At least one variable empty!${NC}"
    exit 1
fi

# Start
echo -e "${C}Starting router$([[ $first_router != $last_router ]] && echo s), if not running${NC}"
sudo  bash ${HOME}/inc/general/start.sh $provider $first_router $last_router $start_delay

# Sleeping
echo -e "${C}Waiting ...${NC}"
sleeping $provider $first_router $last_router

# Download latest vyos image and upgrade
cd ${HOME}/inc/ansible
echo -e "${C}Downloading latest Vyos image (if necessary) and system upgrade$([[ $first_router != $last_router ]] && echo s)${NC}"
for r in $(seq $first_router $last_router); do 
	ansible-playbook -i inventories/inventory${provider}.yaml vyos_upgrade.yml "-l p${provider}r${r}v"
done

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
echo -e "${C}Shutting down router$([[ $first_router != $last_router ]] && echo s)${NC}"
sudo  bash ${HOME}/inc/general/shutdown.sh $provider $first_router $last_router
echo -e "${C}Restarting router$([[ $first_router != $last_router ]] && echo s)${NC}"
sudo  bash ${HOME}/inc/general/start.sh $provider $first_router $last_router $start_delay

# Sleeping
echo -e "${C}Waiting ...${NC}"
sleeping $provider $first_router $last_router

# Remove old images from routers
cd ${HOME}/inc/ansible
echo -e "${C}Removing old images from router$([[ $first_router != $last_router ]] && echo s)${NC}"
for r in $(seq $first_router $last_router); do 
    ansible-playbook -i inventories/inventory${provider}.yaml vyos_remove_images.yml "-l p${provider}r${r}v"
done

# Show remaining image
echo -e "${C}Remaining image on router$([[ $first_router != $last_router ]] && echo s):${NC}"
for r in $(seq $first_router $last_router); do 
    ansible-playbook -i inventories/inventory${provider}.yaml vyos_show_image.yml "-l p${provider}r${r}v"
done

if [[ $first_router == $last_router ]]; then
	echo -e "${G}Router ${L}p${provider}r${first_router}v${G} is up to date!${NC}"
else
	echo -e "${G}Routers ${L}p${provider}r${first_router}v${G} to ${L}p${provider}r${last_router}v${G} are up to date!${NC}"
fi
echo -e "${C}Wait a minute until the network is running.${NC}"

sleep 2
