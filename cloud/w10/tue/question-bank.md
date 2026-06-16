# W10 D2 — Question Bank: Secrets Rotation + Supply Chain Security

> Format: câu hỏi → gợi ý trả lời dạng **keyword / bullet ngắn**, highlight từ khóa quan trọng.
> Mức độ: 🟢 Dễ · 🟡 Trung bình · 🔴 Khó

---

## PHẦN 1 — Secret Management Lý thuyết

### 🟢 Q1. Tại sao không được hardcode secret vào source code hoặc Dockerfile?

**A:**
- Lộ trong **git history** — xóa file không xóa được history
- Image layer lưu permanent → `docker history` đọc được
- Ai clone repo / pull image là có secret
- Keyword: **git history**, **image layer**, **immutable leak**

---

### 🟢 Q2. K8s Secret gốc có bảo mật không? Tại sao?

**A:**
- K8s Secret lưu trong **etcd** dạng **base64** — không phải encrypt
- `kubectl get secret -o yaml` → decode base64 là xong
- Bảo mật thật sự cần: **KMS envelope encryption** (EKS hỗ trợ)
- Ai có `etcd` access hoặc `kubectl get secret` permission = đọc được hết
- Keyword: **base64 ≠ encryption**, **etcd**, **KMS envelope**

---

### 🟢 Q3. AWS Secrets Manager và SSM Parameter Store khác nhau điểm gì chính?

**A:**
- **Secrets Manager**: có **automatic rotation** built-in, versioning AWSCURRENT/AWSPREVIOUS, giá cao hơn
- **SSM Parameter Store**: đơn giản hơn, rẻ hơn (SecureString dùng KMS), không có rotation built-in
- Dùng Secrets Manager khi: database password, API key cần **rotate tự động**
- Dùng SSM khi: config value, feature flag, không cần rotate

---

### 🟢 Q4. `AWSCURRENT` và `AWSPREVIOUS` trong Secrets Manager là gì?

**A:**
- `AWSCURRENT` — version **đang active**, app đọc version này
- `AWSPREVIOUS` — version **trước đó**, vẫn valid trong thời gian grace period
- Khi rotation xảy ra: version mới được tạo → test → promote thành `AWSCURRENT`
- Version cũ → `AWSPREVIOUS` → sau đó expire
- Keyword: **zero-downtime rotation**, **grace period**, **version staging**

---

### 🟡 Q5. ESO `refreshInterval: 30s` nghĩa là gì? Pod có restart không?

**A:**
- ESO controller re-sync từ AWS Secrets Manager mỗi **30 giây**
- Nếu secret thay đổi → **K8s Secret được update**
- Pod **không restart** — kubelet tự update file trong volume mount trong vài giây
- Nếu dùng `envFrom` → **phải restart Pod** để lấy giá trị mới (env bị bake vào process)
- Keyword: **refreshInterval**, **volume auto-update**, **env var requires restart**

---

### 🟡 Q6. Tại sao volume mount tốt hơn env var khi cần rotate secret không downtime?

**A:**
- **env var**: inject vào process khi **khởi động** → bất biến trong suốt lifecycle Pod → cần restart
- **volume mount**: kubelet watch K8s Secret → khi Secret update → file trong volume được **replace tự động** → khoảng **~1–2 phút** (configurable)
- App cần **re-read file** khi cần (không cache giá trị), hoặc dùng inotify để watch file change
- Keyword: **kubelet sync**, **file replace**, **inotify**, **no restart needed**

---

### 🟡 Q7. ESO dùng IRSA — nếu IAM Role bị revoke, K8s Secret hiện có còn dùng được không?

**A:**
- K8s Secret **đã sync** vẫn tồn tại và Pod đang dùng vẫn đọc được từ volume/env
- **Lần sync tiếp theo** (sau `refreshInterval`) ESO sẽ fail với `Forbidden` từ AWS
- ESO đánh dấu ExternalSecret là `NotReady` / `SecretSyncError`
- K8s Secret **không bị xóa ngay** — chỉ không được cập nhật
- Keyword: **stale secret**, **sync failure**, **SecretSyncError**, **eventual consistency**

