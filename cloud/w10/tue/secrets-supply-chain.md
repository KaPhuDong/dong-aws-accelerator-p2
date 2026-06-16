# W10 Day B — Secrets Rotation + Supply Chain Security

Ngày học: T3 16/06/2026
Chủ đề: Secure & Operate phần 2 — AWS Secrets Manager, External Secrets Operator, Trivy CI scan, Cosign signing, Admission verify signature

## Mục tiêu hôm nay

- Hiểu tại sao không được hardcode secret vào manifest / env var / image.
- Biết cách AWS Secrets Manager lưu và rotate secret tự động.
- Nắm External Secrets Operator (ESO): cách sync secret từ AWS vào Kubernetes < 60s, không restart Pod.
- Hiểu Trivy scan image trong CI và policy fail-on HIGH/CRITICAL.
- Biết Cosign: keyless OIDC signing và key-based signing.
- Hiểu admission webhook verify signature — reject unsigned image trước khi vào cluster.
- Nắm SLSA supply chain levels ở mức concept.
- Biết exception policy CVE có thời hạn.

---

## Nguồn học hôm nay

### Bắt buộc

1. AWS Secrets Manager Docs
   https://docs.aws.amazon.com/secretsmanager

2. External Secrets Operator (ESO)
   https://external-secrets.io/latest

3. Trivy Docs — image scan
   https://aquasecurity.github.io/trivy

4. Cosign / Sigstore Docs
   https://docs.sigstore.dev/cosign/overview

5. Kyverno Verify Images
   https://kyverno.io/policies/?policytypes=verifyImages

6. SLSA Framework
   https://slsa.dev

### Đọc thêm

1. Sealed Secrets (alternative cho ESO)
   https://github.com/bitnami-labs/sealed-secrets

2. OWASP CI/CD Top 10
   https://owasp.org/www-project-top-10-ci-cd-security-risks

3. SLSA Supply Chain Levels v1.0
   https://slsa.dev/spec/v1.0/levels

---

## Kế hoạch học ~6 giờ

| Thời lượng | Nội dung | Output cần có |
| ---------- | -------- | ------------- |
| 45 phút | Vấn đề secret trong K8s và giải pháp tổng quan | Liệt kê được 3 cách sai phổ biến và cách đúng |
| 60 phút | AWS Secrets Manager: tạo secret, rotation, access policy | Giải thích được rotation tự động hoạt động thế nào |
| 75 phút | External Secrets Operator: SecretStore, ExternalSecret, refreshInterval | Viết được manifest ESO sync secret từ AWS |
| 45 phút | Trivy: scan image, scan repo, CI integration + fail policy | Chạy được `trivy image` local và hiểu output |
| 60 phút | Cosign: keyless signing, key-based signing, verify | Sign và verify được 1 image local |
| 45 phút | Admission verify signature (Kyverno / Gatekeeper) | Viết được Kyverno policy verify image signature |
| 30 phút | SLSA levels + exception CVE policy | Giải thích được SLSA Level 1 → 3 |
| 30 phút | Tổng kết, reflection, câu hỏi cho live T4 | Cập nhật evidence |

---

## Ghi chú bài học

### 1. Vấn đề secret trong Kubernetes

Ba cách sai phổ biến nhất:

| Cách sai | Rủi ro |
| -------- | ------ |
| Hardcode trong Dockerfile / source code | Lộ trong git history, image layer |
| Đặt trong env var của Deployment | Ai có `kubectl get pod -o yaml` là đọc được |
| Dùng K8s Secret gốc không encrypt | etcd lưu base64 — không phải encrypt, ai đọc etcd là xong |

Nguyên tắc đúng:
- Secret **không bao giờ** vào git repo
- K8s Secret phải được **encrypt at rest** (EKS: KMS envelope encryption)
- Prefer **short-lived credentials** (IRSA, token) thay vì long-lived key
- Secret **rotate tự động** — không phụ thuộc "developer nhớ đổi"

