#!/bin/bash
qm set 307999 -delete ide2
qm set 307999 -boot order=virtio0
qm set 307999 -onboot 1