# W10 D3 — Question Bank: Platform Integration + Runbook + Cost Guard

> Format: câu hỏi → gợi ý trả lời dạng **keyword / bullet ngắn**, highlight từ khóa quan trọng.
> Mức độ: 🟢 Dễ · 🟡 Trung bình · 🔴 Khó

---

## PHẦN 1 — ResourceQuota + LimitRange

### 🟢 Q1. ResourceQuota và LimitRange giải quyết vấn đề gì khác nhau?

**A:**
- `ResourceQuota` → giới hạn **tổng resource của namespace** — ngăn 1 team dùng hết cluster
- `LimitRange` → giới hạn **từng container/Pod riêng lẻ** — inject default, enforce min/max
- Scope: ResourceQuota = namespace-level · LimitRange = object-level
- Dùng cả hai: LimitRange inject default → ResourceQuota giữ tổng namespace
- Keyword: **namespace cap**, **per-container**, **default injection**

---

### 🟢 Q2. `default` và `defaultRequest` trong LimitRange khác nhau thế nào?

**A:**
- `default` → inject `resources.limits` nếu container **không khai báo limits**
- `defaultRequest` → inject `resources.requests` nếu container **không khai báo requests**
- Nếu container khai báo một trong hai, LimitRange không override
- Lý do cần cả hai: Kubernetes scheduler dùng `requests` để place Pod, runtime enforce `limits`
- Keyword: **limits inject**, **requests inject**, **scheduler uses requests**

---

### 🟢 Q3. Nếu namespace có ResourceQuota mà Pod không khai báo `resources.requests` thì sao?

**A:**
- Pod bị **reject** ngay — không được tạo
- Error: `"must specify requests for cpu, memory since resource quota is set"`
- Giải pháp: thêm LimitRange với `defaultRequest` để tự inject trước khi ResourceQuota check
- Thứ tự: `LimitRange inject default` → `ResourceQuota check tổng`
- Keyword: **admission reject**, **quota requires explicit requests**, **LimitRange first**

---

### 🟡 Q4. Ai bị ảnh hưởng khi ResourceQuota `count/pods: 20` đã đầy?

**A:**
- **Mọi thứ tạo Pod** đều bị block: Deployment, ReplicaSet, Job, CronJob, DaemonSet
- Không chỉ user — ngay cả rollout tự động (ArgoCD sync, Argo Rollouts canary) cũng block
- Error: `"exceeded quota: dev-quota, requested: count/pods=1, used: count/pods=20, limited: count/pods=20"`
- Keyword: **all pod creators blocked**, **quota exhaustion**, **rollout blocked**

---

### 🟡 Q5. LimitRange `max` và Gatekeeper `require-resource-limits` có thể thay nhau không?

**A:**
- **Không hoàn toàn** — khác nhau về cơ chế
- `LimitRange max`: enforce **range hợp lệ** — Pod vượt max bị reject, Pod không khai báo được inject default
- `Gatekeeper`: enforce **policy tùy ý** — có thể yêu cầu khai báo chính xác, không inject
- Thứ tự xử lý: `LimitRange` inject trước → `Gatekeeper` validate sau
- Nếu có cả hai: Gatekeeper thấy limits đã được LimitRange inject → **policy pass**
- Keyword: **injection vs validation**, **order matters**, **complementary**

---

### 🔴 Q6. Design ResourceQuota cho multi-team cluster — cần cân nhắc gì?

**A:**
- **Namespace per team**: dev-team-a, dev-team-b — quota riêng biệt
- **Tier quota**: production namespace quota cao hơn dev namespace
- **Quota overhead**: tổng quota của tất cả namespace nên <= 80% cluster capacity (để có headroom cho system pods)
- **Request/Limit ratio**: `limits.cpu` nên ~2x `requests.cpu` để burst nhưng không overcommit quá mức
- **Review cadence**: kiểm tra `kubectl describe resourcequota` hằng tuần, tăng quota khi used > 80% hard
- Keyword: **namespace isolation**, **headroom**, **request/limit ratio**, **usage monitoring**

---

## PHẦN 2 — Chaos Testing

