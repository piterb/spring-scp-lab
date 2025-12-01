apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: scp-ingress
  namespace: ${K8S_NAMESPACE}
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: ${APP_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: scp-service
                port:
                  number: 8080
