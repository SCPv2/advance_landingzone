# Multi Account Management

## Organization 

- 조직 단위(OU) 생성

- Account 생성
  - Account명: `CE_Asia`
  - 이메일: ID+1@도메인
  - IAM 역할명: OrganizationAccountAccessRole
 
  - Account명: `CE_Europe`
  - 이메일: ID+2@도메인
  - IAM 역할명: OrganizationAccountAccessRole
 
- 통제정책 생성
  - 통제 정책명: `ResourceControlPolicy`
  - 서비스: `Multi-node GPU Cluster`
  - 제어 유형: `거부 정책`
  - 액션: `Create`
  - 인증 유형: `모든 인증`
  - 적용 IP: `모든 IP`

  - 통제 정책명: `AsiaNetworkAccessPolicy`
  - 통제 정책명: `EuropeNetworkAccessPolicy`

- 조직 단위(OU) 생성
  - 조직 단위명: `Subsidiary`

## ID Center

-ID Center명: creative-energy

- 사용자 생성
  - 사용자 ID: Jeff
  - 비밀번호: 임의로 임력
  - 사용자 실명: `Jeff.Creative`

- 권한 세트 생성
  - 권한 세트명 : `Cloud Engineer`
  - 기본 정책 : 사용, `AdministratorAccess`
  - 인라인 정책 : 사용 

  - 권한 세트명 : `Cloud Monitor`
  - 기본 정책 : 사용, `ViewerAccess`
  - 인라인 정책 : 사용 

- Account 할당
  - CE_Asia
    - 사용자: `Jeff`
    - 권한 세트: `Cloud Engineer`
  - CE_Europe
    - 사용자: `Jeff`
    - 권한 세트: `Cloud Monitor`   

