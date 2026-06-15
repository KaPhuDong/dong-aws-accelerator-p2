# W10 D1 — Question Bank: RBAC + Admission Policy

> Format: câu hỏi → gợi ý trả lời dạng **keyword / bullet ngắn**, highlight từ khóa quan trọng.  
> Mức độ: 🟢 Dễ · 🟡 Trung bình · 🔴 Khó

---

## PHẦN 1 — RBAC Lý thuyết

### 🟢 Q1. Role và ClusterRole khác nhau điểm gì cốt lõi?

**A:**
- `Role` → scope **namespace** cụ thể
- `ClusterRole` → scope **cluster-wide** hoặc tái dùng nhiều namespace
- ClusterRole dùng cho resource không thuộc namespace: `nodes`, `persistentvolumes`, `clusterroles`

---

### 🟢 Q2. RoleBinding vs ClusterRoleBinding — khi nào dùng cái nào?

**A:**
- `RoleBinding` → gán quyền **trong 1 namespace** (kể cả khi bind ClusterRole)
- `ClusterRoleBinding` → gán quyền **toàn cluster**, không giới hạn namespace
- Rule of thumb: **dùng RoleBinding nhiều nhất có thể**, ClusterRoleBinding chỉ khi thực sự cần cluster-scope

---

### 🟢 Q3. ServiceAccount dùng để làm gì, khác User ở điểm nào?

**A:**
- `ServiceAccount` → identity cho **Pod/process**, không phải người dùng
- `User` → identity cho **người** hoặc external tool, Kubernetes không quản lý user trực tiếp
- SA được store trong etcd, có token tự động, có thể bind Role/ClusterRole
- **Namespace-scoped**: `system:serviceaccount:<namespace>:<name>`

---

### 🟢 Q4. `automountServiceAccountToken: false` — đặt ở đâu, khi nào?

**A:**
- Đặt ở `spec.automountServiceAccountToken: false` trong **Pod spec** hoặc **ServiceAccount spec**
- Dùng khi Pod **không cần gọi Kubernetes API**
- Lý do: token được mount vào `/var/run/secrets/kubernetes.io/serviceaccount/` → nếu Pod bị compromise, attacker đọc được token

---

### 🟢 Q5. `kubectl auth can-i` dùng để làm gì?

**A:**
- Kiểm tra xem subject có quyền thực hiện verb trên resource không
- `--as=` → impersonate user/SA
- `--list` → liệt kê **tất cả quyền** của subject trong namespace
- Không cần thật sự thực hiện action → **safe để debug**

---

### 🟡 Q6. Một ClusterRole `viewer` được bind bằng RoleBinding vào namespace `dev` — user có thể list Nodes không?

**A:**
- **Không** — RoleBinding giới hạn scope trong namespace `dev`
- `nodes` là cluster-scoped resource → cần **ClusterRoleBinding** để list
- ClusterRole chứa rule, RoleBinding **giới hạn scope** apply của rule đó
- Keyword: **binding scope** quyết định, không phải role scope

---

### 🟡 Q7. Tại sao không nên dùng ServiceAccount `default` cho workload thật?

**A:**
- `default` SA tồn tại trong **mọi namespace**, không có tên rõ ràng
- Nhiều tool, operator bind quyền vào `default` SA → **blast radius lớn** nếu bị exploit
- Không thể audit dễ dàng "SA này dùng cho app gì"
- Best practice: **tạo SA riêng** per workload, gán quyền tối thiểu

---

### 🟡 Q8. Verbs trong RBAC gồm những gì? `patch` và `update` khác nhau thế nào?

**A:**
- Verbs: `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection`, `exec` (cho pods/exec)
- `update` → **PUT** — gửi toàn bộ object
- `patch` → **PATCH** — gửi phần thay đổi (strategic merge patch, JSON patch)
- Nếu chỉ cần `kubectl set image` → cần `patch`, không nhất thiết cần `update`

---

### 🔴 Q9. Làm thế nào để restrict một developer chỉ được xem log Pod của team mình, không xem Pod team khác trong cùng namespace?

**A:**
- RBAC **không hỗ trợ filter theo label/field** trên resource (không có row-level security)
- Giải pháp: **tách namespace** theo team → RoleBinding per namespace
- Hoặc dùng **admission policy** + **label enforcement** để team phải label Pod
- Kubernetes RBAC là **coarse-grained**, không fine-grained theo attribute

---

### 🔴 Q10. `system:masters` group là gì? Tại sao nguy hiểm?

**A:**
- Built-in group có **ClusterAdmin** không thể bị revoke bằng RBAC (bypass RBAC hoàn toàn)
- Kubeadm cấp cert với `system:masters` cho admin user mặc định
- Không thể audit hay restrict bằng policy
- **Không dùng trong production** — thay bằng ClusterRoleBinding có thể revoke
- Trên EKS: map qua `aws-auth` ConfigMap hoặc EKS Access Entry

