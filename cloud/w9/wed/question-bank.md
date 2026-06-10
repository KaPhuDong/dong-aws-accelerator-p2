# W9 Day C Question Bank - Progressive Delivery: Canary với Argo Rollouts

> Nguồn câu hỏi cho bài self-study T4 10/06/2026. Format tham khảo theo `question-bank.md`: chia theo độ khó, mỗi câu có câu hỏi và đáp án mong đợi.

---

## Easy

### Câu 1 - Dễ *(Chủ đề: Progressive Delivery)*
**Câu hỏi:** Progressive delivery là gì?

**Đáp án mong đợi:**
- Progressive delivery là cách phát hành phần mềm theo từng bước nhỏ.
- Phiên bản mới không nhận 100% traffic ngay lập tức.
- Hệ thống tăng dần traffic và quan sát metrics.
- Nếu metrics xấu, rollout có thể dừng hoặc rollback.
- Mục tiêu là giảm blast radius khi bản mới lỗi.

### Câu 2 - Dễ *(Chủ đề: Canary)*
**Câu hỏi:** Canary deployment là gì?

**Đáp án mong đợi:**
- Canary là cách đưa một phần nhỏ traffic hoặc user sang version mới.
- Sau đó đo metrics như error rate, latency, burn rate.
- Nếu version mới ổn, tăng dần traffic.
- Nếu version mới lỗi, dừng rollout để giảm ảnh hưởng.
- Canary phù hợp với hệ thống có observability tốt.

### Câu 3 - Dễ *(Chủ đề: Argo Rollouts)*
**Câu hỏi:** Argo Rollouts dùng để làm gì?

**Đáp án mong đợi:**
- Argo Rollouts là Kubernetes controller cho progressive delivery.
- Cung cấp `Rollout` CRD thay thế hoặc bổ sung Deployment.
- Hỗ trợ canary, blue-green, pause, analysis và rollback.
- Có thể dùng metrics từ Prometheus để quyết định rollout.
- Phù hợp khi cần auto-abort deployment xấu.

### Câu 4 - Dễ *(Chủ đề: Rollout CRD)*
**Câu hỏi:** `Rollout` CRD khác Deployment thông thường ở điểm nào?

**Đáp án mong đợi:**
- Deployment hỗ trợ rolling update cơ bản.
- Rollout hỗ trợ chiến lược phát hành nâng cao như canary và blue-green.
- Rollout có steps như `setWeight`, `pause`, `analysis`.
- Rollout có thể gắn AnalysisTemplate để kiểm tra metrics.
- Rollout giúp tự động dừng khi bản mới không đạt điều kiện.

### Câu 5 - Dễ *(Chủ đề: Canary Steps)*
**Câu hỏi:** `setWeight` và `pause` trong canary strategy dùng để làm gì?

**Đáp án mong đợi:**
- `setWeight` đặt tỷ lệ traffic hoặc tỷ lệ canary ở một bước.
- Ví dụ `setWeight: 20` nghĩa là đưa 20% sang canary.
- `pause` dừng rollout tạm thời.
- Pause giúp có thời gian quan sát metrics hoặc chờ approve.
- Các step này giúp rollout diễn ra có kiểm soát.

## Medium

### Câu 6 - Trung bình *(Chủ đề: Deployment Strategy)*
**Câu hỏi:** So sánh rolling update, blue-green và canary.

**Đáp án mong đợi:**
- Rolling update thay pod cũ bằng pod mới dần dần, đơn giản nhưng ít kiểm soát traffic.
- Blue-green chạy song song hai môi trường và chuyển traffic khi sẵn sàng.
- Canary đưa một phần nhỏ traffic vào version mới rồi tăng dần.
- Blue-green rollback nhanh nhưng cần nhiều tài nguyên hơn.
- Canary giảm blast radius tốt nhưng cần metrics và traffic routing rõ ràng.

### Câu 7 - Trung bình *(Chủ đề: AnalysisTemplate)*
**Câu hỏi:** `AnalysisTemplate` dùng để làm gì trong Argo Rollouts?

**Đáp án mong đợi:**
- `AnalysisTemplate` định nghĩa cách đo metrics để đánh giá rollout.
- Có thể dùng provider như Prometheus.
- Chứa query PromQL, interval, count.
- Có `successCondition` và `failureCondition`.
- Argo Rollouts tạo `AnalysisRun` từ template trong quá trình rollout.

