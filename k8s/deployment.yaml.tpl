apiVersion: apps/v1
kind: Deployment
metadata:
  name: scp-app
  namespace: ${K8S_NAMESPACE}
  labels:
    app: scp-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scp-app
  template:
    metadata:
      labels:
        app: scp-app
    spec:
      imagePullSecrets:
        - name: gitlab-regcred
      containers:
        - name: scp-app
          image: ${IMAGE}
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: "${SPRING_PROFILE}"
          envFrom:
            - configMapRef:
                name: app-config
            - secretRef:
                name: app-secrets
