# EKS practice

## eks cluster
* aws elastic kubernetes service
* managed service 형태로
  * kubernetes control plane(apiserver, controller-manager, scheduler, etcd)을 별도의 managed vpc에 구성하여 endpoint만 제공한다.
  * worker node(kubelet)은 user vpc 내부에 subnet에 nodegroup을 생성하여 스케일 및 템플레이트를 관리한다.

![eks diagram](/asset/practice/eks-diagram.png)
![eks controlplane](/asset/practice/eks-controlplane.png)
![eks diagram system](/asset/practice/eks-diagram-system.png)

### 특징
* kubernetes control plane이 endpoint로 제공되는데 public/private/모두 3가지 형태로 제공 가능하며, 사용자가 클러스터 생성시 지정가능함(default: public)
* private endpoint의 경우 사용자의 vpc의 subnet에서 port(ip)를 선택하여 endpoint domain에 a type으로 레코드로 등록됨
* 클러스터 생성시 2개 이상의 서로 다른 az의 subnet을 지정해야 한다(지정 안할경우 클러스터 생성 안됨)
  * 클러스터 생성시 지정한 서로 다른 az의 subnet을 기반으로 private endpoint가 나옴(private 클러스터일 경우)
  * 클러스터 생성시 지정한 서로 다른 az의 subnet을 기반으로 ENI가 배치됨(master-worker간 통신용)
* 노드 그룹을 생성할때 프라이빗 서브넷을 지정해도 NAT g/w가 지정안되어 있으면 클러스터 api랑 통신이 안되어 노드 조인이 안된다.[user guide](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
* vpc에 dns 호스트 이름 지원(vpc 옵션)이 되어야 클러스터 조인이 가능하다(이 옵션은 vpc 생성시 default이므로 큰 문제는 없을듯)
  * 리소스 기반의 이름 지정(domain)은 eks에서 지원하지 않음(아마 중복 가능성이 있기 때문이라고 짐작됨)
* subnet은 eks에서 사용할 ip주소가 6개 이상 있어야 함(min req), 16개 이상이 있는것을 추천

* [awsevent](https://www.youtube.com/watch?v=7vxDWDD2YnM&ab_channel=AWSEvents)
* [eksbestpractice](https://aws.github.io/aws-eks-best-practices/reliability/docs/controlplane/)
