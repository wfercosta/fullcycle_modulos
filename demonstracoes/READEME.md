# MÓDULO 03 - BALANCEAMENTO DE CARGA E ROTEAMENTO

## INTRODUÇÃO

### PRÉ-REQUISITOS

Caso você queira executar estas demonstrações no seu ambiente você precisará ter:

- Conta na Amazon Web Services (AWS);
- Credenciais de acesso a AWS, com permissões suficientes para:

  - Administrar manutenção de VPC, subnets, route tables, internet gateway e NAT gateways;
  - Administrar manutenção de instâncias EC2, Load Balancers e Security Groups;
  - Administrar manutenção de DNS com Route53;

- [AWS CLI](https://docs.aws.amazon.com/pt_br/streams/latest/dev/setup-awscli.html) devidamente configurado com as credenciais de acesso;

- Uma Public Hosted Zone configurada na conta para realização de testes de _Policy-based Routing_;

### DISCLAIMER

Como as demonstrações são com base no uso de recursos criados a partir dos serviços da Amazon Web Services (AWS), pode haver a ocorrência de custos pelo período de consumo pelos mesmos.

## DEMONSTRAÇÃO 01

### OBJETIVO

Nesta primeira demonstração iremos observar o comportamento de dois balanceadores de carga, onde um estará trabalhando no modo **Round Robin** e o outro no modo **Weighted Round Robin**, onde definimos um peso no balanceamento para cada workload definido no balanceador.

### EXECUÇÃO

Como primeiro passo, começamos realizando o provisionamento da infraestrutura do experimento:

```
aws --region us-east-1 \
     cloudformation create-stack --stack-name fc-m03-d01 \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://modulo-03_demo-01.yaml
```

Uma vez finalizado o provisionamento, usando o AWS CLI, vamos recuperar algumas informações do nosso ALB Round Robin:

```
export ALB_RR_DNS_NAME="$(aws --region us-east-1 elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-m03-d01-alb-rr-if`].DNSName | [0]' --output text)"
export ALB_RR_DNS_IP="$(dig  +short $ALB_RR_DNS_NAME | tail -n1)"
clear; echo "$ALB_RR_DNS_NAME > $ALB_RR_DNS_IP"

```

Uma vez com as informações, conseguimos executar um primeiro teste para validar o nosso ambiente:

```
clear; curl -fsSL http://$ALB_RR_DNS_NAME | sed -e 's/<[^>]*>//g'
```

Para demonstrar o comportamento do ALB em modo Round Robin, podemos coletar uma amostragem de requisições para comparação:

```
clear; i=0; while [ $i -lt 20 ]; do echo $i; i=$((i+1)); \
    curl -fsSL http://$ALB_RR_DNS_NAME \
        | sed -e 's/<[^>]*>//g' >> fc-m03-d01-alb-rr-if.log; done; sort fc-m03-d01-alb-rr-if.log | uniq -c

```

Agora podemos repetir o processo com o nosso ALB que está configurado com balanceamento com base em peso:

```
export ALB_RR_WTD_DNS_NAME="$(aws --region us-east-1 elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-m03-d01-alb-rr-wtd-if`].DNSName | [0]' --output text)"
export ALB_RR_WTD_DNS_IP="$(dig  +short $ALB_RR_WTD_DNS_NAME | tail -n1)"
clear; echo "$ALB_RR_WTD_DNS_NAME > $ALB_RR_WTD_DNS_IP"
```

Podemos realizar um teste para validar o nosso ambiente:

```
clear; curl -fsSL http://$ALB_RR_WTD_DNS_NAME | sed -e 's/<[^>]*>//g'
```

Assim como anterior, vamos coletar uma amostragem de requisições para comparação:

```
clear; i=0; while [ $i -lt 20 ]; do echo $i; i=$((i+1)); \
    curl -fsSL http://$ALB_RR_WTD_DNS_NAME \
        | sed -e 's/<[^>]*>//g' >> fc-m03-d01-alb-rr-wtd-if.log; done; sort fc-m03-d01-alb-rr-wtd-if.log | uniq -c

```

Por final, vamos fazer o cleanup do nosso ambiente e remover todos os recursos:

```
aws --region us-east-1 cloudformation delete-stack --stack-name fc-m03-d01
```

## DEMONSTRAÇÃO 02

### OBJETIVO

Nesta segunda demonstração iremos observar o comportamento de um balanceador de carga, cujo estará trabalhando no modo **Round Robin**, porém, com definições de regras de roteamento, sendo elas Hosted-based, Path-based e rota de fallback (default).

### EXECUÇÃO

Como primeiro passo, começamos realizando o provisionamento da infraestrutura do experimento:

```
aws --region us-east-1 \
    cloudformation create-stack --stack-name fc-m03-d02 \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://modulo-03_demo-02.yaml
