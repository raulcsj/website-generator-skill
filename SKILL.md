---
name: theme-site-generator
description: Generate a complete, deployable Next.js content website (blog/diary-style) around any theme (travel diary, tech blog, recipe site, product review site, etc.) with rich, on-theme images woven naturally into each article, and prepare it for one-command deployment to Vercel and/or Cloudflare Pages with GitHub-based auto-deploy on updates. Works in claude.ai chat as well as agentic coding tools like Claude Code and OpenAI Codex, where content is written directly by the current agent with no separate model API key needed. Use this skill whenever the user asks to "build a site", "generate a website", "做一个网站/站点", "生成旅游日记网站", "用AI批量生成内容站点", "图文并茂的网站", "部署到 Cloudflare/CF Pages", or wants a themed content site deployed — even if they don't name a platform but mention deploying a site quickly. Also use when the user wants to add a new content batch (text or images) or a new deploy target to a site previously created with this skill.
---

# Theme Site Generator (Vercel / Cloudflare Pages)

一句话流程：**定主题 → 跑脚手架 → AI写图文并茂的内容 → 打包 → 交付部署与自动更新命令（Vercel 和/或 Cloudflare Pages）**。

Claude 的沙盒无法直接访问 vercel.com / cloudflare.com，所以本技能产出的是"开箱即用、一条命令部署"的完整项目，真正的部署命令由用户在本机执行（见 `references/deploy.md`）。项目用 `next.config.mjs` 的 `output: "export"` 纯静态导出（原因见 Step 2），Vercel 和 Cloudflare Pages 两个平台的配置默认都会生成，用户按需选一个或两个都部署。

## 运行环境：claude.ai 网页/App，还是 Claude Code / OpenAI Codex？

这个 skill 可能跑在两类环境里，行为要跟着环境简化，不要一套流程套死：

- **claude.ai 网页/App（默认，本文档其余部分假设的场景）**：沙盒连不到外部网站，也没有用户的真实项目目录，所以要打包成 zip 交付，内容默认由 Claude 直接写，图片/其他文字供应商的 API key 走 `.env.local` 配置。
- **Claude Code / OpenAI Codex（agentic 编码工具）**：跳过下面的判断——**当前正在执行这个 skill 的你就是模型本身**，不需要、也不要提示用户去配置 `ANTHROPIC_API_KEY`/`DEEPSEEK_API_KEY`/`OPENAI_API_KEY` 这类文字生成的 API key。Step 3 永远是"当前 agent 直接写 `.mdx`"，不要问用户选哪个文字供应商，也不要把 `generate-content.mjs` 当成首选路径提起——那是给脱离编码工具、以后想批量换供应商重新生成时用的备用脚本，正常流程和交付说明都不用提。图片是另一码事：Pexels/Unsplash/OpenAI 这些是图片检索/生成服务，不是"模型 API"，仍然需要独立 key，除非当前工具环境自带图片工具（比如有 image_search 之类的工具可直接用），有就直接用现有工具取图，没有就照常引导用户配一个图片服务的 key（只讲图片这一项，不要连带提文字模型 key）。另外这类工具通常直接跑在用户的真实项目目录、有真实的网络和 git 权限，Step 6 的"打包 zip 用 present_files 交付"不适用，跳过这步，直接在项目目录里操作，能自己跑的部署/推送命令（`npm run deploy:vercel` 等）就直接跑，不需要的话才退回到"打印命令让用户自己跑"。

## 何时跳过提问，直接执行

用户已经在同一句话里给出主题+基本信息（如"帮我做一个旅游日记站点，中文，10篇"）时，不要再反复确认，按下方默认值直接开工，最后一并说明假设。只有当**主题本身**完全没给出时才需要问。

## 工作流

### Step 1 — 确定参数（缺失项用默认值，不逐项追问）

| 参数 | 说明 | 默认值 |
|---|---|---|
| theme | 站点主题，如"旅游日记" | 必须由用户提供，缺失才问 |
| site_title | 站点名称 | 根据主题生成一个简洁站名 |
| site_description | 一句话简介 | 根据主题生成 |
| locale | zh / en | en |
| post_count | 首批文章数 | 8 |
| project_dir | 输出目录 | /home/claude/sites/<slug-of-theme> |
| ai_content_provider | 首批内容谁来写 | 当前 agent（Claude / Claude Code / Codex 等）直接写，不问、不需要任何模型 API key；claude.ai 网页场景下额外生成 DeepSeek/OpenAI/Claude 三选一的批量脚本供后续使用，Claude Code/Codex 场景下这个脚本仍会生成但不用在交付说明里提 |
| deploy_target | 部署平台 | 两套配置都生成（Vercel + Cloudflare Pages），用户按需选一个或都部署，不用为此单独提问 |

