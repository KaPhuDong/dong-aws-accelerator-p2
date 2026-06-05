# Portfolio K8s Challenge - Presentation Notes

Tài liệu này dùng để chuẩn bị thuyết trình và trả lời hỏi đáp với mentor về lab `portfolio-k8s-challenge`.

## 1. Mục tiêu bài lab

Mục tiêu chính là dùng Terraform để tự động dựng một môi trường chạy ứng dụng portfolio trong Kubernetes trên AWS.

Kết quả sau khi chạy:

- Terraform tạo hạ tầng AWS gồm EC2, Security Group, ALB, Target Group, Listener và Key Pair.
- EC2 tự cài Docker, kubectl, minikube.
- Minikube chạy bên trong EC2 bằng Docker driver.
- Ứng dụng portfolio static được build thành Docker image nginx.
- Image được load vào minikube và deploy bằng Kubernetes Deployment + Service.
- Người dùng truy cập website qua DNS của ALB.

Điểm quan trọng khi trình bày: app không được cài trực tiếp lên EC2. EC2 chỉ là máy host để chạy Docker và minikube. App thật sự chạy trong Pod Kubernetes.

## 2. Luồng triển khai tổng thể

```text
User
  |
  | terraform apply
  v
Terraform
  |
  | tạo AWS infra + SSH key
  v
EC2 Ubuntu
  |
  | remote-exec cài Docker, kubectl, minikube
  v
minikube cluster
  |
  | kubectl apply
  v
Deployment portfolio -> 3 Pods nginx
  |
  v
Service NodePort 30080
  |
  v
ALB Target Group -> ALB Listener :80
  |
  v
Browser truy cập ALB URL
```

Luồng traffic khi website chạy:

```text
Browser -> ALB port 80 -> Target Group -> EC2 port 30080 -> K8s NodePort -> Pod nginx port 80
```

## 3. Vì sao chọn kiến trúc này?

### Terraform

Terraform được dùng để biến toàn bộ hạ tầng thành code. Thay vì tạo EC2, Security Group, ALB bằng tay trên AWS Console, mình mô tả tất cả trong `.tf` file. Lợi ích là dễ tái tạo, dễ review, dễ destroy và phù hợp yêu cầu "1-click automation".

### Default VPC và Default Subnets

Lab dùng `data "aws_vpc" "default"` và `data "aws_subnets" "default"` để lấy VPC/Subnet có sẵn trong AWS account.

Ý nghĩa:

- Rút ngắn thời gian làm lab.
- Không cần tự viết VPC, route table, internet gateway.
- Tập trung vào mục tiêu chính là Terraform + EC2 + minikube + Kubernetes + ALB.

Trade-off:

- Dùng default VPC phù hợp lab/demo.
- Với production nên tự thiết kế VPC, subnet public/private, NAT Gateway, routing và security boundary rõ hơn.

### EC2 + minikube

Minikube được chạy trên EC2 bằng Docker driver:

```bash
minikube start --driver=docker --cpus=2 --memory=1800mb --ports=30080:30080
```

Ý nghĩa:

- EC2 là môi trường Linux thật trên AWS.
- Docker là runtime để minikube tạo Kubernetes node.
- `--ports=30080:30080` giúp expose NodePort từ minikube ra host EC2, để ALB có thể forward traffic vào.

### ALB

ALB đứng phía trước EC2 để expose app ra Internet qua HTTP port 80.

Ý nghĩa:

- Người dùng không truy cập trực tiếp EC2 NodePort.
- EC2 Security Group chỉ cho ALB gọi vào port 30080.
- ALB có health check để kiểm tra app còn sống hay không.

## 4. Giải thích từng file quan trọng

## `main.tf`

Đây là file chính, chứa phần lớn cấu hình hạ tầng và automation.

### `terraform.required_providers`

Khai báo các provider cần dùng:

- `aws`: tạo hạ tầng AWS như EC2, Security Group, ALB.
- `tls`: sinh SSH key pair tự động.
- `local`: ghi private key `.pem` xuống máy local.
- `http`: gọi API lấy public IP hiện tại.

Điểm để nói với mentor: bài lab dùng nhiều hơn 2 provider và các provider có liên kết thật với nhau, không phải khai báo cho có.

### `provider "aws"`

```hcl
provider "aws" {
  region = var.aws_region
}
```

Ý nghĩa: Terraform deploy toàn bộ resource vào region được cấu hình trong biến `aws_region`, mặc định là `ap-southeast-1`.

### `data "http" "public_ip"` và `locals.ssh_allowed_cidr`

```hcl
data "http" "public_ip" {
  url = "https://api.ipify.org"
}

locals {
  ssh_allowed_cidr = var.ssh_allowed_cidr != "" ? var.ssh_allowed_cidr : "${chomp(data.http.public_ip.response_body)}/32"
}
```

