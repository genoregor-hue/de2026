# Модуль 1 — Настройка сетевой инфраструктуры (гайд)

КОД 09.02.06-1-2026 · 1 ч · 25 баллов · 11 пунктов.
Источник: https://sys.digit-shop.ru/demo/2026/m1

Топология: два офиса (HQ, BR) через ISP, GRE-туннель между роутерами, домен au-team.irpo.

## Адресация (по умолчанию в скриптах)
| Сегмент | Сеть | Узлы |
|---|---|---|
| ISP→HQ | 172.16.1.0/28 | ISP .1, HQ-RTR .2 |
| ISP→BR | 172.16.2.0/28 | ISP .1, BR-RTR .2 |
| VLAN 100 (серверы) | 192.168.100.0/27 | HQ-RTR .1, HQ-SRV .2 |
| VLAN 200 (клиенты, DHCP) | 192.168.200.0/28 | HQ-RTR .1, HQ-CLI DHCP |
| VLAN 999 (управление) | 192.168.99.0/29 | HQ-RTR .1 |
| BR-LAN | 192.168.0.0/28 | BR-RTR .1, BR-SRV .2 |
| GRE-туннель | 10.10.10.0/30 | HQ .1, BR .2 |

VLAN tag 100/200 для HQ-SRV и HQ-CLI задаётся В PROXMOX/VirtualBox (на сетевой карте VM).
На HQ-RTR — router-on-a-stick (сабинтерфейсы enpXsY.100/.200/.999).

## 11 пунктов
1. FQDN-имена, приватная адресация (RFC1918), размеры подсетей.
2. ISP: WAN по DHCP, динамический NAT (MASQUERADE) для офисов.
3. Учётки: sshuser (UID 2026, sudo NOPASSWD) на серверах, net_admin на роутерах.
4. VLAN 100/200/999, router-on-a-stick на HQ-RTR.
5. SSH на HQ-SRV/BR-SRV: порт 2026, только sshuser, MaxAuthTries 2, баннер.
6. GRE-туннель HQ↔BR.
7. OSPF только на туннеле + парольная защита (authentication-key 1245).
8. NAT на HQ-RTR и BR-RTR в сторону ISP.
9. DHCP на HQ-RTR для VLAN 200 (шлюз HQ-RTR, DNS HQ-SRV, суффикс au-team.irpo).
10. DNS (BIND) на HQ-SRV: прямая зона + 2 обратные, forwarder 77.88.8.8.
11. Часовой пояс на всех.

## Запуск
```bash
su -
cd /home/<юзер>/de2026
ip -br link                  # сверить интерфейсы (в VirtualBox enp0s3/8/9)
python3 generate.py --ask    # ввести свои интерфейсы/данные
bash out/<роль>.sh
```
Порядок: ISP → HQ-RTR → HQ-SRV → BR-RTR → BR-SRV → HQ-CLI.
Проблемы при запуске — см. TROUBLESHOOTING.md
