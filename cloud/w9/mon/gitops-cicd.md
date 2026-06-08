# W9 Day A - GitOps & CI/CD

Ngày học: T2 08/06/2026  
Chủ đề: Deliver Smartly phần 1 - GitOps, CI/CD, ArgoCD, Flux và rollback

## Mục tiêu hôm nay

- Hiểu GitOps là gì và vì sao Git là source of truth cho delivery trên Kubernetes.
- Phân biệt CI, CD kiểu push-based và CD kiểu pull-based với GitOps controller.
- Nắm workflow GitHub Actions: plan-on-PR và apply-on-merge.
- So sánh ArgoCD và Flux ở mức concept để biết khi nào dùng công cụ nào.
- Hiểu app-of-apps, sync waves và cách sắp xếp thứ tự sync resource.
- Biết rollback bằng `git revert` và khi nào mới dùng `kubectl rollout undo`.
- Chuẩn bị nền tảng cho D2 Observability và D3 Canary auto-abort.

## Nguồn học hôm nay

### Bắt buộc

1. OpenGitOps - GitOps Principles  
   https://opengitops.dev

2. ArgoCD Docs - Getting Started  
   https://argo-cd.readthedocs.io/en/stable/getting_started/

3. ArgoCD Docs - App of Apps  
   https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/

4. ArgoCD Docs - Sync Phases and Waves  
   https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/

5. GitHub Actions Docs - Understanding GitHub Actions  
   https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions

### Đọc thêm

1. Flux Docs - Concepts  
   https://fluxcd.io/flux/concepts/

2. Kubernetes Docs - Deployments Rollback  
   https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-back-a-deployment

3. ArgoCD Docs - Automated Sync Policy  
   https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/

## Kế hoạch học 6 giờ

| Thời lượng | Nội dung | Output cần có |
| ---------- | -------- | ------------- |
| 45 phút | Đọc GitOps principles và liên hệ với W8 Kubernetes | Ghi được 4 nguyên tắc GitOps bằng lời của mình |
| 60 phút | Tìm hiểu CI/CD push-based vs pull-based GitOps | Vẽ được luồng từ PR đến cluster |
| 75 phút | Đọc GitHub Actions plan-on-PR và apply-on-merge | Viết được workflow YAML mẫu |
| 75 phút | Đọc ArgoCD: Application, sync status, health, app-of-apps | Giải thích được ArgoCD quan sát Git và cluster như thế nào |
| 45 phút | So sánh ArgoCD và Flux | Lập bảng so sánh ngắn gọn |
| 45 phút | Học sync waves và rollback | Ghi được cách rollback ưu tiên bằng `git revert` |
| 30 phút | Tổng kết reflection và câu hỏi | Cập nhật evidence cho ngày D1 |

## Ghi chú bài học

### 1. GitOps là gì?

GitOps là cách vận hành hạ tầng và ứng dụng bằng khai báo trong Git. Repo Git giữ trạng thái mong muốn, còn controller trong cluster đọc repo, so sánh với trạng thái thực tế và reconcile để đưa cluster về đúng trạng thái đã khai báo.

Với W8, sinh viên đã dùng `kubectl apply -f ...` để đưa manifest vào minikube. Sang W9, thao tác thủ công này không còn là đường chính. Thay đổi phải đi qua Git:

1. Sửa manifest trong repo.
2. Tạo pull request.
3. CI kiểm tra syntax, policy và render output.
4. Merge vào branch chính.
5. GitOps controller sync thay đổi vào cluster.
6. Theo dõi status, health và metric sau deploy.

Nói ngắn gọn: Kubernetes chạy theo desired state; GitOps đưa desired state đó vào Git và bắt mọi thay đổi phải có lịch sử commit.

### 2. Bốn nguyên tắc GitOps

| Nguyên tắc | Ý nghĩa |
| ---------- | ------- |
| Declarative | Trạng thái mong muốn được khai báo bằng file, thường là YAML, Helm chart hoặc Kustomize |
| Versioned and immutable | Mỗi thay đổi có commit history, có thể review và quay lại |
| Pulled automatically | Controller trong cluster kéo thay đổi từ Git, không cần pipeline đẩy trực tiếp vào cluster |
| Continuously reconciled | Controller liên tục so sánh Git với cluster và sửa drift nếu có |

