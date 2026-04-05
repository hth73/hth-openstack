# OpenStack Images mit Packer beritstellen

<img src="https://img.shields.io/badge/-Ubuntu%20Server-557C94?logo=ubuntu&logoColor=white&style=flat" /> <img src="https://img.shields.io/badge/-OpenStack-ee003e?logo=openstack&logoColor=white&style=flat" /> <img src="https://img.shields.io/badge/-Bash-3e484d?logo=gnu-bash&logoColor=white&style=flat" /> <img src="https://img.shields.io/badge/-Packer-00a9eb?logo=packer&logoColor=white&style=flat" /> <img src="https://img.shields.io/badge/-Ansible-d5000e?logo=ansible&logoColor=white&style=flat" />

---
## Beschreibung
Für den späteren Aufbau von Virtuellen Maschinen mit Terraform, benötigt es in OpenStack Betriebssystemimages die man verwenden kann.

Folgende Formate werden von OpenStack unterstützt

- QCOW2 (QEMU Copy On Write): Das am weitesten verbreitete Format. Es ist speichereffizient, da die Datei nur so groß ist wie der tatsächlich belegte Speicherplatz (thin provisioning).
- RAW: Ein bitgenaues Abbild der Festplatte. RAW-Images bieten oft eine bessere Performance, sind aber nicht speichereffizient (fixed size).
- VHD/VMDK/VDI: Formate, die von anderen Virtualisierungslösungen (Hyper-V, VMware, VirtualBox) stammen. Diese müssen oft in QCOW2 oder RAW konvertiert werden, da nicht alle Hypervisor sie direkt unterstützen.
- ISO: Wird typischerweise verwendet, um Betriebssystem-Installationsmedien zu booten.
- AKI/ARI/AMI: Ältere Formate aus der Amazon EC2-Welt.

Bekannte Quellen für betriebssystemimages:

- Debian: https://cloud.debian.org/images/cloud
- Ubuntu: https://cloud-images.ubuntu.com
- Fedora: https://fedoraproject.org/cloud/download
- CentOS: https://cloud.centos.org/centos

### QCOW2 Image in OpenStack bereitstellen
```bash
## Verzeichnis für *.img Dateien anlegen und dann nach OpenStack Glance (Image-Service) hochladen.
mkdir -p ~/images
cd ~/images

## Image downloaden
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

## Image in OpenStack bereistellen
openstack image create "ubuntu-24.04-noble-server" \
  --file ~/images/noble-server-cloudimg-amd64.img \
  --disk-format qcow2 \
  --container-format bare \
  --public \
  --property os_type=linux

## Image anzeigen lassen
openstack image list
```

### Golden Image mit Packer und Ansible bearbeiten
Um eine Immutable Infrastructure zu betreiben, sind zwei Schritte erforderlich:

1. Image-Build (Golden Image)
Einmal pro Woche wird mit Packer und Ansible ein neues Golden Image erzeugt. Dieses enthält alle aktuellen Betriebssystem- und Software-Updates der jeweiligen Woche.

2. Re-Deployment der Infrastruktur
Die bestehenden virtuellen Server werden regelmäßig durch neue Instanzen ersetzt, die auf dem aktuellen Golden Image basieren.

Vorteile:

- Kein klassisches Patchmanagement auf laufenden Systemen erforderlich
- Konsistenter, reproduzierbarer Systemzustand
- Verbesserte Recovery-Fähigkeit durch jederzeit neu deploybare Systeme

```bash
## packer init für die benötigten Provider
packer init packer/templates/ubuntu-nginx.pkr.hcl

## packer build um das Image in Openstack zu bauen
packer build packer/templates/ubuntu-nginx.pkr.hcl

# openstack.ubuntu-nginx-image: output will be in this color.

# ==> openstack.ubuntu-nginx-image: Loading flavor: ds512M
# ==> openstack.ubuntu-nginx-image: Creating temporary keypair: packer_69d229de-6164-f827-fd15-6210573ecafb ...
# ==> openstack.ubuntu-nginx-image: Found Image ID: 7e7ddec6-fb62-4139-b10a-f73225a0995b
# ==> openstack.ubuntu-nginx-image: Launching server...
```