### 🟢 Q7. Chaos engineering là gì? Mục đích chính?

**A:**
- Chủ động **inject failure** có kiểm soát để tìm điểm yếu **trước** production thật fail
- Nguyên tắc: xác định **steady state** → inject chaos → quan sát deviation → fix
- Khác pentest: không tìm security hole, tìm **resilience gap**
- Khác debug: debug = reactive (sau khi fail), chaos = proactive (trước khi fail)
- Keyword: **proactive**, **steady state**, **resilience**, **controlled failure**

---

### 🟢 Q8. Ba loại chaos experiment phổ biến cho K8s?

**A:**
- **Pod failure**: kill ngẫu nhiên Pod → test self-healing, recovery time
- **Network chaos**: inject latency/packet loss → test timeout, retry, circuit breaker
- **Resource stress**: CPU spike / memory pressure → test OOM behavior, throttling
- Bonus: **Node failure** (drain/cordon node) → test pod disruption budget
- Keyword: **pod-delete**, **network latency**, **stress**, **node drain**

---

### 🟡 Q9. Pod bị delete trong chaos test — điều gì xảy ra theo thứ tự?

**A:**
1. Pod nhận **SIGTERM** → graceful shutdown period (`terminationGracePeriodSeconds`, default 30s)
2. Nếu chưa thoát sau grace period → **SIGKILL**
3. ReplicaSet controller detect replicas < desired → tạo **Pod mới**
4. Scheduler place Pod mới lên node
5. kubelet pull image (có cache → nhanh hơn), start container
6. `readinessProbe` pass → Pod join Service endpoints
7. Traffic về Pod mới

- Recovery time thường: **30–60 giây** nếu image cached, `readinessProbe` pass nhanh
- Keyword: **SIGTERM**, **grace period**, **ReplicaSet reconcile**, **readiness gate**

---

### 🟡 Q10. Chaos test thành công trông như thế nào?

**A:**
- **SLO không bị breach**: error rate spike nhưng trong error budget
- **Self-healing hoạt động**: Pod mới Ready trong thời gian mong đợi
- **Alert fire đúng**: Prometheus alert khi error rate cao, resolve khi recover
- **Runbook đủ dùng**: on-call follow runbook xử lý được mà không cần escalate
- **Secret không mất**: ESO re-inject đúng sau Pod restart
- Keyword: **SLO within budget**, **self-healing**, **alert accuracy**, **runbook validation**

---

### 🔴 Q11. Khi nào nên chạy chaos test? Khi nào KHÔNG nên?

**A:**
**Nên:**
- Sau khi deploy stack mới (smoke test + chaos)
- Trước khi promote staging → production
- Game day định kỳ (~1 lần/tháng)
- Sau khi thêm dependency mới

**Không nên:**
- **Lần đầu** trên production không có runbook sẵn
- Khi cluster đang **degraded** (đã có incident)
- Khi **quota gần đầy** — pod mới không tạo được → chaos test không valid
- Khi không có người monitor real-time

- Keyword: **game day**, **runbook ready first**, **not on degraded system**

---

## PHẦN 3 — Runbook

### 🟢 Q12. Runbook khác wiki/documentation thế nào?

**A:**
- **Wiki/docs**: giải thích hệ thống hoạt động thế nào, background knowledge
- **Runbook**: **step-by-step action** cho người đang xử lý incident — không cần hiểu sâu
- Runbook được test bằng chaos: "người mới theo runbook có xử lý được không?"
- Runbook có **escalation path** rõ ràng — biết khi nào leo thang
- Keyword: **actionable**, **incident-time**, **step-by-step**, **escalation**

---

### 🟢 Q13. Cấu trúc runbook tối thiểu cần có gì?

**A:**
- **Mô tả ngắn** — incident là gì
- **Điều kiện kích hoạt** — alert nào, threshold nào
- **Tác động** — service nào, severity, SLO nào bị ảnh hưởng
- **Bước xử lý** — có thứ tự, có lệnh cụ thể
- **Escalation path** — sau X phút không fix được thì làm gì
- **Lệnh debug** — copy-paste ready
- Keyword: **actionable steps**, **copy-paste commands**, **escalation timer**

