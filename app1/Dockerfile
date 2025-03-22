# Base Image 설정
FROM openjdk:17-slim

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
