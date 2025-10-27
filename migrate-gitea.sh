#!/bin/bash

# Gitea 数据迁移脚本
# 用途：将 Gitea 数据从机器A迁移到机器B

set -e

# 配置变量
BACKUP_FILE="gitea_data_backup.tar.gz"
COMPOSE_FILE="docker-compose-gitea.yml"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# 显示帮助信息
show_help() {
    echo "Gitea 数据迁移脚本"
    echo ""
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  export <源服务器>      从源服务器导出数据"
    echo "  import               在本地导入数据"
    echo "  backup               创建本地备份"
    echo "  restore <备份文件>   从备份文件恢复"
    echo "  verify               验证数据完整性"
    echo "  help                 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 export user@192.168.1.100"
    echo "  $0 import"
    echo "  $0 backup"
    echo "  $0 restore gitea_backup_20231027.tar.gz"
    echo ""
}

# 检查 Docker 和 Docker Compose
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        error "Docker 未安装或不在 PATH 中"
    fi

    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose 未安装或不在 PATH 中"
    fi
}

# 检查 SSH 连接
check_ssh_connection() {
    local server=$1
    info "检查 SSH 连接到 $server..."
    if ! ssh -o ConnectTimeout=10 $server 'echo "SSH 连接成功"'; then
        error "无法连接到服务器 $server"
    fi
}

# 导出数据函数
export_data() {
    local source_server=$1

    if [ -z "$source_server" ]; then
        error "请提供源服务器地址"
    fi

    log "开始从 $source_server 导出 Gitea 数据..."

    # 检查 SSH 连接
    check_ssh_connection "$source_server"

    # 在源服务器上执行导出操作
    info "在源服务器上执行数据导出..."
    ssh "$source_server" << EOF
        set -e

        # 检查依赖
        if ! command -v docker &> /dev/null; then
            echo "ERROR: 源服务器上未安装 Docker"
            exit 1
        fi

        # 查找 Gitea 相关目录和容器
        echo "查找 Gitea 容器和数据..."
        GITEA_CONTAINER=\$(docker ps -a --filter "name=gitea" --format "{{.Names}}" | head -1)

        if [ -z "\$GITEA_CONTAINER" ]; then
            echo "ERROR: 未找到 Gitea 容器"
            exit 1
        fi

        echo "找到 Gitea 容器: \$GITEA_CONTAINER"

        # 查找数据卷
        GITEA_VOLUME=\$(docker volume ls | grep gitea | awk '{print \$2}' | head -1)
        if [ -z "\$GITEA_VOLUME" ]; then
            echo "ERROR: 未找到 Gitea 数据卷"
            exit 1
        fi

        echo "找到数据卷: \$GITEA_VOLUME"

        # 停止 Gitea 服务
        echo "停止 Gitea 服务..."
        if command -v docker-compose &> /dev/null; then
            # 尝试在常见目录中找到 docker-compose.yml
            for dir in ~/gitea-docker ~/gitea ~/gitea-install ~/docker/gitea /opt/gitea; do
                if [ -f "\$dir/docker-compose.yml" ] || [ -f "\$dir/docker-compose-gitea.yml" ]; then
                    cd "\$dir"
                    echo "在工作目录: \$dir"
                    docker-compose down 2>/dev/null || docker-compose -f docker-compose-gitea.yml down 2>/dev/null || true
                    break
                fi
            done
        fi

        # 停止容器
        docker stop \$GITEA_CONTAINER 2>/dev/null || true

        # 导出数据卷
        echo "导出数据卷数据..."
        BACKUP_FILE="gitea_data_backup_\$(date +%Y%m%d_%H%M%S).tar.gz"

        docker run --rm \\
            -v \$GITEA_VOLUME:/data \\
            -v \$(pwd):/backup \\
            alpine:latest tar czf "/backup/\$BACKUP_FILE" -C /data .

        if [ -f "\$BACKUP_FILE" ]; then
            echo "数据导出成功: \$BACKUP_FILE"
            echo "文件大小: \$(ls -lh "\$BACKUP_FILE" | awk '{print \$5}')"
            echo "文件路径: \$(pwd)/\$BACKUP_FILE"
        else
            echo "ERROR: 数据导出失败"
            exit 1
        fi
EOF

    if [ $? -eq 0 ]; then
        # 查找生成的备份文件
        log "正在查找备份文件..."
        BACKUP_FILES=$(ssh "$source_server" 'find . -name "gitea_data_backup_*.tar.gz" -type f -mmin -5' 2>/dev/null | head -1)

        if [ -n "$BACKUP_FILES" ]; then
            # 下载备份文件
            info "下载备份文件: $BACKUP_FILES"
            scp "$source_server:$BACKUP_FILES" "./"

            # 重命名为标准名称
            if [ -f "$(basename "$BACKUP_FILES")" ]; then
                mv "$(basename "$BACKUP_FILES")" "$BACKUP_FILE"
                log "备份文件已保存为: $BACKUP_FILE"
                log "文件大小: $(ls -lh "$BACKUP_FILE" | awk '{print $5}')"
            fi
        else
            error "未找到生成的备份文件"
        fi
    else
        error "数据导出失败"
    fi

    log "数据导出完成！"
}

