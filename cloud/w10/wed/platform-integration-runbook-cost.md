# W10 Day C — Platform Integration + Runbook + Cost Guard

Ngày học: T4 17/06/2026  
Chủ đề: Secure & Operate phần 3 — Tích hợp toàn stack W8→W10, ResourceQuota + LimitRange, Chaos Test, Runbook Template, AWS Cost Anomaly Detection

> **Buổi chiều 15h–17h**: Live với mentor Minh — AWS Security + K8s Hardening  
> **17h–18h**: Online Test 1 (60 phút, scope D1 + D2 + nội dung live)

---

## Mục tiêu hôm nay

- Hiểu bức tranh tổng thể: stack W8 (K8s + Terraform) → W9 (GitOps + Observability + Canary) → W10 (RBAC + Secrets + Platform) kết nối nhau thế nào.
- Nắm ResourceQuota và LimitRange — tại sao cần, khác nhau thế nào, viết manifest đúng.
- Hiểu chaos testing là gì và tại sao test failure trước khi production thật sự fail.
- Biết cấu trúc Runbook template chuẩn SRE và viết được runbook cho ít nhất 1 incident.
- Nắm AWS Cost Anomaly Detection — setup monitor, alert khi chi phí bất thường.
- Tổng hợp checklist "mini platform working end-to-end" triển khai từ repo < 2 giờ.

---

## Nguồn học hôm nay

### Bắt buộc

1. K8s ResourceQuota  
   https://kubernetes.io/docs/concepts/policy/resource-quotas

2. K8s LimitRange  
   https://kubernetes.io/docs/concepts/policy/limit-range

3. AWS Cost Anomaly Detection  
   https://docs.aws.amazon.com/cost-management/latest/userguide/manage-ad.html

4. Chaos Engineering — Litmus  
   https://litmuschaos.io

5. Google SRE Workbook — Example Postmortem / Runbook  
   https://sre.google/workbook/example-postmortem

### Đọc thêm

1. Chaos Mesh  
   https://chaos-mesh.org

2. K8s Docs — Pod Disruption Budget  
   https://kubernetes.io/docs/tasks/run-application/configure-pdb/

3. AWS Well-Architected — Cost Optimization Pillar  
   https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html

---

## Kế hoạch học ~6 giờ (sáng + trưa)

| Thời lượng | Nội dung | Output cần có |
| ---------- | -------- | ------------- |
| 45 phút | Bức tranh toàn stack W8→W10 — map từng layer | Vẽ được diagram stack đầy đủ |
| 60 phút | ResourceQuota + LimitRange | Viết được manifest và giải thích sự khác nhau |
| 60 phút | Chaos test concept + Litmus/Chaos Mesh cơ bản | Giải thích được 3 loại chaos experiment |
| 60 phút | Runbook template — viết runbook cho 1 incident | Có runbook hoàn chỉnh cho 1 scenario |
| 45 phút | AWS Cost Anomaly Detection — setup + alert | Giải thích được cách monitor và alert |
| 30 phút | Bootstrap checklist "deploy từ repo < 2 giờ" | Có checklist đủ để hand-off cho người khác |
| 30 phút | Tổng kết + chuẩn bị câu hỏi live 15h | Có ít nhất 3 câu hỏi cụ thể |

---

## Ghi chú bài học

### 1. Bức tranh toàn stack W8 → W10

Ba tuần vừa rồi xây từng lớp của một platform. D3 hôm nay là lúc nhìn lại toàn bộ và đảm bảo chúng kết nối đúng.

```text
┌─────────────────────────────────────────────────────────────┐
│                    PLATFORM END-TO-END                      │
├─────────────┬──────────────────────┬────────────────────────┤
│   W8 — Foundation                                           │
│   Kubernetes core: Deployment, Service, Ingress, PVC        │
│   Terraform: VPC + EC2 + RDS + S3 (IaC)                     │
├─────────────┴──────────────────────┴────────────────────────┤
│   W9 — Delivery                                             │
│   GitOps: ArgoCD, repo = source of truth                    │
│   Observability: Prometheus + Grafana + Loki + OTel         │
│   Canary: Argo Rollouts, auto-abort khi error rate cao      │
├─────────────────────────────────────────────────────────────┤
│   W10 — Secure & Operate                                    │
│   D1: RBAC (3 role) + Gatekeeper (4 constraint)             │
│   D2: ESO rotate secret + Cosign sign + Kyverno verify      │
│   D3: ResourceQuota + LimitRange + Runbook + Cost Guard     │
└─────────────────────────────────────────────────────────────┘
```

