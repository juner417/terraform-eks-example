# eks controle traffic
![eks controlplane](/asset/practice/eks-controlplane.png)

## control plane(in managed vpc)
* eks cluster(control plane)을 생성하면 managed k8s master endpoint가 생성됨
* 위 eks cluster는 k8s master component인 kube-apiserver, kube-controller-manager, kube-scheduler, etcd로 구성된다.
* [eks controlplane architecture](https://aws.github.io/aws-eks-best-practices/reliability/docs/controlplane/) 내용 처럼 2개의 apiserver(with controller, scheduler)와 3개의 외부 etcd로 구성된다.
* 각 컴포넌트(apiserver-최소2개, etcd-최소3개)는 ec2 instance로 실행되고, 3개 이상의 az에 걸쳐 Autoscale group 으로 관리된다.
* 각 컴포넌트 instance는 private subnet에 구성되어 있다. instance에서 외부 인터넷망 접근은 public subnet의 NAT g/w를 통한다.
* 위 구조로 단일 az의 failure가 가용성에 영향이 없도록 한다.
* cluster endpoint(master)는 NLB로 부하 분산을 한다.
* worker node group 과 cluster endpoint간 통신을 위한 eni를 user vpc의 az에 프로비저닝 한다.
* 사용자 및 worker 노드가 퍼블릭 엔드포인트 또는 EKS 관리 ENI를 사용하여 API 서버에 연결하는지 여부에 관계없이 연결을 위한 중복 경로가 있다.

## 각 타입별(public/private/동시) 클러스터 endpoint 확인
* 참고 : [eks cluster networking](https://aws.amazon.com/ko/blogs/containers/de-mystifying-cluster-networking-for-amazon-eks-worker-nodes/)
### public endpoint cluster
* [gonz-eks-pub](https://github.kakaoenterprise.in/gonzales-son/terraform-eks-example/blob/main/eks.tf#L75-L96)
![gonz-eks-pub](/asset/practice/eks-gonz-pub.png)

* https://1368909F748386F16EE96FCE0F49A400.yl4.ap-northeast-2.eks.amazonaws.com

* endpoint dig확인
```bash
> dig 1368909F748386F16EE96FCE0F49A400.yl4.ap-northeast-2.eks.amazonaws.com

; <<>> DiG 9.10.6 <<>> 1368909F748386F16EE96FCE0F49A400.yl4.ap-northeast-2.eks.amazonaws.com
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 13544
;; flags: qr rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
;; QUESTION SECTION:
;1368909F748386F16EE96FCE0F49A400.yl4.ap-northeast-2.eks.amazonaws.com. IN A

;; ANSWER SECTION:
1368909F748386F16EE96FCE0F49A400.yl4.ap-northeast-2.eks.amazonaws.com. 60 IN A 43.200.53.253
1368909F748386F16EE96FCE0F49A400.yl4.ap-northeast-2.eks.amazonaws.com. 60 IN A 52.79.39.107
```

* sts token을 이용하여 kube-apiserver로 요청을 보내본다.
```bash
TOKEN=$(aws --region ap-northeast-2 eks get-token --cluster-name gonz- | jq -r .status.token)

curl -XGET  https://1368909F748386F16EE96FCE0F49A400.yl4.ap-northeast-2.eks.amazonaws.com/api --header "Authorization: Bearer ${TOKEN}" --insecure -kv
```
<details>
  <summary>Click me</summary>

```bash
> curl -XGET  https://1368909F748386F16EE96FCE0F49A400.yl4.ap-northeast-2.eks.amazonaws.com/api --header "Authorization: Bearer ${TOKEN}" --insecure -kv
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 43.200.53.253:443...
* Connected to 1368909F748386F16EE96FCE0F49A400.yl4.ap-northeast-2.eks.amazonaws.com (43.200.53.253) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*  CAfile: /etc/ssl/cert.pem
*  CApath: none
* (304) (OUT), TLS handshake, Client hello (1):
* (304) (IN), TLS handshake, Server hello (2):
* (304) (IN), TLS handshake, Unknown (8):
* (304) (IN), TLS handshake, Request CERT (13):
* (304) (IN), TLS handshake, Certificate (11):
* (304) (IN), TLS handshake, CERT verify (15):
* (304) (IN), TLS handshake, Finished (20):
* (304) (OUT), TLS handshake, Certificate (11):
* (304) (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=kube-apiserver
*  start date: Apr 17 04:15:37 2023 GMT
*  expire date: Apr 16 04:20:01 2024 GMT
*  issuer: CN=kubernetes
*  SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.
* Using HTTP2, server supports multiplexing
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x12e00e800)
> GET /api HTTP/2
> Host: 1368909F748386F16EE96FCE0F49A400.yl4.ap-northeast-2.eks.amazonaws.com
> user-agent: curl/7.79.1
> accept: */*
> authorization: Bearer k8s-aws-v1.aHR0cHM6Ly9zdHMuYXAtbm9ydGhlYXN0LTIuYW1hem9uYXdzLmNvbS8_QWN0aW9uPUdldENhbGxlcklkZW50aXR5JlZlcnNpb249MjAxMS0wNi0xNSZYLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUE1NUFEVUpFV0hGNTdNVEhKJTJGMjAyMzA0MjElMkZhcC1ub3J0aGVhc3QtMiUyRnN0cyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjMwNDIxVDAyMDAzMlomWC1BbXotRXhwaXJlcz02MCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QlM0J4LWs4cy1hd3MtaWQmWC1BbXotU2lnbmF0dXJlPTY1ZDYyNjFhNGZhMjFjYzFmYjc1OTA4OTMxZmU0NTQzMTQxZDkyMjAxNzgwMzE3ODM3MGUyZGE4NDliNDZkM2Y
>
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
< HTTP/2 200
< audit-id: 6b32c954-d390-4163-a5ce-fc8b30c75df9
< cache-control: no-cache, private
< content-type: application/json
< x-kubernetes-pf-flowschema-uid: efdd6f28-c897-4762-b382-a823f0228f8a
< x-kubernetes-pf-prioritylevel-uid: 5e874cd0-18cb-4f54-bdba-6bb5083c887e
< content-length: 219
< date: Fri, 21 Apr 2023 02:02:54 GMT
<
{
  "kind": "APIVersions",
  "versions": [
    "v1"
  ],
  "serverAddressByClientCIDRs": [
    {
      "clientCIDR": "0.0.0.0/0",
      "serverAddress": "ip-172-16-57-254.ap-northeast-2.compute.internal:443"
    }
  ]
* Connection #0 to host 1368909F748386F16EE96FCE0F49A400.yl4.ap-northeast-2.eks.amazonaws.com left intact
}%
```
</details>

<details>
  <summary>curl through public vip </summary>

```bash
> curl -XGET  https://43.200.53.253/api --header "Authorization: Bearer ${TOKEN}" --insecure  -kv
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 43.200.53.253:443...
* Connected to 43.200.53.253 (43.200.53.253) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*  CAfile: /etc/ssl/cert.pem
*  CApath: none
* (304) (OUT), TLS handshake, Client hello (1):
* (304) (IN), TLS handshake, Server hello (2):
* (304) (IN), TLS handshake, Unknown (8):
* (304) (IN), TLS handshake, Request CERT (13):
* (304) (IN), TLS handshake, Certificate (11):
* (304) (IN), TLS handshake, CERT verify (15):
* (304) (IN), TLS handshake, Finished (20):
* (304) (OUT), TLS handshake, Certificate (11):
* (304) (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=kube-apiserver
*  start date: Apr 17 04:15:37 2023 GMT
*  expire date: Apr 16 04:20:01 2024 GMT
*  issuer: CN=kubernetes
*  SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.
* Using HTTP2, server supports multiplexing
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x15280e800)
> GET /api HTTP/2
> Host: 43.200.53.253
> user-agent: curl/7.79.1
> accept: */*
> authorization: Bearer k8s-aws-v1.aHR0cHM6Ly9zdHMuYXAtbm9ydGhlYXN0LTIuYW1hem9uYXdzLmNvbS8_QWN0aW9uPUdldENhbGxlcklkZW50aXR5JlZlcnNpb249MjAxMS0wNi0xNSZYLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUE1NUFEVUpFV0hGNTdNVEhKJTJGMjAyMzA0MjElMkZhcC1ub3J0aGVhc3QtMiUyRnN0cyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjMwNDIxVDE1MzQxN1omWC1BbXotRXhwaXJlcz02MCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QlM0J4LWs4cy1hd3MtaWQmWC1BbXotU2lnbmF0dXJlPTA0MTRhMTlkMjIwZDBmNGVhYjU2NWE4NjdlNjQ4ODVmZTU0ZTJjYTRjNzk2ZGYxYjJlMTQyYTBlZTg5MDllOWM
>
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
< HTTP/2 200
< audit-id: b5625bca-c2cd-4b88-855a-c28f0df8913f
< cache-control: no-cache, private
< content-type: application/json
< x-kubernetes-pf-flowschema-uid: efdd6f28-c897-4762-b382-a823f0228f8a
< x-kubernetes-pf-prioritylevel-uid: 5e874cd0-18cb-4f54-bdba-6bb5083c887e
< content-length: 219
< date: Fri, 21 Apr 2023 15:41:31 GMT
<
{
  "kind": "APIVersions",
  "versions": [
    "v1"
  ],
  "serverAddressByClientCIDRs": [
    {
      "clientCIDR": "0.0.0.0/0",
      "serverAddress": "ip-172-16-57-254.ap-northeast-2.compute.internal:443"
    }
  ]
* Connection #0 to host 43.200.53.253 left intact
}%

> curl -XGET  https://52.79.39.107/api --header "Authorization: Bearer ${TOKEN}" --insecure  -kv
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 52.79.39.107:443...
* Connected to 52.79.39.107 (52.79.39.107) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*  CAfile: /etc/ssl/cert.pem
*  CApath: none
* (304) (OUT), TLS handshake, Client hello (1):
* (304) (IN), TLS handshake, Server hello (2):
* (304) (IN), TLS handshake, Unknown (8):
* (304) (IN), TLS handshake, Request CERT (13):
* (304) (IN), TLS handshake, Certificate (11):
* (304) (IN), TLS handshake, CERT verify (15):
* (304) (IN), TLS handshake, Finished (20):
* (304) (OUT), TLS handshake, Certificate (11):
* (304) (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=kube-apiserver
*  start date: Apr 17 04:15:37 2023 GMT
*  expire date: Apr 16 04:15:37 2024 GMT
*  issuer: CN=kubernetes
*  SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.
* Using HTTP2, server supports multiplexing
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x142813c00)
> GET /api HTTP/2
> Host: 52.79.39.107
> user-agent: curl/7.79.1
> accept: */*
> authorization: Bearer k8s-aws-v1.aHR0cHM6Ly9zdHMuYXAtbm9ydGhlYXN0LTIuYW1hem9uYXdzLmNvbS8_QWN0aW9uPUdldENhbGxlcklkZW50aXR5JlZlcnNpb249MjAxMS0wNi0xNSZYLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUE1NUFEVUpFV0hGNTdNVEhKJTJGMjAyMzA0MjElMkZhcC1ub3J0aGVhc3QtMiUyRnN0cyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjMwNDIxVDE1MzQxN1omWC1BbXotRXhwaXJlcz02MCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QlM0J4LWs4cy1hd3MtaWQmWC1BbXotU2lnbmF0dXJlPTA0MTRhMTlkMjIwZDBmNGVhYjU2NWE4NjdlNjQ4ODVmZTU0ZTJjYTRjNzk2ZGYxYjJlMTQyYTBlZTg5MDllOWM
>
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
< HTTP/2 200
< audit-id: 18efd3a0-99bb-40f5-870a-af2a7a4bfe9c
< cache-control: no-cache, private
< content-type: application/json
< x-kubernetes-pf-flowschema-uid: efdd6f28-c897-4762-b382-a823f0228f8a
< x-kubernetes-pf-prioritylevel-uid: 5e874cd0-18cb-4f54-bdba-6bb5083c887e
< content-length: 220
< date: Fri, 21 Apr 2023 15:42:25 GMT
<
{
  "kind": "APIVersions",
  "versions": [
    "v1"
  ],
  "serverAddressByClientCIDRs": [
    {
      "clientCIDR": "0.0.0.0/0",
      "serverAddress": "ip-172-16-173-248.ap-northeast-2.compute.internal:443"
    }
  ]
* Connection #0 to host 52.79.39.107 left intact
}%

```
</details>

* cluster endpoint의 domain으로 api call을 하면 resolving 된 public ip로 요청을 보냄
* ```domain -> public vip(maybe nlb) -> ec2 instance```
* 위처럼 트래픽이 흐르는 것같다...(좀더 확인은 필요)
* cluster endpoint의 domain으로 계속 요청을 해도 public ip(nlb vip)는 변경이 없다.
* 2개의 public ip로 각각 k8s api를 호출하면 다른 ec2 intance의 private domain(.internal)이 serverAddress의 값으로 나옴.
* 1개의 public ip는 매번 같은 ec2 intance의 private domain(.internal) 값을 serverAddress로 보여준다.(혹시나 vip가 아닐수도 있다는 의심 가능, 그렇다면 문서에서 nlb를 사용하고 있다는 말은 거짓인가?)
    * autoscale group을 lb의 target으로 지정하여 연결했을 가능성이 있다. [내용](https://docs.aws.amazon.com/autoscaling/ec2/userguide/attach-load-balancer-asg.html)
* apiserver cert는 1년 기한(kubeadm default)

![eks-gonz-pub-eni](/asset/practice/eks-gonz-pub-eni.png)
* cluster가 생성되면, 해당 cluster의 subnet 중에 2개를 선택하여 ENI가 2개 만들어지고, master-kubelet은 해당 ENI로 통신함
    * master-kubelet 통신을 위한 ENI는 설명에 "Amazon EKS CLUSTER_NAME"으로 설정되어 있고, instance에 assign되진 않는다. 추가로 보조 프라이빗 ip도 없다.
    * public endpoint의 경우, 이 ENI에 public vip가 endpoint domain에 매핑되었을것으로 짐작했는데 아니다.
    * private endpoint의 경우, 이 ENI의 private ip가 endpoint domain에 매핑되어 있다.
    * [ENI](https://docs.aws.amazon.com/ko_kr/AWSEC2/latest/UserGuide/using-eni.html#enis-generalpurpose)

### nodegroup의 worker는 cluster endpoint(kube-apiserver)와 어떻게 통신할까?
```bash
# dig 정보
1368909F748386F16EE96FCE0F49A400.yl4.ap-northeast-2.eks.amazonaws.com. 60 IN A 43.200.53.253
1368909F748386F16EE96FCE0F49A400.yl4.ap-northeast-2.eks.amazonaws.com. 60 IN A 52.79.39.107

# eni private ip 정보
10.0.95.229
10.0.20.41

# kubeapiserver serveraddr 정보
43.200.53.253 -> ip-172-16-57-254.ap-northeast-2.compute.internal:443
52.79.39.107 -> ip-172-16-173-248.ap-northeast-2.compute.internal:443

10.0.95.229 -> ip-172-16-173-248.ap-northeast-2.compute.internal:443
10.0.20.41 -> ip-172-16-57-254.ap-northeast-2.compute.internal:443
```

```bash
# worker node 에서 위 ip들로 tcpdump를 이용하여 트래픽 확인
[root@ip-10-0-105-163 ~]# tcpdump dst 10.0.95.229 and  tcp port 443 -nn
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
09:45:42.934459 IP 10.0.105.163.36338 > 10.0.95.229.443: Flags [.], ack 366601281, win 443, options [nop,nop,TS val 1468955533 ecr 174089829], length 0
09:46:12.935248 IP 10.0.105.163.36338 > 10.0.95.229.443: Flags [P.], seq 0:39, ack 1, win 443, options [nop,nop,TS val 1468985533 ecr 174089829], length 39
09:46:12.935558 IP 10.0.105.163.36338 > 10.0.95.229.443: Flags [.], ack 40, win 443, options [nop,nop,TS val 1468985534 ecr 174119831], length 0
09:46:13.966079 IP 10.0.105.163.36338 > 10.0.95.229.443: Flags [.], ack 4167, win 443, options [nop,nop,TS val 1468986564 ecr 174120861], length 0
09:46:13.966201 IP 10.0.105.163.36338 > 10.0.95.229.443: Flags [P.], seq 39:74, ack 4167, win 443, options [nop,nop,TS val 1468986564 ecr 174120861], length 35
09:46:13.967104 IP 10.0.105.163.36338 > 10.0.95.229.443: Flags [.], ack 6355, win 443, options [nop,nop,TS val 1468986565 ecr 174120862], length 0

[root@ip-10-0-105-163 ~]# ip a show eth0
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP group default qlen 1000
    link/ether 0a:01:63:2f:22:ac brd ff:ff:ff:ff:ff:ff
    inet 10.0.105.163/20 brd 10.0.111.255 scope global dynamic eth0
       valid_lft 3359sec preferred_lft 3359sec
    inet6 fe80::801:63ff:fe2f:22ac/64 scope link
       valid_lft forever preferred_lft forever
[root@ip-10-0-105-163 ~]# ip a show eth0
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP group default qlen 1000
    link/ether 0a:01:63:2f:22:ac brd ff:ff:ff:ff:ff:ff
    inet 10.0.105.163/20 brd 10.0.111.255 scope global dynamic eth0
       valid_lft 3343sec preferred_lft 3343sec
    inet6 fe80::801:63ff:fe2f:22ac/64 scope link
       valid_lft forever preferred_lft forever

# client port로 프로세스 확인
[root@ip-10-0-105-163 ~]# ss -natp | grep  36338
ESTAB     0      0       10.0.105.163:36338      172.20.0.1:443   users:(("aws-k8s-agent",pid=3301,fd=7))

# 해당 트래픽은 aws-vpc-cni
[root@ip-10-0-105-163 ~]# ps -ef | grep 3301
root      3301  3286  0  4월18 ?      00:04:03 ./aws-k8s-agent | tee -i aws-k8s-agent.log 2>&1
root     26220 17504  0 10:00 pts/0    00:00:00 grep --color=auto 3301
[root@ip-10-0-105-163 ~]# ps -ef | grep 3286
root      3286  2988  0  4월18 ?      00:00:00 /app/aws-vpc-cni
root      3301  3286  0  4월18 ?      00:04:03 ./aws-k8s-agent | tee -i aws-k8s-agent.log 2>&1
root     26322 17504  0 10:00 pts/0    00:00:00 grep --color=auto 3286
[root@ip-10-0-105-163 ~]# ps -ef | grep 2988
root      2988     1  0  4월18 ?      00:09:58 /usr/bin/containerd-shim-runc-v2 -namespace k8s.io -id a81881fe0c2444c23775ab47f498f41f6ea81c1341c78dc1341698e806148b92 -address /run/containerd/containerd.sock
65535     3028  2988  0  4월18 ?      00:00:00 /pause
root      3286  2988  0  4월18 ?      00:00:00 /app/aws-vpc-cni
root     26352 17504  0 10:00 pts/0    00:00:00 grep --color=auto 2988

[ec2-user@ip-10-0-105-163 ~]$ sudo lsof -p 3301
aws-k8s-a 3301 root    7u     IPv4  22514      0t0      TCP ip-10-0-105-163.ap-northeast-2.compute.internal:36338->ip-172-20-0-1.ap-northeast-2.compute.internal:https (ESTABLISHED)

# 얼라? aws는 k8s svc ip도 vpc dns resolver에서 모두 리졸빙해주네...
# 이것도 aws-node deploy pod들이 해주는건가? 나중에 확인 필요
~/dev/kubemgr/gonz-eks-pub on master !1 ?1                                                                      at kube gonz-eks-pub at 00:24:24
> k get svc -A
NAMESPACE     NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)         AGE
default       kubernetes      ClusterIP   172.20.0.1      <none>        443/TCP         8d
default       nginx-service   ClusterIP   172.20.44.213   <none>        80/TCP          4d
kube-system   kube-dns        ClusterIP   172.20.0.10     <none>        53/UDP,53/TCP   8d

[ec2-user@ip-10-0-105-163 ~]$ dig ip-172-20-44-213.ap-northeast-2.compute.internal

;; ANSWER SECTION:
ip-172-20-44-213.ap-northeast-2.compute.internal. 60 IN	A 172.20.44.213

;; Query time: 1 msec
;; SERVER: 10.0.0.2#53(10.0.0.2)
...
```
* [build file](https://github.com/aws/amazon-vpc-cni-k8s/blob/3294231c0dce52cfe473bf6c62f47956a3b333b6/Makefile#L135-L139)
* [vpc cni main](https://github.com/aws/amazon-vpc-cni-k8s/blob/f3859a56cffa22cff07c541b1c95ec8d32c9bb18/cmd/aws-vpc-cni/main.go#L362)

```bash
# 위에서 client port로 프로세스확인시 dest에 172.20.0.1을 기준으로 찾아 보자.
> k get service kubernetes
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   172.20.0.1   <none>        443/TCP   7d11h

# 위 서비스는 k8s의 in-cluster 접근시 사용하는 endpoint(kubernetes.default.svc.cluster.local)이다.
[ec2-user@ip-10-0-105-163 ~]$ sudo iptables -L -n -t nat  | grep default/kubernetes
KUBE-MARK-MASQ  all  --  10.0.20.41           0.0.0.0/0            /* default/kubernetes:https */
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            /* default/kubernetes:https */ tcp to:10.0.20.41:443
KUBE-MARK-MASQ  all  --  10.0.95.229          0.0.0.0/0            /* default/kubernetes:https */
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            /* default/kubernetes:https */ tcp to:10.0.95.229:443
KUBE-SVC-NPX46M4PTMTKRN6Y  tcp  --  0.0.0.0/0            172.20.0.1           /* default/kubernetes:https cluster IP */ tcp dpt:443
KUBE-SEP-5UMKMGJMUDXCXVAP  all  --  0.0.0.0/0            0.0.0.0/0            /* default/kubernetes:https -> 10.0.20.41:443 */ statistic mode random probability 0.50000000000
KUBE-SEP-CQ7WW6ZVSX2XUWDS  all  --  0.0.0.0/0            0.0.0.0/0            /* default/kubernetes:https -> 10.0.95.229:443 */

# iptables를 이용하여 확인해 보면 eni의 private ip의 NAT룰이 추가되어 있는것을 확인할수 있다.
# 위와 같다는 것은 kubectl로 default namespace의 svc,ep를 같이 확인해도 동일하게 확인 가능하다.
> k get service,ep
NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/kubernetes      ClusterIP   172.20.0.1      <none>        443/TCP   7d11h
service/nginx-service   ClusterIP   172.20.44.213   <none>        80/TCP    3d

NAME                      ENDPOINTS                                                           AGE
endpoints/kubernetes      10.0.20.41:443,10.0.95.229:443                                      7d11h
endpoints/nginx-service   10.0.100.108:8080,10.0.100.119:8080,10.0.103.62:8080 + 47 more...   3d
```
* vpc cni는 in-cluster config를 이용하여 ENI를 이용하여 통신을 한다.


```bash
[root@ip-10-0-105-163 ~]# tcpdump tcp port 443 -nn
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
15:59:22.790215 IP 43.200.53.253.443 > 10.0.105.163.35144: Flags [P.], seq 1616803828:1616803966, ack 3038070625, win 2594, options [nop,nop,TS val 4008059658 ecr 1747006961], length 138
15:59:22.790279 IP 10.0.105.163.35144 > 43.200.53.253.443: Flags [.], ack 138, win 11790, options [nop,nop,TS val 1747023543 ecr 4008059658], length 0
...
15:59:23.400494 IP 10.0.105.163.46370 > 43.200.53.253.443: Flags [P.], seq 216986868:216986909, ack 214100059, win 443, options [nop,nop,TS val 1747024153 ecr 4008056352], length 41
15:59:23.400528 IP 10.0.105.163.46370 > 43.200.53.253.443: Flags [P.], seq 41:668, ack 1, win 443, options [nop,nop,TS val 1747024153 ecr 4008056352], length 627
15:59:23.401437 IP 43.200.53.253.443 > 10.0.105.163.46370: Flags [.], ack 41, win 2594, options [nop,nop,TS val 4008060269 ecr 1747024153], length 0
15:59:23.401437 IP 43.200.53.253.443 > 10.0.105.163.46370: Flags [.], ack 668, win 2591, options [nop,nop,TS val 4008060269 ecr 1747024153], length 0
...
# client port 36338은 제거하고(vpc cni), 46370,35144를 확인해 보자.
[root@ip-10-0-105-163 ~]# ss -ntap | grep 46370
ESTAB     0      0       10.0.105.163:46370   43.200.53.253:443   users:(("kubelet",pid=2865,fd=16))
[root@ip-10-0-105-163 ~]# ss -natp | grep 35144
ESTAB     0      0       10.0.105.163:35144   43.200.53.253:443   users:(("kube-proxy",pid=3126,fd=11))

# kubeproxy와 kubelet이다. 해당 프로세스는 모두 kube-apiserver와 통신이 필요한 프로세스이다.(svc ip iptable rule 제어, node의 리소스 모니터링 및 제어)
# 두 프로세스 모두 cluster public endpoint를 이용하여 public 통신을 한다.
# pid로 커넥션을 확인해 보자.
[root@ip-10-0-105-163 ~]# lsof -p 2865
...
kubelet 2865 root   16u     IPv4              20221       0t0     TCP ip-10-0-105-163.ap-northeast-2.compute.internal:46370->ec2-43-200-53-253.ap-northeast-2.compute.amazonaws.com:https (ESTABLISHED)
# fd, port, dest 확인
[root@ip-10-0-105-163 ~]# lsof -p 3126
kube-prox 3126 root   11u     IPv4  21123      0t0      TCP ip-10-0-105-163.ap-northeast-2.compute.internal:35144->ec2-43-200-53-253.ap-northeast-2.compute.amazonaws.com:https (ESTABLISHED)

```
* worker -> master로의 트래픽은 public endpoint일 경우, [public vip를 이용하여 커넥션을 맺는다](https://aws.amazon.com/ko/blogs/containers/de-mystifying-cluster-networking-for-amazon-eks-worker-nodes/).

```bash
#local에서 master를 통해 노드의 로그를 확인하고, worker의 tcpdump를 해보자.
# public cluster endpoint시 master -> worker 트래픽 확인
> k logs -f -n kube-system aws-node-chhq8
Defaulted container "aws-node" out of: aws-node, aws-vpc-cni-init (init)
Installed /host/opt/cni/bin/aws-cni
Installed /host/opt/cni/bin/egress-v4-cni
time="2023-04-18T15:04:28Z" level=info msg="Starting IPAM daemon... "
time="2023-04-18T15:04:28Z" level=info msg="Checking for IPAM connectivity... "
time="2023-04-18T15:04:29Z" level=info msg="Copying config file... "
time="2023-04-18T15:04:29Z" level=info msg="Successfully copied CNI plugin binary and config file."

# worker
[root@ip-10-0-105-163 ~]# tcpdump tcp port 10250 -nn
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
16:11:47.471826 IP 10.0.20.41.42562 > 10.0.105.163.10250: Flags [S], seq 2267041613, win 64240, options [mss 1460,sackOK,TS val 3023109565 ecr 0,nop,wscale 7], length 0
16:11:47.471905 IP 10.0.105.163.10250 > 10.0.20.41.42562: Flags [S.], seq 3326597998, ack 2267041614, win 62643, options [mss 8961,sackOK,TS val 1625466556 ecr 3023109565,nop,wscale 7], length 0
16:11:47.472864 IP 10.0.20.41.42562 > 10.0.105.163.10250: Flags [.], ack 1, win 502, options [nop,nop,TS val 3023109566 ecr 1625466556], length 0
16:11:47.473109 IP 10.0.20.41.42562 > 10.0.105.163.10250: Flags [P.], seq 1:258, ack 1, win 502, options [nop,nop,TS val 3023109567 ecr 1625466556], length 257
16:11:47.473132 IP 10.0.105.163.10250 > 10.0.20.41.42562: Flags [.], ack 258, win 488, options [nop,nop,TS val 1625466557 ecr 3023109567], length 0
16:11:47.473529 IP 10.0.105.163.10250 > 10.0.20.41.42562: Flags [P.], seq 1:1280, ack 258, win 488, options [nop,nop,TS val 1625466558 ecr 3023109567], length 1279
16:11:47.474439 IP 10.0.20.41.42562 > 10.0.105.163.10250: Flags [.], ack 1280, win 501, options [nop,nop,TS val 3023109568 ecr 1625466558], length 0
16:11:47.478138 IP 10.0.20.41.42562 > 10.0.105.163.10250: Flags [P.], seq 258:1461, ack 1280, win 501, options [nop,nop,TS val 3023109572 ecr 1625466558], length 1203
16:11:47.478270 IP 10.0.20.41.42562 > 10.0.105.163.10250: Flags [P.], seq 1461:1547, ack 1280, win 501, options [nop,nop,TS val 3023109572 ecr 1625466558], length 86
16:11:47.478353 IP 10.0.20.41.42562 > 10.0.105.163.10250: Flags [P.], seq 1547:1662, ack 1280, win 501, options [nop,nop,TS val 3023109572 ecr 1625466558], length 115
16:11:47.478545 IP 10.0.105.163.10250 > 10.0.20.41.42562: Flags [.], ack 1662, win 478, options [nop,nop,TS val 1625466563 ecr 3023109572], length 0
16:11:47.478638 IP 10.0.105.163.10250 > 10.0.20.41.42562: Flags [P.], seq 1280:1335, ack 1662, win 478, options [nop,nop,TS val 1625466563 ecr 3023109572], length 55
16:11:47.478741 IP 10.0.105.163.10250 > 10.0.20.41.42562: Flags [P.], seq 1335:1379, ack 1662, win 478, options [nop,nop,TS val 1625466563 ecr 3023109572], length 44
16:11:47.479606 IP 10.0.20.41.42562 > 10.0.105.163.10250: Flags [P.], seq 1662:1693, ack 1335, win 501, options [nop,nop,TS val 3023109573 ecr 1625466563], length 31
16:11:47.484182 IP 10.0.105.163.10250 > 10.0.20.41.42562: Flags [P.], seq 1379:1435, ack 1693, win 478, options [nop,nop,TS val 1625466568 ecr 3023109573], length 56
16:11:47.485575 IP 10.0.105.163.10250 > 10.0.20.41.42562: Flags [P.], seq 1435:1502, ack 1693, win 478, options [nop,nop,TS val 1625466570 ecr 3023109573], length 67
16:11:47.485605 IP 10.0.105.163.10250 > 10.0.20.41.42562: Flags [P.], seq 1502:1575, ack 1693, win 478, options [nop,nop,TS val 1625466570 ecr 3023109573], length 73
16:11:47.485636 IP 10.0.105.163.10250 > 10.0.20.41.42562: Flags [P.], seq 1575:1676, ack 1693, win 478, options [nop,nop,TS val 1625466570 ecr 3023109573], length 101
16:11:47.485676 IP 10.0.105.163.10250 > 10.0.20.41.42562: Flags [P.], seq 1676:2018, ack 1693, win 478, options [nop,nop,TS val 1625466570 ecr 3023109573], length 342
16:11:47.485826 IP 10.0.20.41.42562 > 10.0.105.163.10250: Flags [.], ack 1435, win 501, options [nop,nop,TS val 3023109579 ecr 1625466563], length 0
16:11:47.486598 IP 10.0.20.41.42562 > 10.0.105.163.10250: Flags [.], ack 2018, win 501, options [nop,nop,TS val 3023109580 ecr 1625466570], length 0
16:12:02.513043 IP 10.0.105.163.10250 > 10.0.20.41.42562: Flags [.], ack 1693, win 478, options [nop,nop,TS val 1625481597 ecr 3023109580], length 0
16:12:02.514092 IP 10.0.20.41.42562 > 10.0.105.163.10250: Flags [.], ack 2018, win 501, options [nop,nop,TS val 3023124608 ecr 1625466570], length 0
```
* ENI private ip를 통해서 [worker의 kubelet으로 트래픽이 들어옴](https://aws.amazon.com/ko/blogs/containers/de-mystifying-cluster-networking-for-amazon-eks-worker-nodes/)

### private endpoint cluster
* [gonz-eks-pri](https://github.kakaoenterprise.in/gonzales-son/terraform-eks-example/blob/main/eks.tf#L163-L186)
![gonz-eks-pub](/asset/practice/eks-gonz-pri.png)

* https://F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com
* private endpoint cluster로 접근하려면 cluster가 생성된 vpc와 동일한 vpc의 bastion host(그외 DX,VPN,vpc peering 등 vpc에 접근 가능한 연결)가 있어야 한다.

* endpoint dig확인
```bash
> dig F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com

;; ANSWER SECTION:
F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com. 60 IN A 10.0.58.12
F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com. 60 IN A 10.0.18.90
```

* sts token을 이용하여 kube-apiserver로 요청을 보내본다.
```bash
TOKEN=$(aws --region ap-northeast-2 eks get-token --cluster-name gonz-eks-manual-pri | jq -r .status.token)

curl -XGET  https://F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com/api --header "Authorization: Bearer ${TOKEN}" --insecure -kv
```
<details>
  <summary>Click me</summary>

```bash
ubuntu@ip-10-0-38-197:~$ hostname -f
ip-10-0-38-197.ap-northeast-2.compute.internal
ubuntu@ip-10-0-38-197:~$ curl -XGET  https://F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com/api --header "Authorization: Bearer ${TOKEN}" --insecure  -vvv
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 10.0.18.90:443...
* Connected to F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com (10.0.18.90) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* TLSv1.0 (OUT), TLS header, Certificate Status (22):
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.2 (IN), TLS header, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.2 (IN), TLS header, Finished (20):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Request CERT (13):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.2 (OUT), TLS header, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.3 (OUT), TLS handshake, Certificate (11):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=kube-apiserver
*  start date: Apr 24 05:14:45 2023 GMT
*  expire date: Apr 23 05:14:45 2024 GMT
*  issuer: CN=kubernetes
*  SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.
* Using HTTP2, server supports multiplexing
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* Using Stream ID: 1 (easy handle 0x557c979586c0)
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
> GET /api HTTP/2
> Host: F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com
> user-agent: curl/7.81.0
> accept: */*
> authorization: Bearer k8s-aws-v1.aHR0cHM6Ly9zdHMuYXAtbm9ydGhlYXN0LTIuYW1hem9uYXdzLmNvbS8_QWN0aW9uPUdldENhbGxlcklkZW50aXR5JlZlcnNpb249MjAxMS0wNi0xNSZYLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUE1NUFEVUpFV0hGNTdNVEhKJTJGMjAyMzA0MjUlMkZhcC1ub3J0aGVhc3QtMiUyRnN0cyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjMwNDI1VDA5MjcwNlomWC1BbXotRXhwaXJlcz02MCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QlM0J4LWs4cy1hd3MtaWQmWC1BbXotU2lnbmF0dXJlPWJlOTM3MmE5NDg0NGFjNDIxZDA2OWI4YzRlZGI1NWM1ZGVhZDgxZWQyYTQwMTEwOGM0YWQxNTk5OWRmZDM1YjM
>
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
< HTTP/2 200
< audit-id: c67f508d-3322-4c21-a6bc-a4321e7c97e8
< cache-control: no-cache, private
< content-type: application/json
< x-kubernetes-pf-flowschema-uid: 3d7564d2-c1cc-49c0-b0a4-9753e25dc0f7
< x-kubernetes-pf-prioritylevel-uid: a18a653d-53af-47a6-8dd6-cd4b6602424b
< content-length: 219
< date: Tue, 25 Apr 2023 09:28:52 GMT
<
* TLSv1.2 (IN), TLS header, Supplemental data (23):
{
  "kind": "APIVersions",
  "versions": [
    "v1"
  ],
  "serverAddressByClientCIDRs": [
    {
      "clientCIDR": "0.0.0.0/0",
      "serverAddress": "ip-172-16-56-186.ap-northeast-2.compute.internal:443"
    }
  ]
* Connection #0 to host F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com left intact
}

ubuntu@ip-10-0-38-197:~$ curl -XGET  https://F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com/api --header "Authorization: Bearer ${TOKEN}" --insecure  -vvv
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 10.0.58.12:443...
* Connected to F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com (10.0.58.12) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* TLSv1.0 (OUT), TLS header, Certificate Status (22):
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.2 (IN), TLS header, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.2 (IN), TLS header, Finished (20):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Request CERT (13):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.2 (OUT), TLS header, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.3 (OUT), TLS handshake, Certificate (11):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=kube-apiserver
*  start date: Apr 24 05:14:45 2023 GMT
*  expire date: Apr 23 05:19:56 2024 GMT
*  issuer: CN=kubernetes
*  SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.
* Using HTTP2, server supports multiplexing
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* Using Stream ID: 1 (easy handle 0x559a126a76c0)
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
> GET /api HTTP/2
> Host: F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com
> user-agent: curl/7.81.0
> accept: */*
> authorization: Bearer k8s-aws-v1.aHR0cHM6Ly9zdHMuYXAtbm9ydGhlYXN0LTIuYW1hem9uYXdzLmNvbS8_QWN0aW9uPUdldENhbGxlcklkZW50aXR5JlZlcnNpb249MjAxMS0wNi0xNSZYLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUE1NUFEVUpFV0hGNTdNVEhKJTJGMjAyMzA0MjUlMkZhcC1ub3J0aGVhc3QtMiUyRnN0cyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjMwNDI1VDEwMjIwMFomWC1BbXotRXhwaXJlcz02MCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QlM0J4LWs4cy1hd3MtaWQmWC1BbXotU2lnbmF0dXJlPTA4YmE4NmM3ZjMyZmQ4NmNkZGY3NzUwYjFmM2I3NTNhZDJhNTU3MGM4ODY1ZjAzZGZlZWU3NzYwNzVjNzNlYzE
>
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
< HTTP/2 200
< audit-id: e919d723-2a30-4147-963b-ad37ea96da39
< cache-control: no-cache, private
< content-type: application/json
< x-kubernetes-pf-flowschema-uid: 3d7564d2-c1cc-49c0-b0a4-9753e25dc0f7
< x-kubernetes-pf-prioritylevel-uid: a18a653d-53af-47a6-8dd6-cd4b6602424b
< content-length: 220
< date: Tue, 25 Apr 2023 10:22:03 GMT
<
* TLSv1.2 (IN), TLS header, Supplemental data (23):
{
  "kind": "APIVersions",
  "versions": [
    "v1"
  ],
  "serverAddressByClientCIDRs": [
    {
      "clientCIDR": "0.0.0.0/0",
      "serverAddress": "ip-172-16-121-126.ap-northeast-2.compute.internal:443"
    }
  ]
* Connection #0 to host F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com left intact
}
```

</details>

<details>
  <summary>curl through private vip </summary>

```bash
dig F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com
...
;; ANSWER SECTION:
F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com. 60 IN A 10.0.18.90
F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com. 60 IN A 10.0.58.12

ubuntu@ip-10-0-38-197:~$ curl -XGET  https://10.0.18.90/api --header "Authorization: Bearer ${TOKEN}" --insecure  -vvv
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 10.0.18.90:443...
* Connected to 10.0.18.90 (10.0.18.90) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* TLSv1.0 (OUT), TLS header, Certificate Status (22):
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.2 (IN), TLS header, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.2 (IN), TLS header, Finished (20):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Request CERT (13):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.2 (OUT), TLS header, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.3 (OUT), TLS handshake, Certificate (11):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=kube-apiserver
*  start date: Apr 24 05:14:45 2023 GMT
*  expire date: Apr 23 05:14:45 2024 GMT
*  issuer: CN=kubernetes
*  SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.
* Using HTTP2, server supports multiplexing
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* Using Stream ID: 1 (easy handle 0x557400fa96c0)
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
> GET /api HTTP/2
> Host: 10.0.18.90
> user-agent: curl/7.81.0
> accept: */*
> authorization: Bearer k8s-aws-v1.aHR0cHM6Ly9zdHMuYXAtbm9ydGhlYXN0LTIuYW1hem9uYXdzLmNvbS8_QWN0aW9uPUdldENhbGxlcklkZW50aXR5JlZlcnNpb249MjAxMS0wNi0xNSZYLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUE1NUFEVUpFV0hGNTdNVEhKJTJGMjAyMzA0MjUlMkZhcC1ub3J0aGVhc3QtMiUyRnN0cyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjMwNDI1VDEwMjIwMFomWC1BbXotRXhwaXJlcz02MCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QlM0J4LWs4cy1hd3MtaWQmWC1BbXotU2lnbmF0dXJlPTA4YmE4NmM3ZjMyZmQ4NmNkZGY3NzUwYjFmM2I3NTNhZDJhNTU3MGM4ODY1ZjAzZGZlZWU3NzYwNzVjNzNlYzE
>
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
< HTTP/2 200
< audit-id: 09f6a1a1-fcff-4ef4-8f45-06acaeb4428b
< cache-control: no-cache, private
< content-type: application/json
< x-kubernetes-pf-flowschema-uid: 3d7564d2-c1cc-49c0-b0a4-9753e25dc0f7
< x-kubernetes-pf-prioritylevel-uid: a18a653d-53af-47a6-8dd6-cd4b6602424b
< content-length: 219
< date: Tue, 25 Apr 2023 10:27:24 GMT
<
* TLSv1.2 (IN), TLS header, Supplemental data (23):
{
  "kind": "APIVersions",
  "versions": [
    "v1"
  ],
  "serverAddressByClientCIDRs": [
    {
      "clientCIDR": "0.0.0.0/0",
      "serverAddress": "ip-172-16-56-186.ap-northeast-2.compute.internal:443"
    }
  ]
* Connection #0 to host 10.0.18.90 left intact
}

while [ TRUE ]; do curl -XGET  https:///10.0.58.12/api --header "Authorization: Bearer ${TOKEN}" --insecure  -vvv; sleep 0.2 ; done

*   Trying 10.0.58.12:443...
* Connected to 10.0.58.12 (10.0.58.12) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* TLSv1.0 (OUT), TLS header, Certificate Status (22):
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.2 (IN), TLS header, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.2 (IN), TLS header, Finished (20):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Request CERT (13):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.2 (OUT), TLS header, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.3 (OUT), TLS handshake, Certificate (11):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=kube-apiserver
*  start date: Apr 24 05:14:45 2023 GMT
*  expire date: Apr 23 05:19:56 2024 GMT
*  issuer: CN=kubernetes
*  SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.
* Using HTTP2, server supports multiplexing
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* Using Stream ID: 1 (easy handle 0x5650320e66c0)
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
> GET /api HTTP/2
> Host: 10.0.58.12
> user-agent: curl/7.81.0
> accept: */*
> authorization: Bearer k8s-aws-v1.aHR0cHM6Ly9zdHMuYXAtbm9ydGhlYXN0LTIuYW1hem9uYXdzLmNvbS8_QWN0aW9uPUdldENhbGxlcklkZW50aXR5JlZlcnNpb249MjAxMS0wNi0xNSZYLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUE1NUFEVUpFV0hGNTdNVEhKJTJGMjAyMzA0MjUlMkZhcC1ub3J0aGVhc3QtMiUyRnN0cyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjMwNDI1VDEwMjIwMFomWC1BbXotRXhwaXJlcz02MCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QlM0J4LWs4cy1hd3MtaWQmWC1BbXotU2lnbmF0dXJlPTA4YmE4NmM3ZjMyZmQ4NmNkZGY3NzUwYjFmM2I3NTNhZDJhNTU3MGM4ODY1ZjAzZGZlZWU3NzYwNzVjNzNlYzE
>
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
< HTTP/2 200
< audit-id: 9fc59bb7-932f-4c86-ae5a-665def362113
< cache-control: no-cache, private
< content-type: application/json
< x-kubernetes-pf-flowschema-uid: 3d7564d2-c1cc-49c0-b0a4-9753e25dc0f7
< x-kubernetes-pf-prioritylevel-uid: a18a653d-53af-47a6-8dd6-cd4b6602424b
< content-length: 220
< date: Tue, 25 Apr 2023 10:29:32 GMT
<
* TLSv1.2 (IN), TLS header, Supplemental data (23):
{
  "kind": "APIVersions",
  "versions": [
    "v1"
  ],
  "serverAddressByClientCIDRs": [
    {
      "clientCIDR": "0.0.0.0/0",
      "serverAddress": "ip-172-16-121-126.ap-northeast-2.compute.internal:443"
    }
  ]
* Connection #0 to host 10.0.58.12 left intact
}

```

</details>

* cluster endpoint의 domain으로 api call을 하면 resolving 된 private ip로 요청을 보냄
* ```domain -> private ip(ENI) -> ec2 instance```
>> 10.0.58.12 -> ip-172-16-121-126.ap-northeast-2.compute.internal:443
>> 10.0.18.90 -> ip-172-16-56-186.ap-northeast-2.compute.internal:443
* cluster endpoint의 domain으로 계속 요청을 해도 private ip(ENI private ip)는 변경이 없다.
* 2개의 ENI private ip로 각각 k8s api를 호출하면 다른 ec2 intance의 private domain(.internal)이 serverAddress의 값으로 나옴.(로드발란싱이 아님 1:1)
* 1개의 private ip는 매번 같은 ec2 intance의 private domain(.internal) 값을 serverAddress로 보여준다.(혹시나 vip가 아닐수도 있다는 의심 가능, 그렇다면 문서에서 nlb를 사용하고 있다는 말은 거짓인가?)
    * autoscale group을 lb의 target으로 지정하여 연결했을 가능성이 있다. [내용](https://docs.aws.amazon.com/autoscaling/ec2/userguide/attach-load-balancer-asg.html)
* apiserver cert는 1년 기한(kubeadm default)

* ENI 확인
![eks-gonz-pri-eni](/asset/practice/eks-gonz-pri-eni.png)
```bash
# eks-gonz-manual-private cluster endpoint ENI ip
10.0.58.12
10.0.18.90
```
* cluster가 생성되면, 해당 cluster의 subnet 중에 2개를 선택하여 ENI가 2개 만들어지고, master-kubelet은 해당 ENI로 통신함
    * master-kubelet 통신을 위한 ENI는 설명에 "Amazon EKS CLUSTER_NAME"으로 설정되어 있고, instance에 assign되진 않는다. 추가로 보조 프라이빗 ip도 없다.
    * private endpoint cluster의 경우, 이 ENI의 private ip가 endpoint domain에 매핑되어 있다.
    * [ENI](https://docs.aws.amazon.com/ko_kr/AWSEC2/latest/UserGuide/using-eni.html#enis-generalpurpose)

### nodegroup의 worker는 cluster endpoint(kube-apiserver)와 어떻게 통신할까?
```bash
# dig 정보
F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com. 60 IN A 10.0.18.90
F14DED698CE1583E19D28678B846C0CD.yl4.ap-northeast-2.eks.amazonaws.com. 60 IN A 10.0.58.12

# eni private ip 정보
10.0.58.12
10.0.18.90

# kubeapiserver serveraddr 정보
10.0.58.12 -> ip-172-16-121-126.ap-northeast-2.compute.internal:443
10.0.18.90 -> ip-172-16-56-186.ap-northeast-2.compute.internal:443
```

```bash
# worker node 에서 위 ip들로 tcpdump를 이용하여 트래픽 확인
[ec2-user@ip-10-0-24-97 ~]$ ip a show eth0
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP group default qlen 1000
    link/ether 02:5c:e4:b6:5f:ce brd ff:ff:ff:ff:ff:ff
    inet 10.0.24.97/20 brd 10.0.31.255 scope global dynamic eth0
       valid_lft 2604sec preferred_lft 2604sec
    inet6 fe80::5c:e4ff:feb6:5fce/64 scope link
       valid_lft forever preferred_lft forever

[root@ip-10-0-24-97 ~]# tcpdump dst 10.0.18.90 and tcp port 443 -nn
13:07:47.224979 IP 10.0.24.97.45788 > 10.0.18.90.443: Flags [P.], seq 1389741884:1389741925, ack 1897157345, win 443, options [nop,nop,TS val 3034776865 ecr 2597157080], length 41
13:08:05.214361 IP 10.0.24.97.55134 > 10.0.18.90.443: Flags [.], ack 485141919, win 2734, options [nop,nop,TS val 3108903674 ecr 2597176368], length 0
...
14:58:58.268243 IP 10.0.24.97.53578 > 10.0.58.12.443: Flags [.], ack 1143, win 443, options [nop,nop,TS val 404729595 ecr 4234259224], length 0

# client port 로 프로세스 확인
[root@ip-10-0-24-97 ~]# ss -natp | grep 45788
ESTAB     0      0         10.0.24.97:45788      10.0.18.90:443   users:(("kubelet",pid=3074,fd=38))
[root@ip-10-0-24-97 ~]# ss -natp | grep 53578
ESTAB     0      0         10.0.24.97:53578   10.0.58.12:443   users:(("kube-proxy",pid=3746,fd=11))
[root@ip-10-0-24-97 ~]# sudo ss -natp | grep 55134
ESTAB     0      0         10.0.24.97:55134      172.20.0.1:443   users:(("aws-k8s-agent",pid=4218,fd=8))

# aws vpc cni 프로세스 확인
[root@ip-10-0-24-97 ~]# ps -ef | grep 4218
root      4218  4156  0 Apr24 ?        00:00:54 ./aws-k8s-agent
[root@ip-10-0-24-97 ~]# ps -ef | grep 4156
root      4156  4134  0 Apr24 ?        00:00:00 bash /app/entrypoint.sh
root      4218  4156  0 Apr24 ?        00:00:54 ./aws-k8s-agent
root      4219  4156  0 Apr24 ?        00:00:00 tee -i aws-k8s-agent.log
[root@ip-10-0-24-97 ~]# ps -ef | grep 4134
root      4134     1  0 Apr24 ?        00:02:07 /usr/bin/containerd-shim-runc-v2 -namespace moby -id d077348e83ee4316494fb285e230c85fe9432ccaa91e5f4c1d47b8cdb5ac0296 -address /run/containerd/containerd.sock
root      4156  4134  0 Apr24 ?        00:00:00 bash /app/entrypoint.sh


[root@ip-10-0-24-97 ~]# lsof -p 4218
...
aws-k8s-a 4218 root    8u     IPv4  23471      0t0      TCP ip-10-0-24-97.ap-northeast-2.compute.internal:55134->ip-172-20-0-1.ap-northeast-2.compute.internal:https (ESTABLISHED)

# iptables nat rule
[root@ip-10-0-24-97 ~]#iptables -L -n -t nat | grep "default/kubernetes"v
KUBE-MARK-MASQ  all  --  10.0.18.90           0.0.0.0/0            /* default/kubernetes:https */
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            /* default/kubernetes:https */ tcp to:10.0.18.90:443
KUBE-MARK-MASQ  all  --  10.0.58.12           0.0.0.0/0            /* default/kubernetes:https */
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            /* default/kubernetes:https */ tcp to:10.0.58.12:443
KUBE-SVC-NPX46M4PTMTKRN6Y  tcp  --  0.0.0.0/0            172.20.0.1           /* default/kubernetes:https cluster IP */ tcp dpt:443
KUBE-SEP-L4UPTJXVD7SP66Y7  all  --  0.0.0.0/0            0.0.0.0/0            /* default/kubernetes:https */ statistic mode random probability 0.50000000000
KUBE-SEP-NPBLJGMVCYWGRDPS  all  --  0.0.0.0/0            0.0.0.0/0            /* default/kubernetes:https */

# iptables를 이용하여 확인해 보면 eni의 private ip의 NAT룰이 추가되어 있는것을 확인할수 있다.
# 위와 같다는 것은 kubectl로 default namespace의 svc,ep를 같이 확인해도 동일하게 확인 가능하다.
ubuntu@ip-10-0-38-197:~$ kubectl get svc,ep -n default
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   172.20.0.1   <none>        443/TCP   34h

NAME                   ENDPOINTS                       AGE
endpoints/kubernetes   10.0.18.90:443,10.0.58.12:443   34h

# aws-node(vpc-cni)는 private endpoint도 public endpoint 클러스터와 동일하게 svc ip로 접근한다.
# 172.20.0.1 -> iptables -> nat -> 10.0.18.90/10.0.58.12
# 여기도 동일하게 k8s svc ip(clusterip)가 vpc dns resolver에서 ip 조회가 가능함
```
* vpc cni는 in-cluster config를 이용하여 ENI를 이용하여 통신을 한다.

```bash
# aws node(vpc cni) 제외, kubelet,kube-proxy가 어떻게 통신하는지 확인
# kubelet
[root@ip-10-0-24-97 ~]# lsof -p 3074
kubelet 3074 root   38u     IPv4              21257       0t0     TCP ip-10-0-24-97.ap-northeast-2.compute.internal:45788->ip-10-0-18-90.ap-northeast-2.compute.internal:https (ESTABLISHED)

# kube-proxy
[root@ip-10-0-24-97 ~]# lsof -p 3746
kube-prox 3746 root   11u     IPv4  20140      0t0      TCP ip-10-0-24-97.ap-northeast-2.compute.internal:53578->ip-10-0-58-12.ap-northeast-2.compute.internal:https (ESTABLISHED)
```
* worker -> master로의 트래픽은 public endpoint cluster와 동일하다. 다만 kubelet, kube-proxy가 ENI의 ip(private ip)로 커넥션을 맺고 있다.

```bash
ubuntu@ip-10-0-38-197:~$ kubectl logs -f -n kube-system aws-node-2pxr6
Defaulted container "aws-node" out of: aws-node, aws-vpc-cni-init (init)
{"level":"info","ts":"2023-04-24T05:29:00.753Z","caller":"entrypoint.sh","msg":"Validating env variables ..."}
{"level":"info","ts":"2023-04-24T05:29:00.755Z","caller":"entrypoint.sh","msg":"Install CNI binaries.."}
{"level":"info","ts":"2023-04-24T05:29:00.771Z","caller":"entrypoint.sh","msg":"Starting IPAM daemon in the background ... "}
{"level":"info","ts":"2023-04-24T05:29:00.779Z","caller":"entrypoint.sh","msg":"Checking for IPAM connectivity ... "}
{"level":"info","ts":"2023-04-24T05:29:02.794Z","caller":"entrypoint.sh","msg":"Retrying waiting for IPAM-D"}
{"level":"info","ts":"2023-04-24T05:29:02.851Z","caller":"entrypoint.sh","msg":"Copying config file ... "}
{"level":"info","ts":"2023-04-24T05:29:02.861Z","caller":"entrypoint.sh","msg":"Successfully copied CNI plugin binary and config file."}
{"level":"info","ts":"2023-04-24T05:29:02.865Z","caller":"entrypoint.sh","msg":"Foregrounding IPAM daemon ..."}

[root@ip-10-0-24-97 ~]# tcpdump tcp port 10250 -nn
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
16:10:26.569169 IP 10.0.18.90.56978 > 10.0.24.97.10250: Flags [S], seq 145358660, win 64240, options [mss 1460,sackOK,TS val 2608117723 ecr 0,nop,wscale 7], length 0
16:10:26.569248 IP 10.0.24.97.10250 > 10.0.18.90.56978: Flags [S.], seq 2040645225, ack 145358661, win 62643, options [mss 8961,sackOK,TS val 3045736209 ecr 2608117723,nop,wscale 7], length 0
16:10:26.570211 IP 10.0.18.90.56978 > 10.0.24.97.10250: Flags [.], ack 1, win 502, options [nop,nop,TS val 2608117724 ecr 3045736209], length 0
16:10:26.570607 IP 10.0.18.90.56978 > 10.0.24.97.10250: Flags [P.], seq 1:240, ack 1, win 502, options [nop,nop,TS val 2608117724 ecr 3045736209], length 239
16:10:26.570632 IP 10.0.24.97.10250 > 10.0.18.90.56978: Flags [.], ack 240, win 488, options [nop,nop,TS val 3045736211 ecr 2608117724], length 0
```
* master -> worker 통신은 [ENI(private ip - 10.0.58.12/10.0.18.90)를 통해 들어옴](https://aws.amazon.com/ko/blogs/containers/de-mystifying-cluster-networking-for-amazon-eks-worker-nodes/)

### public/private endpoint cluster
* public/private endpoint를 모두 존재함
* 외부 client에서 cluster로 접근할 경우, public vip를 통해서 접근
* worker -> master는 ENI private ip를 통해서 접근
* master -> worker도 ENI private ip를 통해서 접근

## node group 을 subnet별로 증가 시켜 cluster endpoint가 늘어나는지 확인
* 이건 총 4개의 az에 pub/private 8개의 subnet별로 nodegroup을 만들었는데 늘어나지 않음

## cluster endpoint의 부하를 줘서 scale이 되는지 확인
*