---

### 🔴 Q8. Thiết kế secret management cho microservice trên EKS — end to end thế nào?

**A:**
- **AWS Secrets Manager**: lưu secret, bật rotation
- **IRSA**: ServiceAccount của ESO được gán IAM Role có `GetSecretValue`
- **ESO ClusterSecretStore**: dùng lại nhiều namespace, auth qua IRSA
- **ExternalSecret** per namespace: `refreshInterval` <= 60s
- **Volume mount** (không env var): cho rotation không restart
- **KMS envelope encryption**: encrypt etcd at rest
- **Gatekeeper/Kyverno policy**: block Secret có annotation `plaintext=true`
- Keyword: **defense in depth**, **IRSA**, **ESO**, **volume mount**, **KMS**, **no plaintext**

---

## PHẦN 2 — Trivy & CI Security

### 🟢 Q9. Trivy scan được những gì? Severity levels là gì?

**A:**
- Scan: **OS packages**, **language deps** (npm, pip, go.sum), **IaC**, **exposed secrets**
- Severity: `UNKNOWN` → `LOW` → `MEDIUM` → `HIGH` → `CRITICAL`
- `CRITICAL` = exploit có sẵn, impact cao, ưu tiên fix ngay
- `HIGH` = nghiêm trọng nhưng có thể có workaround
- Keyword: **CVE database**, **OS layer**, **app layer**, **severity threshold**

---

### 🟢 Q10. `trivy image --exit-code 1 --severity CRITICAL` làm gì trong CI?

**A:**
- Scan image và **fail CI job** (exit code 1) nếu tìm thấy **CRITICAL** vulnerability
- Pipeline dừng, không push image lên registry
- Thường kết hợp: `CRITICAL` fail CI, `HIGH` report nhưng không fail
- Keyword: **gate trong pipeline**, **fail fast**, **exit-code**

---

### 🟡 Q11. `.trivyignore` dùng để làm gì? Phải có thông tin gì?

**A:**
- List CVE ID để **bỏ qua** trong scan report (exception)
- Bắt buộc có trong comment:
  - **Lý do** ignore (chưa có fix, false positive, ...)
  - **Ngày hết hạn** (review lại khi nào)
  - **Người approve**
- Không được ignore vô thời hạn → **tech debt security**
- Keyword: **time-bound exception**, **approved ignore**, **expiry date**

---

### 🟡 Q12. Trivy scan pass nhưng image vẫn có thể bị compromise — khi nào?

**A:**
- **Zero-day CVE**: chưa có entry trong CVE database → Trivy không biết
- **Supply chain attack**: dependency bị inject malicious code (typosquatting, compromised package)
- **Base image tampering**: nếu không verify image signature
- **Runtime attack**: exploit không có CVE record
- Defense: **signature verify** (Cosign) + **runtime security** (Falco) + **network policy**
- Keyword: **zero-day**, **supply chain attack**, **runtime security**, **defense in depth**

---

### 🔴 Q13. OWASP CI/CD Top 10 — kể 3 rủi ro quan trọng nhất và liên hệ với W10?

**A:**
- **CICD-SEC-1: Insufficient Flow Control** — không có approval gate → merge thẳng vào main → fix: branch protection + required review
- **CICD-SEC-4: Poisoned Pipeline Execution (PPE)** — attacker push code để chạy trong CI → đánh cắp secret trong env CI → fix: **không mount production secret vào CI**, IRSA chỉ cấp quyền tối thiểu
- **CICD-SEC-6: Insufficient Credential Hygiene** — secret hardcode trong pipeline, log CI expose secret → fix: `--secret` flag, mask secret, dùng **OIDC keyless**
- Keyword: **PPE**, **branch protection**, **secret masking**, **least privilege CI**