**Luồng deploy end-to-end khi mọi thứ hoạt động:**

```text
1. Developer push PR
   -> Trivy scan + manifest validate (CI/GitHub Actions)
   -> Code review + branch protection

2. Merge vào main
   -> CI build image, Cosign sign, push lên registry
   -> ArgoCD detect thay đổi trong Git

3. ArgoCD sync
   -> Kyverno verify image signature (block nếu chưa sign)
   -> Gatekeeper check policy (resource limits, non-root, no :latest)
   -> Pod schedule lên node

4. Pod running
   -> ESO inject secret từ AWS Secrets Manager qua volume
   -> Prometheus scrape metrics, Loki collect logs
   -> Argo Rollouts canary: 20% traffic trước, auto-abort nếu error rate > 5%

5. Operate
   -> ResourceQuota: namespace không vượt quá resource cap
   -> LimitRange: container nào không khai báo limits bị auto-set default
   -> Cost Anomaly Detection: alert khi AWS bill tăng bất thường
   -> Runbook: có sẵn cho các incident phổ biến
```

---

### 2. ResourceQuota

`ResourceQuota` đặt **giới hạn tổng tài nguyên** cho toàn namespace. Không có ResourceQuota, một namespace có thể dùng hết CPU/memory của toàn cluster, ảnh hưởng namespace khác.

**Những gì ResourceQuota kiểm soát được:**

| Loại | Ví dụ field |
| ---- | ----------- |
| Compute | `requests.cpu`, `requests.memory`, `limits.cpu`, `limits.memory` |
| Object count | `count/pods`, `count/deployments.apps`, `count/services` |
| Storage | `requests.storage`, `persistentvolumeclaims` |

**Manifest ví dụ:**

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "4"           # tổng CPU request trong namespace <= 4 core
    requests.memory: 8Gi        # tổng memory request <= 8Gi
    limits.cpu: "8"             # tổng CPU limit <= 8 core
    limits.memory: 16Gi         # tổng memory limit <= 16Gi
    count/pods: "20"            # tối đa 20 Pod
    count/deployments.apps: "10"
    count/services: "15"
    requests.storage: 50Gi      # tổng PVC request <= 50Gi
```

**Kiểm tra quota:**

```bash
kubectl get resourcequota -n dev
kubectl describe resourcequota dev-quota -n dev
# Output: Hard (giới hạn) và Used (đang dùng)
```

**Quan trọng:** Khi ResourceQuota tồn tại trong namespace, **mọi Pod phải khai báo `resources.requests` và `resources.limits`**. Pod không khai báo sẽ bị reject. Đây là lý do tại sao LimitRange đi kèm ResourceQuota.

---

### 3. LimitRange

`LimitRange` đặt **default và constraint** cho từng container/Pod **riêng lẻ** trong namespace. Khác ResourceQuota là đặt giới hạn tổng, LimitRange đặt giới hạn per-container.

**Hai tác dụng chính:**

1. **Default**: tự động inject `requests` và `limits` nếu container không khai báo
2. **Min/Max**: enforce range hợp lệ — container không được request quá nhỏ (gây pending) hay quá lớn

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limitrange
  namespace: dev
spec:
  limits:
    - type: Container
      default:              # inject nếu container thiếu limits
        cpu: "500m"
        memory: "256Mi"
      defaultRequest:       # inject nếu container thiếu requests
        cpu: "100m"
        memory: "128Mi"
      max:                  # container không được request hơn thế này
        cpu: "2"
        memory: "2Gi"
      min:                  # container không được request ít hơn thế này
        cpu: "50m"
        memory: "64Mi"
    - type: Pod
      max:                  # tổng resource của tất cả container trong 1 Pod
        cpu: "4"
        memory: "4Gi"
    - type: PersistentVolumeClaim
      max:
        storage: 10Gi
      min:
        storage: 1Gi
```

