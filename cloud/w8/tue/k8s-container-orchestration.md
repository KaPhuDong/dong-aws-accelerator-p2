# W8 Day B - Kubernetes: Container Orchestration

Ngày học: T2 02/06/2026
Chủ đề: Kubernetes container orchestration cơ bản + thực hành trên Minikube / Docker Desktop

## Mục tiêu hôm nay

- Hiểu nhanh Kubernetes là gì và vì sao dùng K8s để orchestration container.
- Nắm kiến trúc control plane vs node và các thành phần chính (`kube-apiserver`, `kubelet`, `etcd`).
- Viết và deploy manifest YAML: Pod, Deployment, Service, ConfigMap, Secret, PVC.
- Thực hành scaling, rolling update, health checks và debug cơ bản với `kubectl`.

## Nguồn học hôm nay

### Bắt buộc

1. Kubernetes official docs - Concepts: https://kubernetes.io/docs/concepts/
2. Kubernetes docs - Tasks: https://kubernetes.io/docs/tasks/
3. Minikube quickstart: https://minikube.sigs.k8s.io/docs/start/
4. kubectl reference: https://kubernetes.io/docs/reference/kubectl/

### Đọc thêm

1. Kubernetes by Example: https://kubernetesbyexample.com/
2. Kelsey Hightower - Kubernetes The Hard Way (tham khảo ý tưởng)
3. NGINX Ingress Controller docs (Ingress overview)

## Kế hoạch học ~6 giờ

| Thời lượng | Nội dung                                       | Output cần có                             |
| ---------: | ---------------------------------------------- | ----------------------------------------- |
|    30 phút | Giới thiệu & kiến trúc tổng quan               | Ghi chú khái niệm                         |
|    45 phút | Objects cơ bản (Pod, Deployment, Service)      | Hiểu khi nào dùng từng object             |
|    60 phút | Lab 1–2: Deploy nginx, Service, scale          | Manifest `deployment.yaml` + truy cập app |
|    60 phút | Lab 3: ConfigMap, Secret, env/volume           | Manifest dùng ConfigMap/Secret            |
|    45 phút | Lab 4: PVC và storage                          | PVC + Pod mount test                      |
|    45 phút | Health checks, rolling update, troubleshooting | Rolling update demo + debug log           |
|    60 phút | Tổng hợp, Q&A, bài tập về nhà                  | Nộp manifest và short note                |

## Ghi chú bài học (tóm tắt chi tiết)

1. Giới thiệu Kubernetes

   - Kubernetes: hệ thống open-source để quản lý container trên cluster.
   - Lợi ích chính: scaling, self-healing, service discovery, declarative config.

2. Kiến trúc tổng quan

   - Control plane vs Node: roles và components.
   - Namespace, labels, annotations: cách tổ chức và chọn đối tượng.

3. Objects cơ bản (ví dụ, khi nào dùng)

   - Pod: chạy 1–n container cùng share network/storage.
   - Deployment: dùng để rollout, rollback, scaling replica.
   - Service: làm stable network endpoint cho Pods.
   - StatefulSet / DaemonSet / Job: dùng cho workload có trạng thái, daemon, hoặc batch.

4. Networking & Expose

   - `ClusterIP` (internal), `NodePort` (dev/test), `LoadBalancer` (cloud).
   - `Ingress` để route HTTP(S).

5. Storage

   - Volumes, PV/PVC, StorageClass; PVC request, PV bind.

6. Config & Secrets

   - ConfigMap để cấu hình; Secret để lưu thông tin nhạy cảm.

7. Health checks

   - `livenessProbe`, `readinessProbe`, `startupProbe` và ví dụ ngắn.

8. Troubleshooting
   - Dùng `kubectl describe pod`, `kubectl logs`, `kubectl exec -it`.

## Ví dụ manifest tối thiểu (Deployment + Service)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
   name: nginx-deploy
spec:
   replicas: 2
   selector:
      matchLabels:
         app: nginx
   template:
      metadata:
         labels:
            app: nginx
      spec:
         containers:
         - name: nginx
            image: nginx:1.25
            ports:
            - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
   name: nginx-svc
