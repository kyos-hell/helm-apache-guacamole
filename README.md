# Apache Guacamole Helm Chart 🚀

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.25%2B-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-v3.10%2B-0F1689?logo=helm&logoColor=white)](https://helm.sh/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-kyos--hell-181717?logo=github)](https://github.com/kyos-hell)
[![Guacamole](https://img.shields.io/badge/Guacamole-1.5.0-green)](https://guacamole.apache.org/)

> **Production-ready Helm chart for Apache Guacamole on Kubernetes** with comprehensive security best practices, auto-scaling, and Ingress routing.

---

## 📚 About This Project

This is a **professional Helm chart** for deploying Apache Guacamole on Kubernetes. It's a **DevOps learning project** where I explore containerization best practices, orchestration, and infrastructure-as-code.

**Learning Goal:** Build a complete, secure, and scalable cloud-native architecture for remote desktop gateway access.

### 🎯 Context

- **Kubernetes Environment**: Deployed on my own Proxmox infrastructure via [terraform-kubernetes-proxmox](https://github.com/kyos-hell/terraform-kubernetes-proxmox)
- **Custom Docker Images**: Built via [DEB-APACHE-GUACAMOLE-COMPOSE](https://github.com/kyos-hell/DEB-APACHE-GUACAMOLE-COMPOSE)
- **Motivation**: Learn, evolve, and master the DevOps/Kubernetes ecosystem

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│  (Proxmox VMs via terraform-kubernetes-proxmox)             │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┼─────────┐
                    │         │         │
            ┌───────▼──┐  ┌──▼────┐  ┌─▼────────┐
            │  MetalLB │  │ Nginx │  │ Guacamole│
            │(LoadBalb)│  │Ingress│  │  Stack   │
            └───────┬──┘  └──┬────┘  └─┬────────┘
                    │       │         │
        192.168.11.21 (External IP)   │
                    │       │         │
                    └───────┼─────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
        ┌──▼────────┐  ┌───▼────────┐  ┌──▼─────────┐
        │ Guacamole │  │   Guacd    │  │  MariaDB   │
        │ (Tomcat)  │  │ (Gateway)  │  │ (Database) │
        │ Port 8080 │  │ Port 4822  │  │ Port 3306  │
        └────┬──────┘  └────┬───────┘  └────┬───────┘
             │              │               │
             └──────────────┼───────────────┘
                  Intra-pod networking (Services)

```

### Components

| Component | Image | Port(s) | Stateful | Role |
|-----------|-------|---------|----------|------|
| **Guacamole** | `kyos-hell/guacamole-deb:latest` | 8080 | No | Remote desktop gateway |
| **Guacd** | `kyos-hell/guacd-deb:latest` | 4822 | No | Protocol server (RDP/VNC/SSH) |
| **MariaDB** | `mariadb:11.5` | 3306 | Yes (PVC) | Configuration & user storage |
| **Nginx Ingress** | Controller | 80/443 | No | HTTP/HTTPS routing |
| **MetalLB** | LoadBalancer | N/A | No | Virtual IP for on-premises LB |

---

## 📋 Prerequisites

### Infrastructure

- ✅ **Kubernetes Cluster** v1.25+ (deployed via [terraform-kubernetes-proxmox](https://github.com/kyos-hell/terraform-kubernetes-proxmox))
- ✅ **MetalLB** for on-premises LoadBalancer (or cloud provider with LB)
- ✅ **Nginx Ingress Controller** 
- ✅ **StorageClass** for PersistentVolumeClaim (MariaDB)

### Local Tools

```bash
# Kubernetes CLI
kubectl >= 1.25
helm >= 3.10

# Verify
kubectl version --client
helm version
```

### Cluster Access

```bash
# Configure kubeconfig
export KUBECONFIG=~/.kube/config

# Verify connection
kubectl cluster-info
```

---

## � GitOps Workflow with ArgoCD

### Overview

This chart integrates with **ArgoCD** for continuous deployment and synchronization. Any changes to the Helm chart (values, templates, images) are automatically applied to the cluster.

```
┌─────────────────────────────────────────────────┐
│         GitHub Repository                        │
│  (This Helm Chart + values.yaml)                │
└──────────────────┬──────────────────────────────┘
                   │
                   │ 1. Commit changes
                   │
┌──────────────────▼──────────────────────────────┐
│         ArgoCD Application                       │
│  watches chart + values for changes             │
└──────────────────┬──────────────────────────────┘
                   │
                   │ 2. Detects diff
                   │
┌──────────────────▼──────────────────────────────┐
│      Kubernetes Cluster                          │
│  helm upgrade --install executed                │
│  New pods deployed, old ones gracefully shut    │
└──────────────────────────────────────────────────┘
```

### Deployment Flow

**Example: Updating MariaDB image tag**

```bash
# 1. Edit values.yaml locally
mariadb:
  image:
    tag: "11.5"  # changed from "11.4"

# 2. Push to GitHub
git commit -am "chore: update mariadb image to 11.5"
git push origin main

# 3. ArgoCD detects changes (polls every 3 minutes)
# 4. Helm diff shows changes
# 5. Helm upgrade applies:
#    - StatefulSet detected image change
#    - Gracefully terminates old MariaDB pod
#    - Mounts same PVC
#    - Launches new MariaDB pod with v11.5
```

### Why StatefulSet for MariaDB?

#### Problem with Deployment (RollingUpdate)

```
When you update a Deployment's image tag:

Pod-old running:    ████████████████░░░░  (old image)
Pod-new starting:   ░░░░░░░░░░████████    (new image)
                    ▲
                    CONFLICT! Both pods try to access same PVC
                    MariaDB locks on old pod block new pod
                    Result: Pod-new crashes ❌
```

#### Solution: StatefulSet (OrderedReady)

```
StatefulSet manages updates serially:

Pod-0 with old image: ████████████████░░░░░░░░░  (stopped)
Pod-0 with new image: ░░░░░░░░░░░░░░░░░░████████  (started)
                                              ▲
                                    No overlap! ✅
                      PVC is free when new pod starts
                      Locks are released from old pod
```

**Key benefits:**

| Feature | Deployment | StatefulSet |
|---------|-----------|-------------|
| **Pod ordering** | Random | Ordered (Pod-0, Pod-1, ...) |
| **Update strategy** | Simultaneous (RollingUpdate) | Serial (OrderedReady) |
| **PVC access** | Multiple pods possible | One pod at a time |
| **DNS stability** | Random names | Stable names (mariadb-0, mariadb-1) |
| **Data persistence** | Risk of locks | Safe & predictable |

### Configuration

MariaDB StatefulSet config:

```yaml
# templates/mariadb-deb/deployment.yaml
apiVersion: apps/v1
kind: StatefulSet  # ← Changed from Deployment
metadata:
  name: guacamole-mariadb
spec:
  serviceName: guacamole-mariadb  # ← Required for StatefulSet
  replicas: 1
  selector:
    matchLabels:
      app: guacamole-mariadb
  template:
    # ... pod spec ...
    volumeMounts:
    - name: mariadb-storage
      mountPath: /var/lib/mysql
  volumes:
  - name: mariadb-storage
    persistentVolumeClaim:
      claimName: guacamole-mariadb  # ← Reuses existing PVC
```

**Why reuse existing PVC?**

- ✅ Preserves all database data
- ✅ No data loss during migration
- ✅ Same PV (PersistentVolume) continues to hold data
- ✅ One pod at a time accesses storage

---

## �🚀 Installation

### 1. Cluster Prerequisites (one-time setup)

```bash
# Create namespace
kubectl create namespace guacamole

# Verify MetalLB (LoadBalancer IP pool)
kubectl get ipaddresspool -n metallb-system
# Should display a pool (e.g., 192.168.11.100-110)

# Verify Nginx Ingress
kubectl get svc -n ingress-nginx
# nginx-ingress-ingress-nginx-controller should have EXTERNAL-IP
```

### 2. Deploy Helm Chart

```bash
# Clone repository
git clone https://github.com/kyos-hell/apache-guacamole-helm-chart.git
cd apache-guacamole-helm-chart

# Validate chart
helm lint .

# Install
helm install guacamole . -n guacamole

# Verify deployment
kubectl get all -n guacamole
```

### 3. Access Guacamole

```bash
# Get LoadBalancer IP
kubectl get svc -n ingress-nginx | grep nginx-ingress-ingress-nginx-controller

# Example: 192.168.11.21

# Access via browser
# http://192.168.11.21/guacamole/
```

---

## ⚙️ Configuration

### Customize Deployment

Create `values-custom.yaml`:

```yaml
guacamole:
  replicaCount: 3  # Scaling
  image:
    repository: kyos-hell/guacamole-deb
    tag: latest
  service:
    type: ClusterIP  # or LoadBalancer
    port: 80

guacd:
  replicaCount: 2

mariadb:
  persistence:
    size: 20Gi  # Increase storage

ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: guacamole.example.com
      paths:
        - path: /guacamole
          pathType: Prefix

hpa:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
```

Install with custom configuration:

```bash
helm install guacamole . -n guacamole -f values-custom.yaml
```

### Secrets & Environment Variables

Sensitive data is stored as **Kubernetes Secrets**:

```bash
# List secrets
kubectl get secrets -n guacamole

# Edit secret (manual edit)
kubectl edit secret guacamole-guacamole-secrets -n guacamole
```

### ArgoCD Integration

To sync this chart with ArgoCD:

```bash
# Create ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guacamole
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/kyos-hell/apache-guacamole-helm-chart.git
    targetRevision: main
    path: .
    helm:
      valuesUrl: "https://raw.githubusercontent.com/kyos-hell/apache-guacamole-helm-chart/main/values.yaml"
  destination:
    server: https://kubernetes.default.svc
    namespace: guacamole
  syncPolicy:
    automated:
      prune: true      # Delete resources not in Git
      selfHeal: true   # Resync on cluster drift
    syncOptions:
    - CreateNamespace=true
```

**Key behaviors:**

- ✅ **Auto-sync enabled**: Changes in Git → Applied to cluster
- ✅ **Prune enabled**: Resources deleted from Git are removed
- ✅ **Self-healing**: Cluster state reverts if manually modified
- ✅ **StatefulSet handles updates gracefully**: No downtime for MariaDB

---

## 📊 Implemented Features

### ✅ Security

- **RBAC**: ServiceAccount, Role, RoleBinding with least-privilege
- **SecurityContext**: Non-root pods, limited capabilities, read-only filesystem
- **NetworkPolicy**: Inter-pod traffic control
- **Secrets Management**: Sensitive data in K8s Secrets

### ✅ High Availability

- **Replicas**: Multi-pod deployments for Guacamole, Guacd
- **HPA**: Auto-scaling based on CPU/Memory
- **Health Checks**: livenessProbe & readinessProbe
- **PVC StatefulSet**: Persistence for MariaDB

### ✅ Routing & Exposure

- **Nginx Ingress**: HTTP routing
- **MetalLB LoadBalancer**: Virtual IP for on-premises
- **Service DNS**: Automatic internal discovery

### ✅ Code Quality

- **Helm Lint**: Syntax validation
- **values.schema.json**: Schema validation
- **Helper Templates**: Reusability & DRY principle

---

## 🔧 Common Operations

### Logs

```bash
# Guacamole logs
kubectl logs -f deployment/guacamole-guacamole -n guacamole

# Guacd logs
kubectl logs -f deployment/guacamole-guacd -n guacamole

# MariaDB logs
kubectl logs -f deployment/guacamole-mariadb -n guacamole
```

### Scaling

```bash
# Manual scaling
kubectl scale deployment guacamole-guacamole --replicas=5 -n guacamole

# View HPA
kubectl get hpa -n guacamole
```

### Upgrade

```bash
# Update values
helm upgrade guacamole . -n guacamole -f values-custom.yaml

# View history
helm history guacamole -n guacamole

# Rollback if needed
helm rollback guacamole 1 -n guacamole
```

### Deletion

```bash
# Remove deployment
helm uninstall guacamole -n guacamole

# Remove namespace
kubectl delete namespace guacamole
```

---

## 🎓 Key Learnings

This project helped me master:

- ✅ **Kubernetes**: Pods, Deployments, Services, Ingress, StatefulSet, PVC
- ✅ **Helm**: Charts, templates, values, helpers, hooks
- ✅ **K8s Security**: RBAC, SecurityContext, NetworkPolicy, Secrets
- ✅ **Infrastructure-as-Code**: Declarative, GitOps principles
- ✅ **Networking**: LoadBalancer, Service DNS, Ingress routing
- ✅ **Monitoring**: Logs, healthchecks, HPA metrics
- ✅ **DevOps Culture**: Documentation, validation, CI/CD readiness

---

## 🚀 Future Improvements

### Short term (v1.1)

- [ ] **Helm Tests**: Chart testing framework for CI
- [ ] **HTTPS/TLS**: Self-signed certificates + Let's Encrypt
- [ ] **Monitoring**: Prometheus + Grafana dashboards
- [ ] **Logging**: ELK stack or Loki integration
- [ ] **Helm Docs**: Auto-generated chart documentation

### Medium term (v1.2)

- [ ] **Multi-environments**: Dev, Staging, Prod values
- [ ] **ConfigMap**: Externalized configuration files
- [ ] **Service Mesh**: Istio for advanced observability
- [ ] **Backup/DR**: Velero for PVC backup
- [ ] **Helm Hooks**: Pre/post install, test, upgrade

### Long term (v2.0)

- [ ] **Operator Pattern**: Custom Resource Definitions (CRD)
- [ ] **Flux/ArgoCD**: GitOps continuous deployment
- [ ] **Multi-cluster**: Kubernetes federation
- [ ] **API Gateway**: Kong or Traefik advanced
- [ ] **Distributed Tracing**: Jaeger for full observability

---

## 🔗 Related Projects

This chart builds upon:

1. **[terraform-kubernetes-proxmox](https://github.com/kyos-hell/terraform-kubernetes-proxmox)**
   - Complete Kubernetes infrastructure on Proxmox
   - MetalLB, Nginx Ingress, StorageClass pre-configured

2. **[DEB-APACHE-GUACAMOLE-COMPOSE](https://github.com/kyos-hell/DEB-APACHE-GUACAMOLE-COMPOSE)**
   - Custom Guacamole & Guacd Docker images
   - Debian-based with optimizations

---

## 📖 Additional Documentation

- [Guacamole Docs](https://guacamole.apache.org/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [MetalLB Documentation](https://metallb.universe.tf/)

---

## 💡 Support & Contribution

I'm open to:

- **Feedback** on architecture and best practices
- **Issues** to report bugs or improvements
- **Pull Requests** for contributions (security, features, docs)
- **Discussions** for collective learning

### Contributing

```bash
# Fork repository
git clone https://github.com/<your-username>/apache-guacamole-helm-chart.git
cd apache-guacamole-helm-chart

# Create branch
git checkout -b feature/my-improvement

# Commit and push
git add .
git commit -m "feat: description of improvement"
git push origin feature/my-improvement

# Create Pull Request
```

---

## 🎯 Learning Objective

> This project is a **catalyst for learning** in my DevOps journey.
> My goal: master the Kubernetes ecosystem, apply security best practices
> and cloud-native architecture, and build scalable, reliable solutions.
>
> **I'm passionate about DevOps technologies and always ready to evolve! 🚀**

---

## 📝 License

Apache License 2.0 - See [LICENSE](LICENSE)

---

## 🙋 About

**Louis GAILLARD-BAHIANA** | DevOps Apprentice 🔥

- 📧 Email: [louis.bahiana@hotmail.com](mailto:louis.bahiana@hotmail.com)
- 🐙 GitHub: [@kyos-hell](https://github.com/kyos-hell)
- 💼 LinkedIn: [coming soon]

---

**⭐ If you like this project, feel free to star it! It's encouraging to continue! 🌟**
