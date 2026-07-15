#!/usr/bin/env bash
set -Eeuo pipefail

KUBERNETES_MINOR="v1.33"

if [[ ${EUID} -eq 0 ]]; then
  echo "Run this script as a regular sudo-enabled user, not as root." >&2
  exit 1
fi

sudo -v

echo "[1/6] Disabling swap"
sudo swapoff -a
sudo sed -i.bak '/\/swap.img/ s/^[^#]/#&/' /etc/fstab

echo "[2/6] Loading Kubernetes kernel modules"
cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

echo "[3/6] Applying Kubernetes network sysctls"
cat <<'EOF' | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf >/dev/null
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system >/dev/null

echo "[4/6] Installing and configuring containerd"
sudo apt-get update
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  containerd \
  curl \
  gpg \
  nfs-common
sudo install -d -m 0755 /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml
sudo systemctl enable --now containerd
sudo systemctl restart containerd

echo "[5/6] Installing Kubernetes ${KUBERNETES_MINOR} packages"
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL \
  "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/deb/Release.key" \
  | sudo gpg --dearmor --yes \
      -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
sudo apt-get update
sudo apt-get install -y cri-tools kubelet kubeadm kubectl
sudo apt-mark hold cri-tools kubelet kubeadm kubectl

cat <<'EOF' | sudo tee /etc/crictl.yaml >/dev/null
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

echo "[6/6] Verifying the template"
test -z "$(swapon --show --noheadings)"
test "$(sysctl -n net.ipv4.ip_forward)" = "1"
grep -q 'SystemdCgroup = true' /etc/containerd/config.toml
test "$(systemctl is-active containerd)" = "active"

containerd --version
sudo crictl version
kubeadm version -o short
kubelet --version
kubectl version --client

echo "Base node is prepared. Do not run kubeadm init before cloning."