---

## PHẦN 2 — OPA / Gatekeeper Lý thuyết

### 🟢 Q11. Gatekeeper giải quyết vấn đề gì mà RBAC không giải quyết được?

**A:**
- RBAC: **ai** được làm gì
- Gatekeeper: **nội dung** request có hợp lệ không
- Ví dụ RBAC không làm được: "Pod phải có `resources.limits`", "image không được dùng `:latest`"
- Gatekeeper là **ValidatingAdmissionWebhook** — chạy sau AuthZ, trước khi lưu vào etcd

---

### 🟢 Q12. ConstraintTemplate và Constraint có quan hệ như thế nào?

**A:**
- `ConstraintTemplate` → như **class/blueprint** — định nghĩa loại policy, chứa Rego
- `Constraint` → như **instance** — áp dụng template vào scope cụ thể (namespace, kind)
- 1 template → nhiều constraint với params khác nhau
- Tương tự: `CRD` và `CR`

---

### 🟢 Q13. `enforcementAction` có những giá trị nào và ý nghĩa?

**A:**
- `deny` → **reject** request ngay, trả lỗi về client
- `warn` → **accept** nhưng warning message trong response
- `dryrun` → accept, **chỉ log** violation vào `.status.violations`, không notify
- Workflow: `dryrun` → fix → `warn` → confirm → `deny`

---

### 🟡 Q14. `input.review.object` trong Rego là gì?

**A:**
- Object Kubernetes đang được **admit** (tạo/update)
- Full JSON của resource: `input.review.object.spec.containers[_].image`
- `input.review.operation`: `CREATE`, `UPDATE`, `DELETE`
- `input.review.userInfo`: thông tin user đang tạo request
- Dùng `input.review.object.metadata.labels` để check label

---

### 🟡 Q15. Tại sao cần chạy `dryrun` trước khi `deny`?

**A:**
- Workload **hiện có** có thể vi phạm policy → enforce ngay = **break production**
- `dryrun` collect violations vào `.status.violations` mà không reject
- Cho phép team **audit và fix** workload trước
- **Không bao giờ enforce policy mới trực tiếp** trên cluster có workload đang chạy

---

### 🟡 Q16. Gatekeeper webhook down thì cluster xử lý thế nào?

**A:**
- Phụ thuộc vào `failurePolicy` trong `ValidatingWebhookConfiguration`
- `failurePolicy: Fail` → webhook down = **mọi request bị reject** (safe but disruptive)
- `failurePolicy: Ignore` → webhook down = **bypass policy** (dangerous)
- Gatekeeper mặc định: `Fail` → plan cho HA Gatekeeper (replicas, PDB)
- Keyword: **failurePolicy**, **webhook availability**, **blast radius**

---

### 🔴 Q17. Làm thế nào để allow exception cho một workload cụ thể trong Gatekeeper?

**A:**
- Dùng `match.excludedNamespaces` trong Constraint để loại namespace
- Dùng `match.labelSelector` để chỉ enforce Pod có label cụ thể
- Dùng annotation `gatekeeper.sh/constraint: skip` theo config
- Best practice: exception phải có **ADR (Architecture Decision Record)** + time-bound (expire date trong comment/label)
- Không hardcode exception mãi mãi → tạo tech debt security

---

### 🔴 Q18. ValidatingAdmissionPolicy (CEL) có thể thay hoàn toàn Gatekeeper không?

**A:**
- **Không hoàn toàn** ở thời điểm hiện tại
- CEL mạnh cho simple/medium rules → đủ cho 80% use case
- Gatekeeper mạnh hơn khi: external data lookup, mutation policy (MutatingWebhook), complex cross-field logic
- VAP không có `MutatingAdmissionPolicy` built-in → Gatekeeper vẫn cần cho **mutation**
- Xu hướng: VAP đang phát triển nhanh → có thể thay phần lớn Gatekeeper trong K8s 1.32+

---

## PHẦN 3 — Thực tiễn & Debug

### 🟢 Q19. Pod bị lỗi `Forbidden` khi gọi Kubernetes API — debug bước nào?

**A:**
1. `kubectl describe pod <name>` → tìm `serviceAccountName`
2. `kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa> -n <ns>`
3. Nếu "no" → kiểm tra RoleBinding có bind SA đó không
4. `kubectl get rolebinding,clusterrolebinding -A | grep <sa-name>`
5. Sửa Role thêm verb còn thiếu hoặc tạo RoleBinding mới

---

### 🟢 Q20. Lệnh nào để xem violation của Gatekeeper Constraint?

