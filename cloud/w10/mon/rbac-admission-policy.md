# W10 Day A — RBAC + Admission Policy

Ngày học: T2 15/06/2026  
Chủ đề: Secure & Operate phần 1 — RBAC, ServiceAccount, OPA/Gatekeeper, ValidatingAdmissionPolicy

## Mục tiêu hôm nay

- Hiểu và phân biệt Role, ClusterRole, RoleBinding, ClusterRoleBinding trong Kubernetes RBAC.
- Biết tạo và gán ServiceAccount đúng nguyên tắc least privilege.
- Kiểm tra quyền với `kubectl auth can-i`.
- Nắm OPA Rego cơ bản và cách Gatekeeper biến Rego thành policy trên cluster.
- Phân biệt ConstraintTemplate vs Constraint trong Gatekeeper.
- Biết ValidatingAdmissionPolicy native (K8s 1.30+) và khi nào dùng thay Gatekeeper.
- Hiểu sự khác nhau giữa audit mode và enforce mode.

---

## Nguồn học hôm nay

### Bắt buộc

1. Kubernetes RBAC Docs  
   https://kubernetes.io/docs/reference/access-authn-authz/rbac

2. OPA (Open Policy Agent) — Rego intro  
   https://www.openpolicyagent.org/docs/latest/policy-language/

3. Gatekeeper Docs — ConstraintTemplate và Constraint  
   https://open-policy-agent.github.io/gatekeeper/website/docs/

4. ValidatingAdmissionPolicy (K8s 1.30+)  
   https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy

### Đọc thêm

1. Kyverno Docs (alternative cho Gatekeeper)  
   https://kyverno.io/docs

2. EKS Best Practices — Security  
   https://aws.github.io/aws-eks-best-practices/security/docs/

3. Kubernetes Pod Security Standards  
   https://kubernetes.io/docs/concepts/security/pod-security-standards

---

## Kế hoạch học ~6 giờ

| Thời lượng | Nội dung | Output cần có |
| ---------- | -------- | ------------- |
| 45 phút | RBAC concepts: Role, ClusterRole, RoleBinding, ClusterRoleBinding | Giải thích được sự khác nhau của 4 object này |
| 45 phút | ServiceAccount + IRSA overview | Tạo được SA và gán Role |
| 30 phút | `kubectl auth can-i` — kiểm tra và debug quyền | Chạy được ít nhất 5 lệnh kiểm tra quyền |
| 60 phút | OPA Rego cơ bản | Đọc và hiểu được 1 policy Rego đơn giản |
| 75 phút | Gatekeeper: ConstraintTemplate + Constraint | Viết và apply được 1 constraint template + constraint |
| 45 phút | ValidatingAdmissionPolicy native K8s | So sánh được với Gatekeeper |
| 45 phút | Audit mode vs enforce mode — thử trong lab | Ghi lại hành vi cluster khi audit vs enforce |
| 30 phút | Tổng kết, reflection, câu hỏi cho live T4 | Cập nhật evidence |

---

## Ghi chú bài học

### 1. Tại sao cần RBAC?

W8 và W9 deploy ứng dụng lên cluster bằng kubeconfig của admin. Trong thực tế, không ai được dùng admin credential cho mọi tác vụ. RBAC (Role-Based Access Control) là cơ chế Kubernetes dùng để giới hạn **ai được làm gì với resource nào trong namespace nào**.

Nguyên tắc cốt lõi: **least privilege** — chỉ cấp đủ quyền cần thiết, không cấp thêm.

Câu hỏi mà RBAC trả lời:

> "Subject `developer-alice` có được `create` Pod trong namespace `production` không?"

---

### 2. Bốn object RBAC cần nắm

#### Role và ClusterRole

`Role` khai báo tập hợp permission trong **một namespace cụ thể**.  
`ClusterRole` khai báo permission ở **cluster scope** (không thuộc namespace) hoặc có thể tái sử dụng lại ở nhiều namespace.

```yaml
# Role: chỉ có hiệu lực trong namespace "dev"
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: dev
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
```

```yaml
# ClusterRole: có hiệu lực toàn cluster hoặc được bind vào namespace tùy ý
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewer
rules:
  - apiGroups: ["", "apps", "batch"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
```

#### RoleBinding và ClusterRoleBinding

`RoleBinding` gán Role hoặc ClusterRole vào một **namespace cụ thể**.  
`ClusterRoleBinding` gán ClusterRole ở **toàn cluster**.

