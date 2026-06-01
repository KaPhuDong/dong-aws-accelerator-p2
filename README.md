# dong-aws-accelerator-p2

Portfolio cá nhân Phase 2 cho track Cloud/DevOps AWS Accelerator.

## Thông tin học viên

- Học viên: Ka Phu Dong
- Track: Cloud/DevOps
- Giai đoạn: Phase 2
- Thời gian: 01/06/2026 - 03/07/2026
- Repo: `dong-aws-accelerator-p2`

## Mục tiêu Phase 2

Phase 2 tập trung vào năng lực tự học, thực hành và ghi lại bằng chứng học tập qua GitHub. Nội dung chính gồm:

- Infrastructure as Code với Terraform
- Container và Kubernetes orchestration
- Kubernetes scaling, networking và deployment trên minikube
- GitOps, observability, canary deployment và security
- Capstone cross-team pod và pitching cuối giai đoạn

## Nhịp học

- T2-T4: self-study online, đọc material, làm exercise và commit cuối ngày
- T5-T6: onsite Đà Nẵng, lab và show-and-tell
- Commit message theo format: `[W8-D1] <topic ngắn>`

## Cấu trúc repo

```text
cloud/
  w8/
    day-a/
      terraform-iac-overview-hcl.md
    day-b/
      k8s-container-orchestration.md
    day-c/
      k8s-scaling-networking.md
    lab/
      mini-k8s-platform-minikube.md
    reflection.md
  w9/
    gitops-observability.md
  w10/
    canary-security.md
capstone/
  w11/
    capstone-planning.md
  w12/
    capstone-pitching.md
```

## W8 - Foundation: IaC + K8s

| Ngày | Nội dung | Evidence |
|---|---|---|
| T2 01/06 | Terraform phần 1: IaC overview + HCL syntax | `cloud/w8/day-a/terraform-iac-overview-hcl.md` |
| T3 02/06 | Terraform phần 2: workflow, state, modules, best practices | `cloud/w8/day-a/terraform-iac-overview-hcl.md` |
| T4 03/06 | K8s foundation: Pod, Service, probes, ConfigMap/Secret, NetworkPolicy | `cloud/w8/day-b/k8s-container-orchestration.md` |
| T5 04/06 | K8s orchestration, scaling, networking, deploy trên minikube | `cloud/w8/day-c/k8s-scaling-networking.md` |
| T6 05/06 | Hoàn thiện lab Mini K8s platform và show-and-tell | `cloud/w8/lab/mini-k8s-platform-minikube.md` |

## Tài liệu tham khảo

### Terraform

- HashiCorp Learn: https://developer.hashicorp.com/terraform/tutorials
- Terraform Docs: https://developer.hashicorp.com/terraform/docs
- Terraform Registry: https://registry.terraform.io
- Terraform Best Practices: https://www.terraform-best-practices.com
- Terraform from Basics to Production: https://kkloudtarus.net/en/blog/series/terraform-from-basics-to-production

### Docker / Containers

- Docker Docs: https://docs.docker.com
- Docker Curriculum: https://docker-curriculum.com
- OCI Image Spec: https://github.com/opencontainers/image-spec
- Docker from Basics to Swarm: https://kkloudtarus.net/en/blog/series/docker-from-basics-to-swarm

### Kubernetes

- Kubernetes Docs: https://kubernetes.io/docs
- Kubernetes Basics: https://kubernetes.io/docs/tutorials/kubernetes-basics
- minikube: https://minikube.sigs.k8s.io/docs/start
- CNCF Curriculum: https://github.com/cncf/curriculum
- kubectl Cheat Sheet: https://kubernetes.io/docs/reference/kubectl/cheatsheet

### AWS

- AWS Docs: https://docs.aws.amazon.com
- AWS Skill Builder: https://skillbuilder.aws
- AWS Workshops: https://workshops.aws
- Well-Architected Framework: https://aws.amazon.com/architecture/well-architected
