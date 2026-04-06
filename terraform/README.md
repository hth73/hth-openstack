# Terraform Deployment - NGINX Webserver auf OpenStack

<img src="https://img.shields.io/badge/-Ubuntu%20Server-557C94?logo=ubuntu&logoColor=white&style=flat" /> <img src="https://img.shields.io/badge/-OpenStack-ee003e?logo=openstack&logoColor=white&style=flat" />  <img src="https://img.shields.io/badge/-Terraform-d5000e?logo=terraform&logoColor=white&style=flat" />

---
## Beschreibung
Automatisierter, reproduzierbarer Deployment-Prozess für einen NGINX Webserver auf OpenStack unter Nutzung eines vorgefertigten Golden Images.

Architektur
- Image Layer (Packer + Ansible)
- Basis-System + NGINX installiert
- Verzeichnisstruktur vorbereitet (/mnt/data)
- Service aktiviert (aber nicht gestartet)
- Runtime Layer (Terraform + cloud-init)
- Infrastruktur bereitstellen
- Volume anhängen und mounten
- Service starten

---

1. Image Auswahl<br>
   data "openstack_images_image_v2" Filterung über "name_regex" Verwendung<br> von "most_recent = true"

2. Netzwerk<br>
   data "openstack_networking_network_v2"

3. SSH Zugriff<br>
   Erstellung eines Keypairs: openstack_compute_keypair_v2<br>
   Nutzung eines lokalen ED25519 Keys (assets/)

4. Compute Instance<br>
   Erstellung einer VM mit: Flavor, Security Groups (sg-ssh, sg-web) und Netzwerkzuweisung.

5. Storage Integration<br>
     Root Disk (Image) - Boot über Image mittels block_device<br>
     source_type      = "image"<br>
     destination_type = "local"<br>
     boot_index       = 0<br>
     Data Volume (persistent)

   Attach eines bestehenden Volumes:<br>
     source_type      = "volume"<br>
     boot_index       = -1<br>
   Volume bleibt bei Destroy erhalten (delete_on_termination = false)

6. Floating IP<br>
   Dynamische Erstellung einer Floating IP<br>
   Zuordnung zur VM: openstack_compute_floatingip_associate_v2

7. cloud-init (Initialisierung)<br>
   Beim ersten Boot wird folgendes automatisch ausgeführt:<br>
     Warten auf Volume (/dev/vdb)<br>
     Filesystem erstellen (falls leer)<br>
     Mount nach /mnt/data<br>
     Berechtigungen setzen<br>
     Persistenter Mount via /etc/fstab<br>
     Start des NGINX Services

8. Variablenstruktur<br>
   Trennung von Code und Konfiguration über variables.tf

9. Outputs<br>
   Ausgabe wichtiger Informationen:<br>
     Floating IP<br>
     SSH Command