```yaml
# RoleBinding: gán ClusterRole "viewer" cho user "alice" trong namespace "staging"
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: alice-viewer
  namespace: staging
subjects:
  - kind: User
    name: alice
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: viewer
  apiGroup: rbac.authorization.k8s.io
```

**Bảng phân biệt nhanh:**

| Object | Scope | Dùng khi |
| ------ | ----- | -------- |
| Role | Namespace | Permission chỉ cần trong 1 namespace |
| ClusterRole | Cluster-wide | Permission dùng lại nhiều namespace hoặc resource cluster-scope |
| RoleBinding | Namespace | Gán Role/ClusterRole vào namespace cụ thể |
| ClusterRoleBinding | Cluster-wide | Gán ClusterRole cho toàn cluster (cẩn thận) |

---

### 3. Ba role mục tiêu cuối W10

Cluster cuối tuần cần có 3 role rõ ràng:

| Role | Quyền | Namespace scope |
| ---- | ----- | --------------- |
| `developer` | `get/list/watch/create/update/patch` trên Deployment, Pod, Service, ConfigMap | Namespace ứng dụng |
| `sre` | Tất cả quyền `developer` + `delete`, `exec` vào Pod, đọc Secret (không tạo) | Namespace ứng dụng + namespace monitoring |
| `viewer` | `get/list/watch` trên mọi resource (không write) | Toàn cluster (ClusterRole) |

---

### 4. ServiceAccount

`ServiceAccount` là identity cho **process chạy trong Pod**, không phải cho người dùng. Mặc định mỗi namespace có `default` ServiceAccount nhưng không nên dùng cho workload thật.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-api
  namespace: dev
```

Gán quyền cho ServiceAccount bằng RoleBinding:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: backend-api-developer
  namespace: dev
subjects:
  - kind: ServiceAccount
    name: backend-api
    namespace: dev
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

Dùng ServiceAccount trong Deployment:

```yaml
spec:
  serviceAccountName: backend-api
```

**Quan trọng:** Tắt auto-mount token nếu Pod không cần gọi Kubernetes API:

```yaml
spec:
  automountServiceAccountToken: false
```

---

### 5. `kubectl auth can-i` — kiểm tra quyền

Lệnh quan trọng nhất để debug RBAC:

```bash
# Bản thân mình có quyền gì?
kubectl auth can-i create pods -n dev
kubectl auth can-i delete deployments -n production

# Kiểm tra quyền của một user khác (cần admin)
kubectl auth can-i list secrets --as=alice -n staging

# Kiểm tra quyền của ServiceAccount
kubectl auth can-i get pods --as=system:serviceaccount:dev:backend-api -n dev

# List tất cả quyền của mình trong namespace
kubectl auth can-i --list -n dev

# Kiểm tra quyền cluster-scoped
kubectl auth can-i list nodes
```

Workflow debug RBAC điển hình:

```text
Pod lỗi "Forbidden" khi gọi API
  -> kubectl describe pod <name>  # xem SA đang dùng
  -> kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa> -n <ns>
  -> Xem Role/RoleBinding có binding SA đó không
  -> Sửa Role hoặc thêm RoleBinding
```

---

### 6. OPA và Rego cơ bản

RBAC kiểm soát **ai** có quyền làm gì. Nhưng RBAC không thể nói "developer được tạo Pod nhưng Pod đó **phải có** `resources.limits`". Đây là lý do cần **admission policy**.

**OPA (Open Policy Agent)** là policy engine viết policy bằng ngôn ngữ **Rego**. Khi tích hợp vào Kubernetes qua Gatekeeper, OPA đóng vai trò webhook — mỗi request tạo/sửa resource đều phải qua OPA trước khi Kubernetes accept.

Cấu trúc Rego tối thiểu:

```rego
# Deny request nếu container không có resource limits
package k8srequiredlimits

violation[{"msg": msg}] {
    container := input.review.object.spec.containers[_]
    not container.resources.limits
    msg := sprintf("Container '%v' thiếu resource limits", [container.name])
}
```

Giải thích từng phần:

- `package`: tên package, phải khớp với ConstraintTemplate.
- `violation[{"msg": msg}]`: rule trả về violation khi điều kiện bên dưới thỏa mãn.
- `input.review.object`: object Kubernetes đang được request (Pod, Deployment, ...).
- `container[_]`: duyệt qua mọi container trong spec.
- `not container.resources.limits`: điều kiện vi phạm — không có limits.

---

### 7. Gatekeeper: ConstraintTemplate và Constraint

Gatekeeper là Kubernetes-native wrapper cho OPA. Gatekeeper dùng 2 custom resource:

**ConstraintTemplate** — định nghĩa loại policy (viết Rego ở đây):

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlimits
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLimits
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlimits

        violation[{"msg": msg}] {
            container := input.review.object.spec.containers[_]
            not container.resources.limits
            msg := sprintf("Container '%v' thiếu resource limits", [container.name])
        }
```