**Bảng so sánh ResourceQuota vs LimitRange:**

| | ResourceQuota | LimitRange |
| - | ------------- | ---------- |
| Scope | Namespace (tổng) | Container/Pod/PVC (individual) |
| Tác dụng | Block khi namespace vượt giới hạn | Inject default, enforce min/max |
| Khi nào dùng | Cô lập resource giữa các team/namespace | Đảm bảo mọi container đều có limits |
| Cần cả hai? | **Có** — cặp đôi tốt nhất | **Có** — complement cho nhau |

**Workflow kết hợp:**

```text
LimitRange inject default limits cho container không khai báo
  -> ResourceQuota kiểm tra tổng request/limit toàn namespace không vượt hard limit
  -> Nếu vượt quota -> Pod bị reject dù đã có limits
```

---

### 4. Chaos Testing

Chaos testing là chủ động **inject failure** vào hệ thống trong môi trường có kiểm soát để phát hiện điểm yếu **trước** khi production thật sự fail.

**Nguyên tắc Chaos Engineering (Netflix/Google):**

1. Xác định **steady state** (hệ thống đang chạy bình thường là thế nào)
2. Giả định chaos **sẽ không thay đổi** steady state
3. Inject chaos trong môi trường kiểm soát
4. Quan sát deviation từ steady state
5. Fix điểm yếu, lặp lại

**Ba loại chaos experiment phổ biến cho K8s:**

| Loại | Mô tả | Tool |
| ---- | ----- | ---- |
| **Pod failure** | Kill ngẫu nhiên Pod trong namespace | Litmus, Chaos Mesh |
| **Network chaos** | Thêm latency, packet loss giữa service | Chaos Mesh `NetworkChaos` |
| **Resource stress** | CPU spike, memory pressure trong container | Litmus `StressChaos` |

**Litmus — chaos experiment đơn giản nhất:**

```yaml
# ChaosEngine: kill ngẫu nhiên Pod trong namespace dev
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: pod-delete-test
  namespace: dev
spec:
  appinfo:
    appns: dev
    applabel: app=demo-web
    appkind: deployment
  engineState: active
  chaosServiceAccount: litmus-admin
  experiments:
    - name: pod-delete
      spec:
        components:
          env:
            - name: TOTAL_CHAOS_DURATION
              value: "30"       # chaos kéo dài 30 giây
            - name: CHAOS_INTERVAL
              value: "10"       # kill Pod mỗi 10 giây
            - name: FORCE
              value: "false"
```

**Chaos Mesh — network chaos:**

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: add-latency
  namespace: dev
spec:
  action: delay
  mode: one
  selector:
    namespaces: [dev]
    labelSelectors:
      app: demo-web
  delay:
    latency: "200ms"
    jitter: "50ms"
  duration: "60s"
```

**Khi nào chạy chaos test:**

- Sau khi deploy stack mới (W10 platform)
- Trước khi chuyển từ staging sang production
- Định kỳ (game day) — thường 1 lần/tháng
- **Không bao giờ** chạy trên production lần đầu mà không có runbook sẵn

**Kết quả mong đợi sau chaos test W10:**

- Pod bị kill → Deployment tự tạo Pod mới (self-healing)
- Secret volume vẫn valid sau Pod restart (ESO đã sync)
- Argo Rollouts detect error rate tăng → auto-abort canary
- Prometheus alert fire → Grafana hiện trạng thái xuống
- ResourceQuota không bị vượt khi Pod mới được tạo

---

### 5. Runbook Template

Runbook là tài liệu hướng dẫn từng bước để **xử lý một incident cụ thể**. Runbook tốt giúp người trực ca đêm không phải "gọi senior" cho mọi alert.

**Cấu trúc runbook chuẩn SRE (Google SRE Workbook):**

```text
# [Tên Incident] — Runbook