**A:**
```bash
kubectl get <constraint-kind> <constraint-name> -o yaml
# xem phần .status.violations
```
- Hoặc: `kubectl describe <constraint-kind> <constraint-name>`
- Violations chỉ update sau **audit interval** (mặc định 60s)
- Violations là **existing resources vi phạm**, không phải request bị reject

---

### 🟡 Q21. Tạo Pod bị lỗi: `admission webhook "validation.gatekeeper.sh" denied the request` — làm gì?

**A:**
1. Đọc message error → Gatekeeper trả về `msg` từ Rego `violation` rule
2. Xác định **Constraint nào** gây ra
3. `kubectl get constraint -A` → tìm constraint liên quan
4. Sửa Pod spec để comply (thêm `resources.limits`, đổi image tag, ...)
5. Nếu cần exception khẩn cấp → `enforcementAction: warn` tạm thời, tạo ticket fix

---

### 🟡 Q22. `kubectl apply` thành công nhưng Pod không chạy được — liệu có phải RBAC lỗi không?

**A:**
- **RBAC** check ở tầng **API server** — nếu apply thành công thì RBAC OK
- Lỗi sau khi Pod được tạo thường do: image pull, resource limits, node selector, PVC, security context
- RBAC lỗi → error ngay khi `kubectl apply`: `Error from server (Forbidden)`
- Admission policy lỗi → error ngay khi apply: `admission webhook denied`
- Pod pending/crash → **scheduler + kubelet** issue, không phải RBAC

---

### 🟡 Q23. Gatekeeper apply thành công nhưng Pod vi phạm vẫn được tạo — tại sao?

**A:**
- Constraint đang ở `enforcementAction: dryrun` hoặc `warn`
- Namespace không match `match.namespaces` trong Constraint
- **Gatekeeper webhook chưa ready** — check `kubectl get pods -n gatekeeper-system`
- Kind của resource không match `match.kinds`
- Check: `kubectl get constraint <name> -o jsonpath='{.spec.enforcementAction}'`

---

### 🟡 Q24. Rego viết đúng nhưng policy không bao giờ trigger — debug thế nào?

**A:**
1. Kiểm tra `kubectl get constrainttemplate` → status có lỗi compile Rego không
2. `kubectl describe constrainttemplate <name>` → xem `.status.byPod[].errors`
3. Dùng **OPA Playground** (play.openpolicyagent.org) để test Rego độc lập với input JSON
4. Kiểm tra `input.review.object` structure thực tế: `kubectl get pod <name> -o json` rồi dùng làm test input
5. Gatekeeper có thể có **namespace exemption** — kiểm tra `gatekeeper-system` namespace config

---

### 🔴 Q25. Một developer tình cờ được cấp `ClusterRoleBinding` với `cluster-admin` — phát hiện và fix thế nào?

**A:**
**Phát hiện:**
```bash
kubectl get clusterrolebinding -o wide | grep cluster-admin
kubectl get clusterrolebinding <name> -o yaml
```

**Fix:**
```bash
kubectl delete clusterrolebinding <name>
# Tạo lại với ClusterRole phù hợp hơn
```

**Kiểm tra audit log** (CloudTrail / EKS audit log) xem đã làm gì với quyền đó

**Preventive:**
- Gatekeeper constraint: block `ClusterRoleBinding` với `roleRef.name: cluster-admin` ngoài namespace `kube-system`
- `validationActions: Deny` cho VAP tương đương
- **Least privilege review** định kỳ: `kubectl get clusterrolebinding -o wide`

---

### 🔴 Q26. Cluster đang production, muốn enforce `require-non-root` mà không downtime — làm thế nào?

**A:**
**Bước 1 — audit không disrupt:**
```bash
# Deploy constraint với dryrun
enforcementAction: dryrun
```

**Bước 2 — xem violations hiện có:**
```bash
kubectl get k8srequirenonroot require-non-root -o yaml | grep -A 20 violations
```

**Bước 3 — fix từng workload:**
- Thêm `securityContext.runAsNonRoot: true` + `runAsUser: <non-zero>` vào Deployment
- Rolling update từng service

**Bước 4 — chuyển warn trước:**
```bash
kubectl patch ... enforcementAction: warn
```

**Bước 5 — monitor 1–2 ngày, enforce:**
```bash
kubectl patch ... enforcementAction: deny
```

- Keyword: **phased rollout**, **dryrun → warn → deny**, **zero downtime**

---

## PHẦN 4 — Kết nối AWS + EKS

### 🟡 Q27. IRSA là gì, khác ServiceAccount RBAC thuần túy thế nào?