---

### 2. AWS Secrets Manager

AWS Secrets Manager là dịch vụ lưu trữ và quản lý secret tập trung. Khác với SSM Parameter Store (đơn giản hơn), Secrets Manager có:

- **Automatic rotation** — Lambda rotate secret theo schedule mà không cần downtime
- **Versioning** — giữ `AWSCURRENT` và `AWSPREVIOUS` để ứng dụng không bị gián đoạn khi rotate
- **Fine-grained access** — IAM policy quyết định resource nào được `GetSecretValue`
- **Audit trail** — mọi access đều log vào CloudTrail

**Lifecycle rotation:**

```text
Rotation trigger (schedule hoặc manual)
  -> Lambda "rotation function" được gọi với 4 step:
     1. createSecret  — tạo version mới với value mới
     2. setSecret     — cập nhật secret ở phía database/service
     3. testSecret    — verify version mới hoạt động
     4. finishSecret  — promote AWSPENDING -> AWSCURRENT
```

Trong suốt quá trình này, `AWSPREVIOUS` vẫn valid để app đang dùng không bị lỗi ngay.

**Tạo secret cơ bản:**

```bash
aws secretsmanager create-secret \
  --name "prod/myapp/db-password" \
  --secret-string '{"username":"admin","password":"s3cr3t!"}'

# Đọc secret
aws secretsmanager get-secret-value \
  --secret-id "prod/myapp/db-password" \
  --query SecretString \
  --output text
```

**IAM policy cho ứng dụng đọc secret:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
      "Resource": "arn:aws:secretsmanager:ap-southeast-1:123456789012:secret:prod/myapp/*"
    }
  ]
}
```

---

### 3. External Secrets Operator (ESO)

ESO là Kubernetes operator bridge secret từ external store (AWS Secrets Manager, SSM, Vault, GCP, ...) vào K8s Secret. Pod dùng K8s Secret như bình thường — không cần biết secret đến từ đâu.

**Hai CRD chính:**

| CRD | Vai trò |
| --- | ------- |
| `SecretStore` | Kết nối đến external secret provider (per namespace) |
| `ClusterSecretStore` | Giống SecretStore nhưng cluster-scoped, dùng lại nhiều namespace |
| `ExternalSecret` | Khai báo secret nào cần sync, sync vào K8s Secret nào |

**Luồng hoạt động:**

```text
ExternalSecret CR tạo/update
  -> ESO controller watch
  -> Gọi AWS Secrets Manager GetSecretValue
  -> Tạo hoặc update K8s Secret
  -> Pod mount K8s Secret như bình thường
  -> refreshInterval tick -> ESO re-sync (rotate tự động)
```

**Mục tiêu W10:** ESO rotate secret < 60s **không restart Pod** — dùng volume mount thay vì env var.

**SecretStore (dùng IRSA):**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: dev
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-southeast-1
      auth:
        jwt:
          serviceAccountRef:
            name: eso-sa   # SA có annotation IRSA
```

**ExternalSecret:**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: dev
spec:
  refreshInterval: 30s          # sync mỗi 30 giây
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: db-secret             # tên K8s Secret sẽ được tạo
    creationPolicy: Owner
  data:
    - secretKey: password       # key trong K8s Secret
      remoteRef:
        key: prod/myapp/db-password   # tên secret trên AWS
        property: password            # field trong JSON secret
```

**Mount bằng volume (để auto-update không cần restart):**

```yaml
spec:
  volumes:
    - name: db-secret-vol
      secret:
        secretName: db-secret
  containers:
    - name: app
      volumeMounts:
        - name: db-secret-vol
          mountPath: /etc/secrets
          readOnly: true