---

## PHẦN 3 — Cosign & Image Signing

### 🟢 Q14. Cosign keyless signing là gì? Khác key-based thế nào?

**A:**
| | Keyless | Key-based |
|---|---|---|
| Key | Short-lived cert từ **Fulcio CA** | Long-lived private key |
| Identity | OIDC token (GitHub, GitLab, ...) | Ai có private key |
| Key management | Không cần quản lý | Phải bảo vệ private key |
| Revocation | Cert expire tự động | Phải revoke thủ công |
- Keyless tốt hơn cho CI/CD — không có long-lived key để leak
- Keyword: **Fulcio**, **OIDC**, **short-lived cert**, **no key management**

---

### 🟢 Q15. Signature Cosign được lưu ở đâu?

**A:**
- Lưu vào **registry** như một OCI artifact cạnh image (không cần storage riêng)
- Đồng thời ghi vào **Rekor transparency log** — public, immutable, audit được
- Verify: tool check registry lấy signature → check Rekor log → verify cert chain
- Keyword: **OCI artifact**, **Rekor**, **transparency log**, **co-located**

---

### 🟡 Q16. Cosign verify — cần những thông tin gì để verify thành công?

**A:**
- **Keyless**: `--certificate-identity` (workflow URL), `--certificate-oidc-issuer` (GitHub/GitLab OIDC URL)
- **Key-based**: `--key cosign.pub`
- Rekor log URL (default: public Rekor, có thể dùng private instance)
- **Image digest** (không nên dùng tag — tag mutable)
- Keyword: **digest not tag**, **identity matching**, **issuer**, **Rekor URL**

---

### 🟡 Q17. Nếu attacker push image cùng tag lên registry (tag mutable) — Cosign bảo vệ thế nào?

**A:**
- Tag có thể bị **overwrite** → `nginx:1.25` hôm nay khác ngày mai
- Cosign sign bằng **digest** (SHA256 immutable) → nếu image bị thay, digest thay đổi → signature không còn valid
- Kyverno/Gatekeeper verify **digest** của image thực tế → reject nếu không khớp signature
- Best practice: **pin image bằng digest** trong manifest, không dùng tag
- Keyword: **tag mutable**, **digest immutable**, **pin digest**, **signature invalidated**

---

### 🔴 Q18. Verify signature nên đặt ở CI, registry, hay admission webhook — hay cả 3?

**A:**
- **CI**: verify trước khi push — phát hiện sớm, nhưng developer có thể bypass nếu push trực tiếp
- **Registry**: một số registry (ECR, Harbor) có policy chỉ accept signed image — tầng 2
- **Admission webhook** (Kyverno/Gatekeeper): **enforce tại cluster** — không thể bypass, kể cả deploy thủ công
- **Defense in depth**: cả 3 tầng, nhưng **admission webhook là tầng cuối cùng quan trọng nhất**
- Keyword: **layered defense**, **admission = last gate**, **bypass risk**

---

## PHẦN 4 — SLSA Framework

### 🟢 Q19. SLSA là gì và dùng để làm gì?

**A:**
- **Supply-chain Levels for Software Artifacts**
- Framework đánh giá **độ tin cậy** của build/delivery pipeline
- Trả lời: "Artifact này có đúng là output của build process không, hay bị tamper?"
- Không phải tool — là **specification + checklist**
- Keyword: **provenance**, **tamper-evident**, **build integrity**

---

### 🟡 Q20. SLSA Level 1, 2, 3 khác nhau thế nào?

**A:**
- **L1**: Build tạo ra **provenance** (ghi lại: build từ source nào, khi nào, bằng tool gì) — có thể tự khai báo
- **L2**: Build chạy trên **hosted CI** (GitHub Actions, GitLab CI), provenance được CI tạo và sign → có thể verify independently
- **L3**: Build **isolated và hardened** — không thể modify build process, two-party review, provenance không thể forge
- Thực tế: GitHub Actions + Cosign + slsa-github-generator = **L2**, đủ cho hầu hết production
- Keyword: **provenance**, **hosted CI**, **isolated build**, **non-forgeable**

