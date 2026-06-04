# Bài học Kubernetes cho sinh viên

Tài liệu này dùng cho buổi học Kubernetes cơ bản, dựa trên nội dung `k8s-part1-foundations.html` và 3 bài lab trong tuần 8:

- Lab 1: Kubernetes foundations, Pod, Deployment, ConfigMap, Secret.
- Lab 2: Scaling và Networking.
- Lab 3: Mini K8s Platform trên minikube.

## 1. Kubernetes là gì?

Kubernetes, thường viết tắt là K8s, là một hệ thống mã nguồn mở dùng để quản lý và điều phối container trên một cụm máy chủ.

Nếu Docker giúp đóng gói ứng dụng thành container để chạy ổn định ở nhiều môi trường, thì Kubernetes giúp vận hành nhiều container trong thực tế: chạy ở đâu, scale thế nào, tự phục hồi ra sao, expose ra ngoài bằng cách nào, và cập nhật phiên bản mới có an toàn không.

Nói ngắn gọn:

- Docker trả lời câu hỏi: "Làm sao đóng gói và chạy một container?"
- Kubernetes trả lời câu hỏi: "Làm sao vận hành nhiều container ổn định trên nhiều máy?"

## 2. Vì sao cần Kubernetes?

Khi chỉ có một vài container, ta có thể tự chạy bằng `docker run`. Nhưng trong môi trường thật, hệ thống thường có nhiều service, nhiều bản sao, nhiều máy chủ và nhiều lần cập nhật.

Kubernetes giải quyết các vấn đề chính:

- Tự khởi động lại container khi container lỗi.
- Tự duy trì số lượng bản sao mong muốn của ứng dụng.
- Scale ứng dụng khi cần nhiều replica hơn.
- Cung cấp địa chỉ truy cập ổn định cho các Pod có IP thay đổi liên tục.
- Hỗ trợ rolling update và rollback khi deploy phiên bản mới.
- Tách cấu hình khỏi image bằng ConfigMap và Secret.
- Theo dõi trạng thái workload qua lệnh `kubectl`.

Ví dụ: ta khai báo "ứng dụng web phải luôn có 3 replica". Nếu một Pod bị xóa hoặc lỗi, Kubernetes sẽ tự tạo Pod mới để đưa hệ thống về đúng trạng thái mong muốn.

## 3. Tư duy cốt lõi: Desired State

Kubernetes hoạt động theo mô hình declarative, nghĩa là người dùng mô tả trạng thái mong muốn, còn Kubernetes tự tìm cách đạt tới trạng thái đó.

Vòng lặp hoạt động cơ bản:

1. Declare: người dùng khai báo trạng thái mong muốn bằng YAML hoặc lệnh `kubectl`.
2. Observe: Kubernetes quan sát trạng thái thực tế của cluster.
3. Diff: Kubernetes so sánh trạng thái thực tế với trạng thái mong muốn.
4. Reconcile: Kubernetes thực hiện hành động để đưa hệ thống về đúng trạng thái mong muốn.

Ví dụ:

```yaml
replicas: 3
```

Dòng này có nghĩa là ta muốn luôn có 3 Pod đang chạy. Nếu thực tế chỉ còn 2 Pod, Kubernetes sẽ tự tạo thêm 1 Pod.

## 4. Kiến trúc Kubernetes

Một cluster Kubernetes gồm hai nhóm chính: Control Plane và Worker Node.

### 4.1. Control Plane

Control Plane là phần điều khiển của cluster. Nó không trực tiếp chạy ứng dụng của sinh viên, mà chịu trách nhiệm quản lý trạng thái toàn hệ thống.

Các thành phần chính:

- `kube-apiserver`: cổng giao tiếp trung tâm của Kubernetes. `kubectl` gửi lệnh đến đây.
- `etcd`: nơi lưu trạng thái của cluster.
- `scheduler`: quyết định Pod sẽ chạy trên node nào.
- `controller-manager`: chạy các control loop để duy trì desired state.

