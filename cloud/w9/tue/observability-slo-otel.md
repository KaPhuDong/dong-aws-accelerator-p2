# W9 Day B - Observability: SLA/SLO, OpenTelemetry, Prometheus, Grafana, Loki

Ngày học: T3 09/06/2026  
Chủ đề: Deliver Smartly phần 2 - Observability, SLA/SLO, OpenTelemetry và burn rate alert

## Mục tiêu hôm nay

- Hiểu observability khác monitoring truyền thống ở điểm nào.
- Phân biệt 3 tín hiệu chính: metrics, logs và traces.
- Hiểu SLA, SLO, error budget và burn rate.
- Biết vai trò của OpenTelemetry SDK và OpenTelemetry Collector.
- Nắm cách Prometheus thu thập metrics và Grafana hiển thị dashboard.
- Hiểu Loki dùng để lưu và truy vấn logs.
- Viết được alert rule cơ bản cho availability, latency và multi-window burn rate.
- Chuẩn bị nền tảng cho D3 Canary auto-abort dựa trên metric xấu.

## Nguồn học hôm nay

### Bắt buộc

1. OpenTelemetry Docs - Concepts  
   https://opentelemetry.io/docs/concepts/

2. OpenTelemetry Docs - Collector  
   https://opentelemetry.io/docs/collector/

3. Prometheus Docs - Overview  
   https://prometheus.io/docs/introduction/overview/

4. Grafana Docs - Dashboards  
   https://grafana.com/docs/grafana/latest/dashboards/

5. Loki Docs - Overview  
   https://grafana.com/docs/loki/latest/

6. Google SRE Book - Service Level Objectives  
   https://sre.google/sre-book/service-level-objectives/

7. Google SRE Workbook - Alerting on SLOs  
   https://sre.google/workbook/alerting-on-slos/

### Đọc thêm

1. Google SRE Workbook - Implementing SLOs  
   https://sre.google/workbook/implementing-slos/

2. Prometheus Docs - Alerting Rules  
   https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/

3. Grafana Docs - Prometheus Data Source  
   https://grafana.com/docs/grafana/latest/datasources/prometheus/

## Kế hoạch học 6 giờ

| Thời lượng | Nội dung | Output cần có |
| ---------- | -------- | ------------- |
| 45 phút | Đọc khái niệm observability, metrics, logs, traces | Ghi được vai trò từng tín hiệu |
| 60 phút | Học SLA, SLO, error budget và burn rate | Tính được error budget đơn giản |
| 75 phút | Đọc OpenTelemetry SDK và Collector | Vẽ được luồng app -> collector -> backend |
| 75 phút | Tìm hiểu Prometheus và Grafana | Viết được vài PromQL cơ bản |
| 45 phút | Tìm hiểu Loki và log correlation | Biết truy vấn log theo label |
| 45 phút | Học multi-window burn rate alert | Viết được alert rule mẫu |
| 30 phút | Tổng kết reflection và câu hỏi | Cập nhật evidence cho ngày D2 |

## Ghi chú bài học

### 1. Observability là gì?

Monitoring trả lời câu hỏi: "Hệ thống có đang chạy không?". Observability đi xa hơn: "Vì sao hệ thống đang có vấn đề?".

Một hệ thống observable tốt giúp người vận hành hiểu trạng thái bên trong của hệ thống thông qua dữ liệu phát ra bên ngoài. Ba nhóm tín hiệu quan trọng nhất là:

| Tín hiệu | Dùng để trả lời |
| -------- | --------------- |
| Metrics | Hệ thống đang nhanh/chậm, lỗi nhiều/ít, tài nguyên cao/thấp như thế nào? |
| Logs | Chuyện gì đã xảy ra trong từng request, pod hoặc service? |
| Traces | Một request đi qua những service nào và tốn thời gian ở đâu? |

Trong W9, observability không chỉ để nhìn dashboard. Mục tiêu là dùng metric để ra quyết định delivery: deploy có ổn không, canary có nên tiếp tục không, có cần rollback hoặc abort không.

### 2. SLA, SLO và error budget

SLA là cam kết hoặc thỏa thuận chất lượng dịch vụ với người dùng/khách hàng. SLO là mục tiêu vận hành cụ thể, đo được, thường dùng nội bộ để đảm bảo hệ thống đạt chất lượng mong muốn trước khi vi phạm SLA. Error budget là phần lỗi được phép xảy ra mà vẫn nằm trong mục tiêu đã đặt.

Ví dụ:

