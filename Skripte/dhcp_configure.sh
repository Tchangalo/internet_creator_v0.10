#!/bin/bash

# This script is tested on Ubuntu-Server. If you use another OS, adjustments might be necessary, e.g for swap. 

C='\033[0;94m'
NC='\033[0m'

vm_user=$(whoami)
echo "Enter the password of the DHCP-server user:"
read password
echo "Enter the MGMT-IP (v4) of the DHCP-server:"
read mgmt_ip
echo "Enter the PVE-IP (v4):"
read pve_ip
pve_hostname=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "user@$pve_ip" hostname -s)

sudo swapoff -a
sudo rm -f /swap.img

cd /home/$vm_user
## This should have already been done. Uncomment, if not.
# sudo apt-get update && sudo apt upgrade -y
# sudo apt install mc termshark kea lnav -y

# You can comment this out for security reasens, but then you will have to enter the user password twice 
# in the backend terminal, bevor the creation of the vyos cloud init image will start.
echo "$vm_user ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo

echo "alias ipbc='ip -br -c a'" >> /home/$vm_user/.bashrc
source ~/.bashrc

sudo apt install qemu-guest-agent -y
sudo systemctl start qemu-guest-agent
sudo systemctl status qemu-guest-agent

touch askpass_script.sh
echo "#!/bin/bash
echo '"$password"'" > askpass_script.sh
chmod +x /home/$vm_user/askpass_script.sh
chmod 700 /home/$vm_user/askpass_script.sh

cd /home/$vm_user/.ssh
touch config
echo "Host $pve_hostname
    HostName $pve_ip
    User user" > config
ssh-keygen -t ed25519 -f id_ed25519 -N ""

ssh-copy-id -i ~/.ssh/id_ed25519 user@$pve_hostname

