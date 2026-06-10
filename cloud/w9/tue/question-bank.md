# W9 Day B Question Bank - Observability: SLO/SLI, OpenTelemetry, Prometheus, Grafana, Loki

> Nguồn câu hỏi cho bài self-study T3 09/06/2026. Format tham khảo theo `question-bank.md`: chia theo độ khó, mỗi câu có câu hỏi và đáp án mong đợi.

---

## Easy

### Câu 1 - Dễ *(Chủ đề: Observability)*
**Câu hỏi:** Observability là gì?

**Đáp án mong đợi:**
- Observability là khả năng hiểu trạng thái bên trong của hệ thống thông qua dữ liệu hệ thống phát ra.
- Dữ liệu chính gồm metrics, logs và traces.
- Observability giúp trả lời vì sao hệ thống có vấn đề.
- Khác monitoring truyền thống ở chỗ không chỉ nhìn "có lỗi hay không".
- Mục tiêu là hỗ trợ debug, vận hành và quyết định deploy.

### Câu 2 - Dễ *(Chủ đề: Metrics)*
**Câu hỏi:** Metrics dùng để trả lời câu hỏi gì?

**Đáp án mong đợi:**
- Hệ thống đang xử lý bao nhiêu request.
- Tỷ lệ lỗi là bao nhiêu.
- Latency p50, p95, p99 như thế nào.
- CPU, memory, replica đang ở mức nào.
- Metrics phù hợp để vẽ dashboard và tạo alert.

### Câu 3 - Dễ *(Chủ đề: Logs)*
**Câu hỏi:** Logs dùng để làm gì trong observability?

**Đáp án mong đợi:**
- Ghi lại sự kiện xảy ra trong app, pod hoặc service.
- Giúp xem lỗi cụ thể, stack trace hoặc message tại thời điểm sự cố.
- Có thể lọc theo namespace, pod, app hoặc level.
- Logs bổ sung ngữ cảnh mà metrics không thể hiện chi tiết.
- Loki là một công cụ phổ biến để lưu và truy vấn logs cùng Grafana.

### Câu 4 - Dễ *(Chủ đề: SLI/SLO)*
**Câu hỏi:** SLI và SLO khác nhau thế nào?

**Đáp án mong đợi:**
- SLI là chỉ số đo chất lượng dịch vụ.
- SLO là mục tiêu chất lượng đặt trên SLI.
- Ví dụ SLI: tỷ lệ request thành công.
- Ví dụ SLO: 99.9% request thành công trong 30 ngày.
- SLO giúp ra quyết định vận hành và deploy dựa trên dữ liệu.

### Câu 5 - Dễ *(Chủ đề: OpenTelemetry)*
**Câu hỏi:** OpenTelemetry dùng để làm gì?

**Đáp án mong đợi:**
- OpenTelemetry cung cấp tiêu chuẩn và công cụ thu thập telemetry.
- Có thể tạo metrics, logs và traces từ ứng dụng.
- SDK gắn vào app để instrument.
- Collector nhận, xử lý và gửi dữ liệu đến backend.
- Giúp giảm phụ thuộc trực tiếp giữa app và backend quan sát.

## Medium

### Câu 6 - Trung bình *(Chủ đề: Error Budget)*
**Câu hỏi:** Error budget là gì? Cho ví dụ với SLO 99.9%.

**Đáp án mong đợi:**
- Error budget là phần lỗi được phép xảy ra mà vẫn đạt SLO.
- SLO 99.9% nghĩa là được phép lỗi 0.1%.
- Với 1,000,000 request, error budget là 1,000 request lỗi.
- Khi error budget bị tiêu nhanh, nên hạn chế deploy rủi ro.
- Error budget giúp cân bằng tốc độ phát hành và độ ổn định.

### Câu 7 - Trung bình *(Chủ đề: Burn Rate)*
**Câu hỏi:** Burn rate là gì?

**Đáp án mong đợi:**
- Burn rate là tốc độ tiêu hao error budget.
- Công thức: `actual error ratio / allowed error ratio`.
- Burn rate = 1 nghĩa là tiêu budget đúng tốc độ cho phép.
- Burn rate cao nghĩa là hệ thống đang lỗi nhanh hơn mức cho phép.
- Burn rate có thể dùng để alert hoặc dừng canary.