---

### 🟡 Q21. Provenance trong SLSA là gì?

**A:**
- Tài liệu mô tả **nguồn gốc của artifact**: build từ repo nào, commit nào, tool nào, thời điểm nào
- Dạng file JSON được **sign** → có thể verify bằng Cosign
- Cho phép audit: "Image này có được build từ source code đã được review không?"
- Keyword: **build metadata**, **signed attestation**, **audit trail**, **SLSA provenance**

---

## PHẦN 5 — Thực tiễn & Debug

### 🟢 Q22. Pod lỗi không start — suspect do secret không có. Debug thế nào?

**A:**
1. `kubectl describe pod <name>` → xem `Events` — có `CreateContainerConfigError` không?
2. `kubectl get secret -n <ns>` → secret có tồn tại không?
3. `kubectl describe externalsecret <name> -n <ns>` → xem `.status.conditions` — ESO sync thành công không?
4. `kubectl get secret <name> -n <ns> -o yaml` → key có đúng không?
5. Kiểm tra volume mount path trong Pod spec khớp với key trong Secret không

---

### 🟡 Q23. ESO ExternalSecret ở trạng thái `SecretSyncError` — nguyên nhân và cách fix?

**A:**
**Nguyên nhân phổ biến:**
- IAM Role bị revoke hoặc thiếu permission `GetSecretValue`
- Secret name trên AWS sai (typo, sai region)
- IRSA chưa setup đúng (SA annotation thiếu, OIDC provider không match)
- `SecretStore` chưa ready

**Debug:**
```bash
kubectl describe externalsecret <name> -n <ns>
# xem .status.conditions[].message

kubectl describe secretstore <name> -n <ns>
# xem connection status với AWS
```

**Fix:**
- Verify IAM Role ARN trong SA annotation
- Test `aws secretsmanager get-secret-value` trực tiếp với credentials của role
- Keyword: **IAM permission**, **OIDC**, **SecretStore health**, **region mismatch**

---

### 🟡 Q24. Kyverno verifyImages reject Pod với "image signature not found" — nguyên nhân?

**A:**
- Image **chưa được sign** — CI chưa chạy bước Cosign sign
- Sign bằng identity/issuer khác với policy expect
- Verify sai **digest** — image được pull bằng tag nhưng policy check digest khác
- Kyverno không thể reach **Rekor** (network issue)
- Image **đã được re-push** cùng tag sau khi sign → digest thay đổi → signature invalid
- Keyword: **identity mismatch**, **digest changed**, **Rekor unreachable**, **re-push**

---

### 🟡 Q25. Trivy scan CI fail do CRITICAL vulnerability trong base image — không có fix ngay. Làm gì?

**A:**
**Option 1 — Tạm thời ignore có kiểm soát:**
```text
# .trivyignore
# CVE-2024-XXXXX: base image openssl — fix expected 2026-07-15
# Approved: security-lead @2026-06-16
CVE-2024-XXXXX
```

**Option 2 — Dùng distroless / scratch base image** để giảm attack surface

**Option 3 — Pin base image version** khi có fix được publish

**Không được làm:** tắt scan hoàn toàn, ignore không có expiry, không có approval

- Keyword: **time-bound exception**, **distroless**, **patch management**, **approved workaround**

---

### 🔴 Q26. Supply chain attack kiểu SolarWinds xảy ra — CI inject malicious code. Phát hiện và ngăn chặn thế nào?

**A:**
**Phát hiện:**
- **SLSA provenance**: verify build artifact có đúng từ expected CI run không
- **Rekor transparency log**: ai sign image này? workflow nào? commit nào?
- **Sigstore**: log public — cộng đồng có thể phát hiện signing anomaly
- **Trivy/grype**: scan artifact cho known malicious signatures (limited)

