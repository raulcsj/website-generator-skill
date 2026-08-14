# 部署细节：Vercel / Cloudflare Pages

Claude 的沙盒网络无法访问 vercel.com / cloudflare.com，因此无法在对话中代替用户完成真实部署。所有部署/推送脚本都是纯 Node.js（`scripts/*.mjs`），通过 `npm run xxx` 调用，Windows（PowerShell/cmd）、Mac、Linux 命令完全一致，不依赖 bash/WSL。
本技能生成的是**可直接部署**的完整项目（两套平台配置都已生成，选一个用即可），实际部署命令需用户在本机终端执行。

项目 `next.config.mjs` 用的是 `output: "export"`（纯静态导出），`next build` 直接产出 `out/` 静态目录——这个决定是关键：静态导出没有运行时服务端函数，Vercel 和 Cloudflare Pages 都能直接托管，不会遇到"Cloudflare Workers 运行时没有文件系统，读 content/*.mdx 会 500"这类问题（这是 Workers 适配层方案的真实坑，测试时验证过）。代价是不支持需要请求时动态渲染的功能（比如登录态页面、表单提交 API），纯内容站/博客/日记类网站不受影响。

## Vercel

**CLI（一次性，最快看到结果）**
```bash
npm run deploy:vercel
```
首次会提示浏览器授权登录，之后每次跑这条命令就是重新部署。每次改动都要重新手动跑一遍，没有自动更新。

**GitHub + Vercel 绑定（推荐，实现 push 自动部署）**
```bash
npm run push:github -- <repo-name> public
```
然后到 https://vercel.com/new 导入这个仓库一次，Framework 自动识别 Next.js（静态导出模式）→ Deploy。之后每次 `git push` 都自动重新构建上线。

## Cloudflare Pages

**CLI（一次性，最快看到结果）**
```bash
npm run deploy:cloudflare
```
内部：`wrangler login`（首次授权）→ 建 Pages 项目 → `wrangler pages deploy out`。

**GitHub + Cloudflare Pages 绑定（推荐，实现 push 自动部署）**
```bash
npm run push:github -- <repo-name> public
```
然后到 Cloudflare 控制台 Workers & Pages → 创建 → Pages → 连接该 Git 仓库，构建命令填 `npm run build`，构建输出目录填 `out`。之后每次 `git push` 都自动重新构建上线。

## 两个平台可以都部署

`vercel.json` 和 Cloudflare Pages 配置互不冲突，产物是同一份 `out/` 静态目录，可以只选一个平台，也可以两个都部署做灾备/对比、或者一个当预览环境一个当生产。

## 常见后续需求
- **自定义域名**：Vercel Settings → Domains；Cloudflare Pages 项目 → Custom domains，都是加一条 CNAME/A 记录
- **图片**：MDX 用 `<ArticleImage src="/images/<slug>/xxx.jpg" />` 引用 `public/images/` 下的文件，参考 `scripts/fetch-images.mjs`（见项目 README）
- **本地构建自查**：`npm run build` 后检查 `out/` 目录是否生成了预期的 HTML 文件，静态导出模式下这一步能提前暴露大部分部署会出的问题
