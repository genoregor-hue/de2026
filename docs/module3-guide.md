# Модуль 3 — Эксплуатация облачных сервисов (ТЗ)

КОД 09.02.06-2-2026 · 1.5 ч · 25 баллов.
Источник: https://sys.digit-shop.ru/demo/2026/m3
> Пошаговая инструкция на сайте помечена «в разработке». Ниже состав задания.

KVM + cloud-init, Ansible, мониторинг Prometheus + Grafana + Node Exporter.

## Состав работ
1. HQ-CLI как нода управления KVM: ключи cloud.key/cloud.pub в /root/.ssh/, пакеты KVM+cloud-init.
2. cloud-init образ: user-data (sshuser + ключ, hostname vm<X>, DHCP), meta-data (instance-id).
3. KVM-гипервизор на CLOUD: NAT-сеть 192.168.123.0/24, пул .100–.200, шлюз .1; ВМ 1 vCPU/2 ГБ/10 ГБ.
4. Ansible update.yml: динамический inventory, обновление кэша пакетов.
5. Ansible inventory.yml: сбор (ядра, ОЗУ, диск, IPv4) → /ansible/inventory/vm_info.yml.
6. Мониторинг: Prometheus + Grafana в Docker, Node Exporter на ВМ, дашборд ID 1860,
   DNS cloud.au-team.irpo и grafana.au-team.irpo, проброс порта 3000.

## Ориентиры
```bash
ssh-keygen -t ed25519 -f /root/.ssh/cloud.key -N ""
cloud-localds seed.iso user-data meta-data
apt-get install -y libvirt qemu-kvm cloud-utils
# Grafana dashboard import ID 1860; node_exporter :9100, Grafana :3000
```