## Mô tả
Ngắn gọn: incident này là gì, ảnh hưởng gì.

## Điều kiện kích hoạt
Alert nào fire? Threshold nào?

## Triệu chứng
Người dùng thấy gì? Log/metric nào bất thường?

## Tác động
- Service nào bị ảnh hưởng?
- Severity (P1/P2/P3)?
- SLO nào đang bị vi phạm?

## Bước xử lý (theo thứ tự)
1. Verify alert thật (không phải noise)
2. Triage — xác định scope
3. Contain — ngăn không lan rộng thêm
4. Diagnose — tìm root cause
5. Fix — apply fix
6. Verify — confirm hệ thống về steady state
7. Escalate nếu không tự fix được trong X phút

## Lệnh debug hay dùng
(paste các lệnh cụ thể)

## Escalation path
- Tier 1 (on-call): tự handle theo runbook
- Tier 2: mention @sre-team sau 30 phút
- Tier 3: page on-call engineer sau 60 phút

## Post-mortem
Link post-mortem nếu incident đã xảy ra trước.
```

**Runbook mẫu: "High Error Rate — demo-web"**

```markdown
# High Error Rate demo-web — Runbook

## Mô tả
Error rate của demo-web vượt 5% trong 5 phút.
Alert: `DemoWebHighErrorRate` severity=warning

## Điều kiện kích hoạt
PromQL: rate(http_requests_total{status=~"5..",app="demo-web"}[5m]) / rate(http_requests_total{app="demo-web"}[5m]) > 0.05

## Triệu chứng
- Users thấy 500/503 khi truy cập demo-web
- Grafana dashboard: error rate panel màu đỏ
- SLO availability đang bị consume

## Tác động
- Service: demo-web
- Severity: P2 (SLO at risk nhưng chưa breach)
- SLO: availability 99.9% — đang consume error budget

## Bước xử lý

### 1. Verify (2 phút)
kubectl get pods -n dev -l app=demo-web
kubectl logs -n dev -l app=demo-web --tail=50

### 2. Kiểm tra Argo Rollouts (nếu đang canary)
kubectl argo rollouts get rollout demo-web -n dev
# Nếu canary đang chạy và error cao -> abort ngay

### 3. Abort canary nếu cần
kubectl argo rollouts abort demo-web -n dev

### 4. Kiểm tra resource
kubectl top pods -n dev
kubectl describe pod <pod-name> -n dev | grep -A5 Limits

### 5. Kiểm tra upstream (DB, external API)
kubectl exec -n dev <pod> -- curl -s http://db:5432/health
aws cloudwatch get-metric-statistics --namespace AWS/RDS ...

### 6. Rollback nếu liên quan deploy mới
git log --oneline -5  # tìm commit gần nhất
git revert <bad-commit>
# Hoặc: kubectl rollout undo deployment/demo-web -n dev

### 7. Verify recovery
watch kubectl get pods -n dev
# Đợi error rate về < 1% trên Grafana

## Escalation
- 30 phút: escalate @sre-team
- 60 phút: page on-call engineer

## Lệnh debug nhanh
kubectl get events -n dev --sort-by='.lastTimestamp'
kubectl describe deployment demo-web -n dev
kubectl logs -n dev -l app=demo-web --previous  # log của container đã crash
```

---

### 6. AWS Cost Anomaly Detection

AWS Cost Anomaly Detection dùng **machine learning** để phát hiện chi phí tăng bất thường — không cần đặt threshold thủ công. Dịch vụ tự học pattern sử dụng trong quá khứ và alert khi có deviation.

**Hai loại monitor:**

| Monitor type | Scope | Dùng khi |
| ------------ | ----- | -------- |
| `AWS_SERVICE` | Theo service (EC2, RDS, S3, ...) | Muốn biết service nào tốn tiền đột biến |
| `COST_CATEGORY` | Theo tag/cost category | Muốn monitor theo team hoặc environment |
| `LINKED_ACCOUNT` | Theo AWS account | Multi-account (AWS Organizations) |
| `CUSTOM` | Tự define filter | Monitor theo tag cụ thể (env=production) |

**Tạo monitor qua AWS CLI:**

```bash
# Tạo monitor cho toàn bộ AWS services
aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorName": "W10-Platform-Monitor",
    "MonitorType": "DIMENSIONAL",
    "MonitorDimension": "SERVICE"
  }'