**Constraint** — áp dụng ConstraintTemplate vào scope cụ thể (namespace, label, ...):

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLimits
metadata:
  name: require-resource-limits
spec:
  enforcementAction: deny   # hoặc: warn (audit mode), dryrun
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces: ["dev", "staging", "production"]
```

**Luồng hoạt động:**

```text
kubectl apply Pod
  -> kube-apiserver
  -> Gatekeeper admission webhook
  -> Rego evaluate input
  -> violation? -> reject với message
  -> no violation? -> Kubernetes accept và store vào etcd
```

**4 Constraint enforce mục tiêu cuối W10:**

| Constraint | Mô tả |
| ---------- | ----- |
| `require-resource-limits` | Mọi container phải có `resources.limits` |
| `require-non-root` | Pod không được chạy với `runAsRoot: true` |
| `disallow-latest-tag` | Image không được dùng tag `:latest` |
| `require-trusted-registry` | Image chỉ được pull từ registry đã cho phép |

---

### 8. ValidatingAdmissionPolicy (K8s 1.30+ native)

Từ K8s 1.28 beta, 1.30 stable, Kubernetes có **ValidatingAdmissionPolicy** built-in — không cần cài Gatekeeper/OPA. Policy viết bằng **CEL (Common Expression Language)**.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-resource-limits
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: >
        object.spec.containers.all(c,
          has(c.resources) && has(c.resources.limits))
      message: "Mọi container phải khai báo resource limits"
```

Bind policy vào scope bằng `ValidatingAdmissionPolicyBinding`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-resource-limits-binding
spec:
  policyName: require-resource-limits
  validationActions: [Deny]   # hoặc: Warn, Audit
  matchResources:
    namespaceSelector:
      matchLabels:
        enforce-limits: "true"
```

**So sánh Gatekeeper vs ValidatingAdmissionPolicy:**

| Tiêu chí | Gatekeeper | ValidatingAdmissionPolicy |
| -------- | ---------- | ------------------------- |
| Ngôn ngữ policy | Rego | CEL |
| Cài đặt | Cần deploy Gatekeeper (CRD + controller) | Built-in từ K8s 1.28+ |
| Độ linh hoạt | Cao hơn, Rego mạnh hơn CEL | Đủ dùng cho hầu hết use case cơ bản |
| Ecosystem | OPA có nhiều policy library sẵn | Còn mới, ecosystem đang phát triển |
| Phù hợp khi | Cần logic phức tạp, nhiều policy tái sử dụng | Muốn đơn giản, không cần external dependency |

---

### 9. Audit mode vs Enforce mode

Khi rollout policy mới, không nên enforce ngay vì có thể break workload hiện có.

**Workflow an toàn:**

```text
Bước 1: Deploy constraint với enforcementAction: warn  (hoặc dryrun)
  -> Cluster vẫn accept request vi phạm
  -> Gatekeeper log violation vào audit

Bước 2: Xem audit violation
kubectl get constraint <name> -o yaml
# Xem phần .status.violations

Bước 3: Fix workload vi phạm

Bước 4: Chuyển sang enforce
kubectl patch <constraint-type> <name> \
  --type=merge -p '{"spec":{"enforcementAction":"deny"}}'
```

**Các giá trị `enforcementAction`:**

| Giá trị | Hành vi |
| ------- | ------- |
| `deny` | Reject request ngay khi tạo/sửa (enforce) |
| `warn` | Accept nhưng trả về warning message cho người dùng |
| `dryrun` | Accept và chỉ log violation, không notify |

Với `ValidatingAdmissionPolicy`, tương tự dùng `validationActions: [Audit]` trước khi chuyển sang `[Deny]`.

---

## Bài thực hành đề xuất

### Cấu trúc thư mục D1

```text
cloud/w10/
├── mon/
│   ├── rbac-admission-policy.md      # file này
│   ├── NOTES.md
│   └── imgs/
│       ├── rbac-can-i.png
│       ├── gatekeeper-violation.png
│       └── constraint-audit.png
└── day-a/
    ├── rbac/
    │   ├── role-developer.yaml
    │   ├── role-sre.yaml
    │   ├── clusterrole-viewer.yaml
    │   ├── serviceaccount-backend.yaml
    │   ├── rolebinding-developer.yaml
    │   ├── rolebinding-sre.yaml
    │   └── clusterrolebinding-viewer.yaml
    └── policies/
        ├── template-require-limits.yaml
        ├── constraint-require-limits.yaml
        ├── template-require-nonroot.yaml
        ├── constraint-require-nonroot.yaml
        ├── template-disallow-latest.yaml
        └── constraint-disallow-latest.yaml
