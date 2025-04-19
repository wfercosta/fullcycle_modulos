# MODULO 03

## DEMONSTRAÇÃO 01

```
aws cloudformation create-stack --stack-name fc-modulo03-demo01 \
    --capabilities CAPABILITY_NAMED_IAM \
    --template-body file://modulo-03_demo-01.yaml
```

```
echo "curl -fsSL http://$(aws elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-modulo03-demo01-alb-rr-if`].DNSName | [0]' --output text)" \
        | bash | sed -e 's/<[^>]*>//g'

```

```
clear; i=0; while [ $i -lt 20 ]; do echo $i; i=$((i+1)); \
    curl -fsSL "http://$(aws elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-modulo03-demo01-alb-rr-if`].DNSName | [0]' --output text)" \
        | sed -e 's/<[^>]*>//g' >> fc-modulo03-demo01-alb-rr-if.log; done; sort fc-modulo03-demo01-alb-rr-if.log | uniq -c

```

```
echo "curl -fsSL http://$(aws elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-modulo03-demo01-alb-rr-wtd-if`].DNSName | [0]' --output text)" \
        | bash | sed -e 's/<[^>]*>//g'

```

```
clear; i=0; while [ $i -lt 20 ]; do echo $i; i=$((i+1)); \
    curl -fsSL "http://$(aws elbv2 describe-load-balancers \
            --query 'LoadBalancers[?LoadBalancerName==`fc-modulo03-demo01-alb-rr-wtd-if`].DNSName | [0]' --output text)" \
        | sed -e 's/<[^>]*>//g' >> fc-modulo03-demo01-alb-rr-wtd-if.log; done; sort fc-modulo03-demo01-alb-rr-wtd-if.log | uniq -c

```

```
aws cloudformation delete-stack --stack-name fc-modulo03-demo01
```
