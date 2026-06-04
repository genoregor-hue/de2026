# Решение проблем при запуске скриптов

Реальные ошибки, которые вылезали на стенде (Альт 11.1, VirtualBox), и как чинить.

## 1. `sysctl: команда не найдена` (строка с ip_forward)
Причина: зашёл под root через `su` БЕЗ дефиса — не подгрузился PATH с /sbin.
Решение — заходи правильно:
```bash
su -          # с дефисом! промпт должен стать [root@... ]#  (решётка, не $)
which sysctl  # должно показать /sbin/sysctl
```
Или разово добавить путь (если уже зашёл):
```bash
export PATH=$PATH:/sbin:/usr/sbin
```
(Внимание: PATH, не PATCH. Если затёр PATH — восстанови: `export PATH=/usr/bin:/bin:/usr/sbin:/sbin`)

## 2. `Failed to set time zone: No such file or directory`
Причина: запуск НЕ под root, timedatectl не может записать зону.
Решение — под root, либо вручную симлинком:
```bash
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
```

## 3. `ens20: FAILED`, `ens21: FAILED` — адреса не встали
Причина: имена интерфейсов в скрипте НЕ совпадают с реальными на стенде.
В VirtualBox обычно enp0s3 / enp0s8 / enp0s9 (а не ens19/ens20/ens21).
Решение:
```bash
ip -br link                    # посмотреть реальные имена
python3 generate.py --ask      # ввести правильные имена интерфейсов
bash out/<роль>.sh             # запустить пересобранный скрипт
```
Если уже записались конфиги для несуществующих интерфейсов — удали:
```bash
rm -rf /etc/net/ifaces/ens20 /etc/net/ifaces/ens21
systemctl restart network
```

## 4. `vim: виртуальный пакет предоставляется многими`
Не критично (vim обычно уже стоит как vim-console). Если нужен:
```bash
apt-get install -y vim-console
```

## 5. `bash: bash: команда не найдена` после export
Затёр PATH опечаткой (`$PATCH` вместо `$PATH`). Восстанови:
```bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
```

## 6. Репозиторий не находится под root (`cd ~/de2026` — нет каталога)
Клонировал под юзером (isp), а зашёл под root. Репо в /home/<юзер>:
```bash
cd /home/isp/de2026
```

## 7. На роутере скрипт падает `exit 1` — "No internet"
HQ-RTR/BR-RTR проверяют интернет и останавливаются, если его нет.
Сначала должен быть настроен ISP, и линк до него поднят. Проверь:
```bash
ping -c2 172.16.1.1     # с HQ-RTR до ISP (или 172.16.2.1 с BR-RTR)
```
Если не пингуется — проблема в сети VirtualBox (адаптеры VM должны быть
в одной Internal Network между ISP и роутером).

## Общее правило запуска (чтобы не ловить эти ошибки)
```bash
su -                          # под root, с дефисом
cd /home/<юзер>/de2026
ip -br link                   # сверить интерфейсы
python3 generate.py --ask     # если интерфейсы не ens19/20/21 — ввести свои
bash out/<роль>.sh            # или setup/<роль>.sh если данные совпадают
```
Порядок машин: ISP → HQ-RTR → HQ-SRV → BR-RTR → BR-SRV → HQ-CLI.
