# QuantLab 量化学习站

线上地址：https://quantlabshark.github.io/

网站采用公开静态页面，阅读课程和题解无需注册或登录。正文、目录、全文搜索、插图与代码附件均由 GitHub Pages 提供，不连接后台数据库。

## 内容

`tools/content/articles/` 保存 744 篇文章：66 节系统课程、394 个基础理论单元、136 节专题课程、100 个笔面试单元和 48 篇参考与实践资料。正文和附件配置在各篇 JSON 中修改；目录与分组保存在 `tools/content/`。不保存用户资料、私人笔记或账号记录。

`source-quant/` 保存入口页与下载附件，`themes/quant-lab/` 保存布局和浏览器交互，`lib/static-content.cjs` 与 `scripts/static-content.js` 将文章生成独立页面。旧的 `/read/?slug=...` 链接会打开对应的 `/read/文章名/` 静态页面。

保留目录搜索、课程分页、主题配色、章节导航、折叠解答、鲨鱼提示、配图放大、代码复制和附件下载。登录、个人中心、后台编辑、数据库评论、私人笔记、成长记录与访问计数已移除。

## 构建与发布

```powershell
npm ci
npm run build -- --force
npm run check
npm run preview
```

预览地址为 http://127.0.0.1:4175/。构建生成 `docs/`，提交并推送到组织仓库后，由 GitHub Pages 从 `main:/docs` 发布。构建不需要数据库账号、密钥或在线服务。全文搜索索引随正文一起生成。

## 本机行情数据

`tools/tushare_fetch.py` 从本机环境变量 `TUSHARE_TOKEN` 或 `.env` 读取令牌，数据写入忽略目录 `.quantlab-work/market-data/`。公开网站只包含不带令牌的示例与教学数据。
