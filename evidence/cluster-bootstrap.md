# Bootstrap control plane и CNI

## Control plane

Control plane инициализирован на `kube1` с Kubernetes `v1.33.13` и
containerd `2.2.1`.

```text
NAME    STATUS   ROLES           VERSION    INTERNAL-IP
kube1   Ready    control-plane   v1.33.13   192.168.56.11
```

API server слушает порт `6443`, а kubelet находится в состоянии `active`.

## Calico

Установлен Calico Open Source `v3.32.1`. Для выбора адреса узла используется
`IP_AUTODETECTION_METHOD=kubernetes-internal-ip`, поскольку первый адаптер
VirtualBox работает через NAT, а межузловая сеть проходит через Host-only
адреса `192.168.56.0/24`.

После установки CNI:

```text
calico-kube-controllers   1/1   Running
calico-node               1/1   Running   192.168.56.11
coredns                   1/1   Running   10.244.18.1
coredns                   1/1   Running   10.244.18.2
```

Оба rollout завершились успешно. Токены и join-команды в Git не сохраняются.

## Worker-узлы

После выполнения `kubeadm join` оба worker-узла перешли в состояние `Ready`:

```text
NAME    STATUS   ROLES           VERSION    INTERNAL-IP
kube1   Ready    control-plane   v1.33.13   192.168.56.11
kube2   Ready    worker          v1.33.13   192.168.56.12
kube3   Ready    worker          v1.33.13   192.168.56.13
```

DaemonSet `calico-node` достиг состояния `3/3 Ready`, а `kube-proxy`
запущен на каждом узле.

## Smoke test сети и DNS

Тестовые Pod были принудительно размещены на разных worker-узлах:

```text
NAME            STATUS    IP             NODE
toolbox-kube2   Running   10.244.2.65    kube2
toolbox-kube3   Running   10.244.9.129   kube3
```

CoreDNS разрешил имя Kubernetes API Service:

```text
Name:    kubernetes.default.svc.cluster.local
Address: 10.96.0.1
```

Проверка ICMP от Pod на `kube2` до Pod на `kube3` завершилась без потерь:

```text
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 1.239/1.486/1.898 ms
```
