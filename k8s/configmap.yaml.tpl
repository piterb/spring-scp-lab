apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: ${K8S_NAMESPACE}
data:
  # sample CI/CD Variables
  EXT_SYSTEM1_URL: "${EXT_SYSTEM1_URL}"
  FEATURE_X_ENABLED: "${FEATURE_X_ENABLED}"
