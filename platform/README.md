# 诗卷内容平台

这个目录是现有静态学习原型进入正式 Web 开发的第一阶段基础：内容规范、PostgreSQL 数据模型、Excel 审核导入、内容管理 API 和本地管理界面。

## 当前组成

| 路径 | 用途 |
|---|---|
| `db/migrations/` | PostgreSQL 表结构与审核暂存区。 |
| `db/seeds/` | 年级、题材、体裁和意象等基础分类。 |
| `docs/content-data-standard.md` | 诗词、拼音、解析、媒体和题目的发布规范。 |
| `tools/import_workbook.py` | 将 Excel 原始内容导入审核暂存区。 |
| `api/` | FastAPI 内容管理 API，包含最小本地后台。 |
| `scripts/start-local.ps1` | Windows 本地启动检查与 Docker Compose 启动。 |

## 本地启动

先安装并启动 Docker Desktop，然后在 PowerShell 中运行：

```powershell
Set-Location platform
Copy-Item .env.example .env
./scripts/start-local.ps1
```

启动完成后：

- 内容后台：`http://localhost:8000/admin/`
- API 健康检查：`http://localhost:8000/health`
- Adminer 数据库查看器：`http://localhost:8080`

后台首次连接时填写 `.env` 中的 `ADMIN_API_TOKEN`。默认开发值不能用于共享环境。

## Excel 导入流程

先只读预检：

```powershell
$workbook = Get-ChildItem .. -File -Filter *.xlsx | Select-Object -First 1
python tools/import_workbook.py --workbook $workbook.FullName --dry-run
```

确认后写入审核暂存区：

```powershell
python tools/import_workbook.py --database-url "postgresql://poetry:poetry_dev_password@localhost:5432/poetry" --workbook $workbook.FullName
```

导入记录不会自动发布。编辑人员需要补齐拼音、分类、解析、背景、媒体和题目，再通过管理 API 发布。

## 下一项实施工作

1. 在管理后台增加暂存记录审核、合并和退回界面。
2. 补充诗词编辑、分类选择、媒体上传与题目编辑 API。
3. 增加正式的用户认证与角色权限，移除本地开发令牌方案。
4. 将现有静态学习页改为调用公开内容 API 和用户学习 API。