# 导入数据函数
import_data() {
    log "开始在本地导入 Gitea 数据..."

    # 检查备份文件
    if [ ! -f "$BACKUP_FILE" ]; then
        error "备份文件 $BACKUP_FILE 不存在！请先执行导出操作。"
    fi

    # 检查 docker-compose 文件
    local compose_file=""
    if [ -f "$COMPOSE_FILE" ]; then
        compose_file="$COMPOSE_FILE"
    elif [ -f "docker-compose.yml" ]; then
        compose_file="docker-compose.yml"
    else
        error "未找到 docker-compose.yml 或 docker-compose-gitea.yml 文件！"
    fi

    info "使用配置文件: $compose_file"

    # 1. 启动服务一次以创建卷
    log "启动服务创建数据卷..."
    docker-compose -f "$compose_file" up -d
    sleep 15

    # 2. 停止服务
    log "停止服务..."
    docker-compose -f "$compose_file" down

    # 3. 查找 Gitea 卷名
    GITEA_VOLUME=$(docker volume ls | grep gitea | awk '{print $2}' | head -1)
    if [ -z "$GITEA_VOLUME" ]; then
        error "未找到 Gitea 数据卷"
    fi

    log "找到数据卷: $GITEA_VOLUME"

    # 4. 导入数据
    log "导入数据到数据卷..."
    docker run --rm \
        -v "$GITEA_VOLUME":/data \
        -v "$(pwd)":/backup \
        alpine:latest tar xzf "/backup/$BACKUP_FILE" -C /data

    if [ $? -ne 0 ]; then
        error "数据导入失败"
    fi

    # 5. 修复权限
    log "修复文件权限..."
    docker run --rm \
        -v "$GITEA_VOLUME":/data \
        alpine:latest chown -R 1000:1000 /data

    # 6. 启动服务
    log "启动 Gitea 服务..."
    docker-compose -f "$compose_file" up -d

    # 7. 等待服务启动
    log "等待服务启动..."
    sleep 30

    # 8. 验证服务
    log "验证服务状态..."
    if docker-compose -f "$compose_file" ps | grep -q "Up"; then
        log "✅ Gitea 服务启动成功！"
    else
        error "Gitea 服务启动失败，请检查日志"
    fi

    # 9. 检查数据完整性
    verify_data

    log "🎉 数据迁移完成！"
    log "Web 访问地址: http://localhost:3000"
    log "管理命令: ./manage-gitea.sh status"
}

# 本地备份函数
backup_data() {
    log "创建本地备份..."

    # 检查服务是否运行
    if ! docker-compose ps | grep -q "gitea.*Up"; then
        warn "Gitea 服务未运行，尝试启动..."
        docker-compose up -d
        sleep 10
    fi

    # 创建备份目录
    BACKUP_DIR="./backups"
    mkdir -p "$BACKUP_DIR"

    # 生成备份文件名
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    LOCAL_BACKUP_FILE="$BACKUP_DIR/gitea_backup_$TIMESTAMP.tar.gz"

    # 查找数据卷
    GITEA_VOLUME=$(docker volume ls | grep gitea | awk '{print $2}' | head -1)
    if [ -z "$GITEA_VOLUME" ]; then
        error "未找到 Gitea 数据卷"
    fi

    log "备份数据卷: $GITEA_VOLUME"

    # 执行备份
    docker run --rm \
        -v "$GITEA_VOLUME":/data \
        -v "$(pwd)/$BACKUP_DIR":/backup \
        alpine:latest tar czf "/backup/gitea_backup_$TIMESTAMP.tar.gz" -C /data .

    if [ -f "$LOCAL_BACKUP_FILE" ]; then
        log "✅ 备份成功: $LOCAL_BACKUP_FILE"
        log "文件大小: $(ls -lh "$LOCAL_BACKUP_FILE" | awk '{print $5}')"
    else
        error "备份失败"
    fi
}

# 恢复数据函数
restore_data() {
    local backup_file=$1

    if [ -z "$backup_file" ]; then
        error "请提供备份文件路径"
    fi

    if [ ! -f "$backup_file" ]; then
        error "备份文件 $backup_file 不存在"
    fi

    log "从备份文件恢复数据: $backup_file"

    # 复制备份文件到标准名称
    cp "$backup_file" "$BACKUP_FILE"

    # 执行导入
    import_data
}

# 验证数据函数
verify_data() {
    log "验证数据完整性..."

    # 检查服务状态
    if ! docker-compose ps | grep -q "gitea.*Up"; then
        error "Gitea 服务未运行"
    fi

    # 等待服务完全启动
    sleep 10

    # 检查仓库数量
    REPO_COUNT=$(docker exec gitea find /data/git/repositories -name "*.git" -type d 2>/dev/null | wc -l)
    log "发现 $REPO_COUNT 个 Git 仓库"

    # 检查数据库文件
    if docker exec gitea test -f /data/gitea/gitea.db; then
        log "✅ 数据库文件存在"

        # 检查数据库完整性
        DB_CHECK=$(docker exec gitea sqlite3 /data/gitea/gitea.db "PRAGMA integrity_check;" 2>/dev/null || echo "ERROR")
        if [[ "$DB_CHECK" == "ok" ]]; then
            log "✅ 数据库完整性检查通过"
        else
            warn "数据库完整性检查失败: $DB_CHECK"
        fi
    else
        warn "数据库文件不存在，可能需要重新初始化"
    fi

    # 检查配置文件
    if docker exec gitea test -f /data/gitea/conf/app.ini; then
        log "✅ 配置文件存在"
    else
        warn "配置文件不存在"
    fi

    # 测试Web服务
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|302"; then
        log "✅ Web服务响应正常"
    else
        warn "Web服务响应异常"
    fi
}

# 主函数
main() {
    # 检查依赖
    check_dependencies

    # 处理命令行参数
    case "${1:-help}" in
        export)
            export_data "$2"
            ;;
        import)
            import_data
            ;;
        backup)
            backup_data
            ;;
        restore)
            restore_data "$2"
            ;;
        verify)
            verify_data
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "未知命令: $1"
            show_help
            ;;
    esac
}

# 脚本入口
main "$@"