### Step 2 — 跑脚手架脚本（确定性部分，不要手写这些文件）

```bash
bash <本skill目录>/scripts/scaffold.sh \
  "<project_dir>" "<site_title>" "<site_description>" "<locale>" "<accent_color_hex 可选>"
```
（`<本skill目录>` 是这个技能实际安装的路径，例如 `/mnt/skills/user/theme-site-generator`，运行前先确认。）
这一步生成 Next.js App Router 骨架：布局、首页列表（带封面缩略图）、`[slug]` 详情页（带封面大图 + `<ArticleImage>` 组件用于正文配图）、`lib/posts.ts`（自动读取 `content/*.mdx`）、Tailwind、`sitemap.ts`/`robots.ts`、`vercel.json`、`README.md`，**以及一组纯 Node.js 跨平台脚本（Windows/Mac/Linux 通用，不依赖 bash）：`scripts/deploy-vercel.mjs`、`scripts/deploy-cloudflare.mjs`、`scripts/push-to-github.mjs`、多AI供应商内容生成脚本 `scripts/generate-content.mjs`（支持 Claude / DeepSeek / OpenAI）、多来源配图脚本 `scripts/fetch-images.mjs`（Pexels / Unsplash 实拍图 / OpenAI AI生图），都通过 `npm run xxx` 调用，密钥从 `.env.local` 自动读取（`content.config.json` + `.env.example` 也一并生成）**。**不要重复手写这些文件**，脚本已经生成好了；如果需要微调（比如换配色、加导航项），在脚本生成之后用 str_replace 改。

**关键架构决定：`next.config.mjs` 用 `output: "export"`（纯静态导出），不要改成 SSR 模式。** 这不是随意选的：测试过 Cloudflare 的 Workers 适配层方案（`@opennextjs/cloudflare`），发现 `lib/posts.ts` 在请求时读文件系统（`fs.readFileSync`）在 Cloudflare Workers 运行时会直接 500——Workers 没有持久文件系统，这是该方案的真实缺陷，不是配置问题。纯静态导出从根本上绕开这个坑：所有 `fs` 调用只发生在 `next build` 期间，产出的 `out/` 是纯 HTML/CSS/JS，Vercel 和 Cloudflare Pages 都能直接托管，不需要任何服务端运行时。代价是不支持请求时动态渲染（登录态、表单提交 API 之类），但博客/日记/评测类内容站不需要这些，不受影响。

### Step 3 — AI 生成图文并茂的内容

**首批内容默认由当前 agent 直接写**（最快，不需要任何模型 API key，Claude Code/Codex 环境下这是唯一路径，不要偏离）：在 `<project_dir>/content/` 下为每篇文章创建一个 `.mdx` 文件。**先读 `references/content-guide.md`** 再动笔，严格遵守其中的 frontmatter 格式、字数、slug 命名规则、"避免空泛套话"以及**配图规则**——图文并茂是硬性要求，不是锦上添花：每篇要有封面图 + 2-4 张正文配图，用 `<ArticleImage src="/images/<slug>/N.jpg" alt="具体描述" caption="可选图注" />` 插在它所配的那段文字旁边，query/alt 必须具体贴题（写清楚具体的地点/菜品/场景，不要写泛泛的关键词），这样图片才会"自然生动"而不是随便凑数的通用图。

主题是"旅游日记"这类时，可以让多篇文章围绕一次假想或真实行程按时间/地点递进，形成系列感，配图也跟着行程走（不同地标/时段/场景）；主题是评测/教程类时，每篇聚焦一个具体子话题，配图对应具体的产品细节或操作步骤。

**同时把选题和图片需求写入 `content.config.json`**（每个 topic 是 `{title, brief, images: [{query, alt, filename}]}`），这样用户在本机跑 `npm run images:fetch -- --provider pexels|unsplash|openai` 才能拿到真正的图片文件——**图片服务连不到（claude.ai 沙盒）或没配 key（Claude Code/Codex 下如果当前工具没有自带取图能力）时，写在 `<ArticleImage>` 里的图片路径还只是占位，图片文件要靠这个脚本才会生成**，这一点必须讲清楚，不要让用户误以为图已经配好了。claude.ai 网页场景下同时也生成了 `generate-content.mjs`（文字多供应商脚本），但那是给"以后脱离对话、想换供应商批量重写"用的备用工具，不是正常交付流程的一部分，不用主动提起。

### Step 4 — 自查 + 本地构建校验（可选但推荐）

如果容器里有 node/npm（本环境的白名单包含 registry.npmjs.org，可以 `npm install` 成功），跑一次构建确认没有语法错误：
```bash
cd <project_dir> && npm install && npm run build
```
构建能过，即使 `public/images/` 下还没有真实图片文件也没关系（`next/image` 用字符串路径引用 `/public` 下的文件，构建期不校验文件是否存在，运行时才会 404）——这是预期行为，不代表配图这步失败了。构建失败大概率是 MDX frontmatter 格式或组件引用问题，检查 `content/*.mdx` 是否符合 `content-guide.md` 的格式。如果环境没有 node，跳过这步，直接交付，在交付说明里提醒用户本地 `npm install && npm run build` 自查。