| Khái niệm | Ví dụ |
| --------- | ----- |
| SLA availability | Cam kết mức độ sẵn sàng với người dùng/khách hàng |
| SLO availability | 99.9% request thành công trong 30 ngày |
| Error budget | 0.1% request được phép lỗi trong 30 ngày |
| SLA latency | Cam kết hoặc kỳ vọng về độ trễ ở mức dịch vụ |
| SLO latency | 95% request dưới 300ms |

Nếu SLO là 99.9%, hệ thống chỉ được phép lỗi 0.1%. Với 1,000,000 request trong kỳ đo:

```text
error budget = 1,000,000 * 0.001 = 1,000 request lỗi
```

Nếu trong vài giờ đầu hệ thống đã đốt hết phần lớn error budget, đội vận hành phải dừng deploy, giảm rủi ro hoặc rollback.

### 3. Burn rate là gì?

Burn rate là tốc độ tiêu hao error budget.

Nếu burn rate = 1, hệ thống đang tiêu error budget đúng tốc độ cho phép. Nếu burn rate = 10, hệ thống đang tiêu error budget nhanh gấp 10 lần. Burn rate càng cao thì càng cần alert mạnh.

Ví dụ với SLO 99.9%:

```text
allowed error ratio = 1 - 0.999 = 0.001
actual error ratio = 0.01
burn rate = actual error ratio / allowed error ratio = 0.01 / 0.001 = 10
```

Nghĩa là hệ thống đang lỗi 1%, trong khi chỉ được phép lỗi 0.1%. Error budget đang bị đốt nhanh gấp 10 lần.

### 4. Multi-window burn rate alert

Alert theo một cửa sổ thời gian duy nhất thường gây hai vấn đề:

- Cửa sổ quá ngắn: dễ báo động nhiễu.
- Cửa sổ quá dài: phát hiện sự cố chậm.

Multi-window burn rate kết hợp cửa sổ nhanh và cửa sổ chậm:

| Loại alert | Window dài | Window ngắn | Ý nghĩa |
| ---------- | ---------- | ----------- | ------- |
| Fast burn | 1h | 5m | Phát hiện sự cố nghiêm trọng rất nhanh |
| Slow burn | 6h | 30m | Phát hiện lỗi âm ỉ nhưng kéo dài |

Ý tưởng: chỉ alert khi cả hai window cùng cho thấy error budget đang bị đốt nhanh. Cách này giảm nhiễu nhưng vẫn phản ứng đủ nhanh.

### 5. OpenTelemetry dùng để làm gì?

OpenTelemetry là bộ tiêu chuẩn và công cụ để instrument ứng dụng, thu thập telemetry data và gửi đến backend quan sát.

Hai thành phần cần nhớ:

| Thành phần | Vai trò |
| ---------- | ------- |
| OpenTelemetry SDK | Gắn vào ứng dụng để tạo metrics, logs, traces |
| OpenTelemetry Collector | Nhận telemetry data, xử lý, lọc, enrich và gửi đến backend |

Luồng cơ bản:

```text
Application
  -> OpenTelemetry SDK
  -> OpenTelemetry Collector
  -> Prometheus / Tempo / Jaeger / Loki / backend khác
  -> Grafana dashboard và alert
```

Collector giúp tách ứng dụng khỏi backend cụ thể. Nếu sau này đổi backend, ứng dụng không cần đổi quá nhiều.

### 6. Prometheus dùng để làm gì?

Prometheus là hệ thống thu thập và lưu metrics theo dạng time series. Prometheus thường scrape endpoint `/metrics` của ứng dụng hoặc exporter.

Các khái niệm cần nhớ:

| Khái niệm | Ý nghĩa |
| --------- | ------- |
| Metric | Tên chỉ số, ví dụ `http_requests_total` |
| Label | Chiều phân loại metric, ví dụ `method="GET"`, `status="500"` |
| Scrape | Prometheus kéo metrics từ target theo chu kỳ |
| PromQL | Ngôn ngữ truy vấn metrics |
| Alert rule | Điều kiện PromQL để tạo alert |

Ví dụ PromQL:

```promql
sum(rate(http_requests_total[5m]))
```

Tính tổng request/giây trong 5 phút gần nhất.

```promql
sum(rate(http_requests_total{status=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
```

Tính tỷ lệ request lỗi 5xx trong 5 phút gần nhất.

### 7. Grafana dùng để làm gì?

Grafana dùng để hiển thị dashboard và alert từ nhiều data source như Prometheus, Loki, Tempo, CloudWatch.

Dashboard tối thiểu cho ứng dụng W8/W9 nên có:

- Request rate.
- Error rate.
- Latency p50, p95, p99.
- CPU và memory của pod.
- Số replica đang chạy.
- Log lỗi gần nhất.
- SLO panel: availability, latency và error budget remaining.

Dashboard tốt không chỉ đẹp. Nó phải giúp trả lời nhanh:

- Có sự cố không?
- Sự cố bắt đầu từ lúc nào?
- Ảnh hưởng đến service nào?
- Có liên quan đến deploy mới không?
- Có cần rollback hoặc abort canary không?

### 8. Loki dùng để làm gì?

Loki là hệ thống lưu logs được thiết kế để làm việc tốt với Grafana. Loki không index toàn bộ nội dung log như một số hệ thống log khác; Loki tập trung index label.

Ví dụ label:

```text
namespace="demo"
pod="demo-web-abc123"
app="demo-web"
```

Ví dụ LogQL:

```logql
{namespace="demo", app="demo-web"}
```

Lọc log theo namespace và app.

```logql
{namespace="demo", app="demo-web"} |= "error"
```

Lọc log có chứa từ `error`.

### 9. Alert rule mẫu cho availability

Ví dụ alert tỷ lệ lỗi 5xx cao trong 5 phút:

```yaml
groups:
  - name: demo-web-slo
    rules:
      - alert: DemoWebHighErrorRate
        expr: |
          (
            sum(rate(http_requests_total{status=~"5.."}[5m]))
            /
            sum(rate(http_requests_total[5m]))
          ) > 0.01
        for: 5m
        labels:
          severity: warning
          service: demo-web
        annotations:
          summary: "Demo web error rate is above 1%"
          description: "5xx error ratio has been above 1% for 5 minutes."
```

### 10. Alert rule mẫu cho multi-window burn rate

Giả sử SLO availability là 99.9%, error budget ratio là `0.001`.

Fast burn: kiểm tra cả 1h và 5m:

```promql
(
  sum(rate(http_requests_total{status=~"5.."}[1h]))
  /
  sum(rate(http_requests_total[1h]))
) / 0.001 > 14.4
and
(
  sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))
) / 0.001 > 14.4
```

Slow burn: kiểm tra cả 6h và 30m:

```promql
(
  sum(rate(http_requests_total{status=~"5.."}[6h]))
  /
  sum(rate(http_requests_total[6h]))
) / 0.001 > 6
and
(
  sum(rate(http_requests_total{status=~"5.."}[30m]))
  /
  sum(rate(http_requests_total[30m]))
) / 0.001 > 6
```

Trong lab, metric name có thể khác tùy ứng dụng hoặc exporter. Quan trọng là hiểu công thức:

```text
burn rate = actual error ratio / allowed error ratio
```

## Cấu trúc thư mục D2

Toàn bộ bài D2 đặt trong `cloud/w9/tue/`, bao gồm ghi chú, cấu hình observability, alert rules, dashboard và ảnh bằng chứng:

```text
cloud/w9/tue/
+-- observability-slo-otel.md
+-- NOTES.md
+-- imgs/
|   +-- prometheus-targets.png
|   +-- grafana-dashboard.png
|   +-- loki-logs.png
|   +-- alert-rules.png
|   +-- burn-rate-query.png
+-- otel/
|   +-- collector-config.yaml
+-- dashboards/
|   +-- demo-web-dashboard.json
+-- alert-rules/
    +-- demo-web-slo-rules.yaml
```

Thư mục `imgs/` dùng để lưu toàn bộ ảnh bằng chứng của ngày D2. Không để ảnh rải ở thư mục khác để khi nộp bài chỉ cần mở `cloud/w9/tue/` là thấy đủ nội dung.

## Bài thực hành đề xuất

### Bài 1 - Ghi chú khái niệm observability

Tạo file:

```text
cloud/w9/tue/NOTES.md
```

Trả lời ngắn gọn:

- Observability khác monitoring ở điểm nào?
- Metrics, logs và traces trả lời những câu hỏi gì?
- SLA và SLO khác nhau thế nào?
- Error budget là gì?
- Burn rate dùng để phát hiện vấn đề gì?

### Bài 2 - Vẽ luồng OpenTelemetry

Trong `NOTES.md`, vẽ hoặc mô tả luồng:

```text
App -> OTel SDK -> OTel Collector -> Prometheus/Loki/Grafana
```

Nếu có dùng app từ W8, ghi rõ:

- App chạy namespace nào.
- Metrics endpoint là gì.
- Logs lấy theo label nào.
- Dashboard sẽ theo dõi những panel nào.

