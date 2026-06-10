# W9 Day A Question Bank - GitOps & CI/CD

> Nguồn câu hỏi cho bài self-study T2 08/06/2026. Format tham khảo theo `question-bank.md`: chia theo độ khó, mỗi câu có câu hỏi và đáp án mong đợi.

---

## Easy

### Câu 1 - Dễ *(Chủ đề: GitOps)*
**Câu hỏi:** GitOps là gì?

**Đáp án mong đợi:**
- GitOps là cách vận hành hạ tầng và ứng dụng bằng khai báo trong Git.
- Git giữ trạng thái mong muốn của hệ thống.
- GitOps controller trong cluster đọc Git, so sánh với trạng thái thực tế và reconcile.
- Mọi thay đổi nên đi qua pull request, review và commit history.
- Mục tiêu là giảm thao tác thủ công và dễ rollback hơn.

### Câu 2 - Dễ *(Chủ đề: Desired State)*
**Câu hỏi:** Vì sao Git được gọi là source of truth trong GitOps?

**Đáp án mong đợi:**
- Trạng thái mong muốn của hệ thống được lưu trong repo Git.
- Cluster phải được sync để khớp với nội dung trong Git.
- Thay đổi trực tiếp bằng `kubectl edit` hoặc `kubectl apply` có thể tạo drift.
- Commit history giúp biết ai thay đổi gì, khi nào và vì sao.
- Rollback có thể thực hiện bằng cách revert commit.

### Câu 3 - Dễ *(Chủ đề: CI/CD)*
**Câu hỏi:** CI và CD khác nhau như thế nào?

**Đáp án mong đợi:**
- CI tập trung vào build, test, validate sau mỗi thay đổi.
- CD tập trung vào đưa phiên bản mới ra môi trường chạy.
- CI thường chạy trên pull request hoặc push.
- CD có thể là push-based hoặc pull-based.
- Trong GitOps, CD thường do controller trong cluster kéo thay đổi từ Git.

### Câu 4 - Dễ *(Chủ đề: ArgoCD)*
**Câu hỏi:** ArgoCD dùng để làm gì?

**Đáp án mong đợi:**
- ArgoCD là GitOps controller cho Kubernetes.
- ArgoCD đọc manifest từ Git.
- ArgoCD so sánh trạng thái Git với trạng thái cluster.
- ArgoCD sync resource vào cluster khi cần.
- ArgoCD hiển thị trạng thái như `Synced`, `OutOfSync`, `Healthy`, `Degraded`.

### Câu 5 - Dễ *(Chủ đề: Rollback)*
**Câu hỏi:** Trong GitOps, rollback ưu tiên nên làm bằng cách nào?

**Đáp án mong đợi:**
- Ưu tiên rollback bằng `git revert`.
- Revert commit lỗi để Git trở về desired state đúng.
- Sau khi revert được merge, ArgoCD/Flux sync cluster theo Git.
- Cách này giữ lịch sử thay đổi rõ ràng.
- `kubectl rollout undo` chỉ nên dùng khẩn cấp và phải cập nhật Git sau đó.

## Medium

### Câu 6 - Trung bình *(Chủ đề: GitHub Actions)*
**Câu hỏi:** Workflow plan-on-PR và apply-on-merge nghĩa là gì?

**Đáp án mong đợi:**
- Plan-on-PR: pull request chỉ chạy kiểm tra, validate, render hoặc diff.
- PR không nên apply trực tiếp vào cluster production.
- Apply-on-merge: khi merge vào branch chính, desired state được chấp nhận.
- GitOps controller sync thay đổi sau khi branch chính cập nhật.
- Cách này giúp review trước khi deploy và giảm rủi ro.

### Câu 7 - Trung bình *(Chủ đề: Push-based vs Pull-based CD)*
**Câu hỏi:** Push-based CD khác pull-based GitOps ở điểm nào?

**Đáp án mong đợi:**
- Push-based CD: pipeline bên ngoài cluster chạy lệnh deploy trực tiếp.
- Pull-based GitOps: controller trong cluster kéo thay đổi từ Git.
- Push-based thường cần kubeconfig hoặc credential trong CI.
- Pull-based giảm nhu cầu để quyền cluster trong pipeline.
- Pull-based giúp cluster liên tục reconcile về desired state trong Git.

### Câu 8 - Trung bình *(Chủ đề: ArgoCD vs Flux)*
**Câu hỏi:** So sánh ngắn ArgoCD và Flux.