---

### 🟡 Q14. Pod bị OOMKilled — debug và xử lý thế nào?

**A:**
**Detect:**
```bash
kubectl get pod <name> -n <ns>  # STATUS: OOMKilled
kubectl describe pod <name> -n <ns>  # Last State: OOMKilled, Exit Code: 137
```

**Diagnose:**
```bash
kubectl top pod <name> -n <ns>  # memory usage hiện tại
kubectl logs <name> -n <ns> --previous  # log trước khi crash
```

**Fix:**
- Tăng `resources.limits.memory` trong Deployment
- Nếu memory leak: restart tạm, tìm root cause trong code
- `kubectl rollout restart deployment/<name> -n <ns>`

**Prevent:**
- Alert khi memory usage > 80% of limit
- LimitRange không set default limit quá thấp
- Keyword: **Exit Code 137**, **OOM**, **limits too low vs memory leak**

---

### 🟡 Q15. Làm thế nào validate runbook là "đủ tốt"?

**A:**
- **Chaos test + follow runbook**: chạy experiment → người khác (không phải tác giả) follow runbook → xem có tự xử lý được không
- **Time to resolve**: đo thời gian từ alert đến recover khi follow runbook
- **Post-mortem review**: sau mỗi real incident, cập nhật runbook với step còn thiếu
- **Runbook dry-run**: đọc lại mỗi quý, check lệnh còn đúng không (API thay đổi, tool update)
- Keyword: **runbook drill**, **time to resolve**, **post-mortem update**, **dry-run**

---

### 🔴 Q16. Cluster K8s bị compromise — 5 phút đầu làm gì?

**A:**
**Minute 1–2: Detect + Scope**
```bash
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
kubectl get pods -A | grep -v Running  # pod lạ không?
kubectl get nodes  # node status?
```

**Minute 2–3: Contain — cô lập Pod suspect**
```bash
# Tạo NetworkPolicy block all traffic từ/đến namespace
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-emergency
  namespace: <suspect-ns>
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
EOF
```

**Minute 3–5: Evidence preservation**
```bash
kubectl describe pod <suspect> -n <ns> > evidence.txt
kubectl logs <suspect> -n <ns> >> evidence.txt
# Không xóa Pod ngay — cần forensics
```

**Escalate ngay sau 5 phút**

- Keyword: **contain first**, **preserve evidence**, **NetworkPolicy isolation**, **escalate**

---

## PHẦN 4 — AWS Cost Anomaly Detection

### 🟢 Q17. Cost Anomaly Detection khác Budget alert thế nào?

**A:**
- **Budget alert**: đặt threshold cố định (ví dụ: $50/tháng) → alert khi **vượt ngưỡng tuyệt đối**
- **Anomaly Detection**: ML học pattern → alert khi **deviation bất thường** so với baseline
- Anomaly detect được: "EC2 tốn $5 hôm nay nhưng mọi ngày chỉ $1 → spike 5x là anomaly"
- Budget không detect được: chi phí tăng dần đều nhưng chưa vượt budget
- Nên dùng **cả hai**: Budget = safety net, Anomaly Detection = early warning
- Keyword: **ML baseline**, **deviation**, **absolute vs relative**, **complement**

---

### 🟢 Q18. Anomaly monitor type nào dùng cho lab W10?

**A:**
- **`AWS_SERVICE`** (DIMENSIONAL/SERVICE) → monitor từng AWS service riêng
- Phù hợp nhất cho lab: biết ngay EC2, EKS, RDS service nào spike
- `LINKED_ACCOUNT` dùng khi có Organizations multi-account
- `COST_CATEGORY` dùng khi đã setup tagging + cost category (phức tạp hơn)
- Keyword: **AWS_SERVICE monitor**, **per-service breakdown**, **simplest setup**

---

### 🟡 Q19. Tagging strategy ảnh hưởng Cost tracking thế nào?

