#!/bin/bash
qm set 1000 -delete ide2
qm set 1000 -boot order=virtio0
qm set 1000 -net0 model=virtio,bridge=vmbr0,firewall=0,macaddr="00:24:18:0A:1B:DE"
qm set 1000 -onboot 1