```

---

### Lab 1 — Tạo 3 Role + test với `kubectl auth can-i`

**Bước 1: Tạo namespace và Role**

```bash
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace production
```

Tạo các file manifest theo cấu trúc `day-a/rbac/` ở trên rồi apply:

```bash
kubectl apply -f cloud/w10/day-a/rbac/
```

**Bước 2: Tạo user giả (dùng ServiceAccount để test)**

```bash
# Tạo SA để giả lập user "developer"
kubectl create serviceaccount test-developer -n dev
kubectl create serviceaccount test-sre -n dev
kubectl create serviceaccount test-viewer -n dev

# Bind role
kubectl create rolebinding test-developer-bind \
  --role=developer \
  --serviceaccount=dev:test-developer \
  -n dev
```

**Bước 3: Kiểm tra quyền**

```bash
# Developer có thể tạo pod không?
kubectl auth can-i create pods \
  --as=system:serviceaccount:dev:test-developer -n dev

# Developer có thể xóa pod không? (phải là no)
kubectl auth can-i delete pods \
  --as=system:serviceaccount:dev:test-developer -n dev

# Developer có thể đọc secret không? (phải là no)
kubectl auth can-i get secrets \
  --as=system:serviceaccount:dev:test-developer -n dev

# SRE có thể exec vào pod không?
kubectl auth can-i create pods/exec \
  --as=system:serviceaccount:dev:test-sre -n dev

# Viewer có thể list nodes không? (ClusterRole)
kubectl auth can-i list nodes \
  --as=system:serviceaccount:dev:test-viewer
```

Ghi lại output vào evidence. Screenshot `cloud/w10/mon/imgs/rbac-can-i.png`.

---

### Lab 2 — Cài Gatekeeper và viết Constraint đầu tiên

**Bước 1: Cài Gatekeeper lên minikube**

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.15/deploy/gatekeeper.yaml

# Đợi Gatekeeper ready
kubectl wait --for=condition=Ready pod \
  -l control-plane=controller-manager \
  -n gatekeeper-system --timeout=120s
```

**Bước 2: Tạo ConstraintTemplate require-resource-limits**

Tạo file `cloud/w10/day-a/policies/template-require-limits.yaml` với nội dung trong mục 7, sau đó:

```bash
kubectl apply -f cloud/w10/day-a/policies/template-require-limits.yaml

# Verify CRD được tạo
kubectl get constrainttemplate k8srequiredlimits
```

**Bước 3: Apply Constraint ở dryrun mode trước**

Tạo file `cloud/w10/day-a/policies/constraint-require-limits.yaml`, đặt `enforcementAction: dryrun` rồi apply:

```bash
kubectl apply -f cloud/w10/day-a/policies/constraint-require-limits.yaml
```

**Bước 4: Test violation**

Tạo Pod vi phạm (không có resource limits):

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: test-no-limits
  namespace: dev
spec:
  containers:
  - name: nginx
    image: nginx:1.25
EOF
```

Ở dryrun mode Pod vẫn tạo được. Kiểm tra violation đã được log:

```bash
kubectl get k8srequiredlimits require-resource-limits -o yaml
# Xem .status.violations
```

**Bước 5: Chuyển sang enforce**

```bash
kubectl patch k8srequiredlimits require-resource-limits \
  --type=merge \
  -p '{"spec":{"enforcementAction":"deny"}}'

# Thử tạo pod không có limits — phải bị reject
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: test-enforce-no-limits
  namespace: dev
spec:
  containers:
  - name: nginx
    image: nginx:1.25
EOF
```

Screenshot lỗi vào `cloud/w10/mon/imgs/gatekeeper-violation.png`.

---

### Lab 3 — ValidatingAdmissionPolicy (nếu cluster K8s 1.30+)

Kiểm tra version cluster:

```bash
kubectl version --short
```

Nếu >= 1.30, thử tạo ValidatingAdmissionPolicy theo ví dụ ở mục 8. So sánh trải nghiệm với Gatekeeper và ghi chú vào NOTES.md.

---

### Lab 4 — Viết thêm 2 Constraint còn lại

Tự viết ConstraintTemplate + Constraint cho:

1. `require-non-root` — Pod phải có `securityContext.runAsNonRoot: true`
2. `disallow-latest-tag` — Image không được dùng tag `:latest`

Gợi ý Rego cho `disallow-latest-tag`:

```rego
package k8sdisallowlatesttag

