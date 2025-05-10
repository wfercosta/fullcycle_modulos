# MÓDULO 04 - SEGURANÇA AVANÇADA NO API GATEWAY

## INTRODUÇÃO

Para esta demonstração de configurações avançadas de segurança no API Gatway, iremos implementa-las utilizando o Kong Gatway. Para tanto, nós vamos precisar criar um ambiente de testes utilizando um cluster Kubernetees com o Kong Ingress Controller, cujo implementa o Kong Gatway.

Para a criação deste ambiente, vamos deixar duas opções. Uma primeira com base em ambiente Amazon Web Services utilizando o serviço do AWS Elastic Kubernetes Service (EKS). E para aqueles que preferem executar em um ambiente local os seus testes, deixaremos como opção de configurar utilizando o projeto do Kind.

## CONFIGURAÇÃO AMBIENTE DE TESTES

### OPÇÃO 1 - AMBIENTE CLOUD COM AMAZON WEB SERVICES E EKS

#### ATENÇÃO

Como as demonstrações são com base no uso de recursos criados a partir dos serviços da Amazon Web Services (AWS), pode haver a ocorrência de custos pelo período de consumo pelos mesmos.

#### PRÉ-REQUISITOS

Caso você queira executar estas demonstrações no seu ambiente usando esta opção você precisará ter:

- Conta na Amazon Web Services (AWS);
- Credenciais de acesso a AWS, com permissões suficientes para:

  - Administrar manutenção de VPC, subnets, route tables, internet gateway e NAT gateways;
  - Administrar manutenção de instâncias EC2, Load Balancers e Security Groups;
  - Administrar manutenção de clusters EKS;

