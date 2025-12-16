// terraform destroy -auto-approve
// terraform apply -auto-approve

terraform {
  required_providers {
    # https://github.com/hashicorp/terraform/issues/34207
    k3d = {
      source  = "sneakybugs/k3d"
      version = "1.0.1"
    }
     helm = {
      source  = "hashicorp/helm"
    }
    # https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    kubectl = {
      source  = "alekc/kubectl"
    }  
    http = {
      source  = "hashicorp/http"
      version = "~> 3.5.0"
    }
    terracurl = {
      source  = "devops-rob/terracurl"
      version = "~> 2.1.0"
    }
  }
}

# https://nikhilsbhat.github.io/terraform-provider-k3d/
# https://k3d.io/v5.8.3/usage/configfile/#all-options-example
# https://k3d.io/v5.8.3/#installation
# https://k3d.io/v5.8.3/#install-current-latest-release
# 

# https://registry.terraform.io/providers/SneakyBugs/k3d/latest/docs
# https://github.com/SneakyBugs/terraform-provider-k3d
# https://github.com/SneakyBugs/terraform-provider-k3d/blob/main/internal/provider/cluster_resource.go


/*
https://docs.k3s.io/installation/configuration

curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
https://raw.githubusercontent.com/quovadis-btp/istio/refs/heads/master/samples/httpbin/httpbin.yaml

https://github.com/NexClipper/k3d-setup-external-ip/blob/main/k3d.yml
https://github.com/NexClipper/k3d-setup-external-ip/blob/main/create.sh

https://developer.hashicorp.com/terraform/mcp-server/deploy

k3d cluster create kyma --port 80:80@loadbalancer --port 443:443@loadbalancer  --image rancher/k3s:v1.31.9-k3s1 --k3s-arg "--disable=traefik@server:*"
*/

resource "k3d_cluster" "kyma" {
  name = "kyma"

  # See https://k3d.io/v5.8.3/usage/configfile/#config-options
  k3d_config= <<YAML
apiVersion: k3d.io/v1alpha5 
kind: Simple
metadata:
  name: kyma 

# ifconfig | grep "inet " | grep -v  "127.0.0.1" | awk -F " " '{print $2}'|head -n1
#kubeAPI: # same as `--api-port myhost.my.domain:6445` (where the name would resolve to 127.0.0.1)
#  hostIP: "10.0.1.127" # where the Kubernetes API will be listening on
image: rancher/k3s:v1.31.9-k3s1
ports:
  - port: 80:80
    nodeFilters:
      - loadbalancer
  - port: 443:443
    nodeFilters:
      - loadbalancer

registries:
  create:
    name: dev
    hostPort: "50000"

options:
  k3s: # options passed on to K3s itself
    extraArgs: # additional arguments passed to the `k3s server|agent` command; same as `--k3s-arg`
#      - arg: "--disable=traefik@server:*"
      - arg: "--disable=traefik"
        nodeFilters:
          - server:*
      - arg: "--tls-san=local.kyma.dev"
        nodeFilters:
          - server:*
YAML

  lifecycle {
    ignore_changes = all
  } 
}

output "kyma" {
  sensitive = true
  value = k3d_cluster.kyma
}

output "kyma_kubeconfig" {
  sensitive = true
  value = k3d_cluster.kyma.kubeconfig
}

provider "kubectl" {
  host                   = resource.k3d_cluster.kyma.host
  client_certificate     = base64decode(resource.k3d_cluster.kyma.client_certificate)
  client_key             = base64decode(resource.k3d_cluster.kyma.client_key)
  cluster_ca_certificate = base64decode(resource.k3d_cluster.kyma.cluster_ca_certificate)
  load_config_file       = false
}

provider "kubernetes" {
  host                   = resource.k3d_cluster.kyma.host
  client_certificate     = base64decode(resource.k3d_cluster.kyma.client_certificate)
  client_key             = base64decode(resource.k3d_cluster.kyma.client_key)
  cluster_ca_certificate = base64decode(resource.k3d_cluster.kyma.cluster_ca_certificate)
}

resource "kubernetes_secret_v1" "postgres_credentials" {
  metadata {
    name = "postgres-credentials"
  }

  data = {
    "postgres-password"    = "development"
    "password"             = "development"
    "replication-password" = "development"
  }
}

provider "helm" {
  kubernetes = {
    host                   = resource.k3d_cluster.kyma.host
    client_certificate     = base64decode(resource.k3d_cluster.kyma.client_certificate)
    client_key             = base64decode(resource.k3d_cluster.kyma.client_key)
    cluster_ca_certificate = base64decode(resource.k3d_cluster.kyma.cluster_ca_certificate)
  }
}


resource "helm_release" "database" {
  name       = "postgres"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  set = [ 
      {
        name  = "auth.existingSecret"
        value = "postgres-credentials"

      }
  ]
}