**A:**
- Không có tag → Cost Explorer chỉ thấy "EC2 $50" — không biết của team/project nào
- Với tag `Environment=dev`, `Team=platform`, `Week=W10` → filter được: "W10 lab tốn bao nhiêu?"
- Cost Anomaly Detection có thể tạo monitor filter theo tag → scope hẹp hơn, ít noise hơn
- **Bắt đầu tag sớm** — không thể retroactive tag cost đã phát sinh
- Gatekeeper policy: enforce tag mandatory trên EC2, RDS resource
- Keyword: **tag = cost dimension**, **retroactive impossible**, **enforce with policy**

---

### 🟡 Q20. Chi phí EKS gồm những gì? Cái nào hay bị quên?

**A:**
- **EKS Control Plane**: $0.10/giờ (~$72/tháng) — **hay bị quên** khi tạo cluster test
- **EC2 Worker Nodes**: phụ thuộc instance type + số node
- **NAT Gateway**: $0.045/giờ + $0.045/GB — **đắt khi có nhiều traffic ra internet**
- **Elastic Load Balancer**: per ALB/NLB
- **Data transfer**: traffic ra ngoài region
- **EBS volumes**: PVC tạo EBS volume — **không tự xóa khi xóa PVC nếu Retain policy**
- Keyword: **control plane cost**, **NAT Gateway**, **EBS orphan**, **data transfer**

---

### 🔴 Q21. EKS cluster dev quên không xóa sau lab — chi phí sau 1 tuần là bao nhiêu và cách phòng?

**A:**
**Estimate:**
- EKS Control Plane: $0.10 × 168h = ~$17
- 2x t3.medium nodes: $0.0416 × 168h × 2 = ~$14
- NAT Gateway: $0.045 × 168h = ~$8
- **Total: ~$39/tuần chỉ để cluster tồn tại**

**Phòng:**
- **AWS Budget**: alert khi vượt $20 → nhắc xóa
- **Tag + Cost Explorer**: weekly review "có cluster nào đang chạy không?"
- **Terraform**: `terraform destroy` sau lab — không để AWS Console tạo thủ công
- **EventBridge + Lambda**: auto-stop node group ngoài giờ làm việc
- **Cloud Custodian / AWS Instance Scheduler**: schedule off sau 18h

- Keyword: **cluster idle cost**, **terraform destroy**, **budget alert**, **scheduler**

---

## PHẦN 5 — Platform Integration (Stack W8→W10)

### 🟡 Q22. Thứ tự nào khi Pod được tạo — layer nào check trước?

**A:**
```text
kubectl apply
  1. Authentication (kubeconfig, IRSA token)
  2. Authorization (RBAC — có quyền create Pod không?)
  3. Admission Controllers theo thứ tự:
     a. LimitRange MutatingWebhook — inject default resources
     b. Gatekeeper ValidatingWebhook — check policy
     c. Kyverno MutatingWebhook (nếu có mutation)
     d. Kyverno ValidatingWebhook — verify image signature
  4. ResourceQuota — check tổng namespace còn đủ không
  5. Scheduler — chọn node
  6. kubelet — pull image, start container
```
- Keyword: **AuthN → AuthZ → Admission → Quota → Schedule → Run**

---

### 🟡 Q23. ArgoCD sync fail sau khi thêm Gatekeeper constraint — nguyên nhân?

**A:**
- ArgoCD apply manifest vào cluster → Gatekeeper webhook check → **reject** vì vi phạm policy
- ArgoCD report: `SyncFailed` với message từ Gatekeeper
- Nguyên nhân thường: manifest trong Git không comply với constraint mới (thiếu `resources.limits`, dùng `:latest` tag, ...)
- Fix: **sửa manifest trong Git** (không sửa cluster trực tiếp — vi phạm GitOps)
- Keyword: **GitOps: fix in Git**, **SyncFailed**, **constraint violation blocks sync**

---

### 🟡 Q24. ESO secret sync OK nhưng Pod vẫn không đọc được secret — debug thế nào?

