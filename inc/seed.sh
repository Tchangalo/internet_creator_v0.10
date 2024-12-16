#!/bin/bash

pve_user=$(whoami)
pve_hostname=$(hostname)

C='\033[0;94m'
R='\033[91m'
NC='\033[0m'

# Automatically determine the SSH type from the public key file
for pubkey_file in "${HOME}/.ssh/"*.pub; do
    if [ -f "$pubkey_file" ]; then
        # Extract the first part (the SSH type) from the file
        ssh_type=$(awk '{print $1}' "$pubkey_file")
        break
    fi
done

if [ -z "$ssh_type" ]; then
    echo "Error: No public key file found in ${HOME}/.ssh/!"
    exit 1
fi

# Select the file based on the detected SSH type
case "$ssh_type" in
    "ssh-rsa")
        pubkey_file="${HOME}/.ssh/id_rsa.pub"
        ;;
    "ssh-ed25519")
        pubkey_file="${HOME}/.ssh/id_ed25519.pub"
        ;;
    "ecdsa-sha2-nistp256"|"ecdsa-sha2-nistp384"|"ecdsa-sha2-nistp521")
        pubkey_file="${HOME}/.ssh/id_ecdsa.pub"
        ;;
    *)
        echo -e "${R}Error: Unsupported ssh_type '${ssh_type}'!${NC}"
        echo -e "${C}Supported types: ssh-rsa, ssh-ed25519, ecdsa-sha2-nistp256, ecdsa-sha2-nistp384, ecdsa-sha2-nistp521${NC}"
        exit 1
        ;;
esac

# Check if the file exists
if [ -f "$pubkey_file" ]; then
    # Extract only the middle part (the actual key value)
    pubkey_user=$(awk '{print $2}' "$pubkey_file")
else
    echo "Error: Public key file not found for ${ssh_type} at ${pubkey_file}!"
    exit 1
fi

if [[ $(df -T / | awk 'NR==2 {print $2}') == "zfs" ]]; then
    sudo rm -f /var/lib/vz/template/iso/seed.iso
else
    sudo rm -f /var/lib/pve/local-btrfs/template/iso/seed.iso
fi

cd ${HOME}/inc/seed
## If you want to modify the network configuration, you can remove the comments here, and apply your changes
# sudo rm -f network-config
# touch network-config
# echo "version: 2
# ethernets:
#   eth0:
#     dhcp4: true
#     dhcp6: false
#     mtu: 1500" > ${HOME}/inc/seed/network-config
sudo rm -f user-data
touch user-data
echo "#cloud-config
vyos_config_commands:
  - set vrf name mgmt table 1020
  - set system host-name 'vyos-init'
  - set interfaces ethernet eth0 vrf mgmt
  - set service ssh vrf mgmt
  - set service ntp server 1.pool.ntp.org
  - set service ntp server 2.pool.ntp.org
  - set system login user vyos authentication public-keys ${pve_user}@${pve_hostname} key '${pubkey_user}'
  - set system login user vyos authentication public-keys ${pve_user}@${pve_hostname} type '${ssh_type}'" > ${HOME}/inc/seed/user-data

mkisofs -joliet -rock -volid "cidata" -output seed.iso meta-data user-data network-config

if [[ $(df -T / | awk 'NR==2 {print $2}') == "zfs" ]]; then
    sudo mv seed.iso /var/lib/vz/template/iso/
    sudo chown root:root /var/lib/vz/template/iso/seed.iso
else
    sudo mv seed.iso /var/lib/pve/local-btrfs/template/iso/
    sudo chown root:root /var/lib/pve/local-btrfs/template/iso/seed.iso
fi

echo -e "${C}Success! The seed.iso is now available.${NC}"
