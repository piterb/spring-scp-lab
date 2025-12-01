apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: ${K8S_NAMESPACE}
type: Opaque
stringData:
  DB_PASSWORD: "${DB_PASSWORD}"
  PAYMENT_API_KEY: "${PAYMENT_API_KEY}"
