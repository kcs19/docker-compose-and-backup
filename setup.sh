#!/bin/bash

# Docker Compose 실행
echo "Starting Docker Compose..."
docker-compose up -d

chmod +x ./backupData.sh
echo "Granted execute permission to backupData.sh"

# Crontab에 백업 스크립트 등록 (매일 새벽 3시 실행 예시)
CRON_JOB="* * * * * /bin/bash /home/ubuntu/start_and_backup/backup/backupData.sh >> /home/ubuntu/start_and_backup/backup/backupData.log 2>&1"

# 기존 크론탭 백업 후 업데이트
echo "Updating Crontab..."
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "Crontab updated successfully."
