# Конфигурация frontend через ConfigMap

Дата проверки: `2026-07-18`

## Назначение

Runtime-конфигурация frontend отделена от образа контейнера. Kubernetes
ConfigMap `frontend-config` предоставляет файл `config.js`, который монтируется
в Pod по пути `/usr/share/nginx/html/config.js` только для чтения.

Конфигурация содержит версию интерфейса и относительный адрес API:

```javascript
window.APP_CONFIG = {
    frontendVersion: "v2-tls",
    apiBaseUrl: "/api",
};
```

URL `/api` остаётся относительным, поэтому браузер обращается к тому же
HTTPS-origin `dz6.local`; внешний HTTP не появляется.

## Реализация

ConfigMap описан декларативно в `k8s/frontend-configmap.yaml`. Deployment
использует отдельный том:

```yaml
volumes:
  - name: frontend-config
    configMap:
      name: frontend-config
```

Ключ `config.js` монтируется поверх одноимённого файла frontend:

```yaml
volumeMounts:
  - name: frontend-config
    mountPath: /usr/share/nginx/html/config.js
    subPath: config.js
    readOnly: true
```

Так как ConfigMap, смонтированный через `subPath`, не обновляет уже запущенный
Pod автоматически, в шаблон Pod добавлена аннотация
`checksum/frontend-config`. При изменении `config.js` значение checksum нужно
обновить в Deployment; изменение шаблона создаст новую ревизию и выполнит
контролируемый RollingUpdate.

## Проверка

Применение ресурсов:

```bash
kubectl apply --dry-run=server \
  -f frontend-configmap.yaml \
  -f frontend-deployment.yaml

kubectl apply -f frontend-configmap.yaml
kubectl apply -f frontend-deployment.yaml

kubectl rollout status deployment/frontend \
  -n homework \
  --timeout=300s
```

Проверка объекта, источника тома и фактического файла в контейнере:

```bash
kubectl get configmap frontend-config -n homework -o yaml

kubectl get deployment frontend -n homework \
  -o jsonpath='configMap={.spec.template.spec.volumes[?(@.name=="frontend-config")].configMap.name}{"\n"}mountPath={.spec.template.spec.containers[0].volumeMounts[?(@.name=="frontend-config")].mountPath}{"\n"}readOnly={.spec.template.spec.containers[0].volumeMounts[?(@.name=="frontend-config")].readOnly}{"\n"}'

POD=$(kubectl get pod \
  -n homework \
  -l app.kubernetes.io/name=frontend \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n homework "$POD" -- \
  cat /usr/share/nginx/html/config.js
```

Проверка внешнего HTTPS после rollout:

```bash
curl --fail --silent --show-error \
  --cacert /tmp/dz6-ca.crt \
  --resolve dz6.local:30443:192.168.56.12 \
  https://dz6.local:30443/config.js

CA_FILE=/tmp/dz6-ca.crt \
  ./infra/verify-https-only.sh
```

Ожидаемый результат: Deployment `2/2 Ready`, содержимое `/config.js` совпадает
с ConfigMap, а сквозная HTTPS-проверка завершается сообщением `PASS`.

## Вывод

Требование о конфигурации frontend через ConfigMap выполнено. Образ остаётся
неизменным, runtime-конфигурация хранится в Kubernetes-манифесте, а защищённый
тракт HTTPS-only сохраняется.
