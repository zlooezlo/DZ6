# Версии и параметры стенда

## Базовый образ узлов

| Компонент | Значение |
|---|---|
| ОС | Ubuntu Server 24.04.4 LTS |
| Архитектура | x86_64 |
| Ядро | 6.8.0-134-generic |
| Container runtime | CRI-O 1.33.13 |
| Runtime до бонусной миграции | containerd 2.2.1 |
| kubeadm | v1.33.13 |
| kubelet | v1.33.13 |
| kubectl | v1.33.13 |
| Helm | v4.2.3 |
| NFS CSI driver | v4.13.4 (`nfs.csi.k8s.io`) |
| PostgreSQL | 15.18 (`postgres:15.18-alpine3.24`) |
| Cgroup driver containerd | systemd |
| Swap | отключён |

## План сети

| Назначение | Значение |
|---|---|
| VirtualBox NAT | первый адаптер каждого узла |
| Host-only сеть | `192.168.56.0/24` |
| Host-only адрес хоста | `192.168.56.1` |
| kube1 | `192.168.56.11` |
| kube2 | `192.168.56.12` |
| kube3 | `192.168.56.13` |
| Kubernetes Pod CIDR | `10.244.0.0/16` |
| Kubernetes Service CIDR | `10.96.0.0/12` |

Pod CIDR выбран так, чтобы он не пересекался с Host-only сетью VirtualBox.