```

Ứng dụng đọc `/etc/secrets/password` — khi ESO cập nhật K8s Secret, kubelet tự động cập nhật file trong volume trong vài giây mà **không cần restart Pod**.

> Nếu dùng `envFrom` hoặc `env.valueFrom.secretKeyRef` → Pod **phải restart** để lấy giá trị mới. Đây là lý do phải dùng volume mount cho rotation không downtime.

---

### 4. Trivy — Image Scan trong CI

Trivy là tool scan vulnerability open-source của Aqua Security. Trivy quét:

- **Container image** — OS packages, language dependencies
- **Filesystem / repo** — source code, IaC, config files
- **K8s cluster** — misconfiguration, exposed secret

**Scan image cơ bản:**

```bash
# Scan image local hoặc từ registry
trivy image nginx:1.25

# Scan và chỉ show HIGH + CRITICAL
trivy image --severity HIGH,CRITICAL nginx:1.25

# Scan và output JSON (dùng trong CI)
trivy image --format json --output trivy-report.json nginx:1.25

# Fail CI nếu có lỗi CRITICAL
trivy image --exit-code 1 --severity CRITICAL nginx:1.25
```

**Output của Trivy:**

```text
nginx:1.25 (debian 11.7)
Total: 147 (UNKNOWN: 0, LOW: 87, MEDIUM: 47, HIGH: 12, CRITICAL: 1)

┌─────────────────┬────────────────┬──────────┬─────────────────────┬──────────┐
│    Library      │ Vulnerability  │ Severity │   Installed Version │ Fixed In │
├─────────────────┼────────────────┼──────────┼─────────────────────┼──────────┤
│ openssl         │ CVE-2023-XXXXX │ CRITICAL │ 1.1.1n-0+deb11u4    │ 1.1.1w   │
└─────────────────┴────────────────┴──────────┴─────────────────────┴──────────┘
```

**Tích hợp vào GitHub Actions:**

```yaml
name: image-security-scan

on:
  push:
    branches: [main]
  pull_request:

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Trivy scan — fail on CRITICAL
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          format: table
          exit-code: 1
          severity: CRITICAL

      - name: Trivy scan — report HIGH (no fail)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          format: sarif
          output: trivy-results.sarif
          severity: HIGH

      - name: Upload scan results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: trivy-results.sarif
```

**Exception CVE có thời hạn:**

Khi có CVE chưa có fix nhưng cần deploy gấp, dùng `.trivyignore`:

```text
# .trivyignore
# CVE-2023-XXXXX: openssl — chưa có fix, review lại 2026-07-01
# Approved by: security-team @2026-06-16
CVE-2023-XXXXX
```

Rule: exception phải có **comment lý do + ngày hết hạn + người approve**. Không được ignore vô thời hạn.

---

### 5. Cosign — Image Signing

Cosign là tool trong hệ sinh thái Sigstore để sign và verify container image. Mục tiêu: đảm bảo image trong registry **đúng là image đã được CI build và sign** — không bị tamper, không phải image giả.

**Hai mode signing:**

| Mode | Cơ chế | Dùng khi |
| ---- | ------- | -------- |
| **Keyless (OIDC)** | Dùng OIDC token (GitHub Actions, GitLab CI) để lấy short-lived cert từ Sigstore Fulcio CA | CI/CD pipeline, không cần quản lý key |
| **Key-based** | Dùng private key cố định để sign | Cần control key riêng, offline signing |

**Keyless signing trong GitHub Actions:**

```yaml
- name: Install cosign
  uses: sigstore/cosign-installer@v3

- name: Sign image (keyless)
  env:
    COSIGN_EXPERIMENTAL: "1"
  run: |
    cosign sign \
      --yes \
      ghcr.io/myorg/myapp@${{ steps.build.outputs.digest }}
```

Cosign lưu signature vào registry cùng image (OCI artifact). Không cần storage riêng.

**Key-based signing:**

```bash
# Tạo key pair
cosign generate-key-pair

# Sign image
cosign sign --key cosign.key myregistry/myapp:v1.0.0

