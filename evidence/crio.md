# Миграция container runtime на CRI-O

## Исходное состояние

После первоначальной установки все три узла использовали containerd `2.2.1`:

```text
NAME    STATUS   RUNTIME              KUBELET
kube1   Ready    containerd://2.2.1   v1.33.13
kube2   Ready    containerd://2.2.1   v1.33.13
kube3   Ready    containerd://2.2.1   v1.33.13
```

Состояние зафиксировано на снимке
`dz6-01-containerd-before-crio-2026-07-16.png`.

Перед изменением runtime созданы согласованные выключенные snapshots трёх VM:
`pre-crio-2026-07-16`.

## Установка и переключение

Использован официальный репозиторий CRI-O `stable:v1.33`. На каждом узле
установлен и зафиксирован пакет `cri-o=1.33.13-1.1`. Версия CRI-O совпадает с
minor и patch версией Kubernetes:

```text
RuntimeName:       cri-o
RuntimeVersion:    1.33.13
RuntimeApiVersion: v1
cgroup_manager:    systemd
```

Перед переключением каждого worker выполнялся `kubectl drain`. Endpoint kubelet
изменён в `/var/lib/kubelet/kubeadm-flags.env`:

```text
--container-runtime-endpoint=unix:///var/run/crio/crio.sock
```

Исходный файл сохранён как
`/var/lib/kubelet/kubeadm-flags.env.containerd-backup`. После переключения
containerd отключён, но пакет оставлен для диагностического отката. CRI-O и
kubelet включены в systemd.

При переключении kube3 kubelet сначала продолжал обращаться к старому сокету
containerd. Причина определена по `journalctl`: endpoint не был изменён в
`kubeadm-flags.env`. После исправления endpoint kubelet подключился к CRI-O, а
узел вернулся в Ready. Ошибка не повлияла на приложение, поскольку kube3 был
заранее осушён.

Kube1 одновременно является control plane и NFS-сервером. Перед его
перезагрузкой PostgreSQL масштабирован до нуля, чтобы корректно отключить NFS
том. После восстановления API Server и NFS StatefulSet возвращён к одной
реплике, прежний PVC подключён повторно.

## Проверка workers

На kube2 и kube3 отдельно запускался BusyBox Pod с nodeSelector. Обе проверки
подтвердили создание контейнера через CRI-O, выдачу Pod IP Calico и DNS:

```text
containerID: cri-o://<container-id>
Server:      10.96.0.10
Name:        kubernetes.default.svc.cluster.local
Address:     10.96.0.1
CRI-O networking works
```

Системные DaemonSet Pod `calico-node`, `kube-proxy` и `csi-nfs-node` на обоих
workers перешли в Ready до выполнения `uncordon`.

## Итоговое состояние

```text
NAME    STATUS   RUNTIME         KUBELET
kube1   Ready    cri-o://1.33.13 v1.33.13
kube2   Ready    cri-o://1.33.13 v1.33.13
kube3   Ready    cri-o://1.33.13 v1.33.13
```

PostgreSQL после миграции работает на kube3, а исходный том остался Bound:

```text
pod/postgres-0                               1/1 Running  kube3
persistentvolumeclaim/postgres-data-postgres-0  Bound    2Gi  nfs-csi
```

Итог зафиксирован на снимке
`dz6-05-all-nodes-crio-2026-07-16.png`. Переход PostgreSQL между workers во
время drain и сохранённая контрольная строка показаны на снимке
`dz6-04-kube3-drain-postgresql-rescheduled-2026-07-16.png`.
