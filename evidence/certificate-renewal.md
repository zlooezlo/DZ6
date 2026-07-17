# Замена сертификатов Kubernetes

## Цель

Выполнить плановую замену сертификатов кластера, подтвердить изменение сертификата API Server и проверить работоспособность Kubernetes и приложения после ротации.

Дата выполнения: `2026-07-17`
Узел управления: `kube1` (`192.168.56.11`)
Kubernetes: `v1.33.13`
Среда выполнения контейнеров: `CRI-O 1.33.13`

## Резервное копирование

Перед заменой создана полная резервная копия `/etc/kubernetes`:

```text
/root/etc-kubernetes-complete-before-renewal-20260717T153309Z.tar.gz
```

Контрольная сумма архива:

```text
197c73b683dc5ec1b4f83ec34a99fd6026d8e4a01d367316ee26b12333bf6c17
```

Наличие критичных файлов в архиве проверено командой `tar -tzf`. В копию вошли:

- сертификат и ключ API Server;
- `admin.conf`;
- манифесты `etcd`, `kube-apiserver`, `kube-controller-manager` и `kube-scheduler`;
- остальные файлы каталога `/etc/kubernetes`.

Архив имеет права `0600`, хранится только на `kube1` и не добавляется в Git, поскольку содержит закрытые ключи и административные данные.

## Состояние до замены

Параметры сертификата `/etc/kubernetes/pki/apiserver.crt`:

```text
subject=CN = kube-apiserver
issuer=CN = kubernetes
serial=29CDB30278C842D9
sha256 Fingerprint=55:EB:00:C9:85:13:91:3F:9B:13:EA:77:18:8F:B4:8B:61:24:EC:E0:D3:88:87:58:21:1B:61:1F:B9:7D:DE:33
notBefore=Jul 15 20:36:41 2026 GMT
notAfter=Jul 15 20:41:41 2027 GMT
```

Отпечаток корневого CA до замены:

```text
84:78:24:9C:B6:8D:0F:70:5A:25:BA:8C:E3:FB:BB:A2:7C:B2:91:16:B1:D1:C1:FF:CC:0A:A1:BE:F1:06:B3:9D
```

Проверка выполнялась командами:

```bash
sudo kubeadm certs check-expiration

sudo openssl x509 \
  -in /etc/kubernetes/pki/apiserver.crt \
  -noout \
  -subject \
  -issuer \
  -serial \
  -fingerprint -sha256 \
  -dates
```

## Замена сертификатов

Сертификаты, управляемые kubeadm, обновлены командой:

```bash
sudo kubeadm certs renew all
```

Чтобы компоненты начали использовать новые файлы, static Pods последовательно перезапущены временным перемещением соответствующих манифестов из `/etc/kubernetes/manifests` и их последующим возвратом.

Контейнеры действительно были пересозданы:

| Компонент | Старый container ID | Новый container ID |
| --- | --- | --- |
| etcd | `ed2afb0f0d4640fad0ef5cc76372ff9e34ab3b2a128bb00a9bdccd732452b2a4` | `fad8666e304c7d5f9b782bd93dfda92d4495471ddba4750a14d3f434c67730e0` |
| kube-apiserver | `c4e6feff5005760d9fe9d76150a83f34f573e6c82c6497d4b95748c01c05d098` | `9a41022868d79733d24f84c43937a5ffb390da3764f70a6436e6081684a213f6` |
| kube-controller-manager | `4b77f76266f404195a89b185fe742a9a510fbfc143a7f897aab81c2d22490312` | `efb26ae8a71d1784e809ce7edfd63af08545546be8748f5e7344dc729880d974` |
| kube-scheduler | `32fd24a39c1dbf3b22f6209ca572ae1a38fdd791972f9e7bfb3cda905027ba82` | `05f913208600bc1f5f3e105a6419e4de9a7e0dd1d57bba24d5b4bfc469cb306f` |

После ротации пользовательский kubeconfig заменён актуальной копией `/etc/kubernetes/admin.conf`. Его резервная копия хранится локально с правами `0600` и не добавляется в Git.

## Состояние после замены

Новый сертификат API Server:

```text
subject=CN = kube-apiserver
issuer=CN = kubernetes
serial=68C8310DDE329F63
sha256 Fingerprint=3C:11:1B:4A:3A:C4:E2:8C:94:D5:69:52:CA:62:D0:11:56:FC:F4:02:DD:A5:90:EE:A3:48:F1:00:86:93:04:F1
notBefore=Jul 17 15:40:32 2026 GMT
notAfter=Jul 17 15:45:32 2027 GMT
```

Отпечаток корневого CA после замены:

```text
84:78:24:9C:B6:8D:0F:70:5A:25:BA:8C:E3:FB:BB:A2:7C:B2:91:16:B1:D1:C1:FF:CC:0A:A1:BE:F1:06:B3:9D
```

Результат сравнения:

- serial сертификата изменился;
- SHA-256 fingerprint сертификата изменился;
- корневой CA не изменился;
- срок действия новых сертификатов продлён до `2027-07-17`.

## Проверка активного TLS-сертификата

Проверен не только файл на диске, но и сертификат, фактически выдаваемый API Server на порту `6443`:

```bash
openssl s_client \
  -connect 127.0.0.1:6443 \
  -servername kube1 \
  </dev/null 2>/dev/null \
  | openssl x509 \
      -noout \
      -serial \
      -fingerprint -sha256 \
      -dates
```

Отпечатки файла и активного TLS-сертификата совпали:

```text
Файл:  3C:11:1B:4A:3A:C4:E2:8C:94:D5:69:52:CA:62:D0:11:56:FC:F4:02:DD:A5:90:EE:A3:48:F1:00:86:93:04:F1
TLS:    3C:11:1B:4A:3A:C4:E2:8C:94:D5:69:52:CA:62:D0:11:56:FC:F4:02:DD:A5:90:EE:A3:48:F1:00:86:93:04:F1
PASS: API Server использует новый сертификат
```

## Проверка кластера и приложения

После замены выполнены проверки:

```bash
kubectl get --raw='/readyz'
kubectl get nodes
kubectl get pods -n kube-system -o wide
kubectl get pods -n homework -o wide
sudo kubeadm certs check-expiration
```

Результаты:

- API Server вернул `ok`;
- `kube1`, `kube2` и `kube3` находятся в состоянии `Ready`;
- системные Pods находятся в состоянии `Running`;
- backend, frontend и PostgreSQL находятся в состоянии `Running`;
- PVC PostgreSQL и NFS CSI продолжили работать.

Внешний запрос к приложению после замены также успешно обработан:

```bash
curl -fsS \
  -H 'Host: dz6.local' \
  -X POST \
  http://192.168.56.12:30080/api/visits
```

Ответ:

```json
{"pod":"backend-cf9b5c578-8xxx5","total":296,"version":"v1","visit_id":296}
```

## Итог

Сертификаты Kubernetes заменены штатными средствами kubeadm. Изменение сертификата API Server подтверждено serial и SHA-256 fingerprint до и после операции. Совпадение нового файла с сертификатом активного TLS-соединения доказано отдельно. Корневой CA сохранён, узлы и рабочие нагрузки после перезапуска функционируют штатно.

Справочная документация: [Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/).