spec:
   type: NodePort
   selector:
      app: nginx
   ports:
   - port: 80
      targetPort: 80
      nodePort: 30080
```

Sử dụng các lệnh:

```bash
kubectl apply -f deployment-svc.yaml
kubectl get pods,svc -o wide
minikube service nginx-svc --url   # hoặc truy cập http://<minikube-ip>:30080
kubectl scale deployment/nginx-deploy --replicas=4
kubectl rollout status deployment/nginx-deploy
kubectl set image deployment/nginx-deploy nginx=nginx:1.26 --record
kubectl rollout undo deployment/nginx-deploy
```

## Hoạt động/Thực hành (labs)

- Lab 0 — Chuẩn bị môi trường
  - Cài `kubectl`, `minikube` hoặc Docker Desktop (k8s enabled).
  - Kiểm tra:

```bash
kubectl version --client
minikube start --driver=docker
kubectl cluster-info
```

- Lab 1 — Deploy nginx (Pod → Deployment)

  - Viết `deployment-svc.yaml` (ví dụ ở trên), `kubectl apply -f`.
  - Scale replicas, xem events, logs.

- Lab 2 — Expose & Ingress

  - Thử `NodePort` rồi cấu hình `Ingress` (nginx-ingress) nếu time cho phép.

- Lab 3 — ConfigMap & Secret
  - Tạo ConfigMap:

```bash
kubectl create configmap app-config --from-literal=GREETING="Hello from ConfigMap"
kubectl create secret generic db-creds --from-literal=username=admin --from-literal=password=pass
```

- Mount vào Pod bằng `envFrom` hoặc volume.

- Lab 4 — Storage cơ bản (PVC)

  - Tạo PVC, mount vào Pod, viết file vào volume, restart Pod và verify dữ liệu tồn tại.

- Lab 5 — Health checks & rolling update

  - Thêm `readinessProbe`/`livenessProbe` vào `deployment` và thử cập nhật image.

- Lab 6 — Troubleshooting challenge
  - Bài tập: cung cấp một manifest có lỗi và yêu cầu debug (CrashLoopBackOff, missing env, wrong image).

## Bài tập về nhà / Đánh giá

- Yêu cầu: Tạo ứng dụng nhỏ (ví dụ: web app trả về tên Pod) và deploy bằng Deployment + Service.
- Phải sử dụng: ConfigMap cho cấu hình, PVC cho lưu trữ tạm, và cung cấp manifest đầy đủ.
- Nộp: thư mục chứa manifest và một file `NOTE.md` (2–3 câu) giải thích các phần chính.

Thư mục gợi ý:

```
cloud/w8/tue/k8s-labs/
├── lab1-deployment-svc/
│   └── deployment-svc.yaml
├── lab2-config-secret/
│   ├── configmap.yaml
│   └── secret.yaml
└── lab3-pvc/
      └── pvc-pod.yaml
```

## Checklist thực hành

- [ ] Cài `kubectl`, `minikube`/Docker Desktop.
- [ ] Khởi động cluster: `minikube start`.
- [ ] Triển khai `deployment-svc.yaml`.
- [ ] Chứng minh app truy cập được (URL hoặc NodePort).
- [ ] Nộp manifest và `NOTE.md`.

## Evidence (ghi nhận khi thực hành)

- `kubectl version --client`:
- `minikube version` / Docker Desktop k8s info:
- Manifest đã thử: (đường dẫn trong repo)
- Lệnh kiểm tra đã chạy: ví dụ `kubectl get pods -o wide`.
- Vấn đề gặp phải và cách giải quyết (ngắn gọn).

## Tài liệu tham khảo & đọc thêm

- Kubernetes docs: https://kubernetes.io/docs/
- Minikube docs: https://minikube.sigs.k8s.io/docs/
- kubectl reference: https://kubernetes.io/docs/reference/kubectl/

---

Ghi chú: Tôi đã cấu trúc lại file theo phong cách `terraform-iac-overview-hcl.md` — nếu bạn muốn, tôi sẽ tách từng lab thành các file manifest riêng và thêm hướng dẫn từng bước cho sinh viên.