**A:**
1. `kubectl get secret <name> -n <ns>` → secret có tồn tại không?
2. `kubectl get secret <name> -n <ns> -o yaml` → có đúng key không? Đúng field name?
3. `kubectl describe pod <name> -n <ns>` → volume mount có error không?
4. `kubectl exec -it <pod> -n <ns> -- ls /etc/secrets/` → file có trong container không?
5. Kiểm tra path mount trong Deployment spec khớp với `mountPath`
6. Nếu dùng env var (không nên): `kubectl exec ... -- env | grep <KEY>`
- Keyword: **key mismatch**, **mountPath**, **volume vs env**, **file exists check**

---

### 🔴 Q25. "Mini platform end-to-end" — nếu chỉ có 2 giờ để deploy từ scratch, bước nào không thể bỏ qua?

**A:**
**Không thể bỏ (blocking):**
1. `terraform apply` — không có cluster thì không có gì
2. `kubectl apply -f bootstrap/argocd/` — không có ArgoCD thì không deploy app được
3. `kubectl apply -f bootstrap/gatekeeper/` — không có policy thì cluster không secure
4. ESO + SecretStore — không có secret thì app không start được
5. ResourceQuota + LimitRange — không có quota thì cluster không protected

**Có thể làm sau:**
- Grafana dashboard (monitoring vẫn hoạt động, chỉ thiếu visualization)
- Kyverno image verify (có thể bật Audit mode trước)
- Cost Anomaly Detection (không blocking cho platform)
- Runbook (cần có trước khi production thật, nhưng không blocking deploy)

- Keyword: **critical path**, **cluster → GitOps → security → secrets → quotas**

---

## PHẦN 6 — Kết nối W8→W10 tổng thể

### 🟡 Q26. Nếu phải giải thích stack W8→W10 cho người mới trong 2 phút — nói gì?

**A:**
```text
W8 — "Bạn có gì?"
  Kubernetes cluster, Terraform IaC, app deploy được

W9 — "Bạn deliver thế nào?"
  GitOps: thay đổi qua Git, ArgoCD sync
  Observability: biết system đang chạy thế nào
  Canary: deploy an toàn, tự rollback khi lỗi

W10 — "Bạn tin tưởng nó không?"
  RBAC: ai được làm gì
  Gatekeeper: policy enforce tại cluster
  Secrets: không hardcode, rotate tự động
  Quotas: không ai dùng hết resource
  Runbook: khi cháy biết làm gì
  Cost guard: không bị bill shock
```
- Keyword: **Foundation → Delivery → Trust**

---

### 🔴 Q27. Sau W10, platform còn thiếu gì để gọi là "production-ready"?

**A:**
**Còn thiếu (capstone W11-W12 territory):**
- **Multi-cluster / DR**: disaster recovery, failover
- **Network segmentation**: Istio service mesh, mTLS between services
- **Runtime security**: Falco detect anomalous behavior in-cluster
- **Secrets rotation test**: automated chaos test cho ESO pipeline
- **SLA formal**: SLO defined, error budget tracking dashboard
- **Compliance audit**: CIS K8s benchmark, AWS Security Hub score
- **Backup strategy**: Velero cho K8s resources + PVC backup
- **Load testing**: k6, Locust — biết capacity trước khi traffic thật đến

- Keyword: **DR**, **mTLS**, **runtime security**, **SLA**, **backup**, **load test**

---

## Quick Reference — Stack W8→W10

```bash
# ResourceQuota
kubectl get resourcequota -A
kubectl describe resourcequota <name> -n <ns>

# LimitRange
kubectl get limitrange -A
kubectl describe limitrange <name> -n <ns>

# Chaos manual
kubectl delete pod -n <ns> -l app=<name> --wait=false
kubectl get pods -n <ns> -w  # watch recovery

# AWS Cost
aws ce get-cost-and-usage \
  --time-period Start=2026-06-15,End=2026-06-17 \
  --granularity DAILY --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

aws ce get-anomalies \
  --date-interval StartDate=2026-06-01,EndDate=2026-06-17

# Full platform health check
kubectl get pods -A | grep -v Running
kubectl get constraint -A
kubectl get externalsecret -A
argocd app list
kubectl top nodes
kubectl get resourcequota -A
```
