#!/bin/bash

# Gitea 管理脚本

set -e

COMPOSE_FILE="docker-compose-gitea.yml"
SERVICE_NAME="gitea"

case "$1" in
    start)
        echo "启动 Gitea 服务..."
        docker-compose -f $COMPOSE_FILE up -d
        echo "Gitea 已启动，访问地址: http://localhost:4000"
        ;;
    stop)
        echo "停止 Gitea 服务..."
        docker-compose -f $COMPOSE_FILE down
        echo "Gitea 已停止"
        ;;
    restart)
        echo "重启 Gitea 服务..."
        docker-compose -f $COMPOSE_FILE restart
        echo "Gitea 已重启"
        ;;
    status)
        echo "Gitea 服务状态:"
        docker-compose -f $COMPOSE_FILE ps
        ;;
    logs)
        echo "Gitea 服务日志:"
        docker-compose -f $COMPOSE_FILE logs -f $SERVICE_NAME
        ;;
    update)
        echo "更新 Gitea..."
        docker-compose -f $COMPOSE_FILE pull
        docker-compose -f $COMPOSE_FILE up -d
        echo "Gitea 已更新到最新版本"
        ;;
    backup)
        echo "备份 Gitea 数据..."
        BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p $BACKUP_DIR

        # 备份数据卷
        docker run --rm -v gitea_data:/data -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/gitea_data.tar.gz -C /data .

        echo "数据已备份到: $BACKUP_DIR"
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs|update|backup}"
        echo ""
        echo "命令说明:"
        echo "  start   - 启动 Gitea 服务"
        echo "  stop    - 停止 Gitea 服务"
        echo "  restart - 重启 Gitea 服务"
        echo "  status  - 查看服务状态"
        echo "  logs    - 查看服务日志"
        echo "  update  - 更新到最新版本"
        echo "  backup  - 备份数据"
        echo ""
        echo "Web 访问地址: http://localhost:4000"
        exit 1
        ;;
esac