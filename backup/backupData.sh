# 1. DB 백업 (MySQL 컨테이너에서 mysqldump 실행)
CONTAINER_NAME="mysqldb"
MYSQL_USER="root"
MYSQL_PASSWORD="root"
MYSQL_DATABASE="fisa"

# 백업 파일 저장 경로
BACKUP_DIR="/home/ubuntu/start_and_backup/backup"
DATE=$(TZ=Asia/Seoul date +"%Y%m%d%H%M")
BACKUP_FILE="$BACKUP_DIR/$MYSQL_DATABASE-$DATE.sql"

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