### Step 5 — GitHub 托管 + 自动部署（Vercel / Cloudflare Pages，实现"更新自动部署"的关键）

一次性手动部署（`npm run deploy:vercel` 或 `npm run deploy:cloudflare`）之后改动不会自动上线；要做到"以后 push 就自动更新"，必须走 GitHub + 平台项目绑定。

- 如果沙盒里 `gh` 已登录（`gh auth status` 成功）或用户之前给过 `GITHUB_TOKEN`：直接跑 `npm run push:github -- <repo-name> public` 完成 git init + 创建仓库 + push，不用等用户确认每一步。
- 否则（大多数情况，因为 GitHub 凭证在用户本机而不在这个沙盒里）：不要假装已经推送，在交付说明里给出这条命令，让用户在本机跑。
- 无论哪种情况，都要说明：GitHub 仓库建好后，去对应平台网页导入一次（Vercel: vercel.com/new；Cloudflare: 控制台 Workers & Pages → Pages → 连接 Git 仓库，构建命令 `npm run build`，输出目录 `out`）——这一步必须用户自己点，Claude 沙盒到不了这两个网站。绑定完成后，以后每次 `git push`（不管是加文章还是改代码）都会自动重新构建部署，不需要再手动跑部署命令。两个平台可以只选一个，也可以都绑定。

### Step 6 — 交付

**claude.ai 网页/App**：打包成 zip 再用 present_files 交付（沙盒里没有用户的真实项目目录，只能这样交接）：
```bash
cd <project_dir>/.. && zip -r <project_name>.zip <project_name> -x "*/node_modules/*" -x "*/.next/*" -x "*/.git/*" -x "*/out/*"
```
交付说明只需六点，不要展开讲：
1. 已生成的文章数量和主题
2. **配图还差最后一步**：把 `.env.example` 复制改名成 `.env.local` 并填入 `PEXELS_API_KEY`（推荐，实拍图）或 `OPENAI_API_KEY`（AI生图）→ `npm run images:fetch -- --provider pexels`，图片才会真正出现，否则页面上是占位裂图
3. 快速上线（二选一或都要，Windows/Mac/Linux 命令一致）：Vercel `npm run deploy:vercel`；Cloudflare `npm run deploy:cloudflare`
4. 长期自动更新：`npm run push:github -- <repo-name>` 推到 GitHub → 对应平台网页导入一次 → 以后 push 自动部署
5. 追加内容：直接让 Claude 写 `.mdx`（不需要 API key）
6. **Windows 用户直接用以上 `npm run ...` 命令即可**，不需要 WSL/Git Bash

**Claude Code / OpenAI Codex**：不打包、不 present_files——项目已经在用户的真实工作目录里，直接说清楚生成了什么（文章数/主题）+ 图片还差最后一步（同上，配一个图片服务 key 再跑 `npm run images:fetch`）就够了。如果当前环境有真实的网络和 git 权限，能自己跑的步骤（`npm install`、`npm run build` 自查、`npm run push:github`、`npm run deploy:vercel`/`deploy:cloudflare`）直接跑，跑不了或没有权限（比如没有 `gh` 登录、没有 Vercel/Cloudflare 授权）才退回去把命令列给用户自己跑，不要不管环境能力一律甩命令了事。

需要更细的部署路径（自定义域名、环境变量、两平台并行）时才读 `references/deploy.md`，默认不用展开讲。

## 更新已有站点

如果用户是要给之前用本技能生成的站点追加内容，跳过 Step 2（脚手架已存在），直接读该项目的 `content/` 目录了解已有文章风格和 slug 规律，Step 3 按同样规范追加新 `.mdx`，然后重新打包交付。

## 关键原则

- **确定性的东西用脚本，创造性的东西 Claude 自己写** —— 项目骨架/配置文件永远用 `scaffold.sh`，不要手写 next.config / tailwind.config 这些样板文件，容易出错且浪费时间；文章内容是脚本做不了的，必须 Claude 自己按主题生成。
- 不要在对话里佯装自己已经"部署上线"——沙盒到不了 vercel.com / cloudflare.com，只能交付可部署的代码 + 命令。
- 默认技术栈固定为 Next.js App Router（纯静态导出）+ MDX + Tailwind，同时对 Vercel 和 Cloudflare Pages 零配置友好，除非用户明确要求其他框架或需要真正的服务端动态渲染（这种情况下静态导出不适用，需要单独说明取舍，不要默默改架构）。