### Câu 8 - Trung bình *(Chủ đề: Prometheus)*
**Câu hỏi:** Prometheus hoạt động theo cơ chế nào?

**Đáp án mong đợi:**
- Prometheus lưu metrics dạng time series.
- Prometheus thường scrape endpoint `/metrics` theo chu kỳ.
- Metric có thể có label để phân loại.
- PromQL dùng để truy vấn và tính toán metrics.
- Alert rule có thể dựa trên PromQL.

### Câu 9 - Trung bình *(Chủ đề: Grafana)*
**Câu hỏi:** Dashboard Grafana tối thiểu cho app nên có những panel nào?

**Đáp án mong đợi:**
- Request rate.
- Error rate.
- Latency p50/p95/p99.
- CPU và memory pod.
- Số replica đang chạy.
- Logs lỗi gần nhất.
- SLO availability, latency và burn rate.

### Câu 10 - Trung bình *(Chủ đề: Loki)*
**Câu hỏi:** Loki truy vấn logs dựa trên gì?

**Đáp án mong đợi:**
- Loki tập trung index label thay vì index toàn bộ nội dung log.
- Label thường gồm namespace, pod, app, container.
- LogQL dùng để truy vấn logs.
- Có thể lọc log theo label và nội dung chuỗi.
- Ví dụ: `{namespace="demo", app="demo-web"} |= "error"`.

## Hard

### Câu 11 - Khó *(Chủ đề: Multi-window Burn Rate)*
**Câu hỏi:** Vì sao nên dùng multi-window burn rate alert thay vì chỉ một cửa sổ thời gian?

**Đáp án mong đợi:**
- Một window quá ngắn dễ gây alert nhiễu.
- Một window quá dài phát hiện sự cố chậm.
- Multi-window kết hợp tín hiệu nhanh và tín hiệu ổn định hơn.
- Fast burn có thể dùng 1h và 5m.
- Slow burn có thể dùng 6h và 30m.
- Chỉ alert khi cả hai window cùng cho thấy error budget bị đốt nhanh.

### Câu 12 - Khó *(Chủ đề: PromQL)*
**Câu hỏi:** Viết PromQL tính tỷ lệ lỗi 5xx trong 5 phút gần nhất.

**Đáp án mong đợi:**
- Có thể dùng `rate()` để tính tốc độ tăng counter.
- Tử số là request 5xx.
- Mẫu số là tổng request.
- Ví dụ:

```promql
sum(rate(http_requests_total{status=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
```

### Câu 13 - Khó *(Chủ đề: OpenTelemetry Collector)*
**Câu hỏi:** Trong OpenTelemetry Collector, receiver, processor và exporter có vai trò gì?

**Đáp án mong đợi:**
- Receiver nhận telemetry data từ app hoặc agent.
- Processor xử lý, batch, filter hoặc enrich dữ liệu.
- Exporter gửi dữ liệu đến backend như Prometheus, Loki, Tempo, Jaeger.
- Pipeline nối receiver, processor và exporter.
- Collector giúp thay đổi backend mà không cần sửa nhiều trong app.

### Câu 14 - Khó *(Chủ đề: SLO Alerting)*
**Câu hỏi:** Với SLO 99.9%, nếu error ratio thực tế là 1%, burn rate là bao nhiêu?

**Đáp án mong đợi:**
- Allowed error ratio = `1 - 0.999 = 0.001`.
- Actual error ratio = `0.01`.
- Burn rate = `0.01 / 0.001 = 10`.
- Nghĩa là hệ thống đang đốt error budget nhanh gấp 10 lần tốc độ cho phép.
- Đây là tín hiệu cần alert hoặc dừng rollout nếu đang deploy.

### Câu 15 - Khó *(Chủ đề: Observability cho Delivery)*
**Câu hỏi:** Observability hỗ trợ progressive delivery như thế nào?

**Đáp án mong đợi:**
- Metrics cho biết bản deploy mới có làm tăng lỗi hoặc latency không.
- Logs giúp điều tra nguyên nhân khi metric xấu.
- Traces giúp tìm service hoặc dependency gây chậm.
- SLO và burn rate giúp biến chất lượng dịch vụ thành điều kiện quyết định.
- Canary có thể tự động tiếp tục hoặc abort dựa trên Prometheus query.