violation[{"msg": msg}] {
    container := input.review.object.spec.containers[_]
    endswith(container.image, ":latest")
    msg := sprintf("Container '%v' không được dùng tag :latest", [container.name])
}

violation[{"msg": msg}] {
    container := input.review.object.spec.containers[_]
    not contains(container.image, ":")
    msg := sprintf("Container '%v' phải khai báo image tag rõ ràng", [container.name])
}
```

---

## Checklist hôm nay

- [ ] Giải thích được Role vs ClusterRole và khi nào dùng cái nào.
- [ ] Giải thích được RoleBinding vs ClusterRoleBinding.
- [ ] Tạo được 3 Role: `developer`, `sre`, `viewer`.
- [ ] Tạo được ServiceAccount và gán Role.
- [ ] Chạy được `kubectl auth can-i` để verify quyền.
- [ ] Giải thích được OPA Rego: `package`, `violation`, `input.review.object`.
- [ ] Phân biệt được ConstraintTemplate và Constraint.
- [ ] Apply được 1 Constraint ở dryrun rồi chuyển sang enforce.
- [ ] Xem được violation trong `.status.violations`.
- [ ] Biết ValidatingAdmissionPolicy là gì và khi nào dùng thay Gatekeeper.
- [ ] Ghi câu hỏi cho live T4 về IRSA và RBAC thực tế trên EKS.

---

## Evidence cần nộp

Trong `cloud/w10/mon/NOTES.md`, ghi tối thiểu:

- Commit message dạng `[W10-D1] rbac-admission-policy`.
- Output `kubectl auth can-i --list -n dev` (hoặc screenshot).
- Output sau khi Gatekeeper reject Pod vi phạm.
- Danh sách các Constraint đã apply và enforcementAction hiện tại.
- So sánh ngắn Gatekeeper vs ValidatingAdmissionPolicy (3–5 câu bằng lời của mình).
- Câu hỏi còn vướng cho mentor.

Lưu ảnh tại:

```text
cloud/w10/mon/imgs/rbac-can-i.png
cloud/w10/mon/imgs/gatekeeper-violation.png
cloud/w10/mon/imgs/constraint-audit.png
```

---

## Câu hỏi ôn tập

1. Role và ClusterRole khác nhau ở điểm nào cốt lõi?
2. Khi nào dùng ClusterRoleBinding thay vì RoleBinding?
3. `system:serviceaccount:dev:backend-api` nghĩa là gì?
4. `automountServiceAccountToken: false` nên đặt ở trường hợp nào?
5. Tại sao RBAC chưa đủ để đảm bảo security cluster? Admission policy bổ sung gì?
6. ConstraintTemplate và Constraint có quan hệ như CRD và CR — đúng hay sai? Giải thích.
7. Tại sao nên chạy dryrun trước khi enforce một policy mới?
8. ValidatingAdmissionPolicy có thể thay hoàn toàn Gatekeeper trong mọi trường hợp không? Tại sao?
9. Nếu Gatekeeper webhook down, cluster xử lý admission request thế nào?
10. Làm thế nào để biết một Pod đang chạy bị vi phạm policy nhưng đã tạo trước khi enforce?

---

## Chuẩn bị cho Live T4 (17/06) — câu hỏi nên mang

- IRSA (IAM Roles for Service Accounts) khác ServiceAccount RBAC thuần túy ở chỗ nào?
- Trên EKS production, ai giữ ClusterAdmin? Kiểm soát bằng cơ chế gì?
- Gatekeeper và OPA có thể block `kubectl exec` vào Pod không?

---

## Tài liệu tham khảo

- Kubernetes RBAC: https://kubernetes.io/docs/reference/access-authn-authz/rbac
- OPA Rego Language: https://www.openpolicyagent.org/docs/latest/policy-language/
- Gatekeeper: https://open-policy-agent.github.io/gatekeeper/website/docs/
- ValidatingAdmissionPolicy: https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy
- Gatekeeper policy library: https://www.openpolicyagent.org/docs/latest/kubernetes-primer/
- EKS Security Best Practices: https://aws.github.io/aws-eks-best-practices/security/docs/
