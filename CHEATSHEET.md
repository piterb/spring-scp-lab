# SCP Module 0 – Cheatsheet prostredia (WIP)

Tento súbor je priebežný cheatsheet k nášmu Spring + Docker + Kubernetes prostrediu.
Budeme ho postupne dopĺňať podľa toho, čo v kurze použijeme.

---

## Obsah

- [1. Základný setup na Macu](#1-základný-setup-na-macu)
  - [1.1 Homebrew](#11-homebrew)
  - [1.2 SSH kľúče (macOS)](#12-ssh-kľúče-macos)
- [2. Docker](#2-docker)
- [3. Kubernetes – kind + kubectl](#3-kubernetes--kind--kubectl)
  - [3.1 Inštalácia nástrojov](#31-inštalácia-nástrojov)
  - [3.2 Vytvorenie a zmazanie clustra](#32-vytvorenie-a-zmazanie-clustra)
  - [3.3 Základné kubectl príkazy](#33-základné-kubectl-príkazy)
- [4. Deploy lokálneho Docker image do kind](#4-deploy-lokálneho-docker-image-do-kind)
- [4. Dockerfile pre Spring Boot aplikáciu](#4-dockerfile-pre-spring-boot-aplikáciu)
- [5. YAML manifesty (Deployment + Service)](#5-yaml-manifesty-deployment--service)
  - [5.1 Deployment (scp-app)](#51-deployment-scp-app)
  - [5.2 Service (scp-service)](#52-service-scp-service)
  - [5.3 Aplikovanie manifestov](#53-aplikovanie-manifestov)
- [6. Prístup k aplikácii (bez Ingress) – port-forward](#6-prístup-k-aplikácii-bez-ingress--port-forward)
- [7. Ingress NGINX – inštalácia, debug a konfigurácia](#7-ingress-nginx--inštalácia-debug-a-konfigurácia)
  - [7.1 Inštalácia Ingress NGINX pre kind](#71-inštalácia-ingress-nginx-pre-kind)
  - [7.2 Riešenie stavu Pending (nodeSelector  label)](#72-riešenie-stavu-pending-nodeselector--label)
  - [7.3 Ingress resource pre aplikáciu](#73-ingress-resource-pre-aplikáciu)
  - [7.4 Port-forward na Ingress Controller (HTTP vstup cez Ingress)](#74-port-forward-na-ingress-controller-http-vstup-cez-ingress)
  - [7.5 Alternatívny port-forward (priame volanie Service – obchádza Ingress)](#75-alternatívny-port-forward-priame-volanie-service--obchádza-ingress)
- [8. Git – základné príkazy](#8-git--základné-príkazy)

---

## 1. Základný setup na Macu

### 1.1 Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

> Inštalácia Homebrew (package manager pre macOS).

```bash
echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/usr/local/bin/brew shellenv)"
```

> Pridanie Homebrew do PATH (Intel Mac).

```bash
brew --version
```

> Overenie, že Homebrew funguje.

### 1.2 SSH kľúče (macOS)

Vytvorenie nového SSH kľúča (Ed25519) + pridanie do agenta a configu:

```bash
ssh-keygen -t ed25519 -C "tvoje-meno@priklad.sk"
```

> Vytvorí kľúč `~/.ssh/id_ed25519` a public `~/.ssh/id_ed25519.pub`.

```bash
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

> Spustí `ssh-agent` a uloží kľúč do macOS Keychain (automatické načítanie).

```bash
ssh-add -l
```
 
> Overi, ze je kluc nacitany

```bash
cat <<'EOF' >> ~/.ssh/config
Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
```

> Základný config, aby sa kľúč pridal do agenta a používal sa automaticky.

```bash
pbcopy < ~/.ssh/id_ed25519.pub
```

> Skopíruje public kľúč do schránky (na pridanie do GitHub/GitLab).

---

## 2. Docker

*(Predpoklad: Docker Desktop nainštalovaný manuálne cez .dmg installer.)*

```bash
docker --version
```

> Overenie, že Docker CLI funguje.

Spustenie lokálneho kontajnera zo Spring Boot image:

```bash
docker build -t spring-scp-lab:local .
```

> Build Docker image z aktuálneho adresára (použije `Dockerfile`).

```bash
docker run --rm -p 8080:8080 spring-scp-lab:local
```

> Spustenie kontajnera, mapovanie portu host: 8080 → kontajner: 8080.

```bash
docker images | grep spring-scp-lab
```

> Kontrola, že image `spring-scp-lab:local` existuje.

---

## 3. Kubernetes – kind + kubectl

### 3.1 Inštalácia nástrojov

```bash
brew install kind
```

> Inštalácia kind (Kubernetes-in-Docker) cez Homebrew.

```bash
brew install kubectl
```

> Inštalácia kubectl klienta.

```bash
kind --version
kubectl version --client
```

> Overenie verzií nástrojov.

### 3.2 Vytvorenie a zmazanie clustra

```bash
kind create cluster --name scp-lab
```

> Vytvorenie kind clustra s názvom `scp-lab` (default konfigurácia).

```bash
kind delete cluster --name scp-lab
```

> Zmazanie clustra `scp-lab`.

### 3.3 Základné kubectl príkazy

```bash
kubectl get nodes
```

> Zoznam node-ov v clustri.

```bash
kubectl get pods
kubectl get pods -A
```

> Zoznam podov v aktuálnom namespace / vo všetkých namespaces.

```bash
kubectl get svc
```

> Zoznam Services v aktuálnom namespace.

```bash
kubectl describe pod <pod-name>
```

> Detail podu (vrátane Events – kľúčové pri debugovaní Pending/CrashLoopBackOff).

---

## 4. Deploy lokálneho Docker image do kind

```bash
kind load docker-image spring-scp-lab:local --name scp-lab
```

> Nahratie lokálneho Docker image do kind clustra, aby ho node vedel použiť.

---

## 4. Dockerfile pre Spring Boot aplikáciu

Súbor: `Dockerfile`

```dockerfile
# 1. Build stage – Gradle image s JDK 17
FROM gradle:8.9-jdk17 AS builder
WORKDIR /app
COPY . .
RUN gradle clean bootJar --no-daemon

# 2. Runtime stage – Java runtime (JRE 17)
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Popis riadkov:**

* **gradle:8.9-jdk17** – image s Gradle + Java 17, vhodný na build.
* `COPY . .` – prenesie celý projekt do image.
* `gradle clean bootJar` – vytvorí jar súbor v `build/libs`.
* **eclipse-temurin:17-jre** – ľahší runtime image (JRE, nie JDK).
* `COPY --from=builder` – prenesie vybuildovaný jar z prvého image.
* `ENTRYPOINT ["java", "-jar", "app.jar"]` – spustí Spring Boot.

---

## 5. YAML manifesty (Deployment + Service)

### 5.1 Deployment (scp-app)

Súbor: `k8s/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scp-app
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
      containers:
        - name: scp-app
          image: spring-scp-lab:local
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
```

> Definuje, že chceme 1 Pod s kontajnerom zo Spring Boot image `spring-scp-lab:local`.

### 5.2 Service (scp-service)

Súbor: `k8s/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: scp-service
spec:
  type: ClusterIP
  selector:
    app: scp-app
  ports:
    - port: 8080
      targetPort: 8080
```

> Vytvorí internú službu `scp-service` v clustri – load-balancer na Pod(y) s `app=scp-app`.

### 5.3 Aplikovanie manifestov

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

> Vytvorenie/aktualizácia Deploymentu a Service v clustri.

```bash
kubectl get pods
kubectl get svc
```

> Kontrola, či Pod beží a Service existuje.

---

## 6. Prístup k aplikácii (bez Ingress) – port-forward

```bash
kubectl port-forward svc/scp-service 8080:8080
```

> Vytvorí tunel z `localhost:8080` na Service `scp-service:8080` v clustri.

Potom v prehliadači:

* `http://localhost:8080/hello`

---

## 7. Ingress NGINX – inštalácia, debug a konfigurácia

### 7.1 Inštalácia Ingress NGINX pre kind

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/kind/deploy.yaml
```

> Nainštaluje NGINX Ingress Controller do clustra (namespace `ingress-nginx`). Manifest pre KIND obsahuje `nodeSelector`, preto sa musí node označiť `ingress-ready=true`.

```bash
kubectl get pods -n ingress-nginx
```

> Kontrola stavu podov.

### 7.2 Riešenie stavu Pending (nodeSelector / label)

Ak `describe pod` ukazuje:

```
0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector.
```

→ node nemá požadovaný label.

Pridaj label na node:

```bash
kubectl label node scp-lab-control-plane ingress-ready=true
```

> Tento label je nutný, pretože Ingress Controller v manifeste obsahuje `nodeSelector: ingress-ready=true`.

Overenie:

```bash
kubectl get nodes --show-labels
```

---

### 7.3 Ingress resource pre aplikáciu

Súbor: `k8s/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: scp-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: scp-service
                port:
                  number: 8080
```

> Ingress hovorí: všetky HTTP requesty na `/` preposlať na `scp-service:8080`.

Aplikovanie:

```bash
kubectl apply -f k8s/ingress.yaml
```

Kontrola:

```bash
kubectl get ingress
```

---

### 7.4 Port-forward na Ingress Controller (HTTP vstup cez Ingress)

```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8081:80
```

> Forwarduje **localhost:8081 → Ingress Controller:80**.
> Vyvolá kompletný reťazec: Ingress → Service → Pod (Spring Boot).

Test:

```
http://localhost:8081/hello
```

---

### 7.5 Alternatívny port-forward (priame volanie Service – obchádza Ingress)

```bash
kubectl port-forward svc/scp-service 8080:8080
```

> Priamy tunel na Service, **Ingress sa nepoužije**.
> Vhodné na rýchle debugovanie Spring Boot aplikácie bez Ingress vrstvy.

Test:

```
http://localhost:8080/hello
```

--- (vývojársky prístup zvonku)

```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8081:80
```

> Vytvorí HTTP vstup cez Ingress (nie priamo Service).

Test:

```
http://localhost:8081/hello
```

---

*(Len to, čo sme už reálne použili.)*

### 7.1 Inštalácia Ingress NGINX pre kind

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/kind/deploy.yaml
```

> Nainštaluje NGINX Ingress Controller do clustra (namespace `ingress-nginx`).

```bash
kubectl get pods -n ingress-nginx
```

> Kontrola stavu Ingress Controller podov.

### 7.2 Riešenie stavu Pending (nodeSelector / label)

```bash
kubectl describe pod <ingress-nginx-controller-pod> -n ingress-nginx
```

> Zobrazenie Events – napr. `node(s) didn't match Pod's node affinity/selector`.

```bash
kubectl label node scp-lab-control-plane ingress-ready=true
```

> Pridanie labelu `ingress-ready=true` na node, aby mohol ingress-nginx controller bežať (nodeSelector).

---

## 8. Git – základné príkazy

### 8.1 Overenie stavu repozitára

```bash
git status
```

> Zobrazí, ktoré súbory boli zmenené alebo čakajú na commit.

### 8.2 Pridanie súborov do staging

```bash
git add <subor>
```

```bash
git add .
```

> Pridá všetky zmenené súbory do staging oblasti.

### 8.3 Commit

```bash
git commit -m "Popis zmeny"
```

> Uloží staged zmeny do commit histórie.

### 8.4 Push na remote vetvu

```bash
git push origin <branch>
```

> Odošle commitnuté zmeny na GitLab.

```bash
git push --all origin
```

> Odošle commitnuté zmeny vo vsetkych vetvach na vsetky vetvy v danom remote

### 8.5 Stiahnutie zmien z remote

```bash
git pull
```

> Stiahne zmeny z remote repozitára a mergne ich.

### 8.6 Prepnutie vetvy

```bash
git checkout <branch>
```

> Prepnutie medzi vetvami.

### 8.7 Vytvorenie novej vetvy

```bash
git checkout -b <nova-branch>
```

> Vytvorí novú vetvu a prepne na ňu.

### 8.8 Zobrazenie commit histórie

```bash
git log --oneline --graph --decorate --all
```

> Prehľadná vizualizácia histórie.

### 8.9 Porovnanie zmien

```bash
git diff
```

> Zobrazí rozdiely oproti poslednému commitu.

### 8.10 Remote repozitár

```bash
git remote -v
```

> Zobrazí nastavené remote repozitáre.

```bash
git remote add origin git@gitlab.com:username/projekt.git
```

> Pridá nový remote.

---

## 8. Kubernetes Dashboard (GUI)

### 8.1 Inštalácia oficiálneho Kubernetes Dashboardu

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

> Nasadí oficiálny Kubernetes Dashboard do clustra (namespace `kubernetes-dashboard`).

Overenie:

```bash
kubectl get pods -n kubernetes-dashboard
kubectl get svc -n kubernetes-dashboard
```

---

### 8.2 Port-forward na Dashboard (HTTPS)

Dashboard beží ako HTTPS endpoint na porte 443. Pre prístup z hosta použijeme port-forward:

```bash
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard 9090:443
```

> Forwarduje `localhost:9090 → kubernetes-dashboard:443` (HTTPS).

V prehliadači potom otvor:

```text
https://localhost:9090
```

> Browser môže hlásiť nevalidný certifikát (self-signed) – pre lokálne dev prostredie je bezpečné ho ignorovať.

---

### 8.3 Admin používateľ a token (nový spôsob na moderných verziách K8s)

#### 1) Vytvorenie ServiceAccount a ClusterRoleBinding

Súbor: `dashboard-adminuser.yaml`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: admin-user
    namespace: kube-system
```

Aplikovanie:

```bash
kubectl apply -f dashboard-adminuser.yaml
kubectl get sa -n kube-system | grep admin-user
```

#### 2) Vygenerovanie tokenu (nový mechanizmus)

Na novších verziách Kubernetes sa token nevytvára automaticky ako Secret. Namiesto toho použijeme:

```bash
kubectl -n kube-system create token admin-user
```

Príkaz vypíše JWT token (jeden dlhý riadok). Ten skopíruj a v Dashboarde zvoľ:

* spôsob prihlásenia: **Token**
* vlož token
* **Sign in**

---

## 9. Lens – Kubernetes Desktop GUI (odporúčaný nástroj)

### 9.1 Inštalácia Lens na macOS

Najjednoduchšia cesta cez Homebrew:

```bash
brew install --cask lens
```

> Nainštaluje desktopovú aplikáciu Lens – Kubernetes IDE.

Aplikáciu spustíš cez Spotlight (`Lens`) alebo cez Applications.

---

### 9.2 Prihlásenie / licencie

* Lens môže zobrazovať prihlasovacie okno pri prvom spustení.
* **Na základné používanie nie je potrebná platená licencia.**
* Môžeš buď:

    * kliknúť **“Continue without signing in”** / **“Skip for now”**, alebo
    * vytvoriť si bezplatný Lens účet (nič neplatíš), ktorý umožní prístup do aplikácie.

Konfigurácia K8s clusterov zostáva 100% zadarmo.

---

### 9.3 Pripojenie Lens k tvojmu KIND clustru

Lens automaticky načíta contexty z `~/.kube/config` – teda rovnaké, ktoré používa `kubectl`.

Overenie contextov:

```bash
kubectl config get-contexts
```

> Mal by si vidieť context typu `kind-scp-lab`.

V Lense:

* otvor sekciu **Clusters**
* vyber context `kind-scp-lab`
* klikni **Connect**

---

### 9.4 Čo v Lense uvidíš

* **Nodes** (napr. `scp-lab-control-plane`)
* **Workloads** → Deployments, ReplicaSets, Pods
* **Networking** → Services, Ingresses
* **Configuration** → ConfigMaps, Secrets
* Logy konkrétneho Podu jedným klikom
* Port-forward GUI (zjednodušenie oproti CLI)
* Vizualizáciu Events (to isté čo `kubectl describe pod`)

Lens výrazne zjednodušuje orientáciu v Kubernetes clustri počas vývoja.

---

## 10. Poznámky

* Tento cheatsheet je WIP – budeme ho postupne dopĺňať o:

    * Ingress resource (routing na `scp-service`)
    * kind konfiguračný súbor s prednastaveným labelom `ingress-ready`
    * GitLab CI/CD kroky
    * typické `kubectl` a `docker` príkazy pre debug a rollout.

---

## 11. Čistenie `default` namespace (lokálny dev cluster)

Tieto príkazy používaj len na **lokálnom vývojovom clustri** (kind, Docker Desktop, minikube),
aby si vyčistil `default` namespace od svojich testovacích aplikácií.

### Zobrazenie objektov v `default` namespace

```bash
kubectl get all -n default
```

### Zmazanie všetkých Deploymentov v `default`

```bash
kubectl delete deployment --all -n default
```

### Zmazanie všetkých Services v `default`

```bash
kubectl delete service --all -n default
```

> Poznámka: systémová Service `kubernetes` sa **neodstráni** – je chránená Kubernetesom.
> Kubernetes ju buď nedovolí zmazať, alebo ju znovu vytvorí.

### Zmazanie všetkých Ingressov v `default`

```bash
kubectl delete ingress --all -n default
```

### Kompletné vyčistenie bežných workloadov v `default`

```bash
kubectl delete all --all -n default
```

### Overenie, že `default` je „čistý“

```bash
kubectl get all -n default
```

Typicky má ostať iba:

```text
service/kubernetes   ClusterIP   …   443/TCP   AGE
```
