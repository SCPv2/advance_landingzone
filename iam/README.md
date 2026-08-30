# Identity & Access Management

## 실습 도구

**&#128906; 실습 도구 설치**

- 작업 디렉토리 생성 및 작업 환경 가져오기
  ```powershell
  mkdir c:\scpv2lab
  cd c:\scpv2lab
  
  # c:\scpv2lab을 사용자 PATH에 등록
  $d='C:\scpv2lab'; $p=[Environment]::GetEnvironmentVariable('Path','User'); if($p -split ';' -notcontains $d){[Environment]::SetEnvironmentVariable('Path',($p.TrimEnd(';')+';'+$d),'User')}; $env:Path+=";$d"
  
  # Advance LandingZone 실습 챕터 실습 파일 가져오기
  git clone https://github.com/SCPv2/advance_landingzone.git
  ```

- Samsung Cloud Platform CLI 및 Terraform 환경 설정

  아래 파일을 다운로드해서 작업 디렉토리(C:\scpv2lab)에 저장
  
  CLI 다운로드 : https://docs.e.samsungsdscloud.com/clireference/cli-common/
  
  Terraform 다운로드 : https://developer.hashicorp.com/terraform/install

## 실습 환경 배포

**&#128906; 사용자 변수 입력** (c:\scpv2lab\advancevariables.tf)  
 -  variables.tf 수정  
    ```powershell
      
    edit C:\scpv2lab\advance_landingzone\iam\variables.tf
    ```
    your_public _ip : 실습자가 사용하고 있는 PC의 Public IP 주소  
    your_account_id : 실습자가 접속하고 있는 Samsung Cloud Platform의 Account ID
    ```hcl
    variable "user_public_ip" {
      type    = string
      default = "your_public_ip"
    }
    
    variable "iam_account_id" {
      type    = string
      default = "your_account_id"
    }
    ```

**&#128906; Terraform 자원 배포 템플릿 실행** 

```poweshell
terraform init
terraform validate
terraform plan

terraform apply --auto-approve

# Key Pair 파일 추출 (mykey.pem)
terraform output -raw keypair_private_key > mykey.pem 

# Key Pair 파일 권한 수정
icacls mykey.pem /inheritance:r /grant:r "$($env:USERNAME):R"

```

## 환경 및 작업 검토

- Architecture Diagram 검토

- IAM 사용자 목록 및 권한 연결 상태

**&#128906; 사용자 및 정책 구성 목표**

- 기존 주체 수정
  
|부서|유형|이름|기존 정책|변경 정책|인증 유형|접근 IP|  
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|   
|개발팀|사용자|Alex|AdministratorAccess||||   
|개발팀|사용자|Robert|AdministratorAccess||||  
|개발팀|사용자|Scott|AdministratorAccess|DBAccess(Custom)|모든 인증|사내 IP|  
|운영팀|사용자|Jeff|AdministratorAccess|AdministratorAccess|모든 인증|사내 IP|  

- 신규 주체 생성

|부서|유형|이름|기존 정책|변경 정책|인증 유형|접근 IP|  
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|  
|개발팀|그룹|DeveloperGroup|신규|DeveloperAccess(Custom)|인증키|사내 IP|  
|외부회사|역할|Steven|None|WebDevAccess(Custom)|모든 인증|외부회사 IP|  

- 사용자 정의 정책

|정책명|인증 유형|정책|  
|:-----:|:-----:|:-----:|    
|DBAccess|모든 인증|VPC/Firewall/Security Group/DirectConnect 전체 허용|  
|DeveloperAccess|인증키|Virtual Server(ceweb,ceapp)전체 허용|  
|WebDevAccess|모든 인증|Virtual Server(ceweb)Read/List/Update, 외부회사 IP|  
|NetworkAccessPolicy|모든 인증|전체 서비스/모든 자원,거부,모든 IP 적용(사내 IP 제외)|
|AccessKeyAccess|모든 인증|Identity Access Management AccessKey액션만 허용, 사내 IP|

## 사용자, 사용자 그룹, 사용자 정의 정책 구성(개발자 정책)

**&#128906; Jeff(Cloud Engineer) 콘솔**

- 과도하게 부여된 사용자 정책 조정  
  IAM AdministratorAccess에서 불필요 사용자 제외

