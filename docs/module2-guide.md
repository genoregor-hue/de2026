# Модуль 2 — Организация сетевого администрирования (с командами)

КОД 09.02.06-1-2026 · 1.5 ч · 25 баллов · 11 заданий.
Источник: https://sys.digit-shop.ru/demo/2026/m2
Адресация: HQ-SRV 192.168.100.2, BR-SRV 192.168.0.2, сеть HQ-CLI 192.168.200.0/24.

---

## Задание 1 — Samba DC (домен au-team.irpo)
5 пользователей hquser1-5, группа hq, члены hq логинятся на HQ-CLI, sudo только cat/grep/id.

### BR-SRV — provisioning
```bash
apt-get update && apt-get install -y task-samba-dc
rm -f /etc/samba/smb.conf && rm -rf /var/lib/samba/ /var/cache/samba/ && mkdir -p /var/lib/samba/sysvol
samba-tool domain provision
# Realm [AU-TEAM.IRPO]: Enter | Domain [AU-TEAM]: Enter | Role [dc]: Enter
# DNS backend [SAMBA_INTERNAL]: Enter | forwarder [77.88.8.8]: Enter
# Administrator password: <пароль> (дважды)
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
systemctl enable --now samba.service
sed -i -e "s/^search.*/search au-team.irpo/" -e "s/^nameserver.*/nameserver 127.0.0.1/" /etc/resolv.conf
samba-tool domain info 127.0.0.1
kinit Administrator; klist
```
### Группа и пользователи
```bash
samba-tool group add hq
for i in {1..5}; do
  samba-tool user add hquser$i P@ssw0rd
  samba-tool user setexpiry hquser$i --noexpiry
  samba-tool group addmembers "hq" hquser$i
done
samba-tool group listmembers hq
```
### HQ-RTR — DNS в DHCP на BR-SRV
```bash
sed -i "s/option domain-name-servers .*/option domain-name-servers 192.168.0.2;/" /etc/dhcp/dhcpd.conf
systemctl restart dhcpd.service
```
### HQ-CLI — ввод в домен
```bash
sed -i "s/nameserver.*/nameserver 192.168.0.2/" /etc/resolv.conf
apt-get update && apt-get install -y task-auth-ad-sssd
# ЦУС → Пользователи → Аутентификация → Домен AD: au-team.irpo, имя hq-cli, SSSD → пароль Administrator
echo "session required pam_mkhomedir.so skel=/etc/skel umask=0022" >> /etc/pam.d/system-auth
getent passwd hquser1; getent group hq
echo "Cmnd_Alias SHELLCMD = /bin/cat, /bin/grep, /usr/bin/id" > /etc/sudoers.d/hq
echo "%hq ALL=(ALL:ALL) SHELLCMD" >> /etc/sudoers.d/hq
```

---

## Задание 2 — RAID 0 (HQ-SRV)
```bash
mdadm --create /dev/md0 -l 0 -n 2 /dev/sdb /dev/sdc
mdadm --detail --scan --verbose | tee -a /etc/mdadm.conf
mkfs.ext4 /dev/md0
echo "/dev/md0 /raid ext4 defaults 0 0" >> /etc/fstab
mkdir /raid && mount -av
```

## Задание 3 — NFS
### HQ-SRV
```bash
apt-get install -y nfs-server
mkdir /raid/nfs && chmod -R 777 /raid/nfs
echo "/raid/nfs 192.168.200.0/24(rw,no_root_squash)" > /etc/exports
exportfs -arv && systemctl enable --now nfs-server.service
```
### HQ-CLI
```bash
mkdir /mnt/nfs && chmod -R 777 /mnt/nfs
echo "192.168.100.2:/raid/nfs /mnt/nfs nfs defaults,_netdev 0 0" >> /etc/fstab
mount -av
```

## Задание 4 — Chrony NTP
### ISP (сервер, stratum 5)
```bash
sed -i 's/^pool/#pool/' /etc/chrony.conf
cat <<E >> /etc/chrony.conf
server ntp0.ntp-servers.net iburst prefer minstratum 4
local stratum 5
allow 0.0.0.0/0
E
systemctl restart chronyd && chronyc tracking
```
### Клиенты (HQ → 172.16.1.1, BR → 172.16.2.1)
```bash
sed -i "s/^pool/#pool/" /etc/chrony.conf
echo "server 172.16.1.1 iburst" >> /etc/chrony.conf
systemctl restart chronyd && chronyc sources
```