# Lấy MonitorArn từ output
```

**Tạo subscription (alert):**

```bash
aws ce create-anomaly-subscription \
  --anomaly-subscription '{
    "SubscriptionName": "W10-Cost-Alert",
    "MonitorArnList": ["arn:aws:ce::123456789012:anomalymonitor/xxxxxxxx"],
    "Subscribers": [
      {
        "Address": "team@example.com",
        "Type": "EMAIL"
      }
    ],
    "Threshold": 20,
    "Frequency": "DAILY"
  }'
```

**Giải thích các tham số:**

- `Threshold: 20` → chỉ alert khi cost tăng **> $20** so với baseline
- `Frequency`: `DAILY` (email tổng hợp hằng ngày), `IMMEDIATE` (alert ngay khi phát hiện)
- Có thể thêm `ThresholdExpression` để dùng tỷ lệ % thay vì giá trị tuyệt đối

**Console setup (đơn giản hơn):**

```text
AWS Console -> Cost Management -> Cost Anomaly Detection
-> Create monitor -> AWS Services -> All services
-> Create alert subscription -> Email -> Threshold $10
-> Save
```

**Kết hợp với Tagging strategy:**

```bash
# Tag resource theo environment
aws ec2 create-tags \
  --resources <instance-id> \
  --tags Key=Environment,Value=dev Key=Team,Value=platform Key=Week,Value=W10
```

Với tagging đúng, Cost Explorer + Anomaly Detection có thể breakdown: "Tuần W10 tốn bao nhiêu so với W9?".

**Budget alert (complement với Anomaly Detection):**

```bash
aws budgets create-budget \
  --account-id 123456789012 \
  --budget '{
    "BudgetName": "W10-Lab-Budget",
    "BudgetLimit": {"Amount": "50", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }' \
  --notifications-with-subscribers '[{
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80
    },
    "Subscribers": [{"SubscriptionType": "EMAIL","Address": "you@example.com"}]
  }]'
```

---

### 7. Bootstrap Checklist — "Deploy từ repo < 2 giờ"

Đây là checklist để deploy toàn bộ platform lên **fresh cluster** trong < 2 giờ từ repo. Mục tiêu cuối W10 là có checklist này hoàn chỉnh.

```text
PHASE 1 — Infrastructure (30 phút)
□ terraform init && terraform apply (VPC, EKS, RDS, S3)
□ aws eks update-kubeconfig --name <cluster>
□ kubectl cluster-info  # verify connected

PHASE 2 — Platform components (30 phút)
□ ArgoCD: kubectl apply -f bootstrap/argocd/
□ Gatekeeper: kubectl apply -f bootstrap/gatekeeper/
□ ESO: helm install external-secrets ...
□ Kyverno: helm install kyverno ...
□ Prometheus + Grafana: helm install kube-prometheus-stack ...
□ Loki: helm install loki ...

PHASE 3 — Security config (20 phút)
□ kubectl apply -f cloud/w10/day-a/rbac/         # 3 roles
□ kubectl apply -f cloud/w10/day-a/policies/     # 4 constraints (dryrun mode)
□ kubectl apply -f cloud/w10/day-b/eso/          # SecretStore + ExternalSecret
□ kubectl apply -f cloud/w10/day-b/signing/      # Kyverno verify policy

PHASE 4 — Namespace config (10 phút)
□ kubectl apply -f bootstrap/namespaces/         # dev, staging, production + labels
□ kubectl apply -f bootstrap/quotas/             # ResourceQuota + LimitRange per ns

PHASE 5 — Application (20 phút)
□ ArgoCD root-app sync: kubectl apply -f argocd/root-app.yaml
□ Verify applications synced: argocd app list
□ Verify canary rollout ready: kubectl argo rollouts list rollouts -A

PHASE 6 — Verify & Smoke test (10 phút)
□ kubectl get pods -A | grep -v Running  # check không có pod lỗi
□ kubectl get constraint -A              # check policies active
□ kubectl get externalsecret -A          # check secrets synced
□ curl <app-url>                         # end-to-end traffic test
□ Check Grafana dashboard loaded
□ Check ArgoCD all apps Healthy + Synced

TOTAL: ~2 giờ (với Terraform apply ~20 phút)
```

---

## Cấu trúc thư mục D3

```text
cloud/w10/
├── wed/
│   ├── platform-integration-runbook-cost.md    # file này
│   ├── NOTES.md
│   └── imgs/
│       ├── resourcequota-describe.png
│       ├── chaos-pod-delete.png
│       ├── cost-anomaly-dashboard.png
│       └── platform-stack-diagram.png
└── day-c/
    ├── platform-bootstrap/
    │   ├── namespaces.yaml
    │   ├── resourcequota-dev.yaml
    │   ├── resourcequota-staging.yaml
    │   ├── limitrange-dev.yaml
    │   └── limitrange-staging.yaml
    ├── runbooks/
    │   ├── high-error-rate.md
    │   ├── pod-oom-killed.md
    │   └── secret-sync-failure.md
    └── chaos/
        ├── pod-delete-experiment.yaml
        └── network-delay-experiment.yaml
```

---

## Bài thực hành đề xuất

### Lab 1 — ResourceQuota + LimitRange

**Bước 1: Apply vào namespace dev**

Tạo các file manifest theo cấu trúc `day-c/platform-bootstrap/` rồi apply:

```bash
kubectl apply -f cloud/w10/day-c/platform-bootstrap/

# Verify
kubectl describe resourcequota dev-quota -n dev
kubectl describe limitrange dev-limitrange -n dev
```

Screenshot `cloud/w10/wed/imgs/resourcequota-describe.png`.

**Bước 2: Test LimitRange inject default**

```bash
# Tạo Pod KHÔNG khai báo resources
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: test-no-resources
  namespace: dev
spec:
  containers:
  - name: nginx
    image: nginx:1.25
EOF

# Xem Pod có được inject limits không
kubectl get pod test-no-resources -n dev -o jsonpath='{.spec.containers[0].resources}'
```

**Bước 3: Test ResourceQuota exceed**

```bash
# Tạo nhiều Pod để vượt quota count/pods: 20
# Sau Pod thứ 20, pod tiếp theo phải bị reject với "exceeded quota"
kubectl get resourcequota dev-quota -n dev
```

**Bước 4: Kết hợp với Gatekeeper (D1)**

Lúc này có cả:
- Gatekeeper: block Pod không có `resources.limits` (admission policy)
- LimitRange: inject default nếu thiếu (nhưng Gatekeeper chặn trước)
- ResourceQuota: block khi namespace vượt tổng

Ghi chú vào NOTES.md: "Thứ tự kiểm tra là gì khi tạo Pod?"

---

### Lab 2 — Chaos Test cơ bản (không cần cài Litmus)

Nếu chưa cài Litmus, có thể simulate chaos thủ công:

**Pod delete chaos:**

```bash
# Terminal 1: Watch pods liên tục
kubectl get pods -n dev -l app=demo-web -w

# Terminal 2: Delete pod ngẫu nhiên
kubectl delete pod -n dev -l app=demo-web --wait=false

# Quan sát Terminal 1: Pod mới được tạo (self-healing)
# Ghi lại: mất bao nhiêu giây để Pod mới Ready?
```

**Node pressure simulation:**

```bash
# Tạo Pod stress CPU để test ResourceQuota
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: cpu-stress
  namespace: dev
spec:
  containers:
  - name: stress
    image: polinux/stress:latest
    command: ["stress"]
    args: ["--cpu", "2", "--timeout", "60s"]
    resources:
      requests:
        cpu: "1"
      limits:
        cpu: "2"
EOF

# Xem ResourceQuota used tăng lên
kubectl describe resourcequota dev-quota -n dev
```

**Câu hỏi sau chaos test:**
- Pod bị delete → mất bao lâu để service recover?
- Secret volume vẫn valid sau khi Pod mới start không?
- Prometheus có bắt được downtime không?
- Alert có fire không?

Screenshot `cloud/w10/wed/imgs/chaos-pod-delete.png`.

---

### Lab 3 — Viết 3 Runbook

Tạo thư mục `cloud/w10/day-c/runbooks/` và viết 3 runbook:

**1. `high-error-rate.md`** — theo template mục 5 (đã có sẵn)

**2. `pod-oom-killed.md`:**

```markdown
# Pod OOMKilled — Runbook

## Mô tả
Container bị kill vì vượt memory limit.

## Triệu chứng
kubectl get pod <name> -n dev -> Status: OOMKilled
kubectl describe pod <name> -n dev -> "OOMKilled" trong Events

## Bước xử lý
1. kubectl describe pod <name> -n dev | grep -A10 "Last State"
2. kubectl top pod <name> -n dev  # xem memory usage
3. Nếu memory request quá thấp -> tăng limits trong Deployment
4. Nếu memory leak -> check app code / restart policy
5. kubectl rollout restart deployment/<name> -n dev  # restart tạm
6. Cập nhật manifest, commit, push -> ArgoCD sync

## Prevent
- LimitRange default memory không quá nhỏ
- Grafana alert khi memory usage > 80% of limit
```

**3. `secret-sync-failure.md`:**

```markdown
# ESO Secret Sync Failure — Runbook

## Mô tả
ExternalSecret không sync được từ AWS Secrets Manager.

## Điều kiện kích hoạt
kubectl get externalsecret -A -> STATUS: SecretSyncError

## Bước xử lý
1. kubectl describe externalsecret <name> -n <ns>  # xem error message
2. Kiểm tra IAM Role còn valid: aws sts get-caller-identity --profile eso-role
3. Kiểm tra SecretStore: kubectl describe secretstore <name> -n <ns>
4. Verify secret tồn tại trên AWS:
   aws secretsmanager describe-secret --secret-id <name>
5. Nếu IAM hết quyền -> update IAM policy hoặc IRSA binding
6. Force re-sync: kubectl annotate externalsecret <name> -n <ns> \
     force-sync=$(date +%s) --overwrite

## Impact
K8s Secret hiện có vẫn dùng được (stale) cho đến khi Pod restart.
```

---

### Lab 4 — AWS Cost Anomaly Detection

```bash
# Tạo monitor qua Console hoặc CLI
# Console path: AWS Cost Management -> Cost Anomaly Detection -> Create monitor

# Sau khi tạo, xem anomaly history
aws ce get-anomalies \
  --date-interval StartDate=2026-06-01,EndDate=2026-06-17 \
  --max-results 10

# Xem cost by service (manual check)
aws ce get-cost-and-usage \
  --time-period Start=2026-06-15,End=2026-06-17 \
  --granularity DAILY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

Screenshot AWS Console: Cost Anomaly Detection dashboard → `cloud/w10/wed/imgs/cost-anomaly-dashboard.png`.

---

## Checklist hôm nay

- [ ] Vẽ được diagram stack W8→W10 end-to-end (bằng text hoặc draw.io).
- [ ] Giải thích được ResourceQuota vs LimitRange — scope và tác dụng khác nhau thế nào.
- [ ] Apply được ResourceQuota + LimitRange vào namespace dev.
- [ ] Verify LimitRange inject default limits vào Pod không khai báo.
- [ ] Giải thích được 3 loại chaos experiment (pod failure, network chaos, resource stress).
- [ ] Chạy được 1 manual chaos experiment (pod delete) và ghi lại recovery time.
- [ ] Viết được runbook hoàn chỉnh cho ít nhất 1 incident.
- [ ] Biết AWS Cost Anomaly Detection khác Budget alert thế nào.
- [ ] Setup được 1 anomaly monitor trên AWS Console.
- [ ] Có bootstrap checklist đủ để deploy platform từ scratch < 2 giờ.
- [ ] Chuẩn bị ít nhất 3 câu hỏi cho live 15h với mentor Minh.

