#!/bin/env bash

C='\033[0;94m'
NC='\033[0m'

set -euo pipefail

while getopts p:r: flag
do
    case "${flag}" in
        p) provider=${OPTARG};;
        r) router=${OPTARG};;
    esac
done

if [[ -n "${provider+set}" && "${router+set}" ]]
then
    vmid=${provider}0${provider}0$(printf '%02d' $router)
    mgmtmac=00:24:18:A${provider}:$(printf '%02d' $router):00

    # destroy
    echo -e "${C}Stopping and destroying router $vmid (if exists)${NC}"
    qm stop $vmid || true
    qm destroy $vmid || true

    # create
    echo -e "${C}Creating router $vmid${NC}"
    qm create $vmid --name "p${provider}r${router}v" --ostype l26 --memory 1664 --balloon 1664 --cpu cputype=host --cores 4 --scsihw virtio-scsi-single --net0 virtio,bridge=vmbr1001,macaddr="${mgmtmac}"
    qm importdisk $vmid vyos-1.5.0-cloud-init-10G-qemu.qcow2 local-zfs
	qm set $vmid --virtio0 local-zfs:vm-$vmid-disk-0
    qm set $vmid --boot order=virtio0

    # add interfaces
	echo -e "${C}Adding interfaces and VLAN-tags to router $vmid${NC}"
    for net in {1..4}
    do
        if [[ ${provider} == 1 && ${router} == 9 && ${net} == 2 ]]
        then
            vlanid=1074
        elif [[ ${provider} == 2 && ${router} == 9 && ${net} == 2 ]]
        then
            vlanid=2074
        elif [[ ${provider} == 3 && ${router} == 9 && ${net} == 2 ]]
        then
            vlanid=3074
        else
            vlanid=$(/home/user/inc/vlans.sh 8 2 ${router} ${net} ${provider})
        fi
        qm set $vmid --net${net} virtio,bridge=vmbr${provider},tag=${vlanid},macaddr=00:${provider}4:18:F${provider}:$(printf '%02d' $router):$(printf '%02d' $net)
    done

    # import seed.iso
	echo -e "${C}Importing seed.iso for router $vmid${NC}"
    qm set $vmid --ide2 media=cdrom,file=local:iso/seed.iso
    #qm set $vmid --onboot 1
fi
