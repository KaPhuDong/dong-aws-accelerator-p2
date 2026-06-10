# W9 Day C - Progressive Delivery: Canary với Argo Rollouts

Ngày học: T4 10/06/2026  
Chủ đề: Deliver Smartly phần 3 - Progressive Delivery, Canary, Argo Rollouts và auto-abort bằng metrics

## Mục tiêu hôm nay

- Hiểu progressive delivery là gì và vì sao không nên deploy toàn bộ traffic ngay lập tức.
- Phân biệt rolling update, blue-green và canary deployment.
- Hiểu Argo Rollouts dùng để làm gì trong Kubernetes.
- Đọc được `Rollout` CRD và các phần quan trọng trong canary strategy.
- Viết được `AnalysisTemplate` dùng Prometheus query để đánh giá bản canary.
- Hiểu abort criteria: khi nào canary phải dừng hoặc rollback.
- Tích hợp burn rate từ D2 vào quá trình quyết định canary.
- Chuẩn bị cho lab T5-T6: GitOps-ify W8 platform + observability + canary.

## Nguồn học hôm nay

### Bắt buộc

1. Argo Rollouts Docs - Concepts  
   https://argoproj.github.io/argo-rollouts/concepts/

2. Argo Rollouts Docs - Getting Started  
   https://argoproj.github.io/argo-rollouts/getting-started/

3. Argo Rollouts Docs - Canary Strategy  
   https://argoproj.github.io/argo-rollouts/features/canary/

4. Argo Rollouts Docs - Analysis  
   https://argoproj.github.io/argo-rollouts/features/analysis/

5. Argo Rollouts Docs - Prometheus Metric Provider  
   https://argoproj.github.io/argo-rollouts/analysis/prometheus/

6. Prometheus Docs - Querying Basics  
   https://prometheus.io/docs/prometheus/latest/querying/basics/

### Đọc thêm

1. Argo Rollouts Docs - Kubectl Plugin  
   https://argoproj.github.io/argo-rollouts/installation/#kubectl-plugin-installation

2. Argo Rollouts Docs - BlueGreen Strategy  
   https://argoproj.github.io/argo-rollouts/features/bluegreen/

3. Flagger Docs - Canary Release  
   https://docs.flagger.app/tutorials/kubernetes-blue-green

4. CNCF - Progressive Delivery patterns  
   https://www.cncf.io/blog/2024/01/26/progressive-delivery/

## Kế hoạch học 6 giờ

| Thời lượng | Nội dung | Output cần có |
| ---------- | -------- | ------------- |
| 45 phút | Đọc progressive delivery, rolling, blue-green, canary | So sánh được 3 kiểu deploy |
| 60 phút | Đọc Argo Rollouts concepts và Rollout CRD | Giải thích được Rollout thay Deployment ở điểm nào |
| 75 phút | Học canary strategy: steps, setWeight, pause | Viết được Rollout YAML mẫu |
| 75 phút | Học AnalysisTemplate với Prometheus | Viết được query kiểm tra error rate hoặc latency |
| 45 phút | Học abort criteria và rollback | Ghi được điều kiện dừng canary |
| 45 phút | Tích hợp burn rate từ D2 | Viết được AnalysisTemplate dùng burn rate |
| 30 phút | Tổng kết reflection và câu hỏi | Cập nhật evidence cho ngày D3 |

## Ghi chú bài học

### 1. Progressive delivery là gì?

Progressive delivery là cách phát hành phần mềm theo từng bước nhỏ, có quan sát và có điều kiện dừng. Thay vì đưa phiên bản mới cho 100% traffic ngay lập tức, hệ thống chỉ cho một phần nhỏ người dùng hoặc request đi qua bản mới, đo metric, rồi mới tăng dần traffic.

Mục tiêu không phải deploy chậm hơn. Mục tiêu là giảm blast radius: nếu version mới lỗi, chỉ một phần nhỏ traffic bị ảnh hưởng và hệ thống có thể tự dừng rollout.

### 2. Rolling update, blue-green và canary

