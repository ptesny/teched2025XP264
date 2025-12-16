resource terraform_data "modules" {
	
  input = {
    host                   = resource.k3d_cluster.kyma.host
    client_certificate     = base64decode(resource.k3d_cluster.kyma.client_certificate)
    client_key             = base64decode(resource.k3d_cluster.kyma.client_key)
    cluster_ca_certificate = base64decode(resource.k3d_cluster.kyma.cluster_ca_certificate)
  }

 provisioner "local-exec" {
   //on_failure  = continue

   interpreter = ["/bin/bash", "-c"]
   command = <<EOF
     (
	echo "Install Kyma Istio"
	kubectl create ns kyma-system || true
	kubectl label namespace kyma-system istio-injection=enabled --overwrite
	kubectl apply -f https://github.com/kyma-project/istio/releases/latest/download/istio-manager.yaml
	kubectl apply -f https://github.com/kyma-project/istio/releases/latest/download/istio-default-cr.yaml

	echo "Wait for Istio CR to be ready"
	kubectl wait -n kyma-system istio default --for=condition=ready --timeout=5m

	echo "Install API Gateway"
	kubectl apply -f https://github.com/kyma-project/api-gateway/releases/latest/download/api-gateway-manager.yaml
	kubectl apply -f https://github.com/kyma-project/api-gateway/releases/latest/download/apigateway-default-cr.yaml

	echo "Wait for APIGateway CR to be ready"
	kubectl wait apigateway default --for=jsonpath='{.status.state}'=Ready --timeout=5m

	echo "Install BTP Manager"
	kubectl apply -f https://github.com/kyma-project/btp-manager/releases/latest/download/btp-manager.yaml
	kubectl apply -f https://github.com/kyma-project/btp-manager/releases/latest/download/btp-operator.yaml

	echo "Wait for BTP Manager CR to be ready"
    # https://github.com/kyma-project/btp-manager/blob/main/docs/user/03-00-create-btp-manager-secret.md

	kubectl get btpoperators btpoperator -n kyma-system
	kubectl wait -n kyma-system btpoperators/btpoperator --for=jsonpath='{.status.state}'=Warning --timeout=5m

	echo "Wait Serverless CR Ready"
	kubectl apply -f https://github.com/kyma-project/serverless/releases/latest/download/serverless-operator.yaml
	kubectl apply -f https://github.com/kyma-project/serverless/releases/latest/download/default-serverless-cr.yaml
    kubectl wait -n kyma-system serverless.operator.kyma-project.io/default --for='jsonpath={.status.state}=Ready' --timeout=5m

    ### enable serverless buildless
    kubectl patch serverlesses.operator.kyma-project.io default \
            -n kyma-system \
            --type='merge' \
            -p '{"metadata": {"annotations": {"serverless.kyma-project.io/buildless-mode": "enabled"}}}'

	echo "Install namespace"
	kubectl create ns test || true
	kubectl label namespace test istio-injection=enabled --overwrite

    echo "Remove traefik post installation"
    # https://github.com/k3s-io/k3s/issues/1160#issuecomment-1299212589
	### helm -n kube-system delete traefik traefik-crd
	### kubectl -n kube-system delete helmchart traefik traefik-crd

     )
   EOF
 } 

  depends_on = [ k3d_cluster.kyma ]
}