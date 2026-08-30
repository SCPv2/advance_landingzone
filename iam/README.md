# Identity & Access Management

## 실습 도구

**&#128906; 실습 도구 설치**

- 작업 디렉토리 생성

```powershell
mkdir c:\scpv2lab
cd c:\scpv2lab
```

- Samsung Cloud Platform CLI 및 Terraform 환경 설정

아래 파일을 다운로드해서 작업 디렉토리(C:\scpv2lab)에 저장

CLI 다운로드 : https://docs.e.samsungsdscloud.com/clireference/cli-common/

Terraform 다운로드 : https://developer.hashicorp.com/terraform/install

## 실습 환경 배포

**&#128906; Terraform 파일 다운로드** 

작업 디렉토리(C:\scpv2lab)에서 Git 명령 실행

```powershell


- [main.tf](./main.tf)  
- [variables.tf](variables.tf)  
- [outputs.tf](outputs.tf)  

**&#128906; 사용자 변수 입력** (variables.tf)

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

- Architecture Diagram

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
|DBAccess|모든 인증|VPC/Firewall/Security Group 전체 허용|  
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

- 공통 정책 생성(IP 접근 제어)
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

**&#128906; Alex(Developer) 콘솔**
 
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

## 역할(자격 증명 공급자)로 네트워크 엔지니어 권한 부여

- 네트워크 엔지니어 정책 생성
  - 정책명 : `NetworkEngineerAccess`
  - 권한 설정(JSON 모드)
    ```json
    {
    	"Version": "2024-07-01",
    	"Statement": [
    		{
    			"Sid": "VisualEditor0",
    			"Effect": "Allow",
    			"Action": [
    				"vpc:*"
    			],
    			"Resource": [
    				"*"
    			]
    		},
    		{
    			"Sid": "VisualEditor1",
    			"Effect": "Allow",
    			"Action": [
    				"direct-connect:*"
    			],
    			"Resource": [
    				"*"
    			]
    		},
    		{
    			"Sid": "VisualEditor2",
    			"Effect": "Allow",
    			"Action": [
    				"firewall:*"
    			],
    			"Resource": [
    				"*"
    			]
    		},
    		{
    			"Sid": "VisualEditor3",
    			"Effect": "Allow",
    			"Action": [
    				"security-group:*"
    			],
    			"Resource": [
    				"*"
    			]
    		}
    	]
    }
    ```

- 자격 증명 공급자 생성
  - 자역 증명 공급자명 : `creative-energy`
  - 메타 데이터 : `keycloak-metadata.xml`     # 앞서 IdP로 생성한 Keycloak에서 받은 XML

생성 후 페이지에서 로그인 URL에서 SP Entity ID를 확인 (SAMLSP00000000AAAAAAAAA 형식)

https://console.kr-west1.e.samsungsdscloud.com/your_account_id/saml/acs/SP_Entity_ID   # your_account_id와 SP_Entity_ID는 실제 값으로 나타남

- 역할 생성
  - 역할명: `NetworkEngineerRole`
  - 최대 세션 지속시간: 12시간
  - 수행주체: 구분 :  자격 증명 공급자 , Value : creative-energy
  - 정책 연결 : NetworkEngineerAccess

- IdP 설정을 위해 Keycloak 접속
  ```url
  http://webvm_public_ip:8080
  ```

- Create Client 
     - Client type : SAML
     - Client ID :  위 Samsung Cloud Platform의 SP Entity ID 입력
     - Name : `Samsung Cloud Platform`
     - Valid redirect URIs : https://console.kr-west1.e.samsungsdscloud.com/your_account_id/saml/acs/*    # your_account_id는 실제 값으로 바꿔서 입력
     - Master SAML Processing URL	: https://console.kr-west1.e.samsungsdscloud.com/your_account_id/saml/acs/SP_Entity_ID   # your_account_id와 SP_Entity_ID는 실제 값으로 바꿔서 입력
     - Name ID format : persistent     # username에서 persistent로 변경
     - Sign assertions : On            # Off에서 On으로 변경 나머지는 기본값
     - Key 탭 : Client signature required : Off # On에서 Off로 변경
     - Client scopes 탭 : role_list 삭제 

- email mapper 등록
  - Clients → SP_Entity_ID → Client scopes → SP_Entity_ID-dedicated → Add predefined mapper → X500 email 선택
  - Clients → SP_Entity_ID → Client scopes → SP_Entity_ID-dedicated → Add mapper - by Configuration → Hardcoded attribute
    - Name : `scp-role`
    - Friendly Name :
    - SAML Attribute Name : Role
    - SAML Attribute NameFormat : Basic
    - Attribute value : 앞서 생성했던 NetworkEngineerRole의 SRN, 자격 증명 공급자의 SRN






 ## 임시키 인증을 위한 설정(외부회사 웹개발자)

**&#128906; Jeff(Cloud Engineer) 콘솔**

- 외부 웹개발자 정책 생성
  - 정책명 : `ExternalWebDevAccess`
  - 서비스 : Virtual Server
  - 제어 유형 : 허용 정책
  - 액션 : List / Read / Update
  - 적용 자원 : 개별 자원 : webvm }
  - 인증 유형 : 인증키 인증
  - 적용 IP : 외부회사 지정 IP

- 임시키 관리를 위한 권한 설정
  - 정책명 : `TempKeyManagement`
  - 권한 설정(JSON 모드)
  ```json
  {
  	"Version": "2024-07-01",
  	"Statement": [
  		{
  			"Sid": "VisualEditor0",
  			"Effect": "Allow",
  			"Action": [
  				"secretvault:*"
  			],
  			"Resource": [
  				"*"
  			]
  		},
  		{
  			"Sid": "VisualEditor1",
  			"Effect": "Allow",
  			"Action": [
  				"iam:*"
  			],
  			"Resource": [
  				"*"
  			]
  		}
  	]
  }
  ```

- 외부 웹개발자 관리용 사용자 생성
  - 사용자명 : externalwebdev
  - 비밀번호 : 임의 지정
  - 권한 설정 방식 : 정책에 직접 연결 : ExternalWebDevAccess, AccessKeyAccess, TempKeyManagement

**&#128906; externalwebdev 콘솔**

- 인증키 생성(만료일 영구)

- Secret Vault 생성
  - Secret명 : `externalwebdev`
  - 유형 : SCP Open API Key
  - 인증키 : 앞서 생성한 인증키 선택
  - Token 사용 기간 : 30일
  - 임시키 교체 주기 : 1시간
  - 접근 허용 IP : 외부회사 지정 IP

- Secret Vault Token ID & Secret 확인
   
**&#128906; Jeff(Cloud Engineer) 콘솔**

- externalwebdev에서 권한 제거 : AccessKeyAccess, TempKeyManagement

**&#128906; externalwebdev의 Local PC**

- 임시키를 이용한 API 호출 테스트

API 호출용 스크립트 : [Invoke-ScpApi.ps1](./Invoke-ScpApi.ps1)

```powershell



