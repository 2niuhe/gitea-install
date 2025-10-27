# Gitea 常见问题 FAQ

## 🚀 安装和启动

### Q: Gitea 启动失败怎么办？
**A**: 按以下步骤排查：
```bash
# 1. 检查端口是否被占用
netstat -tlnp | grep :3000

# 2. 查看服务日志
docker-compose -f docker-compose-gitea.yml logs gitea

# 3. 检查Docker服务
systemctl status docker

# 4. 重新启动服务
docker-compose -f docker-compose-gitea.yml down
docker-compose -f docker-compose-gitea.yml up -d
```

### Q: 访问 http://localhost:3000 显示 502 错误
**A**: 通常是服务未完全启动，等待1-2分钟再试：
```bash
# 查看启动进度
docker-compose -f docker-compose-gitea.yml logs -f gitea

# 等待看到 "Server listening on" 日志
```

### Q: 可以更改端口吗？
**A**: 可以，修改 `docker-compose-gitea.yml`：
```yaml
ports:
  - '8080:3000'    # 改为8080端口
  - '2222:22'      # 改为2222端口
```
然后重启服务。

## 🔑 用户和权限

### Q: 忘记管理员密码怎么办？
**A**: 重置密码：
```bash
# 查看现有用户
docker exec -it gitea gitea admin user list

# 重置密码
docker exec -it gitea gitea admin user change-password --username admin --password 新密码
```

### Q: 如何创建新用户？
**A**: 两种方式：
1. **Web界面**: 管理员 → 用户管理 → 创建新用户
2. **命令行**:
```bash
docker exec -it gitea gitea admin user create --username 用户名 --password 密码 --email 邮箱
```

### Q: 如何关闭用户注册？
**A**: Web界面 → 管理员设置 → 用户设置 → 取消勾选"启用注册"

## 📁 数据和备份

### Q: 数据存储在哪里？
**A**: 数据存储在Docker卷中：
```bash
# 查看卷信息
docker volume ls | grep gitea

# 查看卷位置
docker volume inspect gitea_data

# 实际位置: /var/lib/docker/volumes/gitea_data/_data
```

### Q: 如何备份数据？
**A**: 使用备份脚本：
```bash
# 创建备份
./manage-gitea.sh backup

# 查看备份文件
ls -la backups/
```

### Q: 如何恢复数据？
**A**: 从备份恢复：
```bash
# 使用迁移脚本恢复
./migrate-gitea.sh restore backups/backup_file.tar.gz
```

## 🔄 迁移和升级

### Q: 如何迁移到新服务器？
**A**: 使用迁移脚本：
```bash
# 在新服务器上执行
./migrate-gitea.sh export user@old-server
./migrate-gitea.sh import
```

### Q: 如何升级Gitea版本？
**A**: 使用更新脚本：
```bash
# 自动更新
./manage-gitea.sh update

# 手动更新
docker-compose -f docker-compose-gitea.yml pull
docker-compose -f docker-compose-gitea.yml up -d
```

### Q: 迁移后数据丢失怎么办？
**A**: 检查步骤：
```bash
# 1. 验证备份文件完整性
tar -tzf backup_file.tar.gz

# 2. 检查数据卷
docker volume ls | grep gitea

# 3. 验证数据完整性
./migrate-gitea.sh verify
```

## 🔌 SSH和Git操作

### Q: SSH连接失败怎么办？
**A**: 检查配置：
```bash
# 1. 检查SSH端口
docker-compose -f docker-compose-gitea.yml ps

# 2. 测试SSH连接
ssh -T -p 222 git@localhost

# 3. 检查SSH密钥
ls -la ~/.ssh/id_rsa*
```

### Q: 如何克隆仓库？
**A**: 两种方式：
```bash
# HTTP方式
git clone http://localhost:3000/username/repository.git

# SSH方式
git clone ssh://git@localhost:222/username/repository.git
```