### 4.2. Worker Node

Worker Node là nơi container thật sự chạy.

Các thành phần chính:

- `kubelet`: agent trên node, nhận lệnh từ API server và đảm bảo Pod được chạy.
- `container runtime`: thành phần chạy container, ví dụ containerd.
- `kube-proxy`: xử lý networking cơ bản cho Service.

Trong lab, sinh viên dùng minikube, nên control plane và worker thường nằm chung trên một node local.

## 5. Các object cơ bản trong Kubernetes

### 5.1. Pod

Pod là đơn vị nhỏ nhất có thể deploy trong Kubernetes. Một Pod có thể chứa một hoặc nhiều container, dùng chung network và storage.

Điểm cần nhớ:

- Pod có IP riêng.
- Pod có tính tạm thời, có thể bị xóa và tạo lại.
- Không nên chạy Pod trần trong production vì nếu Pod bị xóa, không có object nào tự tạo lại nó.

Lệnh minh họa:

```bash
kubectl run hello --image=nginx:1.27 --port=80
kubectl get pods -o wide
kubectl describe pod hello
kubectl delete pod hello
```

### 5.2. Deployment

Deployment dùng để quản lý nhiều bản sao của ứng dụng. Deployment tạo ReplicaSet, ReplicaSet tạo và duy trì các Pod.

Deployment giúp:

- Chạy nhiều replica.
- Tự phục hồi khi Pod lỗi.
- Scale số lượng Pod.
- Rolling update khi đổi image.
- Rollback khi bản deploy mới có vấn đề.

Ví dụ manifest:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: nginx:1.27
```

Lệnh triển khai:

```bash
kubectl apply -f web.yaml
kubectl get deploy,rs,pods
```

### 5.3. Label và Selector

Label là cặp key-value dùng để đánh dấu object. Selector dùng để chọn object dựa trên label.

Ví dụ:

```bash
kubectl get pods --show-labels
kubectl get pods -l app=web
kubectl logs -l app=web --tail=3
```

Trong Kubernetes, Service, Deployment và nhiều object khác dùng label/selector để tìm đúng Pod cần quản lý hoặc expose.

### 5.4. Service

Pod có IP thay đổi, nên không nên gọi trực tiếp vào IP của Pod. Service cung cấp một endpoint ổn định để truy cập nhóm Pod.

Các loại Service cơ bản:

- `ClusterIP`: chỉ truy cập nội bộ trong cluster.
- `NodePort`: expose qua port của node, phù hợp lab/dev.
- `LoadBalancer`: dùng trên cloud provider để tạo load balancer thật.

Ví dụ Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
```

### 5.5. ConfigMap và Secret

ConfigMap dùng để lưu cấu hình không nhạy cảm, ví dụ `APP_ENV`, `LOG_LEVEL`.

Secret dùng để lưu dữ liệu nhạy cảm hơn, ví dụ password, token, API key. Cần lưu ý Secret mặc định chỉ được encode base64, không phải mã hóa tuyệt đối.

Ví dụ:

```bash
kubectl create configmap app-cfg --from-literal=APP_ENV=production
kubectl create secret generic app-sec --from-literal=DB_PASSWORD=s3cr3t
kubectl set env deploy/web --from=configmap/app-cfg
kubectl set env deploy/web --from=secret/app-sec
```

## 6. Các thao tác Kubernetes sinh viên cần nắm

### 6.1. Xem trạng thái

```bash
kubectl get nodes
kubectl get pods
kubectl get pods -o wide
kubectl get deploy,rs,pods
kubectl get svc
```