## Задание 5 — Ansible (BR-SRV)
```bash
apt-get install -y ansible sshpass
cat <<E > /etc/ansible/ansible.cfg
[defaults]
inventory = /etc/ansible/hosts
host_key_checking = False
E
cat <<E > /etc/ansible/hosts
HQ-SRV ansible_host=192.168.100.2 ansible_user=sshuser ansible_password=P@ssw0rd ansible_port=2026
HQ-CLI ansible_host=192.168.200.2 ansible_user=admin ansible_password=toor ansible_port=22
HQ-RTR ansible_host=10.10.10.1 ansible_user=net_admin ansible_password=P@ssw0rd ansible_port=22
BR-RTR ansible_host=192.168.0.1 ansible_user=net_admin ansible_password=P@ssw0rd ansible_port=22
[all:vars]
ansible_python_interpreter=/usr/bin/python3
E
cd /etc/ansible/ && ansible -m ping all
```

## Задание 6 — Docker testapp (BR-SRV)
```bash
apt-get install -y docker-engine docker-compose-v2
systemctl enable --now docker.service
mount /dev/sr0 /mnt/
docker load < /mnt/docker/site_latest.tar
docker load < /mnt/docker/mariadb_latest.tar
# compose.yaml: app (site:latest, порт 8080:8000) + db (mariadb:10.11)
#   db env: MARIADB_DATABASE=testdb, USER=testc, PASSWORD=P@ssw0rd, ROOT_PASSWORD=toor
#   app env: DB_HOST=192.168.0.2, DB_NAME=testdb, DB_USER=testc, DB_PASS=P@ssw0rd
docker compose up -d && docker compose ps
```

## Задание 7 — LAMP (HQ-SRV)
```bash
apt-get install -y lamp-server
mount /dev/sr0 /mnt/
cp /mnt/web/index.php /mnt/web/logo.png /var/www/html/
# в index.php: user=webc, password=P@ssw0rd, dbname=webdb
systemctl enable --now mariadb
mariadb -u root <<SQL
CREATE DATABASE webdb;
CREATE USER 'webc'@'localhost' IDENTIFIED BY 'P@ssw0rd';
GRANT ALL PRIVILEGES ON webdb.* TO 'webc'@'localhost' WITH GRANT OPTION;
SQL
mariadb -u webc --password='P@ssw0rd' -D webdb < /mnt/web/dump.sql
systemctl enable --now httpd2.service
```

## Задание 8 — Проброс портов (DNAT)
### HQ-RTR (8080→HQ-SRV:80, 2026→HQ-SRV:2026)
```bash
iptables -t nat -A PREROUTING -i enp0s3 -p tcp --dport 2026 -j DNAT --to-destination 192.168.100.2:2026
iptables -t nat -A PREROUTING -i enp0s3 -p tcp --dport 8080 -j DNAT --to-destination 192.168.100.2:80
iptables -t nat -A POSTROUTING -d 192.168.100.2 -p tcp --dport 2026 -j MASQUERADE
iptables -t nat -A POSTROUTING -d 192.168.100.2 -p tcp --dport 80 -j MASQUERADE
iptables-save >> /etc/sysconfig/iptables
```
### BR-RTR (8080→BR-SRV:8080, 2026→BR-SRV:2026) — аналогично на 192.168.0.2

## Задание 9 — Nginx reverse proxy (ISP)
```bash
apt-get install -y nginx
cat <<E > /etc/nginx/sites-available.d/default.conf
server { listen 80; server_name web.au-team.irpo;    location / { proxy_pass http://172.16.1.2:8080; } }
server { listen 80; server_name docker.au-team.irpo; location / { proxy_pass http://172.16.2.2:8080; } }
E
ln -s /etc/nginx/sites-available.d/default.conf /etc/nginx/sites-enabled.d/
systemctl enable --now nginx
```

## Задание 10 — Web-auth (ISP, basic auth WEB/P@ssw0rd)
```bash
apt-get install -y apache2-htpasswd
htpasswd -bc /etc/nginx/.htpasswd WEB P@ssw0rd
# в server web.au-team.irpo добавить в location:
#   auth_basic "Restricted area"; auth_basic_user_file /etc/nginx/.htpasswd;
systemctl restart nginx.service
```

## Задание 11 — Yandex Browser (HQ-CLI)
```bash
apt-get update && apt-get install -y yandex-browser-stable
```