**A:**
- **IRSA** (IAM Roles for Service Accounts) = ServiceAccount K8s được annotate với IAM Role ARN
- SA token được sign bởi OIDC provider của EKS cluster → AWS STS verify → issue **short-lived AWS credentials**
- **RBAC thuần túy**: control quyền trong K8s cluster
- **IRSA**: control quyền với **AWS services** (S3, DynamoDB, Secrets Manager, ...)
- Thay thế cho static AWS credentials (Access Key/Secret) trong Pod → **không hardcode key**

```yaml
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-app-role
```

---

### 🟡 Q28. Tại sao không dùng static AWS credentials (env var) trong Pod?

**A:**
- Credentials **không rotate** tự động
- Nếu Pod bị compromise → attacker có **long-lived credential**
- Credentials có thể bị leak qua `kubectl describe pod`, log, env dump
- Vi phạm **AWS Security Best Practices**: prefer temporary credentials
- IRSA → token expire sau **15 phút** → blast radius nhỏ hơn nhiều

---

### 🔴 Q29. Pod trên EKS không thể gọi AWS Secrets Manager mặc dù IAM Role có đủ quyền — debug thế nào?

**A:**
1. Kiểm tra SA có annotation `eks.amazonaws.com/role-arn` không
2. Kiểm tra namespace có label `oidc` không (một số setup cần)
3. `kubectl exec -it <pod> -- env | grep AWS` → xem `AWS_ROLE_ARN`, `AWS_WEB_IDENTITY_TOKEN_FILE`
4. Nếu thiếu env vars → IRSA chưa được inject → kiểm tra EKS Pod Identity / IRSA config
5. Test assume role thủ công:
```bash
aws sts assume-role-with-web-identity \
  --role-arn <arn> \
  --web-identity-token <token> \
  --role-session-name test
```
6. Kiểm tra IAM Role **trust policy** có trust EKS OIDC provider không
7. Kiểm tra IAM Policy có permission `secretsmanager:GetSecretValue` và đúng resource ARN không

---

## PHẦN 5 — Câu hỏi kiểu "What happens if..."

### 🟡 Q30. Nếu xóa RoleBinding của một ServiceAccount đang được dùng bởi Deployment — điều gì xảy ra?

**A:**
- Pod **đang chạy** không bị ảnh hưởng ngay (RBAC check per request, không per session)
- Lần **tiếp theo Pod gọi API** → `Forbidden`
- Pod không restart, app có thể tiếp tục chạy nếu không gọi K8s API liên tục
- New Pod tạo ra (sau rolling update, crash) → vẫn có SA token nhưng bị Forbidden khi gọi API
- Fix: recreate RoleBinding

---

### 🟡 Q31. Gatekeeper constraint `deny` đang bật, ai đó apply một CronJob tạo Pod không có `resources.limits` — điều gì xảy ra?

**A:**
- CronJob object được **tạo thành công** (Gatekeeper match kind `Pod`, không match `CronJob`)
- Khi CronJob trigger tạo **Job → Pod** → Gatekeeper check Pod spec → **reject**
- CronJob vẫn tồn tại nhưng Job/Pod luôn fail với admission error
- Fix: thêm `resources.limits` vào CronJob `spec.jobTemplate.spec.template.spec.containers`
- Lesson: phải match **đúng kind** (Pod thay vì CronJob/Deployment) vì Pod được tạo gián tiếp

---

### 🔴 Q32. Rollout một ConstraintTemplate mới làm cluster bị lỗi — cách rollback?

**A:**
```bash
# Xóa Constraint trước (tránh orphan constraint)
kubectl delete <constraint-kind> <name>

# Xóa ConstraintTemplate
kubectl delete constrainttemplate <name>
```
- Xóa Template tự động xóa CRD tương ứng và **tất cả Constraint** của template đó
- Nếu Gatekeeper controller crash do Rego lỗi → patch ConstraintTemplate sửa Rego
- **Không nên** apply template lỗi compile lên production → test ở OPA Playground trước
- Kiểm tra: `kubectl get constrainttemplate <name> -o yaml` → `.status.byPod[].errors`

---

## Quick Reference — Các lệnh debug hay dùng nhất

```bash
# RBAC
kubectl auth can-i <verb> <resource> -n <ns>
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa> -n <ns>
kubectl auth can-i --list -n <ns>
kubectl get rolebinding,clusterrolebinding -A -o wide | grep <name>

# Gatekeeper
kubectl get constrainttemplate
kubectl get constraint -A
kubectl get <constraint-kind> <name> -o yaml            # xem violations
kubectl describe constrainttemplate <name>              # xem Rego compile error

# ServiceAccount
kubectl get sa -n <ns>
kubectl describe sa <name> -n <ns>
kubectl get pod <name> -o jsonpath='{.spec.serviceAccountName}'

# Policy enforcement action
kubectl patch <constraint-kind> <name> \
  --type=merge -p '{"spec":{"enforcementAction":"deny"}}'
```
