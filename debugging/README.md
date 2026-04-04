# OpenStack Debugging

<img src="https://img.shields.io/badge/-Ubuntu%20Server-557C94?logo=ubuntu&logoColor=white&style=flat" /> <img src="https://img.shields.io/badge/-OpenStack-ee003e?logo=openstack&logoColor=white&style=flat" /> <img src="https://img.shields.io/badge/-Bash-3e484d?logo=gnu-bash&logoColor=white&style=flat" />

---
## Beschreibung
Die initiale Einrichtung von OpenStack/DevStack verlief nicht wirklich stabil und erforderte mehrere Anläufe. Hauptursachen waren Probleme in den Bereichen Datenbank, Virtualisierung und insbesondere OpenStack Networking.

- Bei der ersten Installation unter Ubuntu 24.04 trat ein Problem mit MySQL 8 auf. Die Standard-Authentifizierungsmethoden (z. B. "auth_socket") verhinderten eine klassische Benutzername/Passwort-Anmeldung, die DevStack jedoch erwartet. Dadurch schlug die Installation wiederholt fehl und verursachte erhöhten Debug-Aufwand. Die praktikable Lösung bestand darin, auf PostgreSQL ("DATABASE_TYPE=postgresql") umzusteigen.

- Ein weiteres Problem ergab sich durch die Nutzung von VirtualBox. Obwohl Nested Virtualisierung theoretisch unterstützt wird, funktionierte sie in der Praxis nicht zuverlässig. OpenStack nutzte dadurch nur QEMU ohne KVM-Beschleunigung, was zu extrem hoher CPU-Last führte. 
Beim Start einer VM fror der gesamte Host ein. Die Erkenntnis daraus, VirtualBox ist für OpenStack-Lab-Umgebungen ungeeignet, stattdessen sollte Baremetal, VMware Workstation oder eine native KVM-Umgebung verwendet werden.

- Das größte Problem lag jedoch im Netzwerkdesign. DevStack erstellt standardmäßig ein externes Netzwerk im Bereich ("172.24.4.0/24"), das auf NAT basiert und nicht Teil des realen Heimnetzwerks ist. In Kombination mit Open Virtual Network (OVN), Open vSwitch (OVS) und einer Single-NIC-Umgebung führte dazu, dass Floating IPs zwar existierten, aber nicht erreichbar waren. Der Datenverkehr vom Laptop wurde verworfen, da weder der lokale Router noch das System selbst eine Route zu diesem künstlichen Netzwerk hatten.

- Die Lösung bestand darin, das DevStack-Standardnetz vollständig zu ersetzen und ein sogenanntes Provider Network zu verwenden. Dazu wurde die physische Netzwerkkarte ("eth0") in die OVS-Bridge ("br-ex") integriert und die IP-Adresse vom Interface auf die Bridge verschoben. Anschließend wurde das Default-External-Network entfernt und ein neues Netzwerk im realen Heimnetz ("192.168.xxx.xxx/24") erstellt. Dadurch erhielten die Floating IPs, Adressen aus dem echten LAN.

- Nach dieser Umstellung war die VM direkt im Layer2-Netzwerk erreichbar. Der Zugriff funktionierte ohne NAT über ARP-Auflösung, sodass SSH und Ping sofort möglich waren.

### Hardware muss Nested Virtualisierung unterstützen
```bash
## check nested virtualization on laptop
lscpu | grep Virtualization
# Virtualization: AMD-V oder VT-x

egrep -c '(vmx|svm)' /proc/cpuinfo
# >0 = OK

cat /sys/module/kvm_amd/parameters/nested
# File: /sys/module/kvm_amd/parameters/nested = 1
oder
cat /sys/module/kvm_intel/parameters/nested = Y
# File: /sys/module/kvm_intel/parameters/nested = Y

## Wenn nested virtualization nicht unterstützt wird (0 oder N)
## Unbedingt im BIOS alles für die Virtualisierung einschalten!
##
sudo rmmod kvm_intel
sudo rmmod kvm
sudo modprobe kvm_intel nested=1

## Dauerhaft speichern
echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm-intel.conf
sudo update-initramfs -u
sudo reboot

# ---

sudo rmmod kvm_amd
sudo modprobe kvm_amd nested=1

## Dauerhaft speichern
echo "options kvm_amd nested=1" | sudo tee /etc/modprobe.d/kvm_amd.conf
sudo update-initramfs -u
sudo reboot

## check nested virtualization inside vm
##
sudo apt install cpu-checker -y
kvm-ok
# KVM acceleration can be used
```

### Sollte das devstack Setup abbrechen (Neuinstallation)
```bash
## Sollte das devstack Setup abbrechen, dann nochmal alles von vorne
##
cd /opt/stack/devstack
./unstack.sh
./clean.sh

oder

sudo rm -rf /opt/stack/*
git clone https://opendev.org/openstack/devstack /opt/stack/devstack
cd /opt/stack/devstack

## Minimal-Konfiguration (local.conf)
vi kocal.conf

# --- local.conf ---
[[local|localrc]]
ADMIN_PASSWORD=secret
DATABASE_PASSWORD=$ADMIN_PASSWORD
RABBIT_PASSWORD=$ADMIN_PASSWORD
SERVICE_PASSWORD=$ADMIN_PASSWORD

HOST_IP=192.168.xxx.54

# optional
LOGFILE=/opt/stack/logs/stack.sh.log
# --- local.conf ---

## OpenStack/devstack installation starten
./stack.sh
```

### Netzwerk fixen
```bash
ip a
sudo ip addr flush dev eno1
sudo ovs-vsctl add-port br-ex eno1
sudo ip addr add 192.168.xxx.54/24 dev br-ex
sudo ip link set br-ex up
# sudo ip route add default via 192.168.xxx.1
sudo ip route replace default via 192.168.xxx.1

ip a
# 2: eno1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc ...
# ...
# 6: br-ex: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc ...
#     inet 192.168.xxx.54/24 scope global br-ex

# ---

# WORKAROUND nach Server REBOOT
# bridge (br-ex) verliert IP Adresse
# eno1 bekommt ebenfalls keine IP Adresse zugewiesen

cat /etc/netplan/50-cloud-init.yaml

network:
  version: 2
  renderer: networkd

  ethernets:
    eno1:
      dhcp4: false

# ---

cat /etc/systemd/system/dhclient-br-ex.service

[Unit]
Description=DHCP on br-ex
After=network.target openvswitch-switch.service
Wants=openvswitch-switch.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/dhcpcd br-ex
RemainAfterExit=true

[Install]
WantedBy=multi-user.target

# ---

sudo systemctl daemon-reload
sudo systemctl enable dhclient-br-ex.service
sudo systemctl status dhclient-br-ex.service
```

### OpenStack Netzwerk konfigurieren
```bash
# --------------------------------------------------
# Environment laden
# --------------------------------------------------
source openrc admin admin
env | grep OS_

## Danach die vorhanden Netzwerke anpassen/löschen (admin)
##
# openstack router remove subnet <router> <subnet>
# openstack router unset --external-gateway <router>
# openstack subnet delete <subnet>
# openstack network delete <network>

openstack network delete public # (172.16.24.0./24) ggf. Ports und Subnetze löschen
openstack network delete shared # (192.168.233.0/24) ggf. Ports und Subnetze löschen

# --------------------------------------------------
# OpenStack Network configuration
# --------------------------------------------------

## neues Public Netzwerk anlegen (admin)
##
openstack network create public \
  --external \
  --provider-network-type flat \
  --provider-physical-network public

openstack subnet create public-subnet \
  --network public \
  --subnet-range 192.168.xxx.0/24 \
  --gateway 192.168.xxx.1 \
  --allocation-pool start=192.168.xxx.200,end=192.168.xxx.220 \
  --no-dhcp

## OVN nutzt encapsulation (Geneve) - 
## Geneve Overhead ≈ 50–60 Bytes daher die MTU nicht auf 1500 setzen - LAN 1500/OVN 1442
# ---------------------
# Layer       | MTU
# ---------------------
# VM          | 1442
# OVN overlay | ~1442
# physisch    | 1500
# ---------------------

openstack network create dev-net --mtu 1442
openstack network show dev-net | grep mtu

openstack subnet create dev-subnet \
  --network dev-net \
  --subnet-range 172.16.1.0/24 \
  --dns-nameserver 192.168.xxx.1

openstack router create dev-router
openstack router set dev-router --external-gateway public
openstack router add subnet dev-router dev-subnet
```

