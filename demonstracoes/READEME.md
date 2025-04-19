# MODULO 03

## DEMONSTRAÇÃO 01

```
aws --region us-east-1 \
     cloudformation create-stack --stack-name fc-m03-d01 \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://modulo-03_demo-01.yaml
```

```
export ALB_RR_DNS_NAME="$(aws --region us-east-1 elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-m03-d01-alb-rr-if`].DNSName | [0]' --output text)"
export ALB_RR_DNS_IP="$(dig  +short $ALB_RR_DNS_NAME | tail -n1)"
clear; echo "$ALB_RR_DNS_NAME > $ALB_RR_DNS_IP"

```

```
clear; curl -fsSL http://$ALB_RR_DNS_NAME | sed -e 's/<[^>]*>//g'
```

```
clear; i=0; while [ $i -lt 20 ]; do echo $i; i=$((i+1)); \
    curl -fsSL http://$ALB_RR_DNS_NAME \
        | sed -e 's/<[^>]*>//g' >> fc-m03-d01-alb-rr-if.log; done; sort fc-m03-d01-alb-rr-if.log | uniq -c

```

```
export ALB_RR_WTD_DNS_NAME="$(aws --region us-east-1 elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-m03-d01-alb-rr-wtd-if`].DNSName | [0]' --output text)"
export ALB_RR_WTD_DNS_IP="$(dig  +short $ALB_RR_WTD_DNS_NAME | tail -n1)"
clear; echo "$ALB_RR_WTD_DNS_NAME > $ALB_RR_WTD_DNS_IP"
```

```
clear; curl -fsSL http://$ALB_RR_WTD_DNS_NAME | sed -e 's/<[^>]*>//g'
```

```
clear; i=0; while [ $i -lt 20 ]; do echo $i; i=$((i+1)); \
    curl -fsSL http://$ALB_RR_WTD_DNS_NAME \
        | sed -e 's/<[^>]*>//g' >> fc-m03-d01-alb-rr-wtd-if.log; done; sort fc-m03-d01-alb-rr-wtd-if.log | uniq -c

```

```
aws --region us-east-1 cloudformation delete-stack --stack-name fc-m03-d01
```

## DEMONSTRAÇÃO 02

```
aws --region us-east-1 \
    cloudformation create-stack --stack-name fc-m03-d02 \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://modulo-03_demo-02.yaml
```

```
export ALB_DNS_NAME="$(aws --region us-east-1 elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-m03-d02-alb-rr-if`].DNSName | [0]' --output text)"
export ALB_DNS_IP="$(dig  +short $ALB_DNS_NAME | tail -n1)"
clear; echo "$ALB_DNS_NAME > $ALB_DNS_IP"
```

```
clear; curl -fsSL http://$ALB_DNS_NAME
```

```
clear; curl -fsSL http://$ALB_DNS_NAME/users
```

```
clear; curl -fsSL --resolve api.laboratorio.com.br:80:$ALB_DNS_IP http://api.laboratorio.com.br/users | sed -e 's/<[^>]*>//g'
```

```
clear; curl -fsSL --resolve laboratorio.com.br:80:$ALB_DNS_IP http://laboratorio.com.br | sed -e 's/<[^>]*>//g'

```

```
aws --region us-east-1 cloudformation delete-stack --stack-name fc-m03-d02
```

## DEMONSTRAÇÃO 03

```
aws --region us-east-1 \
    cloudformation create-stack --stack-name fc-m03-d03-us \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://modulo-03_demo-03-1.yaml \
        --parameters \
            ParameterKey=AvailabilityZones,ParameterValue="us-east-1a\,us-east-1b" \
            ParameterKey=AMI,ParameterValue=ami-084568db4383264d4
```

```
aws --region sa-east-1 \
    cloudformation create-stack --stack-name fc-m03-d03-sa \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://modulo-03_demo-03-1.yaml \
        --parameters \
            ParameterKey=AvailabilityZones,ParameterValue="sa-east-1a\,sa-east-1c" \
            ParameterKey=AMI,ParameterValue=ami-0d866da98d63e2b42
```

```
export ALB_RR_REGION_US="$(aws --region us-east-1 elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-m03-d03-us-alb-rr-if`].DNSName | [0]' --output text)"
export ALB_RR_REGION_BR="$(aws --region sa-east-1 elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-m03-d03-sa-alb-rr-if`].DNSName | [0]' --output text)"
clear; echo "$ALB_RR_REGION_US, $ALB_RR_REGION_BR"
```

```
export HOSTED_ZONE_NAME=<PUBLIC_HOSTED_ZONE_NAME>
```

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

```
clear; i=0; while [ $i -lt 20 ]; do echo $i; i=$((i+1)); \
 curl -fsSL http://weighted.$HOSTED_ZONE_NAME \
 | sed -e 's/<[^>]*>//g' >> fc-m03-d03-r53-weighted.log; done; sort fc-m03-d03-r53-weighted.log | uniq -c
```

```
clear; i=0; while [ $i -lt 20 ]; do echo $i; i=$((i+1)); \
 curl -fsSL http://geo.$HOSTED_ZONE_NAME \
 | sed -e 's/<[^>]*>//g' >> fc-m03-d03-r53-geo.log; done; sort fc-m03-d03-r53-geo.log | uniq -c
```

```
aws --region us-east-1 cloudformation delete-stack --stack-name fc-m03-d03-r53
aws --region us-east-1 cloudformation delete-stack --stack-name fc-m03-d03-us
aws --region sa-east-1 cloudformation delete-stack --stack-name fc-m03-d03-sa
```
