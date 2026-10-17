# QuantLab 量化学习站

线上地址：https://quantlabshark.github.io/

源文件在 `source-quant/`，主题在 `themes/quant-lab/`。运行 `npm ci`、`npm run build` 生成 `docs/`，提交并推送后由 GitHub Pages 发布 main 分支的 `/docs`。

## 内容与账号

网站沿用原学习站的账号、课程进度、私人笔记、讨论回复、作者工作台、审核与管理功能。量化站使用独立 Supabase 项目 `skqoondpsqzvybnmcaas`。网页内只包含公开 publishable key，数据权限由数据库策略控制。首次使用已验证的 GitHub 所有者账号登录后自动获得管理员身份。

课程与文章正文在数据库中管理；`tools/content/catalog-content.json` 只保留公开目录信息。通过网站管理平台更新内容。原 OpenFOAM 项目没有被写入。

吉祥物已替换为原创鲨鱼矢量形象。小镇入口关闭，部分兼容代码和数据库结构暂时保留。

## 本机行情获取

`tools/tushare_fetch.py` 从环境变量 `TUSHARE_TOKEN` 或本机 `.env` 读取令牌，通过 HTTPS 请求日线数据。运行示例：

```powershell
D:\anaconda3\python.exe tools/tushare_fetch.py --code 000001.SZ --start 20260101 --end 20261016
```

结果写入 `.quantlab-work/market-data/`，不会提交到 GitHub。返回价格为未复权日线，不能直接当作含分红收益率。勿将 `.env`、令牌或原始账号数据放到网页中。公开实验使用可重复的合成数据。

## 迁移说明

迁移文件来自原站并适配新项目。原站文件名的历史顺序并非完整依赖顺序：`town_eggs` 应在 `town_egg_final_catalog_and_times` 前应用，`quant_scoped_search_dependency` 应在 `article_login_required` 前应用。新站不启用小镇 Realtime 策略。`quant_private_notes` 补齐私人笔记与新站所有者首次登录授权。

原博客已保存在本机 `.quantlab-work/legacy-site/`，Git 标签 `pre-quant-learning-20261017` 保留原发布版本。
