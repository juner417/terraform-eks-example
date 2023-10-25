# A step of multi-az api design
## IKE api resources(AS-IS)
* clusters (CRUD)
  * clustername
* nodepools (CRUD)
  * nodepoolname
* nodes (CRUD)
  * nodename
* upgrade(R)
  * upgrade versions
* quotas(R)
  * clustername
* service agent(CR)
  * projectid
* internal
  * controlplane network(CRUD)
  * metering(R)

### specs
* clusters
```bash
    clusterCreateRequest:
      properties:
        name:
          example: example
          type: string
        description:
          type: string
        vpcInfo:
          $ref: "#/components/schemas/vpcInfo"
        allocateFIP:
          type: boolean
        version:
          type: string
        isDevCluster:
          type: boolean
      required:
        - name
        - description
        - vpcInfo
        - allocateFIP
        - version
      type: object
```

## aws eks api
* region eks endpoint : https://eks.ap-northeast-2.amazonaws.com:443
* endpoint를 가지고 확인할수 있는 내용 cluster는 region리소스 이다.
* [eks data type](https://docs.aws.amazon.com/ko_kr/eks/latest/APIReference/API_Types.html)

### cluster
```bash
## create cluster request
{
   # 요청 멱등석 보장을 위한 토큰으로 response에 담겨옴(openstack req id와 유사)
   "clientRequestToken": "string",
   # 암호화를 위한 설정, etcd에 저장되는 데이터를 kms의 키로 암호화
   "encryptionConfig": [
      {
         "provider": {
            "keyArn": "string"
         },
         "resources": [ "string" ]
      }
   ],
   # https://docs.aws.amazon.com/ko_kr/eks/latest/APIReference/API_KubernetesNetworkConfigRequest.html
   # k8s 클러스터의  네트워크 컨피그 정보
   "kubernetesNetworkConfig": {
      # ipv4/ipv6
      "ipFamily": "string",
      # service ip cidr
      # k8s는 apiserver의 옵션중 svc(clusterip)에서 사용하는 cidr를 옵션으로 입력받음(--service-cluster-ip-range)
      # aws는 vpc cni를 사용하기 때문에 node,pod과 ip가 곂치면 안됨(다른 구성도 동일한 조건 필요)
      # cluster 생성후 변경 불가
      "serviceIpv4Cidr": "string"
   },
   # https://docs.aws.amazon.com/ko_kr/eks/latest/APIReference/API_Logging.html
   #
   "logging": {
      # https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/control-plane-logs.html
      # control plane에 유저가 접근할수 없는 manged 서비스 구조이므로
      # 로깅에 대한 설정 string array로 type이 "api | audit | authenticator | controllerManager | scheduler"
      "clusterLogging": [
         {
            "enabled": boolean,
            "types": [ "string" ]
         }
      ]
   },
   # cluster name
   "name": "string",

   # outpost 정보들, kic도 구성을 준비하고 있음... 미리 두어야 하나?
   "outpostConfig": {
      "controlPlaneInstanceType": "string",
      "controlPlanePlacement": {
         "groupName": "string"
      },
      "outpostArns": [ "string" ]
   },
   # cluster control plane이 사용하는 vpc 구성 정보
   # user의 vpc 정보, 선택한 subnet(ENI), endpoint access type, sec group
   "resourcesVpcConfig": {
      "endpointPrivateAccess": boolean,
      "endpointPublicAccess": boolean,
      "publicAccessCidrs": [ "string" ],
      "securityGroupIds": [ "string" ],
      "subnetIds": [ "string" ]
   },
   # control plane이 사용자를 대신하여 aws api 작업을 호출할수 있는 권한을 가진 arn 이름
   "roleArn": "string",
   # 리소스 태그
   "tags": {
      "string" : "string"
   },
   # k8s 버전
   "version": "string"
}


## create cluster response
{{
   "cluster": {
      "arn": "string",
      "certificateAuthority": {
         "data": "string"
      },
      "clientRequestToken": "string",
      "connectorConfig": {
         "activationCode": "string",
         "activationExpiry": number,
         "activationId": "string",
         "provider": "string",
         "roleArn": "string"
      },
      "createdAt": number,
      "encryptionConfig": [
         {
            "provider": {
               "keyArn": "string"
            },
            "resources": [ "string" ]
         }
      ],
      "endpoint": "string",
      "health": {
         "issues": [
            {
               "code": "string",
               "message": "string",
               "resourceIds": [ "string" ]
            }
         ]
      },
      "id": "string",
      "identity": {
         "oidc": {
            "issuer": "string"
         }
      },
      "kubernetesNetworkConfig": {
         "ipFamily": "string",
         "serviceIpv4Cidr": "string",
         "serviceIpv6Cidr": "string"
      },
      "logging": {
         "clusterLogging": [
            {
               "enabled": boolean,
               "types": [ "string" ]
            }
         ]
      },
      "name": "string",
      "outpostConfig": {
         "controlPlaneInstanceType": "string",
         "controlPlanePlacement": {
            "groupName": "string"
         },
         "outpostArns": [ "string" ]
      },
      "platformVersion": "string",
      "resourcesVpcConfig": {
         "clusterSecurityGroupId": "string",
         "endpointPrivateAccess": boolean,
         "endpointPublicAccess": boolean,
         "publicAccessCidrs": [ "string" ],
         "securityGroupIds": [ "string" ],
         "subnetIds": [ "string" ],
         "vpcId": "string"
      },
      "roleArn": "string",
      "status": "string",
      "tags": {
         "string" : "string"
      },
      "version": "string"
   }
}
```

#### 실제 데이터
```bash
# response jsondata

{
    "cluster": {
        "name": "gonz-eks-manual-pp",
        "arn": "arn:aws:eks:ap-northeast-2:955637844268:cluster/gonz-eks-manual-pp",
        "createdAt": "2023-04-24T14:07:49.796000+09:00",
        "version": "1.23",
        "endpoint": "https://EB31BB32914C5CE0CBB57CB48A54D35E.sk1.ap-northeast-2.eks.amazonaws.com",
        "roleArn": "arn:aws:iam::955637844268:role/gonz-eks-cluster",
        "resourcesVpcConfig": {
            "subnetIds": [
                "subnet-0ddd4952bb8626031",
                "subnet-074813c93a43a7182",
                "subnet-01f29e37a95d27a03",
                "subnet-0a8e5a6c14b26e894",
                "subnet-00e46ab064cbb9fe7",
                "subnet-029f52b3dbd18a7ff"
            ],
            "securityGroupIds": [],
            "clusterSecurityGroupId": "sg-0890901079ec25d75",
            "vpcId": "vpc-01821523c1618f7be",
            "endpointPublicAccess": true,
            "endpointPrivateAccess": true,
            "publicAccessCidrs": [
                "0.0.0.0/0"
            ]
        },
        "kubernetesNetworkConfig": {
            "serviceIpv4Cidr": "172.20.0.0/16",
            "ipFamily": "ipv4"
        },
        "logging": {
            "clusterLogging": [
                {
                    "types": [
                        "api",
                        "audit",
                        "authenticator",
                        "controllerManager",
                        "scheduler"
                    ],
                    "enabled": true
                }
            ]
        },
        # OpenID Connect 공급자 URL
        "identity": {
            "oidc": {
                "issuer": "https://oidc.eks.ap-northeast-2.amazonaws.com/id/EB31BB32914C5CE0CBB57CB48A54D35E"
            }
        },
        # cluster status
        "status": "ACTIVE",
        # k8s ca
        "certificateAuthority": {
            "data": "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMvakNDQWVhZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJek1EUXlOREExTVRJek5sb1hEVE16TURReU1UQTFNVEl6Tmxvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTHdqCktITUJkK3lkVmYzMFIxWFV3T3ZQRS9jUVY2L3M5czFkeVM5WityYmdxa1VRNGVEYXc2MjA1cEE1T2tjcUVhZTIKdXJVK3dndEpNQXZ1aDVvWnBlVlppQkF1YkxJUGxuZXM0UWJXaFk3RHRXeTRycm5ZZWxwa2hRRTlwdHBjcnZZWQpRazhaMGlReWVLMlMyRG1ZSVFvYnJIZVVTV0tUa2dzWmRucmtSdmo4bDg5eWlleDlwc0IrZGJsanIvbGFVK3NrClFhaWtUbktJakJXZzcxbW9Dc0NnU2NNaEJhWmpYOG1CdHlKOU9zMGdrWS9PbW9HbmFmc05Qd1RMOTk5WXBWdC8KZWw2OGNNcGNNVENNUDdadnVwR0dubGViNWRJVGNHU0UySDlUTHBxbjVIS3dCdHNMaFIwMFpReklVV2F3aTRxaApvVCtRSzRNTWQ3RTMxUXluYThrQ0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZMODB4ZHNkU0RINFM1MTZaN3d3dFd3am9CSFhNQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBRFd5djlIQlY2MmFzRmV2ZTFIYQpvTmVQUmZjNlByNGhwcHBrVSsvYmxvRUxYOGN0eWI5SDJBdFVLaS8rOEVsMUFsSnFkamZBZ0c5SzBQVXRKRk9FClZhVlVUbUhGZ0dUNDNpNFdESVhmZEVtQnFQWEl6bTRzSXpncjFwUW5qUmZ1RUpOUEdINVNnWEtrYml2NHhqcEYKYW9lN0EvMnFIVXdITXhmSGxickNyTWVUL1UzVjQyeS9rMlVJcGZHU2lNMXo1WUtZcjlSNDVPTmhVT3Ayc3JxRgpUSEYyY3AwaFVORmp5UUw5QkxvS090amtKUjk3Myt6TUQydWxyNzVGM2Q3dGl0bGJHQW5PU21FNHBMSzN1QjFDClFyOHhrdFRCak9lamhhYngvZGlXUkp0blkvZVg1aURCVVhTTHBlaGd6SERzWE1sYWp4ZzdqZ3NQMFA5VW81Q2UKdnQ4PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
        },
        # eks platform version
        "platformVersion": "eks.7",
        "tags": {
            "Owner": "owner",
            "Team": "teamname"
        }
    }
}

```
#### 차이
* eks는 cluster의 모든 정보를 가지고 있다.(cluster api cluster CR과 유사)
  * vpc 정보는 둘다 유사하나, sg, endpoint 활성화 부분이 추가되어 있음
  * k8s endpoint 노출과 관련하여 ike도 데이터만 있으면 가능함(pub ip - pri ip 1:1 nat)구조
  * aws iam의 arn 정보가 추가되어 있음
  * k8s 버전 외에 eks platform 버전도 별도로 있음
  * k8s의 clusterip cidr(svc range)도 별도로 있음(vpc cni 때문에 있을것 같음)
  * 로깅에 대한 정보, oidc 정보도 있다.
  * CA(root ca)도 클러스터 정보에 있다.
* cluster api CR의 spec과 vpc 정보를 추가하여 데이터 spec을 정의하면 eks와 유사할 것으로 보인다.
* 좀더 고민해볼 필요가 있는 데이터는
  * iam 관련된 리소스네임은 어떻게 할것인가?(arn)
  * root ca는 제공해야 하는 이유를 좀더 알아볼 필요가 있다.