# Verify
cosign verify --key cosign.pub myregistry/myapp:v1.0.0
```

**Verify image sau khi pull:**

```bash
# Verify keyless (dùng OIDC identity)
cosign verify \
  --certificate-identity "https://github.com/myorg/myrepo/.github/workflows/build.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/myorg/myapp:v1.0.0

# Verify key-based
cosign verify --key cosign.pub myregistry/myapp:v1.0.0
```

**Luồng trust với Sigstore:**

```text
GitHub Actions build image
  -> cosign sign (keyless) với OIDC token từ GitHub
  -> Sigstore Fulcio cấp short-lived cert (cert có identity: repo + workflow)
  -> Signature lưu vào Sigstore Rekor transparency log
  -> Signature attach vào image trong registry
  -> Admission webhook: cosign verify khi Pod được tạo
  -> Nếu không verify được -> reject Pod
```

---

### 6. Admission Verify Signature — Kyverno

Sau khi sign image, cần enforce tại cluster: **chỉ chạy image đã được sign**. Kyverno có built-in `verifyImages` rule cho việc này — đơn giản hơn Gatekeeper cho use case này.

**Kyverno ClusterPolicy verify image:**

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: verify-cosign-signature
      match:
        any:
          - resources:
              kinds: [Pod]
              namespaces: [dev, staging, production]
      verifyImages:
        - imageReferences:
            - "ghcr.io/myorg/*"
          attestors:
            - count: 1
              entries:
                - keyless:
                    subject: "https://github.com/myorg/myrepo/.github/workflows/build.yml@refs/heads/main"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
```

Khi Pod được tạo với image từ `ghcr.io/myorg/*`:
- Kyverno gọi `cosign verify` bên trong
- Nếu không có signature hợp lệ → **reject Pod** với message rõ ràng
- Nếu signature valid → allow

**Key-based verify (dùng public key):**

```yaml
verifyImages:
  - imageReferences: ["myregistry/myapp:*"]
    attestors:
      - entries:
          - keys:
              publicKeys: |-
                -----BEGIN PUBLIC KEY-----
                MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
                -----END PUBLIC KEY-----
```

---

### 7. SLSA — Supply Chain Levels

SLSA (Supply-chain Levels for Software Artifacts) là framework đánh giá độ tin cậy của software supply chain theo 4 level.

| Level | Yêu cầu chính | Ý nghĩa thực tế |
| ----- | ------------- | --------------- |
| **L0** | Không có gì | Baseline — không có bảo đảm |
| **L1** | Build có provenance (ghi lại how/where/when build) | Có thể audit được nguồn gốc |
| **L2** | Build trên hosted CI, source version controlled | CI tạo provenance, có thể verify |
| **L3** | Build hardened (isolated, không thể modify), two-party review | Build không thể bị tamper |

**Thực tế W10:**
- Image build bằng GitHub Actions + Cosign sign → đạt **SLSA L2**
- Thêm provenance attestation → tiến gần **SLSA L3**
- Đa số team bắt đầu từ L1, target L2 là đủ cho production vừa

**Tạo SLSA provenance trong GitHub Actions:**

```yaml
# Dùng slsa-github-generator
- uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v2
  with:
    image: ghcr.io/myorg/myapp
    digest: ${{ steps.build.outputs.digest }}
```

---

## Cấu trúc thư mục D2

```text
cloud/w10/
├── tue/
│   ├── secrets-supply-chain.md    # file này
│   ├── NOTES.md
│   └── imgs/
│       ├── eso-sync.png
│       ├── trivy-scan-output.png
│       ├── cosign-sign-verify.png
│       └── kyverno-reject.png
└── day-b/
    ├── eso/
    │   ├── secretstore.yaml
    │   └── externalsecret.yaml
    ├── signing/
    │   ├── kyverno-verify-policy.yaml
    │   └── cosign-verify.sh
    └── ci-trivy/
        ├── .trivyignore
        └── trivy-scan.yml          # GitHub Actions workflow
```

---