### 6.2. Xem chi tiết và debug

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl logs -f <pod-name>
kubectl exec -it <pod-name> -- sh
```

Thứ tự debug nên dùng:

1. `kubectl get`: xem object có tồn tại và trạng thái hiện tại.
2. `kubectl describe`: xem Events và lý do lỗi.
3. `kubectl logs`: xem log của container.
4. `kubectl exec`: vào trong container để kiểm tra khi cần.

### 6.3. Deploy và cập nhật

```bash
kubectl apply -f app.yaml
kubectl scale deploy/web --replicas=5
kubectl set image deployment/web web=nginx:1.28
kubectl rollout status deployment/web
kubectl rollout undo deployment/web
```

## 7. Lab 1: Kubernetes Foundations

### Mục tiêu

Sinh viên hiểu cách dựng cluster local, tạo Pod, tạo Deployment, dùng label và thấy self-healing hoạt động.

### Nội dung chính

- Cài hoặc kiểm tra `kubectl`, Docker, minikube.
- Khởi động cluster local bằng minikube.
- Tạo Pod nginx đơn giản.
- Xóa Pod trần và quan sát Pod mất hẳn.
- Tạo Deployment có 3 replica.
- Xóa một Pod thuộc Deployment và quan sát Kubernetes tự tạo Pod mới.
- Tạo ConfigMap và Secret, inject vào Deployment qua environment variable.

### Lệnh chính

```bash
minikube start
kubectl get nodes
kubectl cluster-info

kubectl run hello --image=nginx:1.27 --port=80
kubectl get pods -o wide
kubectl delete pod hello

kubectl apply -f web.yaml
kubectl get deploy,rs,pods
kubectl delete pod <pod-name>
kubectl get pods -w
```

### Kết quả cần đạt

- Node ở trạng thái `Ready`.
- Sinh viên giải thích được sự khác nhau giữa Pod trần và Pod được quản lý bởi Deployment.
- Sinh viên thấy được self-healing: xóa Pod nhưng Deployment tự tạo lại Pod mới.
- Sinh viên biết dùng `get`, `describe`, `logs`, `exec` ở mức cơ bản.

## 8. Lab 2: Scaling và Networking

### Mục tiêu

Sinh viên biết scale Deployment, expose ứng dụng bằng Service và kiểm tra endpoint.

### Nội dung chính

- Tạo Deployment chạy ứng dụng mẫu.
- Tạo Service để expose Deployment.
- Scale số replica.
- Kiểm tra Service, Endpoint và Pod được chọn bởi selector.
- Thử rolling update hoặc rollback.

### Lệnh chính

```bash
kubectl apply -f deployment-svc.yaml
kubectl get pods,svc -o wide
kubectl scale deployment/web --replicas=4
kubectl get endpoints
kubectl logs -l app=web --tail=5
kubectl rollout status deployment/web
kubectl rollout undo deployment/web
```

Với minikube:

```bash
minikube service web-svc --url
```

### Kết quả cần đạt

- Sinh viên hiểu Service không chạy app, mà route traffic đến Pod phù hợp qua selector.
- Sinh viên scale được Deployment và quan sát số Pod tăng/giảm.
- Sinh viên kiểm tra được app đã expose qua Service.
- Sinh viên hiểu rolling update là cách cập nhật dần, hạn chế downtime.

## 9. Lab 3: Mini K8s Platform trên minikube

### Mục tiêu

Sinh viên tổng hợp kiến thức để dựng một nền tảng Kubernetes tối thiểu trên minikube.

### Thành phần cần có

- Namespace riêng cho lab.
- Deployment chạy ứng dụng mẫu.
- Service expose workload.
- ConfigMap hoặc Secret nếu ứng dụng cần cấu hình.
- Probe để kiểm tra health nếu có thời gian.
- Ghi chú show-and-tell cho nhóm.

### Các bước thực hiện

1. Tạo namespace riêng.
2. Deploy ứng dụng mẫu bằng Deployment.
3. Expose ứng dụng bằng Service.
4. Kiểm tra Pod, Service, logs, describe và events.
5. Scale workload.
6. Chuẩn bị phần trình bày ngắn: kiến trúc, manifest, lệnh đã dùng, kết quả chạy.

### Lệnh chính

```bash
kubectl create namespace mini-platform
kubectl apply -n mini-platform -f deployment.yaml
kubectl apply -n mini-platform -f service.yaml
kubectl get all -n mini-platform
kubectl describe pod -n mini-platform <pod-name>
kubectl logs -n mini-platform <pod-name>
kubectl scale deployment/web -n mini-platform --replicas=3
```

### Kết quả cần đạt

- Có namespace riêng.
- Có ứng dụng chạy bằng Deployment.
- Có Service expose ứng dụng.
- Có bằng chứng kiểm tra: `kubectl get`, logs, describe, URL hoặc endpoint.
- Nhóm sinh viên trình bày được ứng dụng đang chạy thế nào và Kubernetes đang quản lý phần nào.

## 10. Hoạt động trên lớp

### Hoạt động 1: So sánh Docker và Kubernetes

Giảng viên đặt câu hỏi:

- Nếu container bị chết lúc nửa đêm thì ai khởi động lại?
- Nếu traffic tăng thì scale bằng cách nào?
- Nếu IP container thay đổi thì service khác gọi đến đâu?

Sinh viên trả lời và liên hệ đến các chức năng của Kubernetes: self-healing, scaling, service discovery.

### Hoạt động 2: Vẽ kiến trúc cluster

Sinh viên vẽ sơ đồ gồm:

- Control Plane.
- Worker Node.
- Pod.
- Deployment.
- Service.
- Luồng lệnh từ `kubectl` đến `kube-apiserver`.

### Hoạt động 3: Debug nhanh

Giảng viên đưa một Pod lỗi hoặc image sai. Sinh viên dùng:

```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

