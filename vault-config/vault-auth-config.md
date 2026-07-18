# Vault Kubernetes Auth Configuration

## Auth Method
- Path: `kubernetes/`
- Type: `kubernetes`
- kubernetes_host: `https://kubernetes.default.svc`
- kubernetes_ca_cert: `@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`

## Role: homework-backend
- bound_service_account_names: `["vault-auth"]`
- bound_service_account_namespaces: `["homework"]`
- policies: `["homework-db-read"]`
- ttl: `10m`
- max_ttl: `30m`
- audience: `vault`