---

## Evidence cần nộp

Trong `cloud/w10/wed/NOTES.md`, ghi tối thiểu:

- Commit message dạng `[W10-D3] platform-integration-runbook-cost`.
- Output `kubectl describe resourcequota dev-quota -n dev` (hoặc screenshot).
- Ghi chú recovery time sau chaos pod delete.
- Link đến 3 runbook file trong `day-c/runbooks/`.
- Screenshot Cost Anomaly Detection dashboard đã setup.
- Bootstrap checklist đã hoàn thiện.
- Reflection ngắn: "Sau 3 tuần, cái gì là layer quan trọng nhất?"
- Câu hỏi cho live T4.

Lưu ảnh tại:

```text
cloud/w10/wed/imgs/resourcequota-describe.png
cloud/w10/wed/imgs/chaos-pod-delete.png
cloud/w10/wed/imgs/cost-anomaly-dashboard.png
cloud/w10/wed/imgs/platform-stack-diagram.png
```

---

## Câu hỏi ôn tập

1. ResourceQuota và LimitRange giải quyết vấn đề gì mà Gatekeeper không giải quyết?
2. Nếu namespace có ResourceQuota mà Pod không khai báo `resources.requests` thì điều gì xảy ra?
3. LimitRange `default` và `defaultRequest` khác nhau thế nào?
4. Chaos engineering khác penetration testing ở điểm nào?
5. Tại sao nên chạy chaos test trước khi viết runbook chứ không phải sau?
6. Runbook khác wiki/documentation thế nào?
7. AWS Cost Anomaly Detection dùng ML để làm gì mà Budget alert không làm được?
8. Tagging strategy ảnh hưởng đến Cost Anomaly Detection thế nào?
9. Nếu deploy full stack lên fresh cluster không có checklist, điều gì có thể sai?
10. "Mini platform end-to-end" sau W10 gồm những layer nào? Mỗi layer bảo vệ điều gì?

---

## Chuẩn bị cho Live 15h với mentor Minh

**3 câu hỏi nên mang:**

1. Khi cluster K8s bị compromise (Pod đang chạy malicious code) — **5 phút đầu làm gì**? Cách ly Pod hay node hay namespace?
2. IRSA vs static credentials trong Pod — trong tình huống nào vẫn phải dùng static key? Mitigate thế nào?
3. Verify signature tại CI vs registry vs admission webhook — khi nào đặt ở đâu là **đủ**? Có cần cả 3 không?

**Nội dung live cần chú ý đặc biệt (scope mentor Minh):**

| Block | Cần ghi chú gì |
| ----- | -------------- |
| Container & K8s Security (15:25–16:00) | IRSA setup cụ thể trên EKS, Pod Security Standards `restricted` profile |
| DevSecOps & Supply Chain (16:00–16:30) | Cosign keyless trong GitHub Actions — step cụ thể, SLSA provenance |
| Incident Response (16:30–16:55) | EC2 isolation pattern, EventBridge Lambda auto-isolate, "5 phút đầu K8s bị compromise" |

---

## Tài liệu tham khảo

- K8s ResourceQuota: https://kubernetes.io/docs/concepts/policy/resource-quotas
- K8s LimitRange: https://kubernetes.io/docs/concepts/policy/limit-range
- K8s Pod Disruption Budget: https://kubernetes.io/docs/tasks/run-application/configure-pdb/
- Litmus Chaos: https://litmuschaos.io
- Chaos Mesh: https://chaos-mesh.org
- AWS Cost Anomaly Detection: https://docs.aws.amazon.com/cost-management/latest/userguide/manage-ad.html
- AWS Budgets: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html
- Google SRE Workbook — Postmortem: https://sre.google/workbook/example-postmortem
- AWS Security Incident Response Guide: https://docs.aws.amazon.com/whitepapers/latest/aws-security-incident-response-guide/welcome.html
