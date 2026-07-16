# Инфраструктура

Здесь будут скрипты подготовки Ubuntu Server и заметки по трём VirtualBox VM:

- `kube1` — control plane;
- `kube2` — worker;
- `kube3` — worker.

## NFS

На `kube1` NFS-сервер настраивается командой:

```bash
sudo ./infra/setup-nfs-server.sh
```

Официальный NFS CSI driver устанавливается с зафиксированной версией chart:

```bash
helm repo add csi-driver-nfs \
  https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update

helm upgrade --install csi-driver-nfs \
  csi-driver-nfs/csi-driver-nfs \
  --version 4.13.4 \
  --namespace kube-system \
  --values infra/nfs-csi-values.yaml \
  --wait \
  --timeout 10m

kubectl apply -f k8s/storageclass-nfs-csi.yaml
```

Проверка динамического PVC:

```bash
kubectl apply -f k8s/storage-smoke-test.yaml
```
