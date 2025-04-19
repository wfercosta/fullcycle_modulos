# MODULO 03

## DEMONSTRAÇÃO 01

```
aws cloudformation create-stack --stack-name fc-modulo03-demo01 \
    --capabilities CAPABILITY_NAMED_IAM \
    --template-body file://modulo-03_demo-01.yaml
```

```
export ALB_RR_DNS_NAME="$(aws elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-modulo03-demo01-alb-rr-if`].DNSName | [0]' --output text)"
export ALB_RR_DNS_IP="$(dig  +short $ALB_RR_DNS_NAME | tail -n1)"
clear; echo "$ALB_RR_DNS_NAME > $ALB_RR_DNS_IP"

```

```
clear; curl -fsSL http://$ALB_RR_DNS_NAME | sed -e 's/<[^>]*>//g'

clear; i=0; while [ $i -lt 20 ]; do echo $i; i=$((i+1)); \
    curl -fsSL http://$ALB_RR_DNS_NAME | sed -e 's/<[^>]*>//g' \
        | sed -e 's/<[^>]*>//g' >> fc-modulo03-demo01-alb-rr-if.log; done; sort fc-modulo03-demo01-alb-rr-if.log | uniq -c

```

```
export ALB_RR_WTD_DNS_NAME="$(aws elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-modulo03-demo01-alb-rr-wtd-if`].DNSName | [0]' --output text)"
export ALB_RR_WTD_DNS_IP="$(dig  +short $ALB_RR_WTD_DNS_NAME | tail -n1)"
clear; echo "$ALB_RR_WTD_DNS_NAME > $ALB_RR_WTD_DNS_IP"
```

```
clear; curl -fsSL http://$ALB_RR_WTD_DNS_NAME | sed -e 's/<[^>]*>//g'

clear; i=0; while [ $i -lt 20 ]; do echo $i; i=$((i+1)); \
    curl -fsSL http://$ALB_RR_WTD_DNS_NAME | sed -e 's/<[^>]*>//g' \
        | sed -e 's/<[^>]*>//g' >> fc-modulo03-demo01-alb-rr-wtd-if.log; done; sort fc-modulo03-demo01-alb-rr-wtd-if.log | uniq -c

```

```
aws cloudformation delete-stack --stack-name fc-modulo03-demo01
```

## DEMONSTRAÇÃO 02

```
aws cloudformation create-stack --stack-name fc-modulo03-demo02 \
    --capabilities CAPABILITY_NAMED_IAM \
    --template-body file://modulo-03_demo-02.yaml
```

```
export ALB_DNS_NAME="$(aws elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-modulo03-demo02-alb-rr-if`].DNSName | [0]' --output text)"
export ALB_DNS_IP="$(dig  +short $ALB_DNS_NAME | tail -n1)"
clear; echo "$ALB_DNS_NAME > $ALB_DNS_IP"
```

```
clear; curl -fsSL http://$ALB_DNS_NAME

clear; curl -fsSL http://$ALB_DNS_NAME/users

clear; curl -fsSL --resolve api.laboratorio.com.br:80:$ALB_DNS_IP http://api.laboratorio.com.br/users | sed -e 's/<[^>]*>//g'

clear; curl -fsSL --resolve laboratorio.com.br:80:$ALB_DNS_IP http://laboratorio.com.br | sed -e 's/<[^>]*>//g'

```

```
aws cloudformation delete-stack --stack-name fc-modulo03-demo02
```

## DEMONSTRAÇÃO 03
