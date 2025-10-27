# Gitea 完整安装与迁移指南

## 📋 目录

1. [Gitea 介绍](#gitea-介绍)
2. [系统要求](#系统要求)
3. [安装步骤](#安装步骤)
4. [存储挂载方式](#存储挂载方式)
5. [数据迁移方案](#数据迁移方案)
6. [故障排除](#故障排除)
7. [维护建议](#维护建议)

---

## 🚀 Gitea 介绍

Gitea 是一个轻量级的自托管 Git 服务，用 Go 语言编写。相比 GitLab，它具有以下优势：

| 特性 | Gitea | GitLab |
|------|-------|--------|
| 资源占用 | ~100MB | ~4GB+ |
| 启动时间 | ~30秒 | ~5-10分钟 |
| 部署复杂度 | 简单 | 复杂 |
| 功能完整 | ✅ 基础功能完整 | ✅ 企业级功能 |
| CI/CD | 支持外部集成 | 内置强大CI/CD |

---

## 💻 系统要求

### 最低配置
- **CPU**: 1核心
- **内存**: 512MB RAM
- **存储**: 2GB 可用空间
- **系统**: Linux/Windows/macOS

### 推荐配置
- **CPU**: 2核心以上
- **内存**: 2GB RAM 以上
- **存储**: 10GB 以上可用空间
- **网络**: 稳定的互联网连接

---

## 🔧 安装步骤

### 步骤1: 安装 Docker

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo apt install docker-compose

# CentOS/RHEL
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker
```

### 步骤2: 创建项目目录

```bash
mkdir -p ~/gitea-docker
cd ~/gitea-docker
```

### 步骤3: 创建配置文件

#### docker-compose.yml
```yaml
version: '3.8'

services:
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    restart: unless-stopped
    ports:
      - '3000:3000'    # Web 端口
      - '222:22'       # SSH 端口
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=sqlite3
      - GITEA__database__PATH=/data/gitea/gitea.db
      - GITEA__server__DOMAIN=localhost
      - GITEA__server__HTTP_PORT=3000
      - GITEA__server__SSH_PORT=222
      - GITEA__server__ROOT_URL=http://localhost:3000/
    volumes:
      - gitea_data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    networks:
      - gitea-network

networks:
  gitea-network:
    driver: bridge

volumes:
  gitea_data:
    driver: local
```

### 步骤4: 启动服务

```bash
# 拉取镜像
docker-compose pull

# 启动服务
docker-compose up -d

# 查看状态
docker-compose ps
```

### 步骤5: 初始化配置

1. **访问 Web 界面**: http://localhost:3000
2. **数据库配置**: 使用默认的 SQLite3
3. **管理员设置**: 创建管理员账户
4. **服务器设置**: 保持默认配置

---

## 📁 存储挂载方式

### Docker 卷方式 (推荐)

```yaml
volumes:
  - gitea_data:/data
```

**优点**:
- ✅ 自动管理存储位置
- ✅ 容器重启数据不丢失
- ✅ 备份和迁移方便

**数据结构**:
```
gitea_data/
├── git/
│   └── repositories/          # Git 仓库
├── gitea/
│   ├── conf/
│   │   └── app.ini           # 配置文件
│   ├── gitea.db              # SQLite 数据库
│   ├── log/
│   └── sessions/
└── ssh/
    └── ssh_host_*_key        # SSH 密钥
```

### 主机目录挂载方式

```yaml
volumes:
  - ./data:/data
  - ./backups:/backups
```

**优点**:
- ✅ 直接访问文件系统
- ✅ 便于文件系统级别的备份
- ✅ 权限控制更灵活

**缺点**:
- ❌ 需要手动管理目录权限
- ❌ 路径依赖性强

---

## 🔄 数据迁移方案

### 场景1: 从机器A迁移到机器B

#### 方法1: Docker 卷迁移 (推荐)

**步骤1: 在机器A导出数据**

```bash
# 1. 停止服务
docker-compose down

# 2. 查找数据卷名
docker volume ls | grep gitea

# 3. 导出数据卷
docker run --rm \
  -v gitea_gitea_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/gitea_data_backup.tar.gz -C /data .

# 4. 传输备份文件到机器B
scp gitea_data_backup.tar.gz user@machineB:/path/to/backup/
```

**步骤2: 在机器B导入数据**

```bash
# 1. 创建相同的项目目录
mkdir -p ~/gitea-docker
cd ~/gitea-docker

# 2. 复制配置文件 (从机器A)
scp user@machineA:~/gitea-docker/docker-compose.yml .

# 3. 启动一次服务以创建卷
docker-compose up -d
sleep 10
docker-compose down

# 4. 导入数据
docker run --rm \
  -v gitea_gitea_data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/gitea_data_backup.tar.gz -C /data

# 5. 修复权限
docker run --rm \
  -v gitea_gitea_data:/data \
  alpine chown -R 1000:1000 /data

# 6. 启动服务
docker-compose up -d
```

#### 方法2: 主机目录迁移

如果使用主机目录挂载，直接复制整个数据目录：

```bash
# 在机器A
tar czf gitea_data_backup.tar.gz ./data/

# 传输到机器B
scp gitea_data_backup.tar.gz user@machineB:/path/to/gitea-docker/

# 在机器B
tar xzf gitea_data_backup.tar.gz
docker-compose up -d
```

### 场景2: 数据库迁移

如果使用 PostgreSQL 或 MySQL 数据库：

```bash
# 导出数据
docker exec gitea-db pg_dump -U gitea gitea > gitea_db_backup.sql

# 传输并导入
scp gitea_db_backup.sql user@machineB:/path/to/
docker exec -i gitea-db psql -U gitea gitea < gitea_db_backup.sql
```

---

## 🛠️ 自动化迁移脚本

### 创建迁移脚本

```bash
#!/bin/bash
# migrate-gitea.sh

SOURCE_SERVER=$1
if [ -z "$SOURCE_SERVER" ]; then
    echo "用法: $0 <源服务器地址>"
    echo "示例: $0 user@192.168.1.100"
    exit 1
fi

# 导出函数
export_data() {
    echo "从 $SOURCE_SERVER 导出数据..."

    ssh $SOURCE_SERVER << 'EOF'
        cd ~/gitea-docker
        docker-compose down

        # 查找数据卷
        VOLUME=$(docker volume ls | grep gitea | awk '{print $2}')
        echo "数据卷: $VOLUME"

        # 导出数据
        docker run --rm \
            -v $VOLUME:/data \
            -v $(pwd):/backup \
            alpine tar czf /backup/gitea_backup.tar.gz -C /data .
EOF

    # 下载备份
    scp $SOURCE_SERVER:~/gitea-docker/gitea_backup.tar.gz .
    echo "导出完成: gitea_backup.tar.gz"
}

# 导入函数
import_data() {
    echo "导入数据到本地..."

    # 创建项目目录
    mkdir -p ~/gitea-docker
    cd ~/gitea-docker

    # 创建 docker-compose.yml
    cat > docker-compose.yml << 'EOFCOMPOSE'
version: '3.8'
services:
  gitea:
    image: gitea/gitea:latest
    restart: unless-stopped
    ports:
      - '3000:3000'
      - '222:22'
    volumes:
      - gitea_data:/data
volumes:
  gitea_data:
EOFCOMPOSE

    # 启动并导入
    docker-compose up -d
    sleep 10
    docker-compose down

    # 导入数据
    docker run --rm \
        -v gitea_gitea_data:/data \
        -v $(pwd):/backup \
        alpine tar xzf /backup/gitea_backup.tar.gz -C /data

    # 修复权限并启动
    docker run --rm \
        -v gitea_gitea_data:/data \
        alpine chown -R 1000:1000 /data

    docker-compose up -d
    echo "导入完成！访问: http://localhost:3000"
}

# 执行
export_data
import_data
```

### 使用方法

```bash
# 保存脚本并赋予执行权限
chmod +x migrate-gitea.sh

# 执行迁移
./migrate-gitea.sh user@source-server
```

---

## 🔍 数据验证

### 迁移后验证步骤

```bash
# 1. 检查服务状态
docker-compose ps

# 2. 检查日志
docker-compose logs gitea

# 3. 验证数据完整性
docker exec gitea find /data/git/repositories -name "*.git" -type d | wc -l

# 4. 检查数据库
docker exec gitea sqlite3 /data/gitea/gitea.db "SELECT COUNT(*) FROM repository;"

# 5. 测试访问
curl -I http://localhost:3000
```

---

## ⚠️ 故障排除

### 常见问题

#### 1. 权限问题
```bash
# 修复权限
docker run --rm \
    -v gitea_gitea_data:/data \
    alpine chown -R 1000:1000 /data
```

#### 2. 端口冲突
```bash
# 检查端口占用
netstat -tlnp | grep :3000

# 修改端口映射
# 在 docker-compose.yml 中修改 ports 部分
ports:
  - '8080:3000'  # 改为其他端口
```

#### 3. 数据库损坏
```bash
# 检查数据库完整性
docker exec gitea sqlite3 /data/gitea/gitea.db "PRAGMA integrity_check;"

# 如果损坏，重新初始化
docker-compose down
docker volume rm gitea_gitea_data
docker-compose up -d
```

#### 4. 容器无法启动
```bash
# 查看详细日志
docker-compose logs --tail=100 gitea

# 检查配置文件
docker exec gitea cat /data/gitea/conf/app.ini
```

---

## 📊 维护建议

### 定期维护任务

#### 1. 自动备份脚本
```bash
#!/bin/bash
# backup-gitea.sh

BACKUP_DIR="/backup/gitea/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# 备份数据卷
docker run --rm \
    -v gitea_gitea_data:/data \
    -v $BACKUP_DIR:/backup \
    alpine tar czf /backup/gitea_data.tar.gz -C /data .

# 备份配置文件
cp docker-compose.yml $BACKUP_DIR/

# 清理旧备份 (保留30天)
find /backup/gitea -type d -mtime +30 -exec rm -rf {} \;
```

#### 2. 更新脚本
```bash
#!/bin/bash
# update-gitea.sh

# 备份数据
./backup-gitea.sh

# 拉取最新镜像
docker-compose pull

# 重启服务
docker-compose up -d

# 验证更新
docker-compose ps
```

#### 3. 监控脚本
```bash
#!/bin/bash
# monitor-gitea.sh

# 检查服务状态
if ! docker-compose ps | grep -q "Up"; then
    echo "Gitea 服务异常，尝试重启..."
    docker-compose restart
fi

# 检查磁盘空间
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "磁盘空间不足: ${DISK_USAGE}%"
fi
```

### 性能优化建议

1. **定期清理 Docker 系统**:
   ```bash
   docker system prune -a
   ```

2. **配置 HTTPS**:
   ```yaml
   environment:
     - GITEA__server__PROTOCOL=https
     - GITEA__server__CERT_FILE=/data/cert/cert.pem
     - GITEA__server__KEY_FILE=/data/cert/key.pem
   ```

3. **启用缓存**:
   ```yaml
   environment:
     - GITEA__cache__ADAPTER=memory
     - GITEA__cache__INTERVAL=60
   ```

---

## 📝 快速参考

### 常用命令
```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 查看日志
docker-compose logs -f gitea

# 进入容器
docker exec -it gitea bash

# 重置管理员密码
docker exec -it gitea gitea admin user change-password --username admin --password newpass
```

### 重要文件路径
- **配置文件**: `/data/gitea/conf/app.ini`
- **数据库**: `/data/gitea/gitea.db`
- **仓库目录**: `/data/git/repositories/`
- **日志目录**: `/data/gitea/log/`

### 网络端口
- **Web**: 3000
- **SSH**: 222

---

## 🎯 总结

Gitea 是一个优秀的轻量级 Git 服务解决方案，具有以下特点：

1. **部署简单**: 一个 docker-compose.yml 文件即可
2. **资源占用少**: 适合个人和小团队使用
3. **功能完整**: 满足日常 Git 托管需求
4. **迁移方便**: 数据迁移相对简单
5. **维护成本低**: 配置和管理都比较简单

通过本指南，您可以轻松完成 Gitea 的安装、配置、迁移和维护工作。