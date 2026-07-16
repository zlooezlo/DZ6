# NFS и динамическое хранилище

## NFS-сервер

Стандартный NFS-сервер запущен на `kube1` (`192.168.56.11`). Каталог
`/srv/nfs/k8s` экспортирован только в Host-only сеть `192.168.56.0/24`.
Клиенты используют NFSv4.2; чтение и запись проверены с `kube2` и `kube3`.

```text
/srv/nfs/k8s  192.168.56.0/24(rw,sync,no_subtree_check,root_squash)
```

## NFS CSI driver

Helm `v4.2.3` установил официальный NFS CSI driver `v4.13.4`. Controller
работает на `kube1`, а DaemonSet запустил node-плагин на каждом из трёх узлов.
Драйвер зарегистрирован под именем `nfs.csi.k8s.io`; StorageClass использует
политику `Retain` и NFSv4.2.

```text
NAME                PROVISIONER       RECLAIMPOLICY   VOLUMEBINDINGMODE
nfs-csi (default)   nfs.csi.k8s.io    Retain          Immediate
```

## Проверка PVC и сохранности данных

PVC автоматически получил PV через StorageClass `nfs-csi`:

```text
NAME            STATUS   CAPACITY   ACCESS MODES   STORAGECLASS
nfs-smoke-pvc   Bound    256Mi      RWX            nfs-csi
```

Объект PV подтверждает, что том создан CSI-драйвером:

```text
NAME                                       DRIVER           STATUS
pvc-908a7417-b82c-40f1-a5b0-26ffccd2b539   nfs.csi.k8s.io   Bound
```

Первый Pod `nfs-writer-5ffd669b7c-5zzpr` записал файл `proof.txt`. После его
удаления Deployment создал Pod `nfs-writer-5ffd669b7c-25m24`, который прочитал
исходное содержимое:

```text
CSI создал Thu Jul 16 09:44:45 UTC 2026 в Pod nfs-writer-5ffd669b7c-5zzpr
```

Разные имена Pod и неизменившаяся строка подтверждают, что данные находятся
на NFS PersistentVolume, а не в файловой системе контейнера. Счётчики restart
компонентов CSI не увеличивались более 100 минут после установки.
