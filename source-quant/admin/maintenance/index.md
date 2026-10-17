---
title: 维护说明
layout: quant-static
section: admin
noindex: true
---
## 日常内容

课程、文章、公告、作业和资料在[管理平台](/admin/)中编辑，保存后立即生效，不需要重新构建网站。导航名称和顺序在「内容管理」的目录树中调整。

## 发布外观或目录变更

1. 后台调整目录或题目后，运行 `npm run sync:catalog`，同步公开目录与搜索范围。
2. 运行 `npm run build` 生成 `docs/`，再运行 `npm run check` 检查站内链接。
3. 提交并推送到 main 分支，由 GitHub Pages 发布。

## 数据与权限

登录、内容和讨论数据保存在独立的 Supabase 项目中，权限由数据库策略控制。网页只包含公开的 publishable key；行情令牌等密钥只放在本机环境变量中，不要写入页面或仓库。
