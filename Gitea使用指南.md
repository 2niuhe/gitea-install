# Gitea Docker 自建服务使用指南

## 🎉 安装成功！

您的 Gitea Git 服务已经成功安装并运行！

## 📋 服务信息

- **Web 访问地址**: http://localhost:3000
- **SSH 地址**: git@localhost:222
- **容器名称**: gitea
- **数据存储**: Docker 持久化卷

## 🚀 首次设置

### 1. 访问 Web 界面
打开浏览器访问：http://localhost:3000

### 2. 初始配置（首次访问时会看到）
- **数据库类型**: SQLite3 (已配置)
- **管理员账户**: 创建您的管理员用户名和密码
- **服务器设置**: 保持默认设置即可

### 3. 推荐设置
- **站点名称**: 自定义您的 Git 服务器名称
- **仓库根目录**: /data/git/repositories (默认)
- **LFS 启用**: 建议启用（Git Large File Storage）
- **用户注册**: 可选择开放或关闭注册

## 💡 使用 Gitea

### 创建第一个仓库
1. 登录后点击 "+" 按钮
2. 选择 "New Repository"
3. 填写仓库名称和描述
4. 选择公开或私有
5. 点击 "Create Repository"

### Git 操作示例

```bash
# 克隆仓库（使用 HTTPS）
git clone http://localhost:3000/username/repository-name.git

# 克隆仓库（使用 SSH）
git clone ssh://git@localhost:222/username/repository-name.git

# 添加远程仓库
git remote add origin http://localhost:3000/username/repository-name.git

# 推送代码
git push -u origin main
```

## 🔧 管理命令

```bash
# 查看服务状态
docker-compose -f docker-compose-gitea.yml ps

# 查看日志
docker-compose -f docker-compose-gitea.yml logs -f gitea

# 停止服务
docker-compose -f docker-compose-gitea.yml down

# 重启服务
docker-compose -f docker-compose-gitea.yml restart

# 更新 Gitea
docker-compose -f docker-compose-gitea.yml pull
docker-compose -f docker-compose-gitea.yml up -d
```

## 📁 数据备份

### 备份数据卷
```bash
# 查看数据卷位置
docker volume inspect gitea_data

# 备份数据
sudo cp -r /var/lib/docker/volumes/gitea_data/_data ./backup/
```

### 配置文件位置
- **应用配置**: `/data/gitea/conf/app.ini` (在容器内)
- **仓库数据**: `/data/git/repositories` (在容器内)
- **数据库**: `/data/gitea/gitea.db` (在容器内)

## 🌐 局域网访问

如果需要让局域网内其他设备访问：

1. **修改配置文件** docker-compose-gitea.yml：
```yaml
environment:
  - GITEA__server__DOMAIN=0.0.0.0  # 或者您的IP地址
  - GITEA__server__ROOT_URL=http://YOUR_IP:3000/
```

2. **重新启动服务**：
```bash
docker-compose -f docker-compose-gitea.yml down
docker-compose -f docker-compose-gitea.yml up -d
```

## 📊 Gitea vs GitLab 对比

| 功能 | Gitea | GitLab |
|------|-------|--------|
| 资源占用 | 轻量 (~100MB) | 重量 (~4GB+) |
| 启动速度 | 快 (~30秒) | 慢 (~5-10分钟) |
| 功能完整 | 基础功能完整 | 功能丰富 |
| CI/CD | 支持 | 内置强大CI/CD |
| 适合场景 | 个人/小团队 | 中大型企业 |

## 🛠️ 高级配置

### 启用邮件通知
编辑配置文件或通过 Web 界面配置 SMTP 设置。

### 自定义主题
可以通过 Web 界面或修改配置文件来自定义界面外观。

### 集成 CI/CD
可以集成外部 CI/CD 工具如 Jenkins、GitHub Actions 等。

## 🔒 安全建议

1. **定期更新**: 使用 `docker-compose pull` 更新到最新版本
2. **备份数据**: 定期备份仓库和数据库
3. **防火墙**: 只开放必要端口
4. **SSL证书**: 生产环境建议配置 HTTPS

## ❓ 常见问题

### Q: 忘记管理员密码怎么办？
A: 可以通过 Docker 容器重置密码：
```bash
docker exec -it gitea gitea admin user change-password --username admin --password newpassword
```

### Q: 如何修改端口？
A: 编辑 docker-compose-gitea.yml 中的端口映射。

### Q: 数据存储在哪里？
A: 数据存储在 Docker 卷中，即使容器重启数据也不会丢失。

---

## 🎯 快速开始总结

1. **访问**: http://localhost:3000
2. **创建管理员账户**
3. **创建第一个仓库**
4. **开始使用您的私有 Git 服务器！**

恭喜！您现在拥有了一个功能完整的私有 Git 服务！🎉