| Kiểu deploy | Cách hoạt động | Ưu điểm | Rủi ro |
| ----------- | -------------- | ------- | ------ |
| Rolling update | Thay pod cũ bằng pod mới dần dần | Đơn giản, Kubernetes hỗ trợ sẵn | Khó kiểm soát traffic theo phần trăm chính xác |
| Blue-green | Chạy song song blue và green, sau đó chuyển traffic | Rollback nhanh bằng đổi route | Cần tài nguyên gần gấp đôi trong lúc chuyển |
| Canary | Cho một phần nhỏ traffic vào version mới, đo metric rồi tăng dần | Giảm blast radius, phù hợp auto-abort | Cần metric, traffic routing và quy trình rõ |

Trong W9, trọng tâm là canary vì nó kết nối trực tiếp với observability D2: deploy chỉ tiếp tục nếu metric tốt.

### 3. Argo Rollouts là gì?

Argo Rollouts là Kubernetes controller mở rộng khả năng deployment. Thay vì chỉ dùng `Deployment`, ta dùng `Rollout` CRD để mô tả chiến lược phát hành nâng cao như canary, blue-green, pause, analysis và auto rollback.

Deployment bình thường trả lời câu hỏi:

- Cần chạy image nào?
- Có bao nhiêu replica?
- Update pod theo rolling update như thế nào?

Rollout trả lời thêm:

- Version mới được nhận bao nhiêu phần trăm traffic?
- Có pause ở từng bước để quan sát không?
- Metric nào quyết định canary pass/fail?
- Nếu metric xấu thì abort hay rollback như thế nào?

### 4. Rollout CRD cơ bản

Ví dụ Rollout canary đơn giản:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: demo-web
  namespace: demo
spec:
  replicas: 5
  selector:
    matchLabels:
      app: demo-web
  template:
    metadata:
      labels:
        app: demo-web
    spec:
      containers:
        - name: demo-web
          image: nginx:1.27
          ports:
            - containerPort: 80
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause:
            duration: 5m
        - setWeight: 50
        - pause:
            duration: 10m
        - setWeight: 100
```

Ý nghĩa:

- `replicas`: số pod mong muốn.
- `selector`: chọn pod thuộc rollout.
- `template`: định nghĩa pod giống Deployment.
- `strategy.canary.steps`: các bước tăng traffic hoặc tăng tỷ lệ canary.
- `setWeight`: phần trăm traffic hoặc replica dành cho version mới.
- `pause`: dừng tạm để quan sát metric hoặc chờ phê duyệt.

### 5. Canary với traffic routing

Canary có hai kiểu thường gặp:

- Không dùng traffic manager: Argo Rollouts điều chỉnh số replica canary/stable. Cách này đơn giản nhưng traffic thực tế có thể không đúng chính xác theo phần trăm.
- Có traffic manager: dùng NGINX Ingress, Istio, AWS ALB hoặc service mesh để route traffic chính xác theo weight.

Trong bài self-study, cần hiểu concept trước. Lab có thể bắt đầu từ kiểu đơn giản, sau đó mới gắn ingress/service mesh nếu môi trường hỗ trợ.

### 6. AnalysisTemplate là gì?

`AnalysisTemplate` mô tả cách đo metric để quyết định rollout có tiếp tục hay không. Argo Rollouts tạo `AnalysisRun` từ template này trong quá trình canary.

Một AnalysisTemplate thường gồm:

- Metric cần đo.
- Provider lấy metric, ví dụ Prometheus.
- Query PromQL.
- Điều kiện thành công `successCondition`.
- Điều kiện thất bại `failureCondition`.
- Số lần đo và khoảng cách giữa các lần đo.

Ví dụ kiểm tra error rate 5xx:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: demo-web-error-rate
  namespace: demo
spec:
  metrics:
    - name: error-rate
      interval: 1m
      count: 5
      successCondition: result[0] < 0.01
      failureCondition: result[0] >= 0.01
      provider:
        prometheus:
          address: http://prometheus-server.monitoring.svc.cluster.local
          query: |
            sum(rate(http_requests_total{app="demo-web",status=~"5.."}[5m]))
            /
            sum(rate(http_requests_total{app="demo-web"}[5m]))
```

