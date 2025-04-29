# MÓDULO 04 - SEGURANÇA AVANÇADA NO API GATEWAY

## INTRODUÇÃO

### PRÉ-REQUISITOS

Caso você queira executar estas demonstrações no seu ambiente você precisará ter:

- Conta na Amazon Web Services (AWS);
- Credenciais de acesso a AWS, com permissões suficientes para:

  - Administrar manutenção de VPC, subnets, route tables, internet gateway e NAT gateways;
  - Administrar manutenção de instâncias EC2, Load Balancers e Security Groups;
  - Administrar manutenção de clusters EKS;

- [AWS CLI](https://docs.aws.amazon.com/pt_br/streams/latest/dev/setup-awscli.html) devidamente configurado com as credenciais de acesso;

### DISCLAIMER

Como as demonstrações são com base no uso de recursos criados a partir dos serviços da Amazon Web Services (AWS), pode haver a ocorrência de custos pelo período de consumo pelos mesmos.

## CONFIGURACAO BASE

### OBJETIVO

Nesta primeira etapa, vamos realizar uma configuração básica de um cluster Kubnernetes na AWS usando o serviço do EKS que irá servir de base para execução dos laboratórios deste módulo.

### EXECUÇÃO

Como primeiro passo, começamos realizando o provisionamento da infraestrutura inicial:

```
aws --region us-east-1 \
     cloudformation create-stack --stack-name fc-mod04-eks-cluster \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://modulo-04_base.yaml
```

```
aws eks update-kubeconfig --name fc-mod04-eks-cluster
```

```
helm repo add kong https://charts.konghq.com
helm repo update
```

```
helm install kong kong/kong --namespace kong --create-namespace \
  --set proxy.type=LoadBalancer \
  --set proxy.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --set proxy.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing"
```

Por final, vamos fazer o cleanup do nosso ambiente e remover todos os recursos:

```
aws --region us-east-1 cloudformation delete-stack --stack-name fc-mod04-eks-cluster
```
