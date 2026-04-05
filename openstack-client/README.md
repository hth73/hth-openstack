# OpenStack Client für den Remotezugriff

<img src="https://img.shields.io/badge/-Ubuntu%20Server-557C94?logo=ubuntu&logoColor=white&style=flat" /> <img src="https://img.shields.io/badge/-OpenStack-ee003e?logo=openstack&logoColor=white&style=flat" />

---
## Beschreibung
Hier eine kurze Anleitung wie man den OpenStack Client lokal auf dem Laptop installiert um Remote mit dem OpenStack Server zu arbeiten

### Installation und Konfiguration des Clients
```bash
## install
sudo apt install python3-openstackclient -y

## config
## Openstack UI --> Project --> API Access --> Download OpenStack cloud.yaml file

mkdir -p ~/.config/openstack
vi ~/.config/openstack/clouds.yaml

# -----
clouds:
  openstack-dev:
    auth:
      auth_url: http://cloud.htdom.local/identity
      username: "dev-user"
      password: secret
      project_id: 386220f37fe142fb97479e90fa997f07
      project_name: "dev"
      user_domain_name: "Default"
    region_name: "RegionOne"
    interface: "public"
    identity_api_version: 3

  openstack-adm:
    auth:
      auth_url: http://cloud.htdom.local/identity
      username: "admin"
      password: secret
      project_id: cd1076e2887b47878c88f1846261b030
      project_name: "admin"
      user_domain_name: "Default"
    region_name: "RegionOne"
    interface: "public"
    identity_api_version: 3
# -----

## alias in ~/.zshrc anlegen
function osdev () {
  export OS_CLOUD=openstack-dev
  env | grep OS_
}

function osadm () {
  export OS_CLOUD=openstack-adm
  env | grep OS_
}

osadm
OS_CLOUD=openstack-adm

osdev
OS_CLOUD=openstack-dev

openstack server list
+-------------------+------------+--------+---------------------------------------+---------------------------+--------+
| ID                | Name       | Status | Networks                              | Image                     | Flavor |
+-------------------+------------+--------+---------------------------------------+---------------------------+--------+
| 391054fb-cd00-... | vm-nginx-1 | ACTIVE | dev-vpc=172.16.1.110, 192.168.xxx.xxx | ubuntu-24.04-noble-server | ds512M |
+-------------------+------------+--------+---------------------------------------+---------------------------+--------+
```