### 3. CI/CD và GitOps khác nhau thế nào?

CI tập trung vào việc build và kiểm tra code sau mỗi thay đổi. CD tập trung vào đưa phiên bản mới ra môi trường chạy. Trong delivery truyền thống, pipeline có thể chạy `kubectl apply` trực tiếp vào cluster. Cách này gọi là push-based CD.

GitOps thường dùng pull-based CD:

```text
Developer
  -> Pull Request
  -> GitHub Actions test/validate/plan
  -> Merge
  -> Git repo cập nhật desired state
  -> ArgoCD/Flux trong cluster pull thay đổi
  -> Kubernetes apply và reconcile
```

Điểm quan trọng: pipeline CI không cần giữ kubeconfig production để apply trực tiếp. Quyền sync nằm trong cluster controller, và Git là nơi ghi lại thay đổi.

### 4. Workflow plan-on-PR và apply-on-merge

Với Terraform ở W8, `plan` giúp thay đổi được review trước khi apply. Với Kubernetes manifest, tư duy tương tự:

- Pull request: chạy validate, lint, render Kustomize/Helm, diff nếu có.
- Merge vào branch chính: cho phép thay đổi trở thành desired state.
- GitOps controller: sync thay đổi vào cluster.

Ví dụ workflow GitHub Actions tối thiểu cho manifest Kubernetes:

```yaml
name: k8s-manifest-check

on:
  pull_request:
    paths:
      - "cloud/w9/mon/**"
      - "apps/**"
      - "clusters/**"
  push:
    branches:
      - main
    paths:
      - "cloud/w9/mon/**"
      - "apps/**"
      - "clusters/**"

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup kubectl
        uses: azure/setup-kubectl@v4

      - name: Validate rendered manifests
        run: |
          kubectl kustomize cloud/w9/mon/demo-app | kubectl apply --dry-run=client -f -
```

Ghi chú:

- `pull_request` là plan/check phase, không thay đổi cluster.
- `push` vào `main` là lúc desired state đã được chấp nhận.
- Nếu dùng ArgoCD auto-sync, pipeline không cần `kubectl apply`.
- Nếu dùng manual sync, người vận hành có thể bấm sync trên ArgoCD UI/CLI sau khi merge.

### 5. ArgoCD là gì?

ArgoCD là GitOps controller cho Kubernetes. ArgoCD đọc cấu hình Application, lấy manifest từ Git, render bằng plain YAML, Kustomize hoặc Helm, rồi sync vào cluster.

Một ArgoCD Application thường trả lời 4 câu hỏi:

- Repo Git nào là source?
- Path nào trong repo chứa manifest?
- Cluster và namespace nào là destination?
- Chính sách sync là manual hay automated?

Ví dụ Application tối thiểu:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-web
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/platform-repo.git
    targetRevision: main
    path: cloud/w9/mon/demo-app
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Trạng thái quan trọng trong ArgoCD:

| Trạng thái | Ý nghĩa |
| ---------- | ------- |
| Synced | Cluster đang khớp với Git |
| OutOfSync | Cluster khác Git, cần sync hoặc đang chờ controller reconcile |
| Healthy | Workload đang chạy ổn định theo health check |
| Degraded | Workload có vấn đề, ví dụ Pod lỗi hoặc Deployment chưa available |

### 6. Flux là gì?

Flux cũng là GitOps controller cho Kubernetes. Flux thường được mô tả là modular và Kubernetes-native hơn, vì dùng nhiều custom resource riêng như `GitRepository`, `Kustomization`, `HelmRelease`.

Bảng so sánh ngắn:

| Tiêu chí | ArgoCD | Flux |
| -------- | ------ | ---- |
| Trải nghiệm UI | Có UI mạnh, dễ demo và quan sát sync/health | Chủ yếu CLI và Kubernetes CRD |
| Cách cấu hình | Application và AppProject | GitRepository, Kustomization, HelmRelease |
| Phù hợp học tập | Dễ nhìn thấy luồng Git -> cluster | Tốt để hiểu GitOps theo CRD native |
| Multi-cluster | Hỗ trợ tốt | Hỗ trợ tốt |
| Hệ sinh thái | Thường đi cùng Argo Rollouts | Thường đi cùng Flagger |

Trong W9, ưu tiên ArgoCD vì sinh viên cần quan sát trực quan sync status, health, diff và chuẩn bị cho D3 Argo Rollouts.

### 7. App-of-apps

App-of-apps là pattern trong ArgoCD: một Application gốc quản lý nhiều Application con. Thay vì tạo từng app bằng tay, ta khai báo tất cả app con trong Git, rồi ArgoCD sync app gốc.

Ví dụ cấu trúc repo:

```text
cloud/w9/mon/
+-- argocd/
|   +-- root-app.yaml
|   +-- apps/
|       +-- demo-web-app.yaml
|       +-- observability-app.yaml
+-- demo-app/
    +-- namespace.yaml
    +-- deployment.yaml
    +-- service.yaml
```

Lợi ích:

- Bootstrap cluster bằng một root app.
- Mỗi app con vẫn có path và sync policy riêng.
- Dễ quản lý nhiều thành phần: app, monitoring, ingress, rollout.

### 8. Sync waves

Sync waves dùng annotation để sắp xếp thứ tự apply resource trong ArgoCD. Resource có wave nhỏ hơn sync trước.

Ví dụ:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
```

Thứ tự gợi ý:

| Wave | Resource |
| ---- | -------- |
| -1 | Namespace, CRD |
| 0 | ConfigMap, Secret, ServiceAccount |
| 1 | Deployment, Service |
| 2 | Ingress, Rollout, monitoring rule |

Không nên lạm dụng sync waves cho mọi resource. Chỉ dùng khi có phụ thuộc thật sự, vì Kubernetes đã có khả năng xử lý nhiều thứ tự apply thông thường.

### 9. Rollback: git revert vs kubectl rollout undo

Trong GitOps, rollback ưu tiên là sửa desired state trong Git. Cách sạch nhất là `git revert` commit lỗi, merge revert vào branch chính, để ArgoCD/Flux sync cluster về trạng thái đúng.

Lệnh mẫu:

```bash
git log --oneline
git revert <bad-commit-sha>
git push
```

Sau đó kiểm tra:

```bash
argocd app sync demo-web
argocd app get demo-web
kubectl rollout status deployment/demo-web -n demo
```

`kubectl rollout undo` chỉ nên dùng như thao tác khẩn cấp khi cần khôi phục workload ngay lập tức. Nếu dùng lệnh này mà không cập nhật Git, cluster sẽ bị drift. GitOps controller có thể sync lại version lỗi từ Git và làm mất rollback thủ công.

Quy tắc:

- Bình thường: rollback bằng `git revert`.
- Khẩn cấp: có thể `kubectl rollout undo`, nhưng phải tạo commit/revert trong Git ngay sau đó.
- Luôn ghi lại evidence: commit revert, ArgoCD status, rollout status.

## Bài thực hành đề xuất

### Cấu trúc thư mục D1

Toàn bộ bài D1 đặt trong `cloud/w9/mon/`, bao gồm ghi chú, manifest, cấu hình ArgoCD và ảnh bằng chứng:

```text
cloud/w9/mon/
+-- gitops-cicd.md
+-- NOTES.md
+-- imgs/
|   +-- kustomize-output.png
|   +-- github-actions-check.png
|   +-- argocd-application.png
|   +-- rollback-history.png
+-- demo-app/
|   +-- namespace.yaml
|   +-- deployment.yaml
|   +-- service.yaml
|   +-- kustomization.yaml
+-- argocd/
    +-- demo-web-app.yaml
```

Thư mục `imgs/` dùng để lưu toàn bộ ảnh bằng chứng của ngày D1. Không để ảnh rải ở `assets/` hoặc thư mục khác để khi nộp bài chỉ cần mở `cloud/w9/mon/` là thấy đủ nội dung.

### Bài 1 - Vẽ luồng GitOps

Tạo file ghi chú:

```text
cloud/w9/mon/NOTES.md
```

Trả lời ngắn gọn:

- GitOps khác `kubectl apply` thủ công ở điểm nào?
- CI làm gì trong workflow này?
- ArgoCD/Flux làm gì trong workflow này?
- Vì sao Git phải là source of truth?
- Nếu sửa trực tiếp resource trên cluster thì điều gì xảy ra?

### Bài 2 - Tạo manifest demo app

Tạo thư mục:

```text
cloud/w9/mon/demo-app/
```

Cấu trúc tối thiểu:

```text
demo-app/
+-- namespace.yaml
+-- deployment.yaml
+-- service.yaml
+-- kustomization.yaml
```

Gợi ý `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
```

Kiểm tra local:

```bash
kubectl kustomize cloud/w9/mon/demo-app
kubectl kustomize cloud/w9/mon/demo-app | kubectl apply --dry-run=client -f -
```

### Bài 3 - Viết GitHub Actions check

Tạo workflow:

```text
.github/workflows/w9-d1-k8s-check.yml
```

Workflow cần:

- Chạy khi có pull request vào `main`.
- Checkout repo.
- Cài `kubectl`.
- Chạy `kubectl kustomize`.
- Chạy dry-run client để bắt lỗi YAML cơ bản.

Không đưa kubeconfig thật vào GitHub Actions trong bài D1.

### Bài 4 - Khai báo ArgoCD Application mẫu

Tạo thư mục:

```text
cloud/w9/mon/argocd/
```

Tạo file:

```text
cloud/w9/mon/argocd/demo-web-app.yaml
```

Nội dung cần có:

- `kind: Application`
- `source.repoURL`
- `source.path`
- `destination.namespace`
- `syncPolicy.automated`
- `syncOptions: CreateNamespace=true`

Chưa bắt buộc phải sync thật nếu máy chưa cài ArgoCD. Nếu đã có minikube, có thể cài ArgoCD và apply Application để quan sát UI.

### Bài 5 - Mô phỏng rollback

Thực hiện bằng Git:

1. Commit version app ban đầu.
2. Sửa image tag hoặc replica để tạo thay đổi.
3. Tạo commit lỗi giả định.
4. Dùng `git revert` để quay lại.
5. Ghi lại commit history và giải thích vì sao đây là rollback đúng theo GitOps.

## Checklist hôm nay

- [ ] Ghi được định nghĩa GitOps bằng lời của mình.
- [ ] Vẽ được workflow PR -> CI check -> merge -> ArgoCD sync -> Kubernetes.
- [ ] Giải thích được plan-on-PR và apply-on-merge.
- [ ] So sánh được ArgoCD và Flux.
- [ ] Giải thích được app-of-apps và sync waves.
- [ ] Tạo được manifest demo app có `kustomization.yaml`.
- [ ] Tạo được GitHub Actions workflow check manifest.
- [ ] Tạo được ArgoCD Application YAML mẫu.
- [ ] Giải thích được rollback bằng `git revert` và rủi ro của `kubectl rollout undo`.
- [ ] Cập nhật evidence và câu hỏi cho mentor.

## Evidence cần nộp

Trong `cloud/w9/mon/NOTES.md`, ghi tối thiểu:

- Link hoặc tên commit D1 với message dạng `[W9-D1] <topic ngắn>`.
- Ảnh chụp hoặc output `kubectl kustomize`, lưu trong `cloud/w9/mon/imgs/kustomize-output.png`.
- Ảnh chụp hoặc output GitHub Actions check nếu đã push, lưu trong `cloud/w9/mon/imgs/github-actions-check.png`.
- Ảnh chụp ArgoCD Application nếu đã chạy ArgoCD, lưu trong `cloud/w9/mon/imgs/argocd-application.png`.
- Ảnh chụp hoặc output commit history khi mô phỏng rollback, lưu trong `cloud/w9/mon/imgs/rollback-history.png`.
- Nội dung ArgoCD Application YAML.
- Ghi chú so sánh ArgoCD vs Flux.
- Mô tả rollback bằng `git revert`.
- Câu hỏi còn vướng cho mentor.

## Câu hỏi ôn tập

1. GitOps có điểm gì giống và khác với Kubernetes desired state?
2. Vì sao pipeline không nên apply trực tiếp vào production cluster nếu đã dùng GitOps?
3. `Synced` và `Healthy` trong ArgoCD khác nhau thế nào?
4. App-of-apps giải quyết vấn đề gì?
5. Sync waves nên dùng trong tình huống nào?
6. Nếu ai đó sửa Deployment trực tiếp bằng `kubectl edit`, GitOps controller sẽ làm gì?
7. Rollback bằng `git revert` có lợi ích gì so với `kubectl rollout undo`?
8. ArgoCD và Flux khác nhau chủ yếu ở trải nghiệm vận hành nào?