sudo mv /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.bak
sudo touch /etc/kea/kea-dhcp4.conf
sudo chown root:root /etc/kea/kea-dhcp4.conf
echo "{
    \"Dhcp4\": {
    // Add names of your network interfaces to listen on.
    \"interfaces-config\": {
        \"interfaces\": [ \"ens19/$mgmt_ip\" ]
    },

    \"control-socket\": {
        \"socket-type\": \"unix\",
        \"socket-name\": \"/tmp/kea4-ctrl-socket\"
    },

    // Use Memfile lease database backend to store leases in a CSV file.
    // Depending on how Kea was compiled, it may also support SQL databases
    // (MySQL and/or PostgreSQL) and even Cassandra. Those database backends
    // require more parameters, like name, host and possibly user and password.
    // There are dedicated examples for each backend. See Section 7.2.2 \"Lease
    // Storage\" for details.
    \"lease-database\": {
        // Memfile is the simplest and easiest backend to use. It's an in-memory
        // C++ database that stores its state in CSV file.
        \"type\": \"memfile\",
        \"lfc-interval\": 3600
    },

    // Kea allows storing host reservations in a database. If your network is
    // small or you have few reservations, it's probably easier to keep them
    // in the configuration file. If your network is large, it's usually better
    // to use database for it. To enable it, uncomment the following:
    // \"hosts-database\": {
    //     \"type\": \"mysql\",
    //     \"name\": \"kea\",
    //     \"user\": \"kea\",
    //     \"password\": \"kea\",
    //     \"host\": \"localhost\",
    //     \"port\": 3306
    // },
    // See Section 7.2.3 \"Hosts storage\" for details.

    // Setup reclamation of the expired leases and leases affinity.
    // Expired leases will be reclaimed every 10 seconds. Every 25
    // seconds reclaimed leases, which have expired more than 3600
    // seconds ago, will be removed. The limits for leases reclamation
    // are 100 leases or 250 ms for a single cycle. A warning message
    // will be logged if there are still expired leases in the
    // database after 5 consecutive reclamation cycles.
    \"expired-leases-processing\": {
        \"reclaim-timer-wait-time\": 10,
        \"flush-reclaimed-timer-wait-time\": 25,
        \"hold-reclaimed-time\": 3600,
        \"max-reclaim-leases\": 100,
        \"max-reclaim-time\": 250,
        \"unwarned-reclaim-cycles\": 5
    },

    // Global timers specified here apply to all subnets, unless there are
    // subnet specific values defined in particular subnets.
    \"renew-timer\": 900,
    \"rebind-timer\": 1800,
    \"valid-lifetime\": 3600,

    \"subnet4\": [
        {
            \"subnet\": \"10.20.30.0/24\",
            \"pools\": [ { \"pool\": \"10.20.30.10 - 10.20.30.200\" } ],

            \"reservations\": [
                // This is a reservation for a specific hardware/MAC address.
                // It's a rather simple reservation: just an address and nothing
                // else.
                // This is a reservation for a specific client-id. It also shows
                // the this client will get a reserved hostname. A hostname can
                // be defined for any identifier type, not just client-id.
                {
                    \"hw-address\": \"00:24:18:A1:01:00\",
                    \"ip-address\": \"10.20.30.11\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A1:02:00\",
                    \"ip-address\": \"10.20.30.12\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A1:03:00\",
                    \"ip-address\": \"10.20.30.13\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A1:04:00\",
                    \"ip-address\": \"10.20.30.14\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A1:05:00\",
                    \"ip-address\": \"10.20.30.15\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A1:06:00\",
                    \"ip-address\": \"10.20.30.16\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A1:07:00\",
                    \"ip-address\": \"10.20.30.17\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A1:08:00\",
                    \"ip-address\": \"10.20.30.18\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A1:09:00\",
                    \"ip-address\": \"10.20.30.19\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A2:01:00\",
                    \"ip-address\": \"10.20.30.21\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A2:02:00\",
                    \"ip-address\": \"10.20.30.22\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A2:03:00\",
                    \"ip-address\": \"10.20.30.23\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A2:04:00\",
                    \"ip-address\": \"10.20.30.24\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A2:05:00\",
                    \"ip-address\": \"10.20.30.25\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A2:06:00\",
                    \"ip-address\": \"10.20.30.26\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A2:07:00\",
                    \"ip-address\": \"10.20.30.27\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A2:08:00\",
                    \"ip-address\": \"10.20.30.28\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A2:09:00\",
                    \"ip-address\": \"10.20.30.29\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A3:01:00\",
                    \"ip-address\": \"10.20.30.31\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A3:02:00\",
                    \"ip-address\": \"10.20.30.32\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A3:03:00\",
                    \"ip-address\": \"10.20.30.33\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A3:04:00\",
                    \"ip-address\": \"10.20.30.34\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A3:05:00\",
                    \"ip-address\": \"10.20.30.35\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A3:06:00\",
                    \"ip-address\": \"10.20.30.36\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A3:07:00\",
                    \"ip-address\": \"10.20.30.37\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A3:08:00\",
                    \"ip-address\": \"10.20.30.38\",
                    \"client-classes\": [ \"KnownClients\" ]
                },
                {
                    \"hw-address\": \"00:24:18:A3:09:00\",
                    \"ip-address\": \"10.20.30.39\",
                    \"client-classes\": [ \"KnownClients\" ]
                }
            ]
            // You can add more subnets there.
        }
    ],

    // Logging configuration starts here. Kea uses different loggers to log various
    // activities. For details (e.g. names of loggers), see Chapter 18.
    \"loggers\": [
    {
        // This section affects kea-dhcp4, which is the base logger for DHCPv4
        // component. It tells DHCPv4 server to write all log messages (on
        // severity INFO or more) to a file.
        \"name\": \"kea-dhcp4\",
        \"output_options\": [
            {
                // Specifies the output file. There are several special values
                // supported:
                // - stdout (prints on standard output)
                // - stderr (prints on standard error)
                // - syslog (logs to syslog)
                // - syslog:name (logs to syslog using specified name)
                // Any other value is considered a name of the file
                \"output\": \"/var/log/kea-dhcp4.log\"

                // Shorter log pattern suitable for use with systemd,
                // avoids redundant information
                // \"pattern\": \"%-5p %m\n\"

                // This governs whether the log output is flushed to disk after
                // every write.
                // \"flush\": false,

                // This specifies the maximum size of the file before it is
                // rotated.
                // \"maxsize\": 1048576,

                // This specifies the maximum number of rotated files to keep.
                // \"maxver\": 8
            }
        ],
        // This specifies the severity of log messages to keep. Supported values
        // are: FATAL, ERROR, WARN, INFO, DEBUG
        \"severity\": \"INFO\",

        // If DEBUG level is specified, this value is used. 0 is least verbose,
        // 99 is most verbose. Be cautious, Kea can generate lots and lots
        // of logs if told to do so.
        \"debuglevel\": 0
    }
    ]
}
}" | sudo tee /etc/kea/kea-dhcp4.conf > /dev/null

echo -e "${C}dhcp_configure.sh executed successfully!${NC}"

sudo reboot