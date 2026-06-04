# Интерфейсы и generate.py — как заполнять

На разных стендах интерфейсы называются по-разному:
- VirtualBox: обычно `enp0s3`, `enp0s8`, `enp0s9`
- другие: `ens19/ens20/ens21`, `eth0/eth1/eth2`

**На КАЖДОЙ машине сначала смотри реальные имена:**
```bash
ip -br link
```

## Сколько интерфейсов на какой машине
| Машина | Сколько | Назначение |
|---|---|---|
| ISP | 3 | WAN (интернет) + к HQ-RTR + к BR-RTR |
| HQ-RTR | 2 | к ISP + trunk (VLAN) |
| BR-RTR | 2 | к ISP + к BR-SRV |
| HQ-SRV | 1 | в сеть VLAN 100 |
| BR-SRV | 1 | в сеть BR-LAN |
| HQ-CLI | 1 | в сеть VLAN 200 (DHCP) |

---

## Способ 1 — отредактировать CONFIG (проще, рекомендуется)

Открой generate.py, найди блок `CONFIG = {` вверху. Поменяй ТОЛЬКО имена
интерфейсов под свой стенд (значения справа в кавычках), сохрани. Затем:
```bash
python3 generate.py        # без --ask, соберёт все 6 скриптов в out/
```
Поля интерфейсов в CONFIG:
```
"isp_if_wan":  "enp0s3"    # ISP: к интернету
"isp_if_hq":   "enp0s8"    # ISP: к HQ-RTR
"isp_if_br":   "enp0s9"    # ISP: к BR-RTR
"rtr_if_wan":  "enp0s3"    # роутеры: к ISP
"hqrtr_if_lan":"enp0s8"    # HQ-RTR: trunk (VLAN)
"brrtr_if_lan":"enp0s8"    # BR-RTR: к BR-SRV
"srv_if":      "enp0s3"    # серверы/клиент: единственный интерфейс
```
Один раз вписал — годится для всех машин (generate.py делает все 6 скриптов сразу,
а каждая машина берёт свой out/<роль>.sh).

---

## Способ 2 — через --ask (вопросы по очереди)

```bash
python3 generate.py --ask
```
Спрашивает ВСЕ поля подряд (~30 штук). Правило простое:
**на нужное поле вписываешь значение, на все остальные — просто Enter.**

Какие поля заполнять для интерфейсов (остальное Enter):

**ISP** — три поля:
```
isp_if_wan [...]: enp0s3
isp_if_hq  [...]: enp0s8
isp_if_br  [...]: enp0s9
```
**HQ-RTR** — два:
```
rtr_if_wan   [...]: enp0s3
hqrtr_if_lan [...]: enp0s8
```
**BR-RTR** — два:
```
rtr_if_wan   [...]: enp0s3
brrtr_if_lan [...]: enp0s8
```
**HQ-SRV / BR-SRV / HQ-CLI** — одно:
```
srv_if [...]: enp0s3
```

> В квадратных скобках `[...]` показано текущее значение. Enter = оставить его.
> Если ошибся — просто запусти `python3 generate.py --ask` заново.

---

## Запуск после генерации
```bash
su -                       # под root (с дефисом!)
cd /home/<юзер>/de2026
bash out/<роль>.sh         # напр. bash out/isp.sh
```
