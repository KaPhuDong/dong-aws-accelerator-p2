resource "aws_instance" "k8s" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  key_name                    = aws_key_pair.generated.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = self.public_ip
    private_key = tls_private_key.ssh.private_key_pem
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
      #!/usr/bin/env bash
      set -euxo pipefail

      sudo apt-get update
      sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https

      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      sudo apt-get update
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      sudo usermod -aG docker ubuntu
      sudo systemctl enable --now docker

      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
      rm -f kubectl

      curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
      sudo install minikube-linux-amd64 /usr/local/bin/minikube
      rm -f minikube-linux-amd64

      sudo -u ubuntu -H minikube start --driver=docker --cpus=2 --memory=1800mb --ports=${var.node_port}:${var.node_port}

      sudo -u ubuntu -H mkdir -p /home/ubuntu/k8s-manifests
      cat <<'CONFIGMAP' | sudo -u ubuntu -H tee /home/ubuntu/k8s-manifests/configmap.yaml >/dev/null
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: portfolio-site
      data:
        index.html: |
          <!doctype html>
          <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Cloud Portfolio</title>
            <style>
              :root {
                color-scheme: light;
                --ink: #172033;
                --muted: #5b6578;
                --line: #d9e2ef;
                --accent: #0f8b8d;
                --warm: #f2a65a;
                --bg: #f7f9fc;
              }
              * { box-sizing: border-box; }
              body {
                margin: 0;
                min-height: 100vh;
                font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                color: var(--ink);
                background: var(--bg);
              }
              main {
                width: min(1040px, calc(100% - 32px));
                margin: 0 auto;
                padding: 48px 0;
              }
              header {
                display: grid;
                grid-template-columns: 1.2fr 0.8fr;
                gap: 28px;
                align-items: end;
                padding-bottom: 30px;
                border-bottom: 1px solid var(--line);
              }
              h1 {
                margin: 0;
                max-width: 760px;
                font-size: clamp(2.25rem, 6vw, 4.75rem);
                line-height: 1;
                letter-spacing: 0;
              }
              .tagline {
                margin: 16px 0 0;
                max-width: 650px;
                color: var(--muted);
                font-size: 1.05rem;
                line-height: 1.7;
              }
              .panel {
                border-left: 4px solid var(--accent);
                padding: 8px 0 8px 18px;
              }
              .panel strong {
                display: block;
                margin-bottom: 8px;
                font-size: 0.78rem;
                text-transform: uppercase;
                letter-spacing: 0.12em;
                color: var(--accent);
              }
              .panel p {
                margin: 0;
                color: var(--muted);
                line-height: 1.6;
              }
              section {
                padding: 28px 0;
                border-bottom: 1px solid var(--line);
              }
              h2 {
                margin: 0 0 16px;
                font-size: 1rem;
                text-transform: uppercase;
                letter-spacing: 0.12em;
                color: var(--accent);
              }
              .grid {
                display: grid;
                grid-template-columns: repeat(3, minmax(0, 1fr));
                gap: 16px;
              }
              .item {
                min-height: 150px;
                padding: 18px;
                border: 1px solid var(--line);
                border-radius: 8px;
                background: #ffffff;
              }
              .item h3 {
                margin: 0 0 10px;
                font-size: 1.1rem;
              }
              .item p {
                margin: 0;
                color: var(--muted);
                line-height: 1.55;
              }
              .skills {
                display: flex;
                flex-wrap: wrap;
                gap: 10px;
              }
              .skills span {
                padding: 8px 12px;
                border: 1px solid var(--line);
                border-radius: 999px;
                background: #ffffff;
                color: var(--ink);
                font-size: 0.92rem;
              }
              footer {
                display: flex;
                justify-content: space-between;
                gap: 16px;
                padding-top: 26px;
                color: var(--muted);
              }
              a { color: var(--accent); font-weight: 700; text-decoration: none; }
              @media (max-width: 760px) {
                main { padding: 28px 0; }
                header, .grid { grid-template-columns: 1fr; }
                footer { flex-direction: column; }
              }
            </style>
          </head>
          <body>
            <main>
              <header>
                <div>
                  <h1>Cloud Engineer Portfolio</h1>
                  <p class="tagline">I build reliable cloud platforms, automate infrastructure with Terraform, and ship Kubernetes workloads that are observable, repeatable, and easy to operate.</p>
                </div>
                <div class="panel">
                  <strong>Live Lab</strong>
                  <p>Served from nginx inside a minikube cluster on EC2, exposed through an AWS Application Load Balancer.</p>
                </div>
              </header>

              <section>
                <h2>Featured Work</h2>
                <div class="grid">
                  <article class="item">
                    <h3>Kubernetes on AWS</h3>
                    <p>Provisioned EC2, Docker, minikube, NodePort, and ALB routing with a single Terraform apply.</p>
                  </article>
                  <article class="item">
                    <h3>Infrastructure as Code</h3>
                    <p>Used AWS, TLS, and Local providers to create network, compute, keys, and outputs cleanly.</p>
                  </article>
                  <article class="item">
                    <h3>Platform Automation</h3>
                    <p>Bootstrap scripts install tooling, deploy manifests, and verify the app before Terraform completes.</p>
                  </article>
                </div>
              </section>

              <section>
                <h2>Skills</h2>
                <div class="skills">
                  <span>AWS</span>
                  <span>Terraform</span>
                  <span>Kubernetes</span>
                  <span>Docker</span>
                  <span>Linux</span>
                  <span>CI/CD</span>
                  <span>Networking</span>
                </div>
              </section>

              <footer>
                <span>Available for cloud and platform engineering work.</span>
                <a href="mailto:cloud@example.com">cloud@example.com</a>
              </footer>
            </main>
          </body>
          </html>
      CONFIGMAP

      cat <<'DEPLOYMENT' | sudo -u ubuntu -H tee /home/ubuntu/k8s-manifests/deployment.yaml >/dev/null
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: web
      spec:
        replicas: ${var.app_replicas}
        selector:
          matchLabels:
            app: web
        template:
          metadata:
            labels:
              app: web
          spec:
            containers:
              - name: nginx
                image: nginx:1.27-alpine
                ports:
                  - containerPort: 80
                volumeMounts:
                  - name: portfolio-content
                    mountPath: /usr/share/nginx/html/index.html
                    subPath: index.html
                readinessProbe:
                  httpGet:
                    path: /
                    port: 80
                  initialDelaySeconds: 5
                  periodSeconds: 5
                livenessProbe:
                  httpGet:
                    path: /
                    port: 80
                  initialDelaySeconds: 15
                  periodSeconds: 10
            volumes:
              - name: portfolio-content
                configMap:
                  name: portfolio-site
      DEPLOYMENT

      cat <<'SERVICE' | sudo -u ubuntu -H tee /home/ubuntu/k8s-manifests/service.yaml >/dev/null
      apiVersion: v1
      kind: Service
      metadata:
        name: web
      spec:
        type: NodePort
        selector:
          app: web
        ports:
          - name: http
            port: 80
            targetPort: 80
            nodePort: ${var.node_port}
      SERVICE

      sudo -u ubuntu -H kubectl apply -f /home/ubuntu/k8s-manifests/
      sudo -u ubuntu -H kubectl rollout status deployment/web --timeout=180s

      curl --retry 20 --retry-delay 3 --retry-connrefused -I http://127.0.0.1:${var.node_port}/
      EOT
    ]
  }

  tags = {
    Name = "${var.project_name}-minikube"
  }
}
