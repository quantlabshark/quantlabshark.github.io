# QuantLab 量化学习站

线上地址：https://quantlabshark.github.io/

源文件在 `source-quant/`，主题在 `themes/quant-lab/`。运行 `npm ci`、`npm run build` 生成 `docs/`，提交并推送后由 GitHub Pages 发布 main 分支的 `/docs`。

## 内容与账号

网站沿用原学习站的账号、课程进度、私人笔记、讨论回复、作者工作台、审核与管理功能。量化站使用独立 Supabase 项目 `skqoondpsqzvybnmcaas`。网页内只包含公开 publishable key，数据权限由数据库策略控制。首次使用已验证的 GitHub 所有者账号登录后自动获得管理员身份。

课程与文章正文在数据库中管理；`tools/content/catalog-content.json` 只保留公开目录信息。通过网站管理平台更新内容。原 OpenFOAM 项目没有被写入。

## 系统学习与笔面试

`/courses/` 按 Roadmap Ultimate Edition 与 Xin Guo《量化交易：算法、分析、数据、模型和优化》组织为 11 个阶段、66 课，并以《深入浅出 Python 量化交易实战》补充程序和案例。课程含例题、练习解答、原书对应位置和示例代码包。原 20 篇课程保留直接阅读地址，作为旧版参考内容，不计入新版进度。

`/interview/` 包含经典书籍题解与笔面试资料两册，共 100 个阅读单元。Zhou 教材全部 7 章整理为 33 节；QuantMaterial 整理为 67 节。`/interview/sources/` 逐项列出 93 个原文件及压缩包内 4 个独有文件，记录重复合并、配套附件和原始条件缺项。数据包包含计算结果和复现脚本，交易表已去除姓名列。笔面试内容不计入系统课程进度。

笔面试正文中的 636 组解答使用原生 `details` 默认折叠，保留题干可见；每页可统一展开和收起。目录跳转和私人笔记定位会展开对应解答。

`/theory/` 是“基础理论与原理”的书籍入口，沿用 OpenFOAM 站的书籍卡片、章节目录与阅读导航。首册《因子投资：方法与实践》覆盖 7 章、43 个二级小节，另设阅读导引、后记、附录 A 与参考文献索引，共 47 个阅读单元。正文补充收益率、统计、回归和矩阵基础，说明原书历史实证与教学模拟的区别。`factor-book-coverage.json` 记录原书页码对应关系，配套示例在 `factor-investing-examples.zip`。

导航的初始页面和动态目录共用 `navigation-tree.js`，避免跳转时入口缺失。`npm run sync:catalog` 从量化站读取最新公开目录信息，更新 `tools/content/navigation.json`、`course-catalog.json`、`interview-catalog.json`、`theory-catalog.json` 与搜索范围；后台调整目录或题目后，先同步，再构建发布。同步脚本不读取正文或私有数据。在线目录读取失败时，页面仍保留发布时的导航和索引。

吉祥物小鲨是内联矢量图，形象与装扮在 `panda-art.js`、`panda-character.css` 中（文件名沿用旧站，便于兼容数据库里的装扮记录）。小镇前端代码和管理入口已移除；数据库中的小镇表与迁移暂时保留，未删除数据。

## 本机行情获取

`tools/tushare_fetch.py` 从环境变量 `TUSHARE_TOKEN` 或本机 `.env` 读取令牌，通过 HTTPS 请求日线数据。运行示例：

```powershell
D:\anaconda3\python.exe tools/tushare_fetch.py --code 000001.SZ --start 20260101 --end 20261016
```

结果写入 `.quantlab-work/market-data/`，不会提交到 GitHub。返回价格为未复权日线，不能直接当作含分红收益率。勿将 `.env`、令牌或原始账号数据放到网页中。公开实验使用可重复的合成数据。

## 迁移说明

迁移文件来自原站并适配新项目。原站文件名的历史顺序并非完整依赖顺序：`town_eggs` 应在 `town_egg_final_catalog_and_times` 前应用，`quant_scoped_search_dependency` 应在 `article_login_required` 前应用。新站不启用小镇 Realtime 策略。`quant_private_notes` 补齐私人笔记与新站所有者首次登录授权。

原博客已保存在本机 `.quantlab-work/legacy-site/`，Git 标签 `pre-quant-learning-20261017` 保留原发布版本。