## Bài thực hành đề xuất

### Lab 1 — AWS Secrets Manager + ESO local (minikube)

**Bước 1: Tạo secret trên AWS**

```bash
aws secretsmanager create-secret \
  --name "w10/dev/db-password" \
  --secret-string '{"username":"devuser","password":"dev-s3cr3t"}'
```

**Bước 2: Cài ESO lên minikube**

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace
```

**Bước 3: Tạo SecretStore + ExternalSecret**

Tạo manifest theo cấu trúc `day-b/eso/`, apply và kiểm tra:

```bash
kubectl apply -f cloud/w10/day-b/eso/

# Kiểm tra ESO đã sync chưa
kubectl get externalsecret -n dev
kubectl get secret db-secret -n dev -o yaml

# Xem status sync
kubectl describe externalsecret db-credentials -n dev
```

**Bước 4: Test rotate**

```bash
# Cập nhật secret trên AWS
aws secretsmanager put-secret-value \
  --secret-id "w10/dev/db-password" \
  --secret-string '{"username":"devuser","password":"new-rotated-pass"}'

# Đợi refreshInterval (30s) rồi kiểm tra K8s Secret đã update chưa
sleep 35
kubectl get secret db-secret -n dev \
  -o jsonpath='{.data.password}' | base64 -d
```

Screenshot `cloud/w10/tue/imgs/eso-sync.png`.

---

### Lab 2 — Trivy scan image

**Bước 1: Scan local**

```bash
# Cài trivy (nếu chưa có)
# Windows: winget install AquaSecurity.Trivy
# hoặc dùng Docker: docker run aquasec/trivy image nginx:1.25

trivy image nginx:1.25
trivy image --severity HIGH,CRITICAL nginx:1.25
trivy image --exit-code 1 --severity CRITICAL nginx:1.25
```

**Bước 2: Scan image của chính mình**

Nếu có image từ W8/W9 portfolio:

```bash
trivy image <your-image>:<tag>
```

Ghi lại số lượng HIGH/CRITICAL. Screenshot `cloud/w10/tue/imgs/trivy-scan-output.png`.

**Bước 3: Tạo `.trivyignore` nếu có exception**

Tạo file `cloud/w10/day-b/ci-trivy/.trivyignore` với format đúng (comment lý do + expiry).

---

### Lab 3 — Cosign sign và verify

**Bước 1: Cài cosign**

```bash
# Windows: winget install sigstore.cosign
# hoặc: go install github.com/sigstore/cosign/v2/cmd/cosign@latest
cosign version
```

**Bước 2: Key-based signing (local test)**

```bash
# Tạo key pair
cosign generate-key-pair

# Tạo image giả để test (hoặc dùng image từ registry)
# Sign
cosign sign --key cosign.key <your-registry>/<image>:<tag>

# Verify
cosign verify --key cosign.pub <your-registry>/<image>:<tag>
```

Screenshot output verify vào `cloud/w10/tue/imgs/cosign-sign-verify.png`.

---

### Lab 4 — Kyverno verify image (nếu có minikube)

**Bước 1: Cài Kyverno**

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
```

**Bước 2: Apply ClusterPolicy verify signature**

Tạo manifest theo mục 6, bắt đầu với `validationFailureAction: Audit` rồi chuyển sang `Enforce`.

**Bước 3: Test**

```bash
# Tạo Pod với image chưa sign -> phải bị reject hoặc warning
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: test-unsigned
  namespace: dev
spec:
  containers:
  - name: app
    image: nginx:1.25
EOF

# Xem Kyverno policy report
kubectl get policyreport -n dev
```

Screenshot vào `cloud/w10/tue/imgs/kyverno-reject.png`.

---

## Checklist hôm nay

