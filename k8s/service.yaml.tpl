apiVersion: v1
kind: Service
metadata:
  name: scp-service
  namespace: ${K8S_NAMESPACE}
  labels:
    app: scp-app
spec:
  type: ClusterIP
  selector:
    app: scp-app
  ports:
    - name: http
      protocol: TCP
      port: 8080
      targetPort: 8080