Mục tiêu là tìm được lỗi qua Events hoặc logs.

### Hoạt động 4: Show-and-tell cuối buổi

Mỗi nhóm trình bày trong 3-5 phút:

- Ứng dụng nhóm deploy là gì?
- Có những object Kubernetes nào?
- Service expose app như thế nào?
- Nhóm đã scale hoặc debug ra sao?
- Một vấn đề gặp phải và cách xử lý.

## 11. Câu hỏi ôn tập

1. Kubernetes giải quyết vấn đề gì mà Docker một mình chưa đủ?
2. Desired state là gì?
3. Pod khác Deployment như thế nào?
4. Vì sao không nên truy cập trực tiếp IP của Pod?
5. Service dùng selector để làm gì?
6. ConfigMap khác Secret như thế nào?
7. Khi Pod bị lỗi, nên dùng những lệnh nào để debug?
8. Self-healing trong Kubernetes hoạt động ra sao?
9. Scale Deployment bằng lệnh nào?
10. Rolling update giúp ích gì khi deploy phiên bản mới?

## 12. Checklist đánh giá sinh viên

- [ ] Khởi động được minikube và kiểm tra node `Ready`.
- [ ] Tạo được Pod và Deployment.
- [ ] Giải thích được Pod trần không tự phục hồi.
- [ ] Scale được Deployment.
- [ ] Expose được ứng dụng bằng Service.
- [ ] Dùng được ConfigMap hoặc Secret ở mức cơ bản.
- [ ] Biết debug bằng `get`, `describe`, `logs`.
- [ ] Hoàn thành Mini K8s Platform và có evidence rõ ràng.

## 13. Sản phẩm nộp cuối buổi

Mỗi nhóm nộp một thư mục gồm:

```text
k8s-mini-platform/
+-- namespace.yaml
+-- deployment.yaml
+-- service.yaml
+-- configmap.yaml
+-- NOTE.md
```

File `NOTE.md` cần có:

- Tên nhóm và thành viên.
- Mô tả ngắn ứng dụng.
- Các lệnh `kubectl` đã dùng.
- Kết quả kiểm tra.
- Vấn đề gặp phải và cách xử lý.
