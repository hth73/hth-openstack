# OpenStack Demoumgebung mit devstack

<img src="https://img.shields.io/badge/-Ubuntu%20Server-557C94?logo=ubuntu&logoColor=white&style=flat" /> <img src="https://img.shields.io/badge/-OpenStack-ee003e?logo=openstack&logoColor=white&style=flat" /> <img src="https://img.shields.io/badge/-Bash-3e484d?logo=gnu-bash&logoColor=white&style=flat" /> <img src="https://img.shields.io/badge/-Ansible-d5000e?logo=ansible&logoColor=white&style=flat" /> <img src="https://img.shields.io/badge/-Terraform-6543e2?logo=terraform&logoColor=white&style=flat" />

---
## Beschreibung
Hier ein kleiner Bericht über meine Erfahrungen Rund um OpenStack und devstack. Der Ganze Aufbau erfolgte bei mir auf einem älteren Laptop mit 2 Core CPU, 16GB RAM und 1 NIC.

Diese Dokumentation war ein kleiner Leitfaden<br>
[Installing OpenStack under Ubuntu 24.04](https://medium.com/@ion.stefanache0/installing-openstack-using-devstack-under-virgin-fresh-ubuntu-24-04-lts-e3790280359b)

---

### Laptop muss auf Nested Virtualisierung vorbereiten sein
```bash
## check nested virtualization on laptop
lscpu | grep Virtualization
# Virtualization: AMD-V

egrep -c '(vmx|svm)' /proc/cpuinfo
# >0 = OK

cat /sys/module/kvm_amd/parameters/nested
# File: /sys/module/kvm_amd/parameters/nested = 1
```

### Ubuntu Server Grundkonfiguration
```bash
## ubuntu updaten
sudo apt update & sudo apt upgrade -y

## copy ssh key into the vm
ssh-copy-id -i ~/.ssh/id_ed25519.pub hth@192.168.xxx.xxx
ssh hth@192.168.xxx.xxx

## hostnamen setzen
sudo hostnamectl set-hostname cloud.htdom.local
sudo vi /etc/hosts
# 127.0.1.1 cloud.htdom.local cloud

## Server durchstarten (optional)
sudo reboot

## Erste ssh Verbindung zum OpenStack Server
ssh cloud.htdom.local
```

### OpenStack Server vorbereitung
```bash
## Grundpakete installieren
sudo apt install git vim curl net-tools -y

## Wichtig für Keystone Tokens (Zeit muss passen)
timedatectl status
sudo timedatectl set-timezone Europe/Berlin
sudo timedatectl set-ntp true

## OpenStack User anlegen
sudo useradd -s /bin/bash -d /opt/stack -m stack
sudo chmod +x /opt/stack
echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack
sudo -u stack -i

## OpenStack/devstack Repo clonen
git clone https://opendev.org/openstack/devstack
cd devstack

## Minimal OpenStack/devstack Konfiguration (local.conf)
vi local.conf

# --- local.conf ---
[[local|localrc]]
ADMIN_PASSWORD=secret
DATABASE_PASSWORD=$ADMIN_PASSWORD
RABBIT_PASSWORD=$ADMIN_PASSWORD
SERVICE_PASSWORD=$ADMIN_PASSWORD

HOST_IP=192.168.xxx.xxx

# optional
LOGFILE=/opt/stack/logs/stack.sh.log
# --- local.conf ---

## OpenStack/devstack installation starten
./stack.sh
```

### OpenStack Dashboard (Horizon)
http://cloud.htdom.local/dashboard<br>
user: admin<br>
password: secret

### OpenStack über die CLI erkunden
```bash
## Environment laden
sudo -u stack -i
cd ~/devstack

source openrc admin admin

## Ein paar OpenStack default abfragen
openstack service list
openstack hypervisor list
openstack network list
openstack subnet list
openstack router list
openstack port list
openstack port show <PORT>
openstack server list
openstack image list
openstack image show cirros-x.x.x-x86_64-disk
openstack hypervisor show $(openstack hypervisor list -f value -c ID)
```

### In OpenStack das erste Image über CLI hochladen
```bash
## Verzeichnis für *.img dateien anlegen und dann nach glance hochladen
mkdir -p ~/images
cd ~/images

## Image downloaden
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

## Image in OpenStack bereitstellen
openstack image create "ubuntu-24.04-noble-server" \
  --file ~/images/noble-server-cloudimg-amd64.img \
  --disk-format qcow2 \
  --container-format bare \
  --public \
  --property os_type=linux

sudo ls -lh /opt/stack/data/glance/images
# ...
# -rw-r--r-- 1 stack stack 601M Apr  3 20:37 7e7ddec6-fb62-4139-b10a-f73225a0995b

openstack image list [--format value]
# ...
# 7e7ddec6-fb62-4139-b10a-f73225a0995b ubuntu-24.04-noble-server active

openstack image show ubuntu-24.04-noble-server [--format json,yaml,csv]
# {
#   ...
#   "container_format": "bare",
#   "disk_format": "qcow2",
#   "id": "7e7ddec6-fb62-4139-b10a-f73225a0995b",
#   "name": "ubuntu-24.04-noble-server",
#   "properties": {
#     ...
#     "os_type": "linux"
#   },
#   "status": "active",
#   ...
#   "visibility": "public"
# }
```

### In OpenStack die erste VM über CLI anlegen
```bash
## VM Type/Flavor auswählen
openstack flavor list

## SSH-Key lokal und in OpenStack anlegen
openstack keypair create ubuntu-ssh-key > ~/images/ubuntu-ssh-key.pem
chmod 600 ~/images/ubuntu-ssh-key.pem

## SSH Key überprüfen
openstack key list

## Wichtige Thema sind die Security Groups für den Zugriff auf die VM
openstack security group create sg-ssh
openstack security group rule create sg-ssh --ingress --protocol tcp --dst-port 22 --description "allow ssh access"

openstack security group create sg-web
for port in 80 443; do
  openstack security group rule create sg-web --ingress --protocol tcp --description "allow http/https access" --dst-port $port
done

## erste VM erstellen
openstack server create \
  --flavor ds1G \
  --image ubuntu-24.04-noble-server \
  --network admin \
  --security-group sg-ssh \
  --security-group sg-web \
  --key-name ubuntu-ssh-key \
  my-vm-01

## Für den externen Zugriff auf die VM benötigt es eine Floating-IP Adresse
FIP=$(openstack floating ip create public -f value -c floating_ip_address)
openstack server add floating ip my-vm-01 $FIP

openstack server list --format json
# [
#   {
#     "ID": "1e1aa371-36d5-47a3-91d1-456cc21695db",
#     "Name": "my-vm-01",
#     "Status": "ACTIVE",
#     "Networks": {
#       "dev-vpc": [
#         "172.16.1.110",
#         "192.168.xxx.xxx"
#       ]
#     },
#     "Image": "ubuntu-24.04-noble-server",
#     "Flavor": "ds1G"
#   }
# ]

## Verbindung in die VM per SSH (Floating IP ansprechen)
ssh -i ~/.ssh/ubuntu-ssh-key.pem ubuntu@192.168.xxx.xxx
# ubuntu@my-vm-01:~$
```