- [ ] Giải thích được 3 cách sai khi lưu secret và tại sao sai.
- [ ] Giải thích được rotation lifecycle trong AWS Secrets Manager (4 Lambda steps).
- [ ] Viết được manifest SecretStore + ExternalSecret ESO.
- [ ] Giải thích tại sao volume mount tốt hơn env var cho rotation không restart.
- [ ] Chạy được `trivy image` và đọc hiểu output severity.
- [ ] Biết policy fail-on CI: `--exit-code 1 --severity CRITICAL`.
- [ ] Giải thích được keyless vs key-based Cosign.
- [ ] Biết signature được lưu ở đâu (OCI artifact trong registry + Rekor log).
- [ ] Viết được Kyverno `verifyImages` policy.
- [ ] Giải thích được SLSA L1 → L2 → L3.
- [ ] Tạo `.trivyignore` đúng format với comment thời hạn.
- [ ] Ghi câu hỏi cho live T4.

---

## Evidence cần nộp

Trong `cloud/w10/tue/NOTES.md`, ghi tối thiểu:

- Commit message dạng `[W10-D2] secrets-rotation-supply-chain`.
- Output `kubectl get externalsecret -n dev` (hoặc screenshot).
- Kết quả Trivy scan — số lượng HIGH/CRITICAL của image đã chọn.
- Output `cosign verify` thành công.
- Kyverno policy report hoặc reject message (nếu đã lab).
- So sánh keyless vs key-based Cosign (3–5 gạch đầu dòng).
- Câu hỏi còn vướng cho mentor.

Lưu ảnh tại:

```text
cloud/w10/tue/imgs/eso-sync.png
cloud/w10/tue/imgs/trivy-scan-output.png
cloud/w10/tue/imgs/cosign-sign-verify.png
cloud/w10/tue/imgs/kyverno-reject.png
```

---

## Câu hỏi ôn tập

1. Tại sao K8s Secret gốc không phải là giải pháp bảo mật đủ cho production?
2. AWS Secrets Manager khác SSM Parameter Store ở điểm nào chính?
3. `AWSCURRENT` và `AWSPREVIOUS` trong rotation lifecycle có ý nghĩa gì?
4. `refreshInterval: 30s` trong ESO nghĩa là gì? Có khác với restart Pod không?
5. Tại sao phải dùng volume mount thay vì `env.valueFrom.secretKeyRef` để đạt rotate < 60s no-restart?
6. Trivy `--exit-code 1 --severity CRITICAL` làm gì với CI pipeline?
7. Cosign keyless signing khác key-based ở điểm nào về threat model?
8. Signature Cosign được lưu ở đâu? Ai có thể verify?
9. Kyverno `verifyImages` enforce ở tầng nào — CI, registry, hay cluster?
10. SLSA Level 2 yêu cầu gì so với Level 1?
11. Exception CVE trong `.trivyignore` phải có những thông tin gì?
12. Nếu Secrets Manager rotation xảy ra trong khi Pod đang dùng volume mount, Pod có bị ảnh hưởng không?

---

## Chuẩn bị cho Live T4 (17/06) — câu hỏi nên mang

- Cosign verify signature nên đặt ở CI, registry, hay admission webhook — hay cả 3?
- IRSA + ESO: nếu IAM Role của ESO bị revoke, K8s Secret hiện có còn dùng được không? Bao lâu?
- Trivy scan pass nhưng image vẫn có zero-day chưa được biết — phòng vệ thêm ở tầng nào?

---

## Tài liệu tham khảo

- AWS Secrets Manager: https://docs.aws.amazon.com/secretsmanager
- External Secrets Operator: https://external-secrets.io/latest
- Trivy: https://aquasecurity.github.io/trivy
- Cosign: https://docs.sigstore.dev/cosign/overview
- Kyverno verifyImages: https://kyverno.io/docs/writing-policies/verify-images/
- SLSA: https://slsa.dev/spec/v1.0/levels
- OWASP CI/CD Top 10: https://owasp.org/www-project-top-10-ci-cd-security-risks
- Sigstore Rekor: https://docs.sigstore.dev/rekor/overview