Ý nghĩa:

- Đo mỗi 1 phút.
- Đo tối đa 5 lần.
- Nếu error rate dưới 1% thì pass.
- Nếu error rate từ 1% trở lên thì fail.
- Khi analysis fail, rollout có thể abort.

### 7. Gắn AnalysisTemplate vào Rollout

Ví dụ Rollout chạy analysis sau khi canary nhận 20% traffic:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: demo-web
  namespace: demo
spec:
  replicas: 5
  selector:
    matchLabels:
      app: demo-web
  template:
    metadata:
      labels:
        app: demo-web
    spec:
      containers:
        - name: demo-web
          image: nginx:1.27
          ports:
            - containerPort: 80
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause:
            duration: 2m
        - analysis:
            templates:
              - templateName: demo-web-error-rate
        - setWeight: 50
        - pause:
            duration: 5m
        - setWeight: 100
```

Luồng hoạt động:

1. Deploy version mới.
2. Đưa 20% traffic hoặc replica sang canary.
3. Pause 2 phút để hệ thống có dữ liệu.
4. Chạy analysis bằng Prometheus query.
5. Nếu pass, tăng tiếp lên 50%.
6. Nếu fail, abort rollout.

### 8. Abort criteria

Abort criteria là điều kiện khiến canary phải dừng. Điều kiện này phải cụ thể, đo được và liên quan đến trải nghiệm người dùng.

Ví dụ abort criteria:

| Nhóm | Điều kiện dừng |
| ---- | -------------- |
| Availability | Error rate 5xx >= 1% trong 5 phút |
| Latency | p95 latency > 500ms trong 5 phút |
| Saturation | CPU pod > 90% trong 10 phút |
| SLO | Burn rate fast window vượt ngưỡng 14.4 |
| Business | Checkout/payment fail tăng bất thường |

Không nên dùng điều kiện quá mơ hồ như "app có vẻ chậm". Canary cần metric rõ ràng để có thể tự động hóa.

### 9. Tích hợp burn rate với canary

D2 đã học:

```text
burn rate = actual error ratio / allowed error ratio
```

Nếu SLO availability là 99.9%, allowed error ratio là `0.001`. Khi canary làm tăng tỷ lệ lỗi, burn rate sẽ tăng. Ta có thể dùng Prometheus query burn rate trong AnalysisTemplate để quyết định abort.

Ví dụ fast burn query:

```promql
(
  sum(rate(http_requests_total{app="demo-web",status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total{app="demo-web"}[5m]))
) / 0.001
```

Nếu kết quả lớn hơn `14.4`, canary đang đốt error budget quá nhanh và nên abort.

### 10. AnalysisTemplate dùng burn rate

Ví dụ AnalysisTemplate abort khi burn rate cao:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: demo-web-burn-rate
  namespace: demo
spec:
  metrics:
    - name: fast-burn-rate
      interval: 1m
      count: 5
      successCondition: result[0] < 14.4
      failureCondition: result[0] >= 14.4
      provider:
        prometheus:
          address: http://prometheus-server.monitoring.svc.cluster.local
          query: |
            (
              sum(rate(http_requests_total{app="demo-web",status=~"5.."}[5m]))
              /
              sum(rate(http_requests_total{app="demo-web"}[5m]))
            ) / 0.001
```

Có thể mở rộng thành multi-window burn rate bằng cách tạo hai metric riêng:

- `fast-burn-rate-5m`
- `slow-burn-rate-30m`

Trong thực tế, nên dùng cả window ngắn và dài để tránh abort vì nhiễu ngắn hạn.

### 11. Lệnh quan sát Argo Rollouts

Các lệnh thường dùng:

```bash
kubectl get rollout -n demo
kubectl describe rollout demo-web -n demo
kubectl argo rollouts get rollout demo-web -n demo
kubectl argo rollouts dashboard
kubectl argo rollouts promote demo-web -n demo
kubectl argo rollouts abort demo-web -n demo
kubectl argo rollouts undo demo-web -n demo
```

Ghi chú:

- `promote`: cho rollout đi tiếp khi đang pause.
- `abort`: dừng canary hiện tại.
- `undo`: quay về revision trước, nhưng trong GitOps vẫn cần cập nhật Git để tránh drift.

### 12. GitOps và Argo Rollouts

Trong W9, Rollout YAML vẫn phải nằm trong Git và được ArgoCD sync. Không apply tay rồi bỏ quên ngoài repo.

Luồng mong muốn:

```text
Developer
  -> sửa Rollout hoặc AnalysisTemplate trong Git
  -> PR
  -> GitHub Actions validate manifest
  -> merge
  -> ArgoCD sync
  -> Argo Rollouts chạy canary
  -> Prometheus query metric
  -> pass thì tăng traffic, fail thì abort
```

Nếu canary fail:

1. Argo Rollouts abort rollout.
2. Kiểm tra AnalysisRun để biết metric nào fail.
3. Tạo fix commit hoặc `git revert` commit gây lỗi.
4. ArgoCD sync desired state mới.
5. Lưu evidence: rollout status, analysis result, Prometheus query và commit revert.

## Cấu trúc thư mục D3

Toàn bộ bài D3 đặt trong `cloud/w9/wed/`, bao gồm ghi chú, Rollout, AnalysisTemplate, Prometheus query và ảnh bằng chứng:

```text
cloud/w9/wed/
+-- progressive-delivery-canary.md
+-- NOTES.md
+-- imgs/
|   +-- rollout-status.png
|   +-- analysis-run.png
|   +-- prometheus-canary-query.png
|   +-- abort-result.png
|   +-- burn-rate-analysis.png
+-- rollout/
|   +-- demo-web-rollout.yaml
|   +-- demo-web-service.yaml
+-- analysis-template/
|   +-- demo-web-error-rate.yaml
|   +-- demo-web-burn-rate.yaml
+-- prometheus/
    +-- canary-queries.md
```

Thư mục `imgs/` dùng để lưu toàn bộ ảnh bằng chứng của ngày D3. Không để ảnh rải ở thư mục khác để khi nộp bài chỉ cần mở `cloud/w9/wed/` là thấy đủ nội dung.

## Bài thực hành đề xuất

### Bài 1 - Ghi chú progressive delivery

Tạo file:

```text
cloud/w9/wed/NOTES.md
```

Trả lời ngắn gọn:

- Progressive delivery là gì?
- Canary khác rolling update ở điểm nào?
- Argo Rollouts bổ sung gì so với Deployment?
- AnalysisTemplate dùng để làm gì?
- Abort criteria của app demo là gì?
- Burn rate giúp quyết định canary như thế nào?

### Bài 2 - Tạo Rollout YAML

Tạo thư mục:

```text
cloud/w9/wed/rollout/
```

Tạo file:

```text
cloud/w9/wed/rollout/demo-web-rollout.yaml
```

Rollout cần có:

- `apiVersion: argoproj.io/v1alpha1`
- `kind: Rollout`
- `replicas`
- `selector`
- `template`
- `strategy.canary.steps`
- Ít nhất 2 bước `setWeight`
- Ít nhất 1 bước `pause`
- Ít nhất 1 bước `analysis`

### Bài 3 - Tạo Service cho Rollout

Tạo file:

```text
cloud/w9/wed/rollout/demo-web-service.yaml
```

Service cần chọn đúng label của pod:

```yaml
selector:
  app: demo-web
```

Nếu môi trường có traffic manager, có thể bổ sung stable service và canary service theo docs của Argo Rollouts.

### Bài 4 - Tạo AnalysisTemplate error rate

Tạo thư mục:

```text
cloud/w9/wed/analysis-template/
```

Tạo file:

```text
cloud/w9/wed/analysis-template/demo-web-error-rate.yaml
```

AnalysisTemplate cần có:

- Metric `error-rate`.
- Prometheus provider.
- Query tính tỷ lệ lỗi 5xx.
- `successCondition`.
- `failureCondition`.
- `interval` và `count`.

### Bài 5 - Tạo AnalysisTemplate burn rate

Tạo file:

```text
cloud/w9/wed/analysis-template/demo-web-burn-rate.yaml
```

AnalysisTemplate cần dùng công thức:

```text
burn rate = actual error ratio / allowed error ratio
```

Nếu SLO là 99.9%, allowed error ratio là `0.001`. Abort nếu burn rate vượt ngưỡng đã chọn, ví dụ `14.4` cho fast burn.

### Bài 6 - Ghi Prometheus query

Tạo thư mục:

```text
cloud/w9/wed/prometheus/
```

Tạo file:

```text
cloud/w9/wed/prometheus/canary-queries.md
```

Ghi tối thiểu:

- Query request rate.
- Query error rate.
- Query p95 latency nếu app có histogram.
- Query burn rate 5m.
- Query burn rate 30m.

### Bài 7 - Lưu evidence vào imgs

Ảnh bằng chứng lưu trong:

```text
cloud/w9/wed/imgs/
```

Tên ảnh gợi ý:

- `rollout-status.png`: trạng thái Rollout.
- `analysis-run.png`: kết quả AnalysisRun.
- `prometheus-canary-query.png`: Prometheus query cho canary.
- `abort-result.png`: kết quả abort khi metric fail nếu có mô phỏng.
- `burn-rate-analysis.png`: query hoặc AnalysisTemplate burn rate.

## Checklist hôm nay

- [ ] Giải thích được progressive delivery bằng lời của mình.
- [ ] So sánh được rolling update, blue-green và canary.
- [ ] Giải thích được Argo Rollouts và Rollout CRD.
- [ ] Viết được Rollout YAML có canary steps.
- [ ] Viết được AnalysisTemplate dùng Prometheus query.
- [ ] Xác định được abort criteria rõ ràng cho app demo.
- [ ] Viết được PromQL tính error rate.
- [ ] Viết được PromQL hoặc AnalysisTemplate tính burn rate.
- [ ] Giải thích được vì sao burn rate phù hợp để auto-abort canary.
- [ ] Biết dùng lệnh xem Rollout và AnalysisRun.
- [ ] Lưu evidence vào `cloud/w9/wed/imgs/`.
- [ ] Cập nhật câu hỏi còn vướng cho mentor.

## Evidence cần nộp

Trong `cloud/w9/wed/NOTES.md`, ghi tối thiểu:

- Link hoặc tên commit D3 với message dạng `[W9-D3] <topic ngắn>`.
- Bảng so sánh rolling update, blue-green và canary.
- Mô tả Rollout CRD đã viết.
- Nội dung abort criteria.
- Link đến `rollout/demo-web-rollout.yaml`.
- Link đến `analysis-template/demo-web-error-rate.yaml`.
- Link đến `analysis-template/demo-web-burn-rate.yaml`.
- Prometheus query error rate và burn rate.
- Ảnh trạng thái Rollout, lưu trong `cloud/w9/wed/imgs/rollout-status.png`.
- Ảnh AnalysisRun, lưu trong `cloud/w9/wed/imgs/analysis-run.png`.
- Ảnh Prometheus query, lưu trong `cloud/w9/wed/imgs/prometheus-canary-query.png`.
- Ảnh abort result nếu có, lưu trong `cloud/w9/wed/imgs/abort-result.png`.
- Câu hỏi còn vướng cho mentor.

## Câu hỏi ôn tập

1. Progressive delivery giải quyết rủi ro gì trong quá trình deploy?
2. Canary khác rolling update ở điểm nào?
3. Argo Rollouts thay thế hoặc bổ sung Deployment như thế nào?
4. `Rollout` CRD có những phần chính nào?
5. `setWeight` và `pause` trong canary strategy dùng để làm gì?
6. `AnalysisTemplate` khác `AnalysisRun` như thế nào?
7. Prometheus query trong AnalysisTemplate nên đo metric nào?
8. Abort criteria tốt cần có đặc điểm gì?
9. Vì sao `kubectl rollout undo` chưa đủ trong hệ thống GitOps?
10. Burn rate giúp canary auto-abort tốt hơn error rate đơn thuần ở điểm nào?