### Q: 推送代码时权限被拒绝？
**A**: 检查权限设置：
```bash
# 1. 确认你有写入权限
# 2. 检查仓库设置：仓库 → 设置 → 协作者
# 3. 检查SSH密钥：设置 → SSH/GPG密钥
```

## 💾 存储空间

### Q: 磁盘空间不足怎么办？
**A**: 清理和优化：
```bash
# 1. 清理Docker系统
docker system prune -a

# 2. 清理日志文件
docker exec gitea find /data/gitea/log -name "*.log" -mtime +7 -delete

# 3. 检查大文件
docker exec gitea find /data -type f -size +100M
```

### Q: 如何移动数据到更大的磁盘？
**A**: 迁移数据卷：
```bash
# 1. 停止服务
docker-compose down

# 2. 备份数据
docker run --rm -v gitea_data:/data -v /new/path:/backup alpine tar czf /backup/data.tar.gz -C /data .

# 3. 修改docker-compose.yml，使用主机目录挂载
# volumes:
#   - /new/path/gitea-data:/data

# 4. 启动服务
docker-compose up -d
```

## 🐛 错误和异常

### Q: 数据库损坏怎么办？
**A**: 修复或重建：
```bash
# 1. 检查数据库完整性
docker exec gitea sqlite3 /data/gitea/gitea.db "PRAGMA integrity_check;"

# 2. 如果损坏，从备份恢复
./migrate-gitea.sh restore latest_backup.tar.gz
```

### Q: 容器无法启动？
**A**: 查看详细日志：
```bash
# 查看容器状态
docker ps -a | grep gitea

# 查看启动日志
docker logs gitea

# 重新创建容器
docker-compose down
docker-compose up -d
```

### Q: Web界面显示空白？
**A**: 清理缓存和重启：
```bash
# 1. 重启服务
docker-compose restart gitea

# 2. 清理浏览器缓存

# 3. 检查配置文件
docker exec gitea cat /data/gitea/conf/app.ini
```

## 🔧 配置和定制

### Q: 如何配置HTTPS？
**A**: 需要SSL证书和修改配置：
```yaml
environment:
  - GITEA__server__PROTOCOL=https
  - GITEA__server__CERT_FILE=/data/cert/cert.pem
  - GITEA__server__KEY_FILE=/data/cert/key.pem
```

### Q: 如何修改站点标题？
**A**: Web界面 → 管理员设置 → 站点配置 → 站点名称

### Q: 如何配置邮件通知？
**A**: 管理员设置 → 邮件配置：
```
SMTP服务器: smtp.gmail.com:587
用户名: your-email@gmail.com
密码: your-app-password
启用TLS: 是
```

## 📊 性能优化

### Q: Gitea运行缓慢怎么办？
**A**: 优化建议：
```bash
# 1. 检查系统资源
free -h
df -h

# 2. 启用缓存
# 在docker-compose.yml中添加：
environment:
  - GITEA__cache__ADAPTER=memory
  - GITEA__cache__INTERVAL=60

# 3. 优化数据库
environment:
  - GITEA__database__SQLITE_JOURNAL_MODE=WAL
  - GITEA__database__SQLITE_CACHE=2000
```

### Q: 如何支持大量用户？
**A**: 升级配置：
- 使用PostgreSQL数据库
- 增加内存和CPU
- 配置负载均衡
- 使用Redis缓存

## 🆘 获取更多帮助

### 官方资源
- [Gitea官方文档](https://docs.gitea.io/zh-cn/)
- [Gitea配置手册](https://docs.gitea.io/zh-cn/config-cheat-sheet/)

### 社区支持
- [Gitea GitHub](https://github.com/go-gitea/gitea)
- [Gitea社区论坛](https://discourse.gitea.io/)

### 本地帮助
```bash
# 查看脚本帮助
./manage-gitea.sh
./migrate-gitea.sh help

# 查看所有文档
ls -la *.md
```

---

如果问题仍未解决，请检查日志文件或联系技术支持！