**Đáp án mong đợi:**
- Cả hai đều là GitOps controller cho Kubernetes.
- ArgoCD có UI mạnh, dễ quan sát diff, sync và health.
- Flux thiên về Kubernetes-native CRD và CLI.
- ArgoCD thường phù hợp demo, học tập và quan sát trực quan.
- Flux phù hợp môi trường muốn cấu hình modular qua CRD như `GitRepository`, `Kustomization`, `HelmRelease`.

### Câu 9 - Trung bình *(Chủ đề: App-of-apps)*
**Câu hỏi:** App-of-apps trong ArgoCD là gì?

**Đáp án mong đợi:**
- App-of-apps là pattern dùng một Application gốc quản lý nhiều Application con.
- Application con cũng được khai báo trong Git.
- Chỉ cần bootstrap root app, ArgoCD sẽ quản lý các app còn lại.
- Phù hợp khi cluster có nhiều thành phần như app, monitoring, ingress.
- Giúp giảm thao tác tạo app thủ công trên UI.

### Câu 10 - Trung bình *(Chủ đề: Sync Waves)*
**Câu hỏi:** Sync waves dùng để làm gì trong ArgoCD?

**Đáp án mong đợi:**
- Sync waves sắp xếp thứ tự apply resource.
- Resource có wave nhỏ hơn được sync trước.
- Dùng annotation `argocd.argoproj.io/sync-wave`.
- Hữu ích khi có phụ thuộc như Namespace/CRD trước Deployment.
- Không nên lạm dụng cho mọi resource vì Kubernetes đã tự xử lý nhiều trường hợp.

## Hard

### Câu 11 - Khó *(Chủ đề: GitOps Drift)*
**Câu hỏi:** Nếu một người sửa Deployment trực tiếp bằng `kubectl edit` trong cluster đang được ArgoCD quản lý, điều gì có thể xảy ra?

**Đáp án mong đợi:**
- Cluster sẽ khác với desired state trong Git, gọi là drift.
- ArgoCD có thể hiển thị `OutOfSync`.
- Nếu bật self-heal, ArgoCD có thể tự đưa resource về đúng Git.
- Thay đổi thủ công có thể bị mất nếu không được commit vào Git.
- Quy trình đúng là sửa manifest trong repo và đi qua PR.

### Câu 12 - Khó *(Chủ đề: Security trong CI/CD)*
**Câu hỏi:** Vì sao GitOps giúp giảm rủi ro bảo mật so với pipeline deploy trực tiếp bằng kubeconfig?

**Đáp án mong đợi:**
- Pipeline không cần giữ kubeconfig production để chạy `kubectl apply`.
- Quyền sync nằm trong controller chạy bên trong cluster.
- Có thể giới hạn quyền controller theo namespace/project.
- Thay đổi phải đi qua Git, PR và audit log.
- Giảm rủi ro lộ credential dài hạn trong CI.

### Câu 13 - Khó *(Chủ đề: Rollback Strategy)*
**Câu hỏi:** Khi nào có thể dùng `kubectl rollout undo` trong hệ thống GitOps và cần làm gì sau đó?

**Đáp án mong đợi:**
- Chỉ nên dùng khi sự cố khẩn cấp cần khôi phục workload ngay.
- Lệnh này thay đổi trạng thái cluster nhưng chưa thay đổi Git.
- Nếu không cập nhật Git, controller có thể sync lại version lỗi.
- Sau khi undo, phải tạo commit fix hoặc `git revert` trong repo.
- Cần ghi evidence: rollout status, commit revert và trạng thái ArgoCD.

### Câu 14 - Khó *(Chủ đề: Thiết kế Workflow)*
**Câu hỏi:** Thiết kế workflow GitOps tối thiểu cho manifest Kubernetes gồm những bước nào?

**Đáp án mong đợi:**
- Developer sửa manifest trong repo.
- Tạo pull request.
- GitHub Actions chạy validate, render Kustomize/Helm và dry-run nếu có.
- Reviewer kiểm tra diff và approve.
- Merge vào branch chính.
- ArgoCD/Flux sync thay đổi vào cluster.
- Kiểm tra health, logs và metrics sau deploy.

### Câu 15 - Khó *(Chủ đề: Operational Readiness)*
**Câu hỏi:** Một ArgoCD Application đã `Synced` nhưng `Degraded`. Điều này nói lên điều gì?

**Đáp án mong đợi:**
- `Synced` nghĩa là manifest trong cluster đã khớp với Git.
- `Degraded` nghĩa là workload không healthy.
- Có thể Deployment chưa đủ replica, Pod crash, image pull lỗi hoặc probe fail.
- GitOps chỉ đảm bảo desired state được apply, không đảm bảo app chạy tốt nếu cấu hình/app lỗi.
- Cần debug bằng ArgoCD health, `kubectl describe`, logs và metrics.