### Bài 3 - Tạo cấu hình OpenTelemetry Collector mẫu

Tạo file:

```text
cloud/w9/tue/otel/collector-config.yaml
```

Ví dụ cấu hình tối thiểu:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:

processors:
  batch:

exporters:
  logging:
    verbosity: detailed

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging]
```

Mục tiêu của bài này là hiểu cấu trúc receiver, processor, exporter và pipeline. Chưa bắt buộc phải kết nối backend thật nếu môi trường chưa sẵn sàng.

### Bài 4 - Tạo alert rule SLO mẫu

Tạo file:

```text
cloud/w9/tue/alert-rules/demo-web-slo-rules.yaml
```

Alert rule cần có:

- High error rate 5xx.
- High latency p95 nếu có histogram metric.
- Fast burn alert: 1h và 5m.
- Slow burn alert: 6h và 30m.

Ghi chú rõ metric name đang dùng là giả định hay lấy từ app thật.

### Bài 5 - Thiết kế dashboard Grafana

Tạo file ghi chú hoặc dashboard JSON:

```text
cloud/w9/tue/dashboards/demo-web-dashboard.json
```

Dashboard tối thiểu nên có các panel:

- Request rate.
- Error rate.
- Latency p95.
- CPU/memory pod.
- Logs lỗi gần nhất.
- SLO availability.
- Burn rate.

Nếu chưa export được JSON từ Grafana, ghi layout dashboard trong `NOTES.md` và bổ sung ảnh sau.

### Bài 6 - Lưu evidence vào imgs

Ảnh bằng chứng lưu trong:

```text
cloud/w9/tue/imgs/
```

Tên ảnh gợi ý:

- `prometheus-targets.png`: Prometheus target hoặc query metrics.
- `grafana-dashboard.png`: dashboard Grafana.
- `loki-logs.png`: truy vấn log trong Loki/Grafana Explore.
- `alert-rules.png`: alert rules đã load hoặc file rule.
- `burn-rate-query.png`: PromQL burn rate query.

## Checklist hôm nay

- [ ] Ghi được observability là gì bằng lời của mình.
- [ ] Phân biệt được metrics, logs và traces.
- [ ] Giải thích được SLA, SLO, error budget và burn rate.
- [ ] Vẽ được luồng OpenTelemetry SDK -> Collector -> backend.
- [ ] Viết được PromQL tính request rate và error rate.
- [ ] Biết Loki truy vấn log dựa trên label.
- [ ] Thiết kế được dashboard Grafana tối thiểu cho app.
- [ ] Viết được alert rule cho high error rate.
- [ ] Viết được fast burn alert với window 1h và 5m.
- [ ] Viết được slow burn alert với window 6h và 30m.
- [ ] Lưu evidence vào `cloud/w9/tue/imgs/`.
- [ ] Cập nhật câu hỏi còn vướng cho mentor.

## Evidence cần nộp

Trong `cloud/w9/tue/NOTES.md`, ghi tối thiểu:

- Link hoặc tên commit D2 với message dạng `[W9-D2] <topic ngắn>`.
- Tóm tắt SLA/SLO đã chọn cho app.
- Công thức error budget và burn rate.
- Luồng OpenTelemetry đã vẽ hoặc mô tả.
- PromQL request rate và error rate.
- Nội dung alert rule hoặc link đến `alert-rules/demo-web-slo-rules.yaml`.
- Ảnh Prometheus target/query, lưu trong `cloud/w9/tue/imgs/prometheus-targets.png`.
- Ảnh dashboard Grafana, lưu trong `cloud/w9/tue/imgs/grafana-dashboard.png`.
- Ảnh Loki logs nếu có, lưu trong `cloud/w9/tue/imgs/loki-logs.png`.
- Ảnh burn rate query, lưu trong `cloud/w9/tue/imgs/burn-rate-query.png`.
- Câu hỏi còn vướng cho mentor.

## Câu hỏi ôn tập

1. Observability khác monitoring truyền thống ở điểm nào?
2. Metrics, logs và traces bổ sung cho nhau như thế nào?
3. SLA khác SLO như thế nào?
4. Error budget có ý nghĩa gì trong quyết định deploy?
5. Burn rate cao nói lên điều gì?
6. Vì sao multi-window burn rate alert tốt hơn alert một window?
7. OpenTelemetry SDK và Collector khác nhau thế nào?
8. Prometheus scrape metrics theo cơ chế nào?
9. Grafana dashboard tốt cần trả lời những câu hỏi vận hành nào?
10. Loki dùng label để truy vấn logs có lợi ích gì?
