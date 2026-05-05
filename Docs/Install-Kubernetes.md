# How to Install a Kubernetes Cluster in on-prem Linux Server

This document explain how to install Kunernetes cluster in on-prem servers. For this setup, we use one master node and two worker nodes.

### Environment:
    - Master node IP: 192.168.0.210
    - Worker node 1 IP: 192.168.0.201
    - Worker node 2 IP: 192.168.0.202

1. Update the system (Run on all nodes)
2. Edit hosts files in both master and worker nodes
3. Check available memory (Run on all nodes)

    ``` 
    cat /proc/meminfo | grep MemTotal | awk '{print ($2 / 1024) / 1024,"GiB"}'
    ```

4. Check available processor cores (Run on all nodes)

    ``` 
    cat /proc/cpuinfo | grep processor
    ```

5. Disable SWAP memory (Run on all nodes)

    ```
    cat /etc/fstab
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    sudo swapoff -a
    ```

6.  Disable SELinux (Run on all nodes)
    ```
    cat /etc/selinux/config | grep SELINUX=
    sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    sudo setenforce 0
    ```

7. Disable and stop firewall (Run on all nodes)
    ```
    sudo systemctl stop firewalld.service
    sudo systemctl disable firewalld.service
    ```

8. Load netfiler module (Run on all nodes)
    ```
    sudo modprobe br_netfilter
    sudo lsmod | grep br_netfilter
    sudo sysctl -a | grep net.bridge.bridge-nf-call-iptables
    ```

9. Remove if previous docker version (Run on all nodes)
    ```
    sudo yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docler-logrotate docker-engine buildah
    ```

10. Add repository and install docker (Run on all nodes)
    ```
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    ```

11. Add the non-root user to docker user group to allow to run docker commands (Run on all nodes)
    ```
    sudo usermod -aG wheel username (Add sudo user)
    sudo usermod -aG docker $USER
    ```

12. Generate containerd config file and enable SystemdCgroup to true (Run on all nodes)
    ```
    containerd config default | sudo tee /etc/containerd/config.toml
    sudo cat /etc/containerd/config.toml | grep SystemdCgroup
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    sudo cat /etc/containerd/config.toml | grep SystemdCgroup
    ```

13. Start and enable docker (Run on all nodes)
    ```
    sudo systemctl start docker
    sudo systemctl enable docker
    ```

14. Check docker functions (Run on all nodes)
    ```
    sudo docker run hello-world
    ```

15. Add Kubernetes repository (Run on all nodes)
    ```
    cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
    enabled=1
    gpgcheck=1
    gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
    exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
    EOF

    sudo yum repolist
    ```

16. Install Kubernetes components (Run on all nodes)
    ```
    sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    sudo systemctl enable kubelet
    sudo systemctl start kubelet
    ```

17. Create Kubernetes cluster (Run only on master)
    ```
    sudo kubeadm init

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    ```

18. Add Calico network layer. This will reboot the master node. Reconnect after it comes up. (Run only 0n master)
    ```
    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
    ```

    Alternative calico download (Run only on the master)
    ```
    curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml -O
    kubectl apply -f calico.yaml
    ```

19. Generate node join token in controller (Run only on master)
    ```
    kubeadm token create --print-join-command
    ```

20. Add node to cluster (Run this in each worker node as root user)
    ```
    kubeadm join <master-ip>>:6443 --token <token_generated_by_above_command> --discovery-token-ca-cert-hash <hash_generated_by_above_command>
    ```

21. Install bash auto completion. After completion of the steps, signing in back.
    ```
    sudo yum install -y bash-completion
    source /usr/share/bash-completion/bash_completion
    kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
    ```

22. Set up an alias for kubectl and enable auto-completion. After completion of the steps, signing in back.
    ```
    echo 'alias k=kubectl' >>~/.bashrc
    echo 'complete -o default -F __start_kubectl k' >>~/.bashrc
    ```

### In case of IP address changes of the master or worker nodes:
You may have to reset cluster as master and node communication is configured via IP addresses. Do the following steps on all the nodes.
```
sudo kubeadm reset -f
sudo systemctl stop kubelet
rm -rf $HOME/.kube
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/cni/
sudo systemctl restart containerd
sudo systemctl stop kubelet
```