Ý nghĩa:

- Terraform tự lấy public IP của máy đang chạy lệnh.
- Nếu `ssh_allowed_cidr` để trống, Security Group SSH sẽ mở đúng IP đó dạng `/32`.
- Người clone repo không cần sửa IP thủ công trong `terraform.tfvars`.
- Nếu cần override, vẫn có thể truyền `ssh_allowed_cidr = "x.x.x.x/32"`.

Điểm bảo mật: không mở SSH `0.0.0.0/0`, chỉ mở cho public IP hiện tại.

### `data "aws_vpc"`, `data "aws_subnets"`, `data "aws_ami"`

Các data source này không tạo resource mới, mà truy vấn resource/thông tin có sẵn:

- Default VPC.
- Các subnet trong default VPC.
- Ubuntu 22.04 AMI mới nhất từ Canonical.

Ý nghĩa:

- Không hard-code VPC ID, Subnet ID, AMI ID.
- Code dễ chạy ở account khác trong cùng region.
- AMI luôn lấy bản Ubuntu Jammy mới nhất phù hợp filter.

### `tls_private_key`, `aws_key_pair`, `local_file`

Ba resource này tạo SSH key tự động:

- `tls_private_key.ssh`: sinh private/public key RSA 4096 bit.
- `aws_key_pair.generated`: import public key lên AWS EC2 Key Pair.
- `local_file.private_key`: lưu private key thành file `.pem` để SSH debug.

Ý nghĩa:

- Không cần tạo key pair thủ công trên AWS Console.
- Không cần commit private key vào repo.
- Terraform có thể dùng key này trong `connection` block để SSH vào EC2 chạy provisioner.

### `aws_security_group.alb`

Security Group cho ALB:

- Ingress: cho Internet vào port 80.
- Egress: cho ALB forward traffic đến EC2 NodePort.

Ý nghĩa: ALB là entrypoint public duy nhất cho website.

### `aws_security_group.ec2`

Security Group cho EC2:

- Cho ALB Security Group vào port `node_port`, mặc định `30080`.
- Cho SSH port 22 từ `local.ssh_allowed_cidr`.
- Cho outbound Internet để EC2 tải package, Docker, kubectl, minikube.

Điểm quan trọng: port 30080 không mở public trực tiếp. Chỉ ALB được gọi vào port này.

### `aws_lb`, `aws_lb_target_group`, `aws_lb_listener`

Ba resource này tạo Application Load Balancer:

- `aws_lb.app`: ALB public.
- `aws_lb_target_group.app`: Target Group trỏ tới EC2 instance trên port 30080.
- `aws_lb_listener.http`: Listener port 80 forward request vào Target Group.

Health check dùng path `/`, matcher `200-399`.

Ý nghĩa: khi Pod nginx trả HTTP 200, ALB xem target là healthy và cho traffic đi qua.

### `aws_instance.k8s`

Đây là EC2 instance chạy Docker + minikube.

Cấu hình đáng chú ý:

- AMI: Ubuntu 22.04.
- Instance type: mặc định `t3.small`.
- Disk: 20GB gp3.
- Public IP: bật để Terraform SSH vào máy.
- Key pair: dùng key do Terraform tự sinh.

### `connection`

```hcl
connection {
  type        = "ssh"
  user        = "ubuntu"
  host        = self.public_ip
  private_key = tls_private_key.ssh.private_key_pem
  timeout     = "10m"
}
```

Ý nghĩa: Terraform dùng SSH để kết nối EC2 và chạy các provisioner. Private key lấy trực tiếp từ resource `tls_private_key`, không cần user nhập file key.

### `provisioner "file"`

Copy source từ máy local lên EC2:

- `k8s-manifests/` -> `/home/ubuntu/k8s-manifests`
- `frontend/` -> `/home/ubuntu/frontend`

Ý nghĩa: Terraform không chỉ tạo infra mà còn đưa manifest và source app lên server để deploy.

### `provisioner "remote-exec"`

Đây là phần automation chính trên EC2.

Các bước script thực hiện:

1. Cài package cơ bản.
2. Cài Docker Engine.
3. Add user `ubuntu` vào group `docker`.
4. Cài `kubectl`.
5. Cài `minikube`.
6. Start minikube bằng Docker driver.
7. Build Docker image từ folder `frontend`.
8. Load image vào minikube.
9. Apply Kubernetes manifests.
10. Chờ Deployment rollout thành công.
11. Curl thử NodePort local để kiểm tra app phản hồi.

Điểm để trả lời mentor: provisioner phù hợp với lab automation nhanh. Trong production, thường tách phần bootstrap bằng cloud-init, image baking, CI/CD hoặc configuration management thay vì phụ thuộc quá nhiều vào remote-exec.