**Ngăn chặn:**
- **Hermetic build**: CI không có internet access (chỉ trusted deps)
- **Two-party review**: không merge code đơn lẻ
- **SLSA L3**: build isolated, không thể modify build environment
- **Pin dependencies**: `npm ci`, `go.sum`, `requirements.txt` locked version
- **Admission webhook**: chỉ accept image sign bởi expected CI identity

- Keyword: **SLSA L3**, **hermetic build**, **transparency log**, **dependency pinning**, **two-party review**

---

## PHẦN 6 — Kết nối D1 + D2

### 🟡 Q27. RBAC (D1) và Secret Management (D2) bảo vệ những tầng nào?

**A:**
- **RBAC**: kiểm soát **ai** có thể `get/list` K8s Secret — người trong cluster
- **Secret Management (ESO + SM)**: kiểm soát **secret có ở đúng chỗ không**, rotate tự động
- **KMS encryption**: bảo vệ **etcd at rest** — nếu attacker lấy được etcd backup
- **Image signing**: bảo vệ **supply chain** — đảm bảo code chạy đúng là code đã review
- Kết hợp: **defense in depth** — không có single point of failure

---

### 🟡 Q28. ESO ServiceAccount cần những RBAC permission nào trong cluster?

**A:**
- ESO controller SA cần:
  - `get/list/watch/create/update/patch/delete` trên `secrets` (để create/update K8s Secret)
  - `get/list/watch` trên `externalsecrets` và `secretstores`
- ESO được cài với Helm đã tạo sẵn ClusterRole phù hợp
- Workload SA (dùng IRSA để gọi AWS) cần **tách riêng** khỏi ESO SA
- Keyword: **ESO SA**, **workload SA separation**, **least privilege**

---

### 🔴 Q29. Design end-to-end: dev push code → image build → sign → deploy → cluster verify. Vẽ luồng và nêu mỗi bước bảo vệ gì?

**A:**
```text
1. Dev push PR
   -> branch protection + required review (SLSA: two-party)

2. GitHub Actions CI
   -> Trivy scan --exit-code 1 (không push nếu CRITICAL)
   -> Build image với digest
   -> cosign sign --keyless (identity: workflow URL)
   -> Push image + signature lên registry

3. ArgoCD/GitOps sync (W9)
   -> Pull image digest từ Git manifest
   -> Kyverno verifyImages: cosign verify signature
   -> Nếu không có valid signature -> reject Pod

4. Pod chạy
   -> ESO inject secret qua volume mount
   -> IRSA: Pod chỉ có quyền AWS tối thiểu
   -> Gatekeeper: enforce resource limits, non-root, no latest tag

5. Runtime
   -> Falco (nếu có): detect anomalous behavior
   -> CloudTrail: audit mọi AWS API call từ Pod
```
- Keyword: **layered security**, **shift left**, **admission as last gate**, **audit everywhere**

---

## Quick Reference — Lệnh hay dùng nhất

```bash
# ESO
kubectl get externalsecret -A
kubectl describe externalsecret <name> -n <ns>
kubectl get secret <name> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d

# Trivy
trivy image --severity HIGH,CRITICAL <image>
trivy image --exit-code 1 --severity CRITICAL <image>
trivy fs --security-checks secret .        # scan repo tìm secret bị commit

# Cosign
cosign generate-key-pair
cosign sign --key cosign.key <image>@<digest>
cosign verify --key cosign.pub <image>
cosign verify \
  --certificate-identity <workflow-url> \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  <image>

# Kyverno
kubectl get clusterpolicy
kubectl get policyreport -A
kubectl describe clusterpolicy <name>

# AWS Secrets Manager
aws secretsmanager get-secret-value --secret-id <name> --query SecretString
aws secretsmanager rotate-secret --secret-id <name>
aws secretsmanager describe-secret --secret-id <name>   # xem rotation status
```
