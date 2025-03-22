# 🐋docker-compose-and-backup
- 하나의 데이터베이스를 공유하는 두개의 어플리케이션을 실행하는 docker-compose를 구성하고
- shell 스크립트를 이용해 docker-compose를 실행 후 crontab을 활용해 자동 백업하는 환경 구성하는 프로젝트

<br>


## 🎯목표
- 도커 네트워크 지식 확립
- 도커 컴포즈 내의 어플리케이션 실행 순서 고려
- shell 스크립트, crontab 활용
- 빌드 시, 도커 컴포즈, 도커 파일 중 어디서 실행하는 것이 유리한지 고려하여 코드 작성


<br>


## 🏗️ 아키텍처
![image](https://github.com/user-attachments/assets/8215383f-7901-4adc-b832-baf7dc66624a)

<br>

## 📁 파일 구성
![image](https://github.com/user-attachments/assets/5692cfd9-7f84-4a02-aa52-8b936bb5b971)

<br>

### 1. 스프링 mysql 연결url을 DNS로 설정
- 동일한 도커 네트워크에서 DNS를 통해 연결 가능
- ※Default bridge 네트워크에서는 DNS 사용 불가함

```
# MySQL 연결 설정
spring.datasource.url=jdbc:mysql://mysqldb:3306/${DB_NAME}?useSSL=false&allowPublicKeyRetrieval=true
```

<br>

### 2. 도커 컴포즈 파일
- **MySQL** 하나를 공유하는 두 개의 **Spring Boot 프로젝트**를 실행
- **브릿지 네트워크**로 연결
- **MySQL** 서비스가 정상 동작 확인 후, `app`, `app2` 실행
- 중요한 설정 값들은 **환경 변수**를 통해 관리
- 포트 설정 주의

```yaml
version: "1.0"

services:
  db:
    container_name: mysqldb
    image: mysql:${MYSQL_VERSION}  # 환경 변수로 MySQL 버전 지정
    ports:
      - "${MYSQL_PORT}:${MYSQL_PORT}"
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    networks:
      - spring-mysql-net
    healthcheck:
      test: ['CMD-SHELL', 'mysqladmin ping -h 127.0.0.1 -u root --password=$${MYSQL_ROOT_PASSWORD} || exit 1']
      interval: 10s
      timeout: 2s
      retries: 100
  
  app:
    container_name: springbootapp1
    build:
      context: .
      dockerfile: ./app2/Dockerfile
    ports:
      - "${APP1_PORT}:${APP1_PORT}"
    environment:
      MYSQL_PORT: ${MYSQL_PORT}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    depends_on:
      db:
        condition: service_healthy
    networks:
      - spring-mysql-net
  
  app2:
    container_name: springbootapp2
    build:
      context: .
      dockerfile: ./app2/Dockerfile
    ports:
      - "${APP2_PORT}:${APP2_PORT}"
    environment:
      MYSQL_PORT: ${MYSQL_PORT}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    depends_on:
      db:
        condition: service_healthy
    networks:
      - spring-mysql-net

networks:
  spring-mysql-net:
    driver: bridge
```

<br>

### 3. 도커파일

- **eclipse-temurin:17-jre-alpine** 버전을 사용하여 경량화된 이미지로 설정합니다.
- **HEALTHCHECK** 설정은 추후 모니터링 환경이 구축되면 필요 없을 수 있습니다.

```bash
# Base Image 설정
FROM eclipse-temurin:17-jre-alpine

# curl 설치 (slim 이미지에는 기본적으로 없음)
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# 작업 디렉토리 설정
WORKDIR /app

# 애플리케이션 JAR 파일 복사
COPY springProject.jar app.jar

# 환경 변수 설정 (포트 변경이 용이하도록)
ENV SERVER_PORT=8088

# 헬스 체크 설정 (curl을 사용하여 애플리케이션이 정상 작동하는지 확인)
HEALTHCHECK --interval=10s --timeout=30s --retries=3 CMD curl -f http://localhost:${SERVER_PORT}/index.html || exit 1

# 애플리케이션 실행 (exec 방식 사용)
ENTRYPOINT ["java", "-jar", "app.jar"]
```

<br>

### 4. setup.sh

- 도커 컴포즈를 실행하고 백업하는 크론탭을 지정합니다.
- 백업을 1분마다 실행하도록 설정 (서비스에 따라 주기를 조절 가능)

```bash
#!/bin/bash

# Docker Compose 실행
echo "Starting Docker Compose..."
docker-compose up -d

# 백업 스크립트 실행 권한 부여
chmod +x $BACKUP_SCRIPT
echo "Granted execute permission to backupData.sh"

# Crontab에 백업 스크립트 등록 (매일 새벽 3시 실행 예시)
CRON_JOB="* * * * * /bin/bash $BASE_DIR/backup/backupData.sh >> $BASE_DIR/backup/backupData.log 2>&1"

# 기존 크론탭 백업 후 업데이트
echo "Updating Crontab..."
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "Crontab updated successfully."
```

<br>

### 5. backupData.sh
mysqldump를 사용하여 MySQL에 접근하고 백업을 수행하여 데이터를 저장합니다.
DB 백업 (MySQL 컨테이너에서 mysqldump 실행)


```
#!/bin/bash

BACKUP_DIR="$BASE_DIR/backup"
DATE=$(TZ=Asia/Seoul date +"%Y%m%d%H%M")   # 날짜 및 시간 형식
BACKUP_FILE="$BACKUP_DIR/$MYSQL_DATABASE-$DATE.sql"  # 백업 파일 이름

# 백업 디렉토리가 없다면 생성
mkdir -p $BACKUP_DIR

# MySQL 컨테이너에서 mysqldump 명령어로 DB 백업
echo "Starting MySQL backup..."
docker exec $CONTAINER_NAME mysqldump -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE > $BACKUP_FILE

# 백업 성공 여부 확인
if [ $? -eq 0 ]; then
  echo "Backup successful: $BACKUP_FILE"
else
  echo "Backup failed"
fi
```

