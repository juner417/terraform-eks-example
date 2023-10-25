
## aws eks api
* region eks endpoint : https://eks.ap-northeast-2.amazonaws.com:443
* endpoint를 가지고 확인할수 있는 내용 cluster는 region리소스 이다.

## aws eks nodegroup api
* region eks endpoint : https://eks.ap-northeast-2.amazonaws.com:443
* endpoint를 가지고 확인할수 있는 내용 cluster는 region리소스 이다.
* [eks data type](https://docs.aws.amazon.com/ko_kr/eks/latest/APIReference/API_Types.html)

### eks Nodegroup spec
```bash
# request
POST /clusters/name/node-groups HTTP/1.1
Content-type: application/json

{
   # vm image, launchtemplate를 사용하고, custom ami를 사용할 경우 지정할 필요 없음(Required: No)
   "amiType": "string",
   # 노드그룹의 capacity type으로 spot/on-demand(vm) instance인지 구분(Required: No)
   "capacityType": "string",
   # 요청 멱등석 보장을 위한 토큰으로 response에 담겨옴(openstack req id와 유사)
   "clientRequestToken": "string",
   # nodegroup intance root volume size default 20gib (Required: No)
   "diskSize": number,
   # nodegroup에서 사용하는 instance type(flavor)
   "instanceTypes": [ "string" ],
   # k8s node에 적용되는 labels (Required: No)
   "labels": {
      "string" : "string"
   },

   # aws launchtemplate
   # nodegroup 실행시 vm instance template
   "launchTemplate": {
      "id": "string",
      "name": "string",
      "version": "string"
   },
   # unique name (Required: Yes)
   "nodegroupName": "string",
   # nodegroup과 연결한 iam의 역할의 리소스 이름(arn) (Required: Yes)
   # kubelet이 사용자를 대신하여 aws api를 호출함, 노드는 iam 인스턴스 프로필 및 정책을 통해 api 호출 권한을 받음
   # aws는 kubelet이 사용한 iam 권한을 만들어서 그 권한의 리소스 이름을 클러스터 및 노드 그룹을 생성할때 넣어줌
   # launchTemplate와 중복되므로 한곳에만 명시해야 함
   # 상세 내용: https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/create-node-role.html
   # ike service agent와 유사함
   "nodeRole": "string",
   # ami(ec2 image) 버전 default: latest version(Required: No)
   "releaseVersion": "string",
   # ssh 접근을 위한 정보 launchTemplate와 중복되므로 한곳에만 명시해야 함
   "remoteAccess": {
      "ec2SshKey": "string",
      "sourceSecurityGroups": [ "string" ]
   },
   # auto scale group의 상세 스케일 설정(Required: No)
   # https://docs.aws.amazon.com/ko_kr/eks/latest/APIReference/API_NodegroupScalingConfig.html
   "scalingConfig": {
      "desiredSize": number,
      "maxSize": number,
      "minSize": number
   },
   # nodegroup의 생성된 autoscale 그룹에 사용할 subnet(Required: Yes)
   # launchTemplate와 중복되므로 한곳에만 명시해야 함
   "subnets": [ "string" ],
   # nodegroup에 적용되는 tag(분류와 그룹핑의 목적)(Required: No)
   # 노드그룹 태그는 연결된 다른 리소스로 전파되지 않음..(왜지?)
   "tags": {
      "string" : "string"
   },
   # nodegroup의 node에 적용되는 taint 정보
   "taints": [
      {
         "effect": "string",
         "key": "string",
         "value": "string"
      }
   ],
   # nodegroup update를 위한 설정
   # capi machinedeployment spec.stratgy와 유사 https://github.com/kubernetes-sigs/cluster-api/blob/main/api/v1alpha3/machinedeployment_types.go
   "updateConfig": {
      "maxUnavailable": number,
      "maxUnavailablePercentage": number
   },
   # k8s 버전
   # launchTemplate을 사용하고 custom ami를 사용할경우 사용하면 안됨
   # https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/launch-templates.html
   "version": "string"
}

# response
HTTP/1.1 200
Content-type: application/json

{
   "nodegroup": {
      "amiType": "string",
      "capacityType": "string",
      "clusterName": "string",
      "createdAt": number,
      "diskSize": number,
      "health": {
         "issues": [
            {
               "code": "string",
               "message": "string",
               "resourceIds": [ "string" ]
            }
         ]
      },
      "instanceTypes": [ "string" ],
      "labels": {
         "string" : "string"
      },
      "launchTemplate": {
         "id": "string",
         "name": "string",
         "version": "string"
      },
      "modifiedAt": number,
      "nodegroupArn": "string",
      "nodegroupName": "string",
      "nodeRole": "string",
      "releaseVersion": "string",
      "remoteAccess": {
         "ec2SshKey": "string",
         "sourceSecurityGroups": [ "string" ]
      },
      "resources": {
         "autoScalingGroups": [
            {
               "name": "string"
            }
         ],
         "remoteAccessSecurityGroup": "string"
      },
      "scalingConfig": {
         "desiredSize": number,
         "maxSize": number,
         "minSize": number
      },
      "status": "string",
      "subnets": [ "string" ],
      "tags": {
         "string" : "string"
      },
      "taints": [
         {
            "effect": "string",
            "key": "string",
            "value": "string"
         }
      ],
      "updateConfig": {
         "maxUnavailable": number,
         "maxUnavailablePercentage": number
      },
      "version": "string"
   }
}
```

#### 실제 데이터
```bash
# response jsondata
{
    "nodegroup": {
        "nodegroupName": "gonz-eks-manual-pp-ng0",
        "nodegroupArn": "arn:aws:eks:ap-northeast-2:955637844268:nodegroup/gonz-eks-manual-pp/gonz-eks-manual-pp-ng0/88c3d947-e6e6-eb37-e5c0-dea050064413",
        "clusterName": "gonz-eks-manual-pp",
        "version": "1.23",
        "releaseVersion": "1.23.17-20230411",
        "createdAt": "2023-04-24T18:19:44.313000+09:00",
        "modifiedAt": "2023-05-17T00:10:07.380000+09:00",
        "status": "ACTIVE",
        "capacityType": "ON_DEMAND",
        "scalingConfig": {
            "minSize": 2,
            "maxSize": 2,
            "desiredSize": 2
        },
        "instanceTypes": [
            "t3.medium"
        ],
        "subnets": [
            "subnet-0ddd4952bb8626031",
            "subnet-06dcbf9c6790a77b8",
            "subnet-09aacae34b891a3d1",
            "subnet-00e46ab064cbb9fe7"
        ],
        "remoteAccess": {
            "ec2SshKey": "gonz-eks"
        },
        "amiType": "AL2_x86_64",
        "nodeRole": "arn:aws:iam::955637844268:role/gonz-eks-nodegroup",
        "labels": {},
        "resources": {
            "autoScalingGroups": [
                {
                    "name": "eks-gonz-eks-manual-pp-ng0-88c3d947-e6e6-eb37-e5c0-dea050064413"
                }
            ],
            "remoteAccessSecurityGroup": "sg-0730c1596df7f3302"
        },
        "diskSize": 20,
        "health": {
            "issues": []
        },
        "updateConfig": {
            "maxUnavailable": 1
        },
        "tags": {
            "Owner": "owner",
            "Team": "teamname"
        }
    }
}
```

#### 차이
* eks는 launchTemplate, scalingConfig, updateConfig(auto scale), remoteAccess 등 객체로 별도 구분
* cluster api md는 multi az가 반영되지 않음 1:1
  * 데이터 그룹핑이 필요함(autoscale, userdata-template 관련 데이터들)
  * subnet의 정보가 부족함, 정책적인 결정 필요 eks처럼 nodegroup:subnet = 1:n으로 할것인가, 아니면 1:1로 할 것인가
  * eks는 nodegroup이 단일 failure domain이 아니기 때문에 위와 같은 구조로 둔것으로 예상
* status가 필요할까? 있으면 데이터의 상태가 직관적이긴 함(라이프사이클 정의가 필요)