### `aws_lb_target_group_attachment.ec2`

Resource này đăng ký EC2 instance vào Target Group của ALB.

Ý nghĩa:

- ALB biết phải forward traffic đến instance nào.
- Port forward là `var.node_port`, mặc định `30080`.

## `variables.tf`

File này khai báo biến để cấu hình linh hoạt.

### `aws_region`

Region AWS để deploy. Default: `ap-southeast-1`.

### `project_name`

Prefix dùng để đặt tên resource AWS. Giúp dễ nhận diện resource thuộc lab nào.

### `instance_type`

Loại EC2. Default `t3.small`.

Lý do không dùng `t2.micro`: Docker + minikube cần RAM/CPU nhiều hơn. `t2.micro` dễ treo khi start cluster hoặc build image.

### `ssh_allowed_cidr`

Default là chuỗi rỗng.

Ý nghĩa:

- Để trống: tự detect public IP.
- Có giá trị: dùng CIDR user truyền vào.

### `node_port`

Port cố định để expose Kubernetes Service. Default `30080`.

Có validation:

```hcl
condition = var.node_port >= 30000 && var.node_port <= 32767
```

Ý nghĩa: Kubernetes NodePort hợp lệ chỉ nằm trong range `30000-32767`.

### `minikube_memory_mb`

RAM cấp cho minikube. Default `1800`.

Lý do: trước đó minikube báo lỗi memory nếu cấp thấp hơn minimum usable. Giá trị 1800MB phù hợp hơn cho `t3.small`.

## `outputs.tf`

File này in ra thông tin cần dùng sau khi `terraform apply`.

### `alb_url`

URL chính để mở website:

```text
http://<alb_dns_name>
```

### `alb_dns_name`

DNS gốc của ALB. Có thể dùng khi debug hoặc kiểm tra AWS console.

### `ec2_public_ip`

Public IP của EC2, dùng khi cần SSH debug.

### `ssh_private_key_path`

Đường dẫn file `.pem` do Terraform tạo.

### `ssh_command`

Lệnh SSH đầy đủ:

```bash
ssh -i <pem_path> ubuntu@<ec2_public_ip>
```

Ý nghĩa: mentor hoặc người review có thể dùng output này để SSH vào EC2 kiểm tra Docker, minikube, kubectl nếu cần.

## `k8s-manifests/deployment.yaml`

Deployment định nghĩa workload chạy portfolio.

Các điểm chính:

- `replicas: 3`: chạy 3 Pod để thể hiện khả năng scale cơ bản.
- `selector.matchLabels.app = portfolio`: Deployment quản lý các Pod có label này.
- `image: xbrain-portfolio:latest`: image được build trên EC2 rồi load vào minikube.
- `imagePullPolicy: Never`: Kubernetes không pull image từ Docker Hub, chỉ dùng image local trong minikube.
- `containerPort: 80`: nginx phục vụ website trên port 80.

### Readiness probe

Readiness probe kiểm tra Pod đã sẵn sàng nhận traffic chưa.

Nếu readiness fail, Service sẽ không route traffic tới Pod đó.

### Liveness probe

Liveness probe kiểm tra container còn sống không.

Nếu liveness fail, Kubernetes restart container.

Điểm để trình bày: probe giúp app ổn định hơn so với chỉ chạy container đơn giản.

## `k8s-manifests/service.yaml`

Service expose Deployment ra NodePort.

Các điểm chính:

- `type: NodePort`: mở port trên Kubernetes node.
- `selector.app = portfolio`: Service tìm đúng Pod của Deployment.
- `port: 80`: port service bên trong cluster.
- `targetPort: 80`: port container nginx.
- `nodePort: 30080`: port cố định để ALB target tới.

Lý do chọn NodePort cố định: Target Group của ALB cần biết port cụ thể để forward traffic.

## `frontend/Dockerfile`

```dockerfile
FROM nginx:1.27-alpine

COPY . /usr/share/nginx/html/
```

Ý nghĩa:

- Dùng nginx alpine nhẹ để serve static portfolio.
- Copy toàn bộ HTML/CSS/JS/assets vào thư mục web root của nginx.
- Không cần backend runtime, phù hợp static landing portfolio.

## `frontend/`

Đây là source website portfolio.

Các phần chính:

- `index.html`: nội dung trang portfolio.
- `assets/css`: style của theme đã custom.
- `assets/js`: JavaScript cho hiệu ứng/UI.
- `assets/img`: ảnh profile, portfolio, favicon.
- `assets/vendor`: thư viện frontend đi kèm theme.

Trong bài lab, frontend được Docker build thành image và chạy trong Pod Kubernetes.

## `.gitignore`

```text
.terraform/
*.tfstate
*.tfstate.*
*.pem
```

Ý nghĩa:

- `.terraform/`: thư mục plugin/cache local, không commit.
- `*.tfstate`: state có thể chứa thông tin nhạy cảm, không commit lên repo public.
- `*.pem`: private key SSH, tuyệt đối không commit.

Điểm bảo mật quan trọng: Terraform có tạo file `.pem`, nhưng `.gitignore` chặn không cho đưa lên GitHub.

## `.terraform.lock.hcl`

File này lock version provider đã được Terraform chọn.

Ý nghĩa:

- Giúp người khác `terraform init` ra cùng provider version tương thích.
- Tăng tính reproducible của lab.
- Có thể commit file này lên repo.

## 5. Các câu hỏi mentor có thể hỏi

### Vì sao dùng ALB thay vì mở thẳng EC2 port 30080?

Vì ALB là entrypoint chuẩn hơn cho HTTP traffic. EC2 không cần mở NodePort ra toàn Internet; Security Group EC2 chỉ cho ALB gọi vào. ALB cũng có health check và DNS public dễ dùng hơn IP EC2.

### Vì sao Target Group dùng `target_type = "instance"`?

Vì ALB forward trực tiếp đến EC2 instance trên NodePort 30080. Mình không dùng IP Pod hay Ingress Controller, nên target type instance là đủ cho lab này.

### Vì sao dùng NodePort 30080 cố định?

ALB Target Group cần một port cố định để route traffic vào EC2. Nếu để Kubernetes tự chọn NodePort ngẫu nhiên, Terraform không biết chắc port nào để cấu hình Target Group.

### Vì sao `imagePullPolicy: Never`?

Vì image được build trực tiếp trên EC2 và load vào minikube bằng `minikube image load`. Kubernetes chỉ cần dùng image local, không cần pull từ Docker Hub. Điều này giúp lab độc lập hơn và không cần push image lên registry.

### Vì sao cần `--ports=30080:30080` khi start minikube?

Minikube chạy bằng Docker driver, Kubernetes node nằm trong container. Nếu không map port, NodePort bên trong minikube có thể không reachable từ host EC2. Mapping này giúp EC2 port 30080 chuyển vào minikube NodePort.

### Vì sao dùng `t3.small`?

Minikube cần CPU/RAM đủ để chạy Docker, Kubernetes control plane và Pod app. `t2.micro` hoặc cấu hình quá nhỏ dễ lỗi memory hoặc treo khi start cluster.

### Vì sao dùng `remote-exec`?

Vì lab yêu cầu tự động hóa 1 lần bằng Terraform. `remote-exec` giúp bootstrap EC2 ngay sau khi tạo. Với production, mình sẽ cân nhắc cloud-init, AMI build sẵn, CI/CD hoặc EKS thay vì bootstrap thủ công dài trong Terraform.

### Vì sao không dùng EKS?

Vì mục tiêu slide là thực hành Kubernetes/minikube và Terraform automation ở mức lab. EKS phù hợp production hơn nhưng phức tạp, tốn chi phí và vượt phạm vi bài này.

### Nếu public IP thay đổi thì sao?

Khi chạy `terraform apply` lại, `http` provider lấy IP mới và Terraform cập nhật rule SSH trong Security Group. App vẫn truy cập qua ALB, nên IP SSH chỉ ảnh hưởng debug.

### State Terraform nằm ở đâu?

Hiện tại state nằm local vì lab đơn giản. Với team/production nên dùng remote backend như S3 + DynamoDB lock để tránh conflict và bảo vệ state tốt hơn.

### Destroy có xóa hết không?

`terraform destroy` sẽ xóa các resource do Terraform quản lý: ALB, Target Group, Listener, Security Groups, EC2, AWS Key Pair và file `.pem` local. Docker/minikube nằm trong EC2 nên cũng biến mất khi EC2 bị xóa.

## 6. Checklist demo nhanh

Trước khi demo:

```powershell
terraform init
terraform validate
terraform apply
```

Sau khi apply:

```powershell
terraform output -raw alb_url
terraform output -raw ssh_command
```

Nếu cần SSH debug:

```bash
kubectl get pods
kubectl get svc
kubectl describe deployment portfolio
minikube status
docker images
```

Khi kết thúc demo:

```powershell
terraform destroy
```

## 7. Cách nói ngắn gọn khi thuyết trình

"Em dùng Terraform để tự động dựng EC2, Security Group và ALB trên AWS. EC2 được bootstrap bằng remote-exec để cài Docker, kubectl và minikube. Source portfolio được copy lên EC2, build thành nginx Docker image, load vào minikube, rồi deploy bằng Kubernetes Deployment và Service NodePort. ALB forward traffic từ port 80 vào NodePort 30080 trên EC2. SSH được bảo vệ bằng cách Terraform tự detect public IP hiện tại và chỉ mở `/32`, không mở toàn Internet."