```

Uma vez finalizado o provisionamento, usando o AWS CLI, vamos recuperar algumas informações do nosso ALB:

```
export ALB_DNS_NAME="$(aws --region us-east-1 elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-m03-d02-alb-rr-if`].DNSName | [0]' --output text)"
export ALB_DNS_IP="$(dig  +short $ALB_DNS_NAME | tail -n1)"
clear; echo "$ALB_DNS_NAME > $ALB_DNS_IP"
```

Para demonstrar o primeiro comportamento, iremos realizar uma requisição direta ao DNS que recuperamos. Como não temos regras de roteamento que atenda esta requisição é esperado que seja retornado um status code 404:

```
clear; curl -fsSL http://$ALB_DNS_NAME
```

Para reforçar o entendimento do comportamento, mesmo com um path conhecido, pelo fato da requisição não ter a completude dos critérios de roteamento definidos, também é esperado termos um status code 404:

```
clear; curl -fsSL http://$ALB_DNS_NAME/users
```

Agora, para avaliarmos usando todos os critérios e usando um DNS inexistente, podemos nos basear no parâmetro `--resolve` do comando `curl`, onde podemos pedir para que ele resolva o DNS da requisição usando o endereço de **IP** que recuperamos no passo anterior com a ajuda do comando `dig`, onde é esperado que o **node2** responda a requisição:

```
clear; curl -fsSL --resolve api.laboratorio.com.br:80:$ALB_DNS_IP http://api.laboratorio.com.br/users | sed -e 's/<[^>]*>//g'
```

Usando a mesma abordagem, podemos testar o outro critério de roteamento, onde esperamos que o **node1** responda a requisição:

```
clear; curl -fsSL --resolve laboratorio.com.br:80:$ALB_DNS_IP http://laboratorio.com.br | sed -e 's/<[^>]*>//g'

```

Por final, vamos fazer o cleanup do nosso ambiente e remover todos os recursos:

```
aws --region us-east-1 cloudformation delete-stack --stack-name fc-m03-d02
```

## DEMONSTRAÇÃO 03

### OBJETIVO

Para a última demonstração iremos observar o comportamento referente à **Smart Routing** ou **Policy-Based Routing**, neste contexto usando o serviço do **Route53** da AWS. Neste laboratório iremos provisionar duas infraestruturas iguais, porém em regiões diferentes, no caso, **us-east-1** que seria Norte Virgínia, Estados Unidos; e **sa-east-1** que no caso é São Paulo, Brasil.

### EXECUÇÃO

Como primeiro passo, começamos realizando o provisionamento da infraestrutura do experimento em **us-east-1**:

```
aws --region us-east-1 \
    cloudformation create-stack --stack-name fc-m03-d03-us \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://modulo-03_demo-03-1.yaml \
        --parameters \
            ParameterKey=AvailabilityZones,ParameterValue="us-east-1a\,us-east-1b" \
            ParameterKey=AMI,ParameterValue=ami-084568db4383264d4
```

E na sequência, ou ao mesmo tempo que o passo anterior, iremos realizar o mesmo provisionamento porém em **sa-east-1**:

```
aws --region sa-east-1 \
    cloudformation create-stack --stack-name fc-m03-d03-sa \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://modulo-03_demo-03-1.yaml \
        --parameters \
            ParameterKey=AvailabilityZones,ParameterValue="sa-east-1a\,sa-east-1c" \
            ParameterKey=AMI,ParameterValue=ami-0d866da98d63e2b42
```

Uma vez finalizado ambos os provisionamentos, podemos executar o script na sequência, para recuperarmos os DNS de ambos os balanceadores de carga, pois são necessários para fazermos a configuração de roteamento:

```
export ALB_RR_REGION_US="$(aws --region us-east-1 elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-m03-d03-us-alb-rr-if`].DNSName | [0]' --output text)"
export ALB_RR_REGION_BR="$(aws --region sa-east-1 elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-m03-d03-sa-alb-rr-if`].DNSName | [0]' --output text)"
clear; echo "$ALB_RR_REGION_US, $ALB_RR_REGION_BR"
```

Neste passo é requerido que você tenha um DNS válido e já configurado em uma **Public Hosted Zone** na AWS:

```
export HOSTED_ZONE_NAME=<PUBLIC_HOSTED_ZONE_NAME>
```

Uma vez definido o valor da variável de `export`, iremos provisionar a configuração de dois subdomínios, no caso **weighted** e **geo**, cujo são duas **routing policies** de comportamentos diferentes:

```
aws --region us-east-1 \
    cloudformation create-stack --stack-name fc-m03-d03-r53 \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://modulo-03_demo-03-2.yaml \
        --parameters \
            ParameterKey=HostedZone,ParameterValue="$HOSTED_ZONE_NAME" \
            ParameterKey=ResourceRecordUS,ParameterValue="$ALB_RR_REGION_US" \
            ParameterKey=ResourceRecordBR,ParameterValue="$ALB_RR_REGION_BR"

```

Para o primeiro teste, iremos validar a **routing policy** baseada em peso (**weighted**), onde é esperado um roteamento com distribuição de 50% para cada região:

```
clear; i=0; while [ $i -lt 20 ]; do echo $i; i=$((i+1)); \
 curl -fsSL http://weighted.$HOSTED_ZONE_NAME \
 | sed -e 's/<[^>]*>//g' >> fc-m03-d03-r53-weighted.log; done; sort fc-m03-d03-r53-weighted.log | uniq -c
```

Para o último teste, iremos validar a **routing policy** baseada em localidade geográfica (**geo location**), onde é esperado um roteamento de 100% para **sa-east-1**, caso você esteja no Brasil:

```
clear; i=0; while [ $i -lt 20 ]; do echo $i; i=$((i+1)); \
 curl -fsSL http://geo.$HOSTED_ZONE_NAME \
 | sed -e 's/<[^>]*>//g' >> fc-m03-d03-r53-geo.log; done; sort fc-m03-d03-r53-geo.log | uniq -c
```

Por final, vamos fazer o cleanup do nosso ambiente e remover todos os recursos:

```
aws --region us-east-1 cloudformation delete-stack --stack-name fc-m03-d03-r53
aws --region us-east-1 cloudformation delete-stack --stack-name fc-m03-d03-us
aws --region sa-east-1 cloudformation delete-stack --stack-name fc-m03-d03-sa
```