- 개발자 정책 생성
  - 정책명 : `DeveloperAccess`
  - 서비스 : Virtual Server
  - 제어 유형 : 허용 정책
  - 액션 : Create / Delete / List / Read / Update
  - 적용 자원 : 개별 자원 : ceweb, ceapp
  - 인증 유형 : 인증키 인증
  - 적용 IP : 모든 IP

- 공통 정책 생성(인증키)
  - 정책명 : `AccessKeyAccess`
  - 권한 설정(JSON 모드)
    ```json
    {
    	"Statement": [
    		{
    			"Action": [
    				"iam:CreateAccessKey",
    				"iam:DeleteAccessKey",
    				"iam:ListAccessKeys",
    				"iam:ShowAccessKey",
    				"iam:SetAccessKey",
    				"iam:ListEndpoints"
    			],
    			"Effect": "Allow",
    			"Resource": [
    				"*"
    			],
    			"Sid": "AccessKey"
    		}
    	],
    	"Version": "2024-07-01"
    }
    ```

- 공통 정책 생성(사내 IP로 접근 제어)
  - 정책명 : `NetworkAccessPolicy`
  - 권한 설정(JSON 모드)
    ```json
    {
    	"Statement": [
    		{
    			"Action": [
    				"*"
    			],
    			"Condition": {
    				"NotIpAddress": {
    					"scp:SourceIP": [
    						"your_public_ip/32"
    					]
    				}
    			},
    			"Effect": "Deny",
    			"Resource": [
    				"*"
    			],
    			"Sid": "statement1"
    		}
    	],
    	"Version": "2024-07-01"
    }
    ```
    위에서 your_public_ip는 실습자 PC의 Public IP 입력

- 사용자 그룹 생성
  - 사용자 그룹명 : `devloperGroup`
  - 사용자 : Alex, Robert
  - 정책 연결 : DeveloperAccess, NetworkAccessPolicy, AccessKeyAccess

**&#128906; Alex(Developer) CLI**
 
- 개발자 권한 테스트

콘솔에서 인증키를 생성한 후 CLI 환경 설정에 인증키 입력

```powershell
edit $env:USERPROFILE\.scp\cli-config.json
```
CLI 환경 설정
```json
{
     "auth_url": "https://iam.e.samsungsdscloud.com/v1/endpoints",
     "access_key": "인증키 access-key 입력",
     "access_secret_key": "인증키 access-secret-key 입력",
     "default_scp_region": "kr
```

```powershell
scp-cli virtualserver server show --server_id appvm_자원_ID
scp-cli virtualserver server show --server_id webvm_자원_ID
```

## 사용자 그룹에 기존 사용자 추가(DBA)

**&#128906; Jeff(Cloud Engineer) 콘솔**

- DBA 정책 생성
  - 정책명 : `DBAccess`
  - 권한 설정(JSON 모드)
    ```json
    {
    	"Version": "2024-07-01",
    	"Statement": [
    		{
    			"Sid": "VisualEditor0",
    			"Effect": "Allow",
    			"Action": [
    				"postgresql:*"
    			],
    			"Resource": [
    				"*"
    			]
    		}
    	]
    }
    ```
- DBA 정책 연결
- DBA 사용자 그룹 연결
  - 사용자 그룹명 : `DeveloperGroup`

**&#128906; Scott(DBA) 콘솔**

## 역할(다른 Account)로 외부 개발자 권한 부여

**&#128906; Jeff(클라우드 엔지니어) 콘솔**

- 외부 개발자 정책 생성
  - 정책명 : `ExternalWebDevAccess`  
  - 권한 설정:   
    정책 불러오기 - DBAccess  
    액션: List, Read  
    적용 자원: ceweb (ceapp 제외)  
    사용자 지정 IP: 외부회사 지정 IP(실습 편의상 실습자 PC의 Public IP)  

- 역할 생성
  - 역할명: `ExternalWebDevRole`  
  - 최대 세션 지속시간: 2시간  
  - 수행주체: 구분 : 다른 Account , Value : creative-energy  
  - 정책 연결 : `ExternalWebDevAccess`  
 
**&#128906; Steve(외부 개발자) 콘솔**