### OpenStack Projekt anlegen
```bash
## neues Projekt anlegen (dev)
##
openstack project create dev
openstack project list
openstack user create dev-user --password secret
openstack role add --project dev --user dev-user member

## Environment anpassen für (dev)
cp ~/devstack/openrc ~/devstack/openrc-dev
sudo vi ~/devstack/openrc-dev

# Minimal configuration anpassen
export OS_AUTH_TYPE=password
export OS_PROJECT_NAME=dev
export OS_USERNAME=dev-user
export OS_PASSWORD=secret

# ---

source openrc-dev dev dev-user
env | grep OS_
```

### OpenStack Address Groups/Security Groups
In OpenStack werden bei der Erstellung von Security Group Regeln häufig als Standard offene Bereiche wie 0.0.0.0/0 (IPv4) oder ::/0 (IPv6) verwendet. Das bedeutet, dass der jeweilige Port für den gesamten Adressraum erreichbar ist, sowohl für Ingress als auch für Egress.

Wenn dies nicht gewünscht ist, sollten die Regeln auf spezifische IP-Adressen oder Subnetze eingeschränkt werden. Dadurch wird der Zugriff gezielt begrenzt und die Angriffsfläche reduziert.

An dieser Stelle kommen Address Groups ins Spiel. Eine Address Group ist eine Sammlung von IP-Adressen oder Subnetzen, die zentral definiert wird. Diese kann anschließend in Security Group Regeln referenziert werden. Statt eine Regel direkt auf 0.0.0.0/0 oder ein festes Subnetz zu setzen, wird die Address Group als Ziel (Remote) verwendet.

Vorteile dieses Ansatzes:

- Zentrale Verwaltung von erlaubten IPs/Subnetzen
- Wiederverwendbarkeit in mehreren Security Groups
- Einfachere Wartung bei Änderungen

Ändert sich beispielsweise eine IP-Adresse oder kommt ein weiteres Subnetz hinzu, muss nur die Address Group angepasst werden. Die zugehörigen Security Group Regeln bleiben unverändert und übernehmen automatisch die neue Konfiguration.