### Câu 8 - Trung bình *(Chủ đề: Prometheus Query)*
**Câu hỏi:** AnalysisTemplate với Prometheus thường cần những thành phần nào?

**Đáp án mong đợi:**
- `provider.prometheus.address` để chỉ Prometheus endpoint.
- `query` để lấy metric cần đánh giá.
- `successCondition` để xác định khi nào pass.
- `failureCondition` để xác định khi nào fail.
- `interval` và `count` để quyết định đo bao lâu và bao nhiêu lần.

### Câu 9 - Trung bình *(Chủ đề: Abort Criteria)*
**Câu hỏi:** Abort criteria tốt cho canary cần có đặc điểm gì?

**Đáp án mong đợi:**
- Cụ thể và đo được bằng metrics.
- Liên quan đến trải nghiệm người dùng hoặc SLO.
- Có ngưỡng rõ ràng như error rate, latency, burn rate.
- Không nên dùng mô tả mơ hồ như "app có vẻ chậm".
- Có thể tự động hóa bằng AnalysisTemplate.

### Câu 10 - Trung bình *(Chủ đề: GitOps Integration)*
**Câu hỏi:** Argo Rollouts tích hợp với GitOps như thế nào?

**Đáp án mong đợi:**
- Rollout YAML và AnalysisTemplate vẫn nằm trong Git.
- Developer sửa manifest qua PR.
- GitHub Actions validate manifest.
- ArgoCD sync manifest vào cluster.
- Argo Rollouts thực thi canary và analysis.
- Nếu fail, cần fix hoặc `git revert` trong repo.

## Hard

### Câu 11 - Khó *(Chủ đề: Burn Rate Integration)*
**Câu hỏi:** Vì sao burn rate phù hợp để auto-abort canary?

**Đáp án mong đợi:**
- Burn rate đo tốc độ tiêu hao error budget.
- Nó gắn trực tiếp với SLO thay vì chỉ nhìn một metric thô.
- Canary làm lỗi tăng sẽ khiến burn rate tăng nhanh.
- Có thể dùng Prometheus query burn rate trong AnalysisTemplate.
- Nếu burn rate vượt ngưỡng, rollout nên abort để bảo vệ SLO.

### Câu 12 - Khó *(Chủ đề: PromQL cho Canary)*
**Câu hỏi:** Viết PromQL tính burn rate 5 phút cho SLO availability 99.9%.

**Đáp án mong đợi:**
- SLO 99.9% có allowed error ratio là `0.001`.
- Tính error ratio trước, sau đó chia cho `0.001`.
- Ví dụ:

```promql
(
  sum(rate(http_requests_total{app="demo-web",status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total{app="demo-web"}[5m]))
) / 0.001
```

### Câu 13 - Khó *(Chủ đề: AnalysisTemplate Conditions)*
**Câu hỏi:** Với burn rate threshold 14.4, `successCondition` và `failureCondition` nên viết thế nào?

**Đáp án mong đợi:**
- Nếu query trả về một giá trị trong `result[0]`, có thể dùng điều kiện trực tiếp.
- `successCondition: result[0] < 14.4`.
- `failureCondition: result[0] >= 14.4`.
- Điều kiện thành công và thất bại phải rõ ràng, không chồng chéo.
- Cần chọn interval/count đủ để tránh nhiễu ngắn hạn.

### Câu 14 - Khó *(Chủ đề: Rollout Debugging)*
**Câu hỏi:** Canary bị abort. Cần kiểm tra những gì?

**Đáp án mong đợi:**
- Kiểm tra `kubectl argo rollouts get rollout`.
- Kiểm tra `AnalysisRun` để biết metric nào fail.
- Mở Prometheus query tương ứng để xác nhận dữ liệu.
- Xem logs của canary pod để tìm lỗi ứng dụng.
- Kiểm tra ArgoCD sync status để biết manifest có đúng Git không.
- Tạo fix commit hoặc `git revert` commit gây lỗi.

### Câu 15 - Khó *(Chủ đề: Rollback trong GitOps)*
**Câu hỏi:** Vì sao `kubectl argo rollouts undo` chưa đủ trong hệ thống GitOps?

**Đáp án mong đợi:**
- `undo` thay đổi trạng thái rollout trong cluster.
- Git vẫn có thể đang chứa desired state lỗi.
- ArgoCD/Flux có thể sync lại manifest từ Git và làm mất thay đổi thủ công.
- Cần cập nhật Git bằng fix commit hoặc `git revert`.
- Evidence nên gồm rollout status, analysis result, Prometheus query và commit revert.