- [AWS CLI](https://docs.aws.amazon.com/pt_br/streams/latest/dev/setup-awscli.html) devidamente instalado e configurado;
- [KUBECTL](https://kubernetes.io/docs/reference/kubectl/) devidamente instalado;
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

Para validar o provisionamento do cluster, podemos tentar executar um comando para recuperar as informações dos nós que fazem parte dele:

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

Uma vez que o _Load Balancer_ não estiver mais presente, podemos realizar o remoção do restante da _stack_:

```
aws --region us-east-1 cloudformation delete-stack --stack-name fc-mod04-eks-cluster
```

### OPÇÃO 2 - AMBIENTE LOCAL COM KIND

#### PRÉ-REQUISITOS

Caso você queira executar estas demonstrações no seu ambiente usando esta opção você precisará ter:

- Possui um container runtime instalado como `docker` ou `podman`;
- [KIND](https://kind.sigs.k8s.io/docs/user/quick-start/) devidamente instalado;
- [KUBECTL](https://kubernetes.io/docs/reference/kubectl/) devidamente instalado;
- [HELM](https://helm.sh/docs/intro/install/) devidamente instalado;

#### EXECUÇÃO

Como primeiro passo, iremos criar o nosso cluster para testes locais usando o `kind`, onde para este ambiente iremos provisionar um nó de _controlplane_ e outro de _dataplane_ (_worker_). Note que nesta configuração estamos adiconando uma configuração de _extraPortMappings_ que vai ser importante para realizarmos um _port forward_ a partir da porta local **80** para **31000** que irá nos dar acesso ao **Kong**:

```
cat << EOF | kind create cluster --name=fc-k8s --config -
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: false
nodes:
  - role: control-plane
  - role: worker
    extraPortMappings:
      - containerPort: 31000
        hostPort: 80
        protocol: TCP
EOF
```

Ao término da configuração do cluster local, provavelmente já estará confiugrando no seu `kubectl` como ambiente atual.
Para validar o provisionamento do cluster, podemos tentar executar um comando para recuperar as informações dos nós que fazem parte dele:

```
kubectl get nodes
```

Agora que temos o cluster configurando, a através do cli do `helm` iremos configurar o **kong ingress controller**, para tanto primeiro vamos configurar o repositório do kong:

```
helm repo add kong https://charts.konghq.com
helm repo update
```

Em seguida, vamos instala-lo no nosso cluster. Note que diferente da opção de instalação em ambiente cloud, alteramos a configuração para instala-lo com exposição via `NodePort`:

```
helm install kong kong/kong --namespace kong --create-namespace \
  --set proxy.type=NodePort
```

Como configuramos o nosso `kind` com um _port forward_ --> **80:31000**, precisamos ajustar a configuração do serviço que foi criado no passo anterior, alterando o `NodePort` randomico para seja de acordo com a configuração do `kind`:

```
export KONG_GATEWAY_NODE_PORT_CURRENT=$(kubectl -n kong get svc kong-kong-proxy \
    -ojsonpath='{.spec.ports[?(@.name=="kong-proxy")].nodePort}')

kubectl -n kong get svc kong-kong-proxy -o yaml \
    | sed "s/nodePort: $KONG_GATEWAY_NODE_PORT_CURRENT/nodePort: 31000/g" \
    | kubectl replace -f -
```

Para conferir, basta validarmos a alteração que foi realizado no serviço:

```
kubectl -n kong get svc kong-kong-proxy -o wide
```

Por ultimo, vamos exportar uma variável para DNS do `kong` para `localhost`:

```
export KONG_GATEWAY_DNS=localhost
```

#### PÓS DEMONSTRAÇÃO E CLEANUP

Após o término desta demonstração, para desprovisionar os recursos por ser ambiente local basta removermos o nosso cluster no `kind`:

```
kind delete clusters fc-k8s
```

## DEMONSTRAÇÃO

### EXPOSIÇÃO DE API PARA SIMULAÇÃO

A primeira ação que vamos realizar nesta demonstração será o provisionamento de uma aplicação que irá fazer o papel de API. Para tanto, iremos provisionar um container chamado de [HTTPBIN](https://httpbin.org) que é um serviço de HTTP simples usado para testes.

#### EXECUÇÃO

Primeiramente, vamos criar um _deployment_ no nosso cluster kubernetes usando a imagem `kennethreitz/httpbin` que pode ser encontrada no **docker hub**:

```
kubectl create deploy httpbin --image=kennethreitz/httpbin --port=80 --replicas=1
```

Na sequëncia vamos criar um _service_ do tipo `ClusterIP` nosso _deployment_:

```
kubectl expose deploy httpbin --port=80 --name=httpbin
```

Uma vez gerado o _service_, iremos expor o nosso serviço através do _ingress controller_ do **kong**, criando um rota `/api/*`:

```
kubectl create ingress httpbin --class=kong \
    --rule="/api/*=httpbin:80" \
    --annotation=konghq.com/strip-path=true
```

Através do comando a seguir conseguirmos ter uma visão dos recursos criados e validar se estão todos executando:

```
kubectl get po,deploy,svc
```

Para um teste de sanidade, iremos chamar o endpoint `/anything` do container que acabamos de implantar e verificar se estamos tendo uma resposta via **Kong Ingress Controller/ Gateway**:

```
curl -fsSL "http://$KONG_GATEWAY_DNS/api/anything?param1=example"
```

### IMPLANTAÇÃO DE IDENTITY PROVIDER (IdP)

Agora que temos uma API para simular os nossos testes, agora precisamos de um IdP que irá nos ajudar a prover credenciais de acesso para usarmos nos nossos testes. Para este objetivo iremos utilizar o **Keycloack** realizando uma configuração usando kubernetes.

#### EXECUÇÃO

Primeiramente, com base na documentação do [Keycloack](https://www.keycloak.org/getting-started/getting-started-kube), iremos aplicar um manifesto de deployment para termos os nosso IdP executando no nosso ambiente de testes:

```
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
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 9000
EOF
```

Na sequëncia, iremos criar um _resourece_ do tipo _service_ para o nosso **Keycloack**:

```
kubectl expose deployment keycloak --port=80 --target-port=8080 --name=keycloak
```

Por último, iremos expor este serviço via _ingress controller_:

```
kubectl create ingress keycloak --class=kong --rule="/*=keycloak:80" --annotation=konghq.com/strip-path=false
```

Para validar o status do recursos implantados, podemos listar todos com o seguinte comando:

```
kubectl get deploy,svc,ing
```

Como último passo desta parte da deminstração, vamos acessar o console administrativo do **Keycloack**, usando o endereço que dá acesso ao seu ingress controle no path `/admin` usando as credenciais de acesso são usuário `admin` e senha `admin` e em seguida vamos alterar o tempo de expiração do access token no `master` realm:

```
echo "http://$KONG_GATEWAY_DNS/admin"
```

Para encerrar esta etapa de configuraça

### CRIAÇÃO DE CREDENCIAIS DE APLICAÇÃO, SCOPES E VALIDAÇÃO VIA GATEWAY

#### EXECUÇÃO

```
KEYCLOACK_ADMIN_ACCESS_TOKEN=$(curl -fsSL \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data "grant_type=password&client_id=admin-cli&username=admin&password=admin" \
    --request POST http://$KONG_GATEWAY_DNS/realms/master/protocol/openid-connect/token \
    | jq -r ."access_token")
```

```
export KEYCLOACK_FC_REALM="fc-mod04"
export KEYCLOACK_FC_CLIENT_ID=$(uuidgen)
export KEYCLOACK_FC_SECRET_ID=$(uuidgen)
```

```
curl -fsSL \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $KEYCLOACK_ADMIN_ACCESS_TOKEN" \
    --data "{\"realm\": \"$KEYCLOACK_FC_REALM\", \"displayName\": \"Fullcycle - Modulo 04\", \"enabled\": true}' \
    --request POST http://$KONG_GATEWAY_DNS/admin/realms
```

```
curl -fsSL \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $KEYCLOACK_ADMIN_ACCESS_TOKEN" \
    --data "{\"name\": \"$KEYCLOACK_FC_REALM\", \"clientId\": \"$KEYCLOACK_FC_CLIENT_ID\", \"secret\": \"$KEYCLOACK_FC_SECRET_ID\", \"serviceAccountsEnabled\": true}" \
    --request POST http://$KONG_GATEWAY_DNS/admin/realms/$KEYCLOACK_FC_REALM/clients
```

```
KEYCLOACK_FC_CLIENT_ID_UUID=$(curl -fsSL \
    --header "Authorization: Bearer $KEYCLOACK_ADMIN_ACCESS_TOKEN" \
    --request GET "http://$KONG_GATEWAY_DNS/admin/realms/$KEYCLOACK_FC_REALM/clients?clientId=$KEYCLOACK_FC_CLIENT_ID" \
    | jq -rc '.[0].id')
```

```
curl -fsSL \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $KEYCLOACK_ADMIN_ACCESS_TOKEN" \
    --data "{\"name\": \"httpbin:read:anything\", \"description\": \"Exemplo de scope\", \"protocol\": \"openid-connect\"}" \
    --request POST http://$KONG_GATEWAY_DNS/admin/realms/$KEYCLOACK_FC_REALM/client-scopes
```

```
KEYCLOACK_SCOPE_ID=$(curl -fsSL \
 --header "Authorization: Bearer $KEYCLOACK_ADMIN_ACCESS_TOKEN" \
    --request GET http://$KONG_GATEWAY_DNS/admin/realms/$KEYCLOACK_FC_REALM/client-scopes \
    | jq -rc '.[] | select(.name=="httpbin:read:anything") | .id')
```

```
curl -fsSL \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $KEYCLOACK_ADMIN_ACCESS_TOKEN" \
    --request PUT http://$KONG_GATEWAY_DNS/admin/realms/$KEYCLOACK_FC_REALM/clients/$KEYCLOACK_FC_CLIENT_ID_UUID/default-client-scopes/$KEYCLOACK_SCOPE_ID
```

```
KEYCLOACK_CLIENT_ACCESS_TOKEN=$(curl -fsSL \
 --header "Content-Type: application/x-www-form-urlencoded" \
 --data "grant_type=client_credentials&client_id=$KEYCLOACK_FC_CLIENT_ID&client_secret=$KEYCLOACK_FC_SECRET_ID" \
 --request POST http://$KONG_GATEWAY_DNS/realms/$KEYCLOACK_FC_REALM/protocol/openid-connect/token \
 | jq -rc '.access_token')
```

```
KEYCLOACK_JWKS_URI=$(curl -fsSL http://$KONG_GATEWAY_DNS/realms/$KEYCLOACK_FC_REALM/.well-known/openid-configuration | jq -rc '.jwks_uri')
```

```
cat <<EOF | openssl x509 -pubkey -noout > key.pem
-----BEGIN CERTIFICATE-----
$(curl $KEYCLOACK_JWKS_URI \
 | jq -r '.keys[] \
 | select(.alg == "RS256").x5c[0]')
-----END CERTIFICATE-----
EOF
```

```
RSA_PUBLIC_KEY=$(awk '{printf "%s\\n", $0}' key.pem)
```

```
cat << EOF | envsubst | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
    name: fc-mod04-consumer-credential-jwk
    labels:
        konghq.com/credential: jwt
stringData:
  algorithm: RS256
  key: http://$KONG_GATEWAY_DNS/realms/fc-mod04
  rsa_public_key: $RSA_PUBLIC_KEY
EOF

```

```
cat << EOF | kubectl apply -f -
apiVersion: configuration.konghq.com/v1
kind: KongConsumer
metadata:
  name: fc-mod04-consumer
  annotations:
   kubernetes.io/ingress.class: kong
username: fc-mod04-consumer
custom_id: fc-mod04-consumer
credentials:
  - fc-mod04-consumer-credential-jwk
EOF
```

```
cat << EOF | kubectl apply -f -
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
    name: fc-mod04-jwt-plugin
plugin: jwt
config:
    key_claim_name: iss
    run_on_preflight: true
    claims_to_verify:
      - exp
EOF
```

```
kubectl annotate ingress httpbin konghq.com/plugins=fc-mod04-jwt-plugin
```