```bash
## Address Groups definieren (ähnlich Prefix-lists in AWS)
##
openstack address group create ag-lan --address "192.168.xxx.0/24" --description "local subnet"
# openstack address group add address ag-lan 10.0.1.0/24
# openstack address group add address ag-lan 172.16.1.25

openstack address group list
openstack address group show ag-lan
# +-----------------+--------------------------------------+
# | Field           | Value                                |
# +-----------------+--------------------------------------+
# | addresses       | ['192.168.xxx.0/24']                 |
# | created_at      | 2026-04-03T13:48:57Z                 |
# | description     | local subnet                         |
# | id              | d2415a1c-c9f6-4bc1-9431-75dc12bb08bf |
# | name            | ag-lan                               |
# | project_id      | 386220f37fe142fb97479e90fa997f07     |
# | revision_number | 1                                    |
# | updated_at      | 2026-04-03T13:48:58Z                 |
# +-----------------+--------------------------------------+

## Zuweisung mit dem Parameter --remote-address-group [ag-lan]
openstack security group create sg-ssh
openstack security group rule create sg-ssh --ingress --protocol tcp --dst-port 22 --remote-address-group ag-lan --description "allow ssh access"

openstack security group create sg-web
for port in 80 443; do
  openstack security group rule create sg-web --ingress --protocol tcp --remote-address-group ag-lan --description "allow http/https access" --dst-port $port
done

## Zuweisung der Address Group für die Security Group überprüfen (UI zeigt diese leider nicht an, hier erscheint 0.0.0.0/0 als Zuweisung)

## Daher müssen wir die ID der Address Group heraussuchen und gegenprüfen ob die Security Group auch wirklich auf die Address Group verweist.
##
openstack address group list --format value
d2415a1c-c9f6-...bf ag-lan ... ['192.168.xxx.0/24']

openstack security group rule list sg-web -f json | jq -r '.[]'
# {
#   "ID": "88ee9bbb-c681-495f-9887-71d96f401d0a",
#   "IP Protocol": "tcp",
#   ...
   "Remote Address Group": "d2415a1c-c9f6-...bf"
# }

sudo ovn-nbctl find acl | grep "d2415a1c"
# match: "outport ... $ag_d2415a1c_c9f6_...bf ... == 80"

# match: "outport ... $ag_d2415a1c_c9f6_...bf ... == 443"
```

### Nützliche OpenStack Debug Befehle
```bash
# --------------------------------------------------
# OpenStack debugging
# --------------------------------------------------

sudo systemctl | grep devstack                                                 
#   devstack@c-api.service                            loaded active running   Devstack devstack@c-api.service
#   devstack@c-sch.service                            loaded active running   Devstack devstack@c-sch.service
#   devstack@c-vol.service                            loaded active running   Devstack devstack@c-vol.service
#   devstack@dstat.service                            loaded active running   Devstack devstack@dstat.service
#   devstack@etcd.service                             loaded active running   Devstack devstack@etcd.service
#   devstack@g-api.service                            loaded active running   Devstack devstack@g-api.service
#   devstack@keystone.service                         loaded active running   Devstack devstack@keystone.service
#   devstack@n-api-meta.service                       loaded active running   Devstack devstack@n-api-meta.service
#   devstack@n-api.service                            loaded active running   Devstack devstack@n-api.service
#   devstack@n-cond-cell1.service                     loaded active running   Devstack devstack@n-cond-cell1.service
#   devstack@n-cpu.service                            loaded active running   Devstack devstack@n-cpu.service
#   devstack@n-novnc-cell1.service                    loaded active running   Devstack devstack@n-novnc-cell1.service
#   devstack@n-sch.service                            loaded active running   Devstack devstack@n-sch.service
#   devstack@n-super-cond.service                     loaded active running   Devstack devstack@n-super-cond.service
#   devstack@neutron-api.service                      loaded active running   Devstack devstack@neutron-api.service
#   devstack@neutron-ovn-maintenance-worker.service   loaded active running   Devstack devstack@neutron-ovn-maintenance-worker.service
#   devstack@neutron-periodic-workers.service         loaded active running   Devstack devstack@neutron-periodic-workers.service
#   devstack@neutron-rpc-server.service               loaded active running   Devstack devstack@neutron-rpc-server.service
#   devstack@placement-api.service                    loaded active running   Devstack devstack@placement-api.service
#   devstack@q-ovn-agent.service                      loaded active running   Devstack devstack@q-ovn-agent.service
#   system-devstack.slice                             loaded active active    Slice /system/devstack

sudo journalctl -u devstack@glance-api
sudo journalctl -u devstack@n-cpu
sudo journalctl -u devstack@nova-compute

sudo journalctl -u devstack@glance-api --since "5 min ago" -f
sudo journalctl -u devstack@glance-api --since "1 min ago"

sudo journalctl -u devstack@glance-api -p err --since "5 min ago"
sudo journalctl -f -u devstack@glance-api -u devstack@n-cpu

sudo journalctl -f | grep -E "glance|nova"
```


