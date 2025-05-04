# MÓDULO 04 - SEGURANÇA AVANÇADA NO API GATEWAY

## INTRODUÇÃO

Para esta demonstração de configurações avançadas de segurança no API Gatway, iremos implementa-las utilizando o Kong Gatway. Para tanto, nós vamos precisar criar um ambiente de testes utilizando um cluster Kubernetees com o Kong Ingress Controller, cujo implementa o Kong Gatway.

Para a criação deste ambiente, vamos deixar duas opções. Uma primeira com base em ambiente Amazon Web Services utilizando o serviço do AWS Elastic Kubernetes Service (EKS). E para aqueles que preferem executar em um ambiente local os seus testes, deixaremos como opção de configurar utilizando o projeto do Kind.

## CONFIGURAÇÃO AMBIENTE DE TESTES

### OPÇÃO 1 - AMBIENTE CLOUD COM AMAZON WEB SERVICES E EKS

#### ATENÇÃO

Como as demonstrações são com base no uso de recursos criados a partir dos serviços da Amazon Web Services (AWS), pode haver a ocorrência de custos pelo período de consumo pelos mesmos.

#### PRÉ-REQUISITOS

Caso você queira executar estas demonstrações no seu ambiente você precisará ter:

- Conta na Amazon Web Services (AWS);
- Credenciais de acesso a AWS, com permissões suficientes para:

  - Administrar manutenção de VPC, subnets, route tables, internet gateway e NAT gateways;
  - Administrar manutenção de instâncias EC2, Load Balancers e Security Groups;
  - Administrar manutenção de clusters EKS;

- [AWS CLI](https://docs.aws.amazon.com/pt_br/streams/latest/dev/setup-awscli.html) devidamente configurado com as credenciais de acesso;
- [KUBECTL](https://kubernetes.io/docs/reference/kubectl/) devidamente configurado;
- [HELM](https://helm.sh/docs/intro/install/) devidamente instalado;

#### EXECUÇÃO

Como primeiro passo, iremos realizar a configuração da infraestrutura básica que envolve a criação de VPCs, subnets públicas e privadas, internet gateway, NAT Gateways e o cluster EKS:

```
aws --region us-east-1 \
     cloudformation create-stack --stack-name fc-mod04-eks-cluster \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://modulo-04_base.yaml
```

Uma vez finalizado o provisionamento, podemos atualizar o nosso `kubeconfig` com as configurações de acesso ao nosso cluster que criamos no passo anterior:

```
aws eks update-kubeconfig --name fc-mod04-eks-cluster
```

Para validar o provisionamento do cluster, podemos tentar executar um comando para recuperar as informações dos nós que fazem parte do cluster:

```
kubectl get nodes
```

Agora que temos o cluster configurando, a através do cli do `helm` iremos configurar o **kong ingress controller**, para tanto primeiro vamos configurar o repositório do kong:

```
helm repo add kong https://charts.konghq.com
helm repo update
```

Em seguida, vamos instala-lo no nosso cluster:

```
helm install kong kong/kong --namespace kong --create-namespace \
  --set proxy.type=LoadBalancer \
  --set proxy.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --set proxy.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing"
```

Assim que aplicarmos a instalação, o **[AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/)** irá iniciar o provisionamento de um **Network Load Balancer** que será utilizado pelo nosso **Kong Ingress Controller**. Uma vez que o _Load Balancer_ esteja em um estado de pronto para uso, poderemos obter o seu DNS cujo iremos usar ao longo da nossa demonstração.

O primeiro passo para recuperarmos o DNS é filtrar entre os _Load Balancers_ qual está com TAG para o nosso _Kong Ingress Controller_:

```
export KONG_GATEWAY_NLB_ARN="$(aws elbv2 --region us-east-1 describe-load-balancers \
 | jq -r '.LoadBalancers[].LoadBalancerArn' \
 | xargs -I {} \
 aws elbv2 --region us-east-1 describe-tags \
 --resource-arns {} \
 --query "TagDescriptions[?Tags[?Key=='kubernetes.io/cluster/fc-mod04-eks-cluster' &&Value=='owned'] \
 && Tags[?Key=='kubernetes.io/service-name' &&Value=='kong/kong-kong-proxy']].ResourceArn" \
 --output text)"
```

Uma vez que encontramos o ARN do nosso LB, podemos recuperar o seu DNS:

```
export KONG_GATEWAY_DNS="$(aws --region us-east-1 elbv2 describe-load-balancers \
 --load-balancer-arns $KONG_GATEWAY_NLB_ARN \
 --query 'LoadBalancers[*].DNSName | [0]' --output text)"

echo "DNS: $KONG_GATEWAY_DNS, ARN:$KONG_GATEWAY_NLB_ARN"
```

#### PÓS DEMONSTRAÇÃO E CLEANUP

Após o término desta demonstração, para desprovisionar os recursos é importante executar os comandos abaixo em sequência para evitar que o _cloudformation_ fique impossibilitado de finalizar a remoção dos recursos da conta.

Primeiramente precisamos desinstalar o **Kong Ingress Controller**, onde uma vez removido as configurações dele o **AWS Load Balancer Controler** irá indentificar que o _Load Balancer_ que fora criado para o **Kong** precisa ser removido:

```
helm uninstall kong -n kong
```

Uma vez que o _Load Balancer_ não estiver mais presente, podemos realizar o remoção do restante da stack:

```
aws --region us-east-1 cloudformation delete-stack --stack-name fc-mod04-eks-cluster
```

### OPÇÃO 2 - AMBIENTE LOCAL COM KIND

#### PRÉ-REQUISITOS

https://www.keycloak.org/getting-started/getting-started-kube

kind create cluster --name=fc-k8s --config=./kind-config.yaml

#### EXECUÇÃO

Como primeiro passo, começamos realizando o provisionamento da infraestrutura inicial:

```

kubectl run httpbin --image=kennethreitz/httpbin --port=80
kubectl expose  pod httpbin --port=80 --name=httpbin
kubectl create ingress httpbin --class=kong --rule="/api/*=httpbin:80" --annotation=konghq.com/strip-path=true

curl -fsSL "http://$KONG_GATEWAY_DNS/api/anything?param1=example"



kubectl apply -f https://reweave.azurewebsites.net/k8s/v1.29/net.yaml


helm install kong kong/kong --namespace kong --create-namespace \
  --set proxy.type=NodePort

cat << EOF | kubectl apply  -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  labels:
    app: keycloak
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
        - name: keycloak
          image: quay.io/keycloak/keycloak:26.2.2
          args: ["start-dev"]
          env:
            - name: KEYCLOAK_ADMIN
              value: "admin"
            - name: KEYCLOAK_ADMIN_PASSWORD
              value: "admin"
            - name: KC_PROXY_HEADERS
              value: "xforwarded"
            - name: KC_HTTP_ENABLED
              value: "true"
            - name: KC_HEALTH_ENABLED
              value: "true"
            - name: PROXY_ADDRESS_FORWARDING
              value: "true"
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 9000
EOF


kubectl expose deployment keycloak --port=80 --target-port=8080 --name=keycloak
kubectl create ingress keycloak --class=kong --rule="/*=keycloak:80" --annotation=konghq.com/strip-path=false

http://ae885027b363d4c9fa40d8b62d2c4489-b43e93ebf9376250.elb.us-east-1.amazonaws.com/admin

```

Por final, vamos fazer o cleanup do nosso ambiente e remover todos os recursos:
