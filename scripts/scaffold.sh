#!/bin/bash
# scaffold.sh - 生成一个可直接部署到 Vercel 的 Next.js (App Router) 内容站点骨架
# 用法: bash scaffold.sh <project_dir> <site_title> <site_description> <locale: zh|en> [accent_color_hex]
set -e

PROJECT_DIR="${1:?用法: scaffold.sh <project_dir> <site_title> <site_description> <locale> [accent_color_hex]}"
SITE_TITLE="${2:?缺少 site_title}"
SITE_DESC="${3:?缺少 site_description}"
LOCALE="${4:-en}"
ACCENT="${5:-#0ea5e9}"

mkdir -p "$PROJECT_DIR"/{app,content,lib,public,styles,scripts}
cd "$PROJECT_DIR"

# ---------- package.json ----------
cat > package.json <<EOF
{
  "name": "$(basename "$PROJECT_DIR")",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "deploy:vercel": "node scripts/deploy-vercel.mjs",
    "deploy:cloudflare": "node scripts/deploy-cloudflare.mjs",
    "push:github": "node scripts/push-to-github.mjs",
    "content:generate": "node scripts/generate-content.mjs",
    "images:fetch": "node scripts/fetch-images.mjs"
  },
  "dependencies": {
    "next": "^15.5.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "gray-matter": "^4.0.3",
    "next-mdx-remote": "^6.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.14.0",
    "@types/react": "^19.0.0",
    "@tailwindcss/typography": "^0.5.13",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.38",
    "tailwindcss": "^3.4.4",
    "typescript": "^5.5.0",
    "wrangler": "^4.86.0",
    "dotenv": "^16.4.5"
  }
}
EOF

# ---------- config files ----------
cat > next.config.mjs <<'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: "export",
  images: { unoptimized: true },
};
export default nextConfig;
EOF

cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "baseUrl": ".",
    "paths": { "@/*": ["./*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
EOF

cat > tailwind.config.ts <<EOF
import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./lib/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: { accent: "$ACCENT" },
    },
  },
  plugins: [require("@tailwindcss/typography")],
};
export default config;
EOF

cat > postcss.config.js <<'EOF'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
EOF

cat > .gitignore <<'EOF'
node_modules
.next
out
.vercel
.wrangler
.env*.local
EOF

cat > vercel.json <<'EOF'
{
  "framework": "nextjs"
}
EOF

# ---------- styles ----------
cat > styles/globals.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body { @apply bg-white text-slate-900 antialiased; }
a { @apply text-accent underline-offset-2 hover:underline; }
EOF

# ---------- components/ArticleImage.tsx : 文章内配图组件 ----------
mkdir -p components
cat > components/ArticleImage.tsx <<'EOF'
import Image from "next/image";

export default function ArticleImage({
  src,
  alt,
  caption,
}: {
  src: string;
  alt: string;
  caption?: string;
}) {
  return (
    <figure className="my-6 not-prose">
      <div className="relative w-full aspect-[3/2] overflow-hidden rounded-lg bg-slate-100">
        <Image src={src} alt={alt} fill className="object-cover" sizes="(max-width: 768px) 100vw, 700px" />
      </div>
      {caption && <figcaption className="mt-2 text-sm text-slate-500 text-center">{caption}</figcaption>}
    </figure>
  );
}
EOF

# ---------- lib/posts.ts : 读取 content/*.mdx ----------
cat > lib/posts.ts <<'EOF'
import fs from "fs";
import path from "path";
import matter from "gray-matter";

const CONTENT_DIR = path.join(process.cwd(), "content");

export type PostMeta = {
  slug: string;
  title: string;
  description: string;
  date: string;
  cover?: string;
  tags?: string[];
};

export function getAllSlugs(): string[] {
  if (!fs.existsSync(CONTENT_DIR)) return [];
  return fs.readdirSync(CONTENT_DIR).filter((f) => f.endsWith(".mdx")).map((f) => f.replace(/\.mdx$/, ""));
}

export function getPostBySlug(slug: string) {
  const filePath = path.join(CONTENT_DIR, `${slug}.mdx`);
  const raw = fs.readFileSync(filePath, "utf8");
  const { data, content } = matter(raw);
  return { meta: { slug, ...(data as Omit<PostMeta, "slug">) }, content };
}

export function getAllPosts(): PostMeta[] {
  return getAllSlugs()
    .map((slug) => getPostBySlug(slug).meta)
    .sort((a, b) => (a.date < b.date ? 1 : -1));
}
EOF

# ---------- app/layout.tsx ----------
cat > app/layout.tsx <<EOF
import "../styles/globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "$SITE_TITLE",
  description: "$SITE_DESC",
  metadataBase: new URL("https://example.vercel.app"),
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="${LOCALE}">
      <body>
        <header className="max-w-3xl mx-auto px-4 py-6 flex items-center justify-between">
          <a href="/" className="font-bold text-xl">$SITE_TITLE</a>
        </header>
        <main className="max-w-3xl mx-auto px-4 pb-16">{children}</main>
        <footer className="max-w-3xl mx-auto px-4 py-10 text-sm text-slate-400">
          © {new Date().getFullYear()} $SITE_TITLE
        </footer>
      </body>
    </html>
  );
}
EOF

# ---------- app/page.tsx : 首页列表 ----------
cat > app/page.tsx <<'EOF'
import Link from "next/link";
import Image from "next/image";
import { getAllPosts } from "@/lib/posts";

export default function Home() {
  const posts = getAllPosts();
  return (
    <div className="space-y-8 mt-4">
      {posts.map((p) => (
        <article key={p.slug} className="border-b pb-6 flex gap-4">
          {p.cover && (
            <Link href={`/${p.slug}`} className="shrink-0 relative w-28 h-28 sm:w-36 sm:h-36 rounded-lg overflow-hidden bg-slate-100">
              <Image src={p.cover} alt={p.title} fill className="object-cover" sizes="144px" />
            </Link>
          )}
          <div>
            <h2 className="text-2xl font-semibold">
              <Link href={`/${p.slug}`}>{p.title}</Link>
            </h2>
            <p className="text-slate-500 text-sm mt-1">{p.date}</p>
            <p className="mt-2 text-slate-700">{p.description}</p>
          </div>
        </article>
      ))}
      {posts.length === 0 && (
        <p className="text-slate-400">还没有文章，请在 content/ 目录下添加 .mdx 文件。</p>
      )}
    </div>
  );
}
EOF

# ---------- app/[slug]/page.tsx : 文章详情 ----------
mkdir -p "app/[slug]"
cat > "app/[slug]/page.tsx" <<'EOF'
import Image from "next/image";
import { MDXRemote } from "next-mdx-remote/rsc";
import { getAllSlugs, getPostBySlug } from "@/lib/posts";
import ArticleImage from "@/components/ArticleImage";
import type { Metadata } from "next";

export function generateStaticParams() {
  return getAllSlugs().map((slug) => ({ slug }));
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const { meta } = getPostBySlug(slug);
  return { title: meta.title, description: meta.description };
}

export default async function Post({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const { meta, content } = getPostBySlug(slug);
  return (
    <article className="prose prose-slate max-w-none mt-4">
      {meta.cover && (
        <div className="relative w-full aspect-[16/9] not-prose rounded-lg overflow-hidden bg-slate-100 mb-6">
          <Image src={meta.cover} alt={meta.title} fill className="object-cover" priority sizes="700px" />
        </div>
      )}
      <h1>{meta.title}</h1>
      <p className="text-slate-500 text-sm">{meta.date}</p>
      <MDXRemote source={content} components={{ ArticleImage }} />
    </article>
  );
}
EOF

# ---------- SEO: sitemap / robots ----------
cat > app/sitemap.ts <<'EOF'
import { getAllPosts } from "@/lib/posts";
import type { MetadataRoute } from "next";

export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  const base = "https://example.vercel.app";
  const posts = getAllPosts().map((p) => ({
    url: `${base}/${p.slug}`,
    lastModified: p.date,
  }));
  return [{ url: base, lastModified: new Date().toISOString() }, ...posts];
}
EOF

cat > app/robots.ts <<'EOF'
import type { MetadataRoute } from "next";

export const dynamic = "force-static";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: "*", allow: "/" },
    sitemap: "https://example.vercel.app/sitemap.xml",
  };
}
EOF

# ---------- README + 一键部署脚本 ----------
cat > README.md <<EOF
# $SITE_TITLE

$SITE_DESC

> 全部命令都是 \`npm run xxx\`，Windows（PowerShell/cmd）、Mac、Linux 通用，不依赖 bash/WSL。

## 本地运行
\`\`\`bash
npm install
npm run dev
\`\`\`

## 部署（Vercel 或 Cloudflare，任选其一，两套配置都已生成）

### Vercel

**方式一：CLI（最快）**
\`\`\`bash
npm run deploy:vercel
\`\`\`
首次会提示浏览器授权登录，之后每次跑这条命令就是重新部署。

**方式二：Git + Vercel 网页导入（一次绑定，之后 push 自动部署）**
\`\`\`bash
npm run push:github -- my-site-name public
\`\`\`
然后到 https://vercel.com/new 导入该仓库，Framework 会自动识别为 Next.js，直接 Deploy。

### Cloudflare Pages（纯静态导出，零适配层，最稳）

本项目 \`next.config.mjs\` 已设 \`output: "export"\`，\`next build\` 直接产出静态 \`out/\` 目录，Cloudflare Pages 原生托管，不需要 Workers 运行时适配，也就没有"服务端读文件"这类在 Workers 里跑不通的问题。

**方式一：CLI（最快）**
\`\`\`bash
npm run deploy:cloudflare
\`\`\`
内部依次是 build → \`wrangler login\`（首次授权）→ 建 Pages 项目（已存在会跳过）→ \`wrangler pages deploy out\`。

**方式二：Git 集成（Pages 面板导入一次，之后 push 自动部署）**
推送到 GitHub 后，到 Cloudflare 控制台 Workers & Pages → 创建 → Pages → 连接该 Git 仓库，构建命令填 \`npm run build\`，构建输出目录填 \`out\`，之后每次 push 自动重新构建上线。

两套配置（\`vercel.json\` 和 Cloudflare Pages）互不冲突，可以只选一个平台部署，也可以两个都部署做灾备/对比，产物是同一份静态 \`out/\` 目录。

## 新增内容

**推荐方式：让 Claude / Claude Code / Codex 直接写**，不需要配置任何模型 API key。在 \`content/\` 目录下新增 \`xxx.mdx\` 文件：
\`\`\`
---
title: 文章标题
description: 一句话描述
date: "2026-08-13"
tags: ["标签1", "标签2"]
---
正文 Markdown/MDX 内容...
\`\`\`

**备用方式：脱离编码 agent、想批量重新生成/换供应商时**，编辑 \`content.config.json\` 列出要写的选题：
\`\`\`json
{
  "locale": "$LOCALE",
  "topics": [
    { "title": "working title", "brief": "一句话说明角度" }
  ]
}
\`\`\`
然后：
\`\`\`bash
copy .env.example .env.local    # Windows；Mac/Linux 用 cp .env.example .env.local
\`\`\`
编辑 \`.env.local\` 填入对应密钥（三选一即可），脚本会自动读取，不需要手动 export/set：
\`\`\`bash
npm run content:generate -- --provider deepseek   # 或 openai / claude
\`\`\`
无需改代码，首页和详情页会自动读取 \`content/\` 下的所有文件。

## 配图（图文并茂）

每篇文章的封面图 + 正文配图统一放在 \`public/images/<slug>/\` 下，MDX 里用 \`<ArticleImage src="/images/<slug>/1.jpg" alt="具体描述" caption="图注（可选）" />\` 插入。

真正的图片文件需要在本机获取（Claude 沙盒连不到图片服务），同样先把密钥填进 \`.env.local\`：
\`\`\`bash
npm run images:fetch -- --provider pexels   # 或 unsplash / openai（AI生图，适合插画类主题）
\`\`\`
脚本按 \`content.config.json\` 里每篇 topic 的 \`images: [{query, alt, filename}]\` 逐张下载/生成，图片查询词（query）越具体越贴题（比如不要写 "travel"，要写 "narrow stone alley in Kyoto at dusk"）。

## GitHub 托管 + 自动部署（Vercel / Cloudflare 均支持）

一次性设置后，以后每次 \`git push\` 都会自动触发重新构建上线（Vercel 和 Cloudflare 的 Git 集成都是这个模式）：

\`\`\`bash
npm run push:github -- $(basename "$PROJECT_DIR") public
\`\`\`
（Windows PowerShell 下同样是 \`npm run push:github -- 项目名 public\`；需要本机装了 [gh CLI](https://cli.github.com/) 并登录过，没有的话脚本会打印手动创建仓库的步骤。）

推送完成后，任选：
- **Vercel**：https://vercel.com/new 导入该仓库（仅需一次），自动识别 Next.js
- **Cloudflare**：控制台 Workers & Pages → Pages → 连接该 Git 仓库（仅需一次），构建命令 \`npm run build\`，输出目录 \`out\`

绑定完成后，以后无论是加文章、跑 \`content:generate\`/\`images:fetch\`、还是改代码，只要 \`git push\`，对应平台都会自动重新构建部署，不需要再手动跑部署命令。

## Windows 用户须知

- 只需要装好 [Node.js](https://nodejs.org/)（自带 npm/npx），不需要 WSL、Git Bash 或 bash，所有 \`npm run xxx\` 命令在 PowerShell / cmd 里原样可用。
- \`deploy.sh\` / \`deploy-cf.sh\` 是给 Mac/Linux 用户的 bash 便捷别名，Windows 用户忽略即可，直接用对应的 \`npm run deploy:vercel\` / \`npm run deploy:cloudflare\`。
- 唯一需要额外装的外部工具：部署到 Vercel/Cloudflare 不需要预装 CLI（\`npx\` 会按需下载）；如果要用 \`npm run push:github\` 自动建仓库，需要装 [GitHub CLI](https://cli.github.com/) 并 \`gh auth login\`，否则脚本会退化成打印手动步骤，照着做也一样能推送。
EOF

cat > deploy.sh <<'EOF'
#!/bin/bash
# Mac/Linux 用户的便捷别名，等价于 npm run deploy:vercel（Windows 用户直接用 npm run deploy:vercel 即可，不需要这个文件）
set -e
npm install
npm run deploy:vercel
EOF
chmod +x deploy.sh

cat > deploy-cf.sh <<'EOF'
#!/bin/bash
# Mac/Linux 用户的便捷别名，等价于 npm run deploy:cloudflare（Windows 用户直接用 npm run deploy:cloudflare 即可）
set -e
npm install
npm run deploy:cloudflare
EOF
chmod +x deploy-cf.sh

# ---------- 跨平台部署/推送脚本（纯 Node.js，Windows/Mac/Linux 通用，不依赖 bash） ----------
cat > scripts/deploy-vercel.mjs <<'EOF'
#!/usr/bin/env node
// 一键部署到 Vercel。跨平台（Windows/Mac/Linux 通用，只依赖 node/npm，不依赖 bash）。
// 用法: npm run deploy:vercel
import { execSync } from "child_process";

function run(cmd) {
  console.log(`$ ${cmd}`);
  execSync(cmd, { stdio: "inherit" });
}

try {
  run("npx vercel --prod");
} catch (e) {
  console.error("部署失败，检查是否已 `npx vercel login` 授权过。");
  process.exit(1);
}
EOF

cat > scripts/deploy-cloudflare.mjs <<'EOF'
#!/usr/bin/env node
// 一键部署到 Cloudflare Pages（纯静态导出）。跨平台（Windows/Mac/Linux 通用）。
// 用法: npm run deploy:cloudflare
import { execSync } from "child_process";
import path from "path";

const PROJECT_NAME = path.basename(process.cwd());

function run(cmd, opts = {}) {
  console.log(`$ ${cmd}`);
  execSync(cmd, { stdio: "inherit", ...opts });
}

run("npm run build"); // next build，output:"export" 会产出 out/ 静态目录
run("npx wrangler login"); // 首次需要浏览器授权，已登录会跳过

try {
  run(`npx wrangler pages project create "${PROJECT_NAME}" --production-branch=main`);
} catch {
  console.log("（项目已存在，跳过创建）");
}

run(`npx wrangler pages deploy out --project-name="${PROJECT_NAME}"`);
EOF

cat > scripts/push-to-github.mjs <<'EOF'
#!/usr/bin/env node
// 初始化 git 仓库并推送到 GitHub。跨平台（Windows/Mac/Linux 通用）。
// 用法: npm run push:github -- <repo-name> [public|private]
import { execSync } from "child_process";
import fs from "fs";

const REPO_NAME = process.argv[2];
const VISIBILITY = process.argv[3] || "public";

if (!REPO_NAME) {
  console.error("用法: npm run push:github -- <repo-name> [public|private]");
  process.exit(1);
}

function run(cmd) {
  console.log(`$ ${cmd}`);
  execSync(cmd, { stdio: "inherit" });
}

function hasGh() {
  try {
    execSync("gh --version", { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

if (!fs.existsSync(".git")) {
  run("git init");
  run("git add -A");
  run('git commit -m "init: generated site"');
}

if (hasGh()) {
  run(`gh repo create "${REPO_NAME}" --${VISIBILITY} --source=. --remote=origin --push`);
  console.log("已创建并推送到 GitHub。");
} else {
  console.log("未检测到 gh CLI，请手动执行：");
  console.log(`  1. 在 https://github.com/new 创建仓库 ${REPO_NAME}`);
  console.log(`  2. git remote add origin https://github.com/<你的用户名>/${REPO_NAME}.git`);
  console.log("  3. git push -u origin main");
}
EOF

# ---------- 多AI供应商内容生成脚本（用户本机运行，支持 Claude / DeepSeek / OpenAI） ----------
cat > scripts/generate-content.mjs <<'EOF'
#!/usr/bin/env node
/**
 * 多AI供应商内容生成脚本。跨平台（Windows/Mac/Linux 通用）。
 * 正常情况下不需要这个脚本：在 Claude / Claude Code / OpenAI Codex 里直接让当前 agent
 * 写 content/*.mdx 就行，不需要配置任何模型 API key。这个脚本是留给"脱离编码 agent、
 * 想单独批量重新生成/换供应商"场景的备用工具。
 * 用法:
 *   npm run content:generate -- --provider deepseek --config content.config.json
 * 支持的 --provider: claude | deepseek | openai
 * 对应密钥环境变量: ANTHROPIC_API_KEY | DEEPSEEK_API_KEY | OPENAI_API_KEY
 * 密钥从项目根目录的 .env.local 自动读取（复制 .env.example 改名即可），不需要手动 export/set。
 * content.config.json 格式:
 * {
 *   "locale": "en",
 *   "topics": [
 *     { "title": "working title", "brief": "一句话说明这篇要写什么角度" }
 *   ]
 * }
 * 生成结果写入 content/<slug>.mdx，slug 由 title 自动转换。
 */
import fs from "fs";
import path from "path";
import { config as loadEnv } from "dotenv";

loadEnv({ path: ".env.local" });

function getArg(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : def;
}

const PROVIDER = getArg("provider", process.env.AI_PROVIDER || "openai");
const CONFIG_PATH = getArg("config", "content.config.json");

const PROVIDERS = {
  openai: {
    url: "https://api.openai.com/v1/chat/completions",
    key: process.env.OPENAI_API_KEY,
    model: process.env.OPENAI_MODEL || "gpt-4o-mini",
    body: (model, sys, user) => ({ model, messages: [{ role: "system", content: sys }, { role: "user", content: user }] }),
    headers: (key) => ({ "Content-Type": "application/json", Authorization: `Bearer ${key}` }),
    extract: (data) => data.choices[0].message.content,
  },
  deepseek: {
    url: "https://api.deepseek.com/chat/completions",
    key: process.env.DEEPSEEK_API_KEY,
    model: process.env.DEEPSEEK_MODEL || "deepseek-chat",
    body: (model, sys, user) => ({ model, messages: [{ role: "system", content: sys }, { role: "user", content: user }] }),
    headers: (key) => ({ "Content-Type": "application/json", Authorization: `Bearer ${key}` }),
    extract: (data) => data.choices[0].message.content,
  },
  claude: {
    url: "https://api.anthropic.com/v1/messages",
    key: process.env.ANTHROPIC_API_KEY,
    model: process.env.ANTHROPIC_MODEL || "claude-sonnet-4-6",
    body: (model, sys, user) => ({ model, max_tokens: 2000, system: sys, messages: [{ role: "user", content: user }] }),
    headers: (key) => ({ "Content-Type": "application/json", "x-api-key": key, "anthropic-version": "2023-06-01" }),
    extract: (data) => data.content.map((b) => b.text || "").join(""),
  },
};

const provider = PROVIDERS[PROVIDER];
if (!provider) {
  console.error(`未知 provider: ${PROVIDER}. 可选: ${Object.keys(PROVIDERS).join(", ")}`);
  process.exit(1);
}
if (!provider.key) {
  console.error(`缺少密钥环境变量，请设置后重试（见脚本头部注释）。`);
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
const locale = config.locale || "en";

const SYSTEM_PROMPT = `You are a professional content writer producing MDX for a Next.js blog. Given a topic, return ONLY a JSON object (no markdown fences, no commentary) with keys:
title (string), description (string, <=120 chars), tags (array of 2-4 strings), cover (string, image path or ""), body (string, MDX/Markdown, 600-1200 words for zh or 400-800 words for en, using ## / ### subheadings, concrete specific details, no filler openings like "with the development of society").
If an "images" list is provided in the user message, weave in 2-4 <ArticleImage src="..." alt="..." caption="..." /> tags at natural points in the body next to the paragraph they specifically illustrate (not clustered at the top), using the exact src paths given, and set "cover" to the first image's src. If no images are provided, omit inline <ArticleImage> tags and leave cover as "".
Write in ${locale === "zh" ? "Chinese" : "English"}.`;

function slugify(title) {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60);
}

async function generateOne(topic) {
  const slug = slugify(topic.title);
  const images = (topic.images || []).map((img, i) => ({
    src: `/images/${slug}/${img.filename || `${i + 1}.jpg`}`,
    alt: img.alt || img.query,
  }));
  const userPrompt = `Topic: ${topic.title}\nAngle/brief: ${topic.brief || ""}${
    images.length ? `\nAvailable images (use these exact src paths):\n${JSON.stringify(images)}` : ""
  }`;
  const res = await fetch(provider.url, {
    method: "POST",
    headers: provider.headers(provider.key),
    body: JSON.stringify(provider.body(provider.model, SYSTEM_PROMPT, userPrompt)),
  });
  if (!res.ok) {
    throw new Error(`${PROVIDER} API error ${res.status}: ${await res.text()}`);
  }
  const data = await res.json();
  let text = provider.extract(data).trim();
  text = text.replace(/^```json\s*/i, "").replace(/```\s*$/i, "");
  const parsed = JSON.parse(text);
  const frontmatter = `---\ntitle: ${JSON.stringify(parsed.title)}\ndescription: ${JSON.stringify(parsed.description)}\ndate: "${new Date().toISOString().slice(0, 10)}"\ntags: ${JSON.stringify(parsed.tags || [])}${
    parsed.cover ? `\ncover: ${JSON.stringify(parsed.cover)}` : ""
  }\n---\n\n`;
  fs.writeFileSync(path.join("content", `${slug}.mdx`), frontmatter + parsed.body);
  console.log(`✓ content/${slug}.mdx  (via ${PROVIDER})`);
}

(async () => {
  fs.mkdirSync("content", { recursive: true });
  for (const topic of config.topics || []) {
    try {
      await generateOne(topic);
    } catch (e) {
      console.error(`✗ "${topic.title}" 生成失败: ${e.message}`);
    }
  }
})();
EOF
chmod +x scripts/generate-content.mjs

cat > content.config.json <<EOF
{
  "locale": "${LOCALE}",
  "topics": [],
  "_schema_note": "每个 topic 可选 images: [{ query, alt, filename }]，配合 scripts/fetch-images.mjs 使用"
}
EOF

cat > .env.example <<'EOF'
# 文字生成密钥——只有当你脱离 Claude/Claude Code/Codex 这类编码 agent、
# 想单独用 scripts/generate-content.mjs 批量重新生成文章时才需要，三选一：
# 在 Claude Code / OpenAI Codex 等场景下通常不需要配置这几个，直接让当前 agent 写 content/*.mdx 即可。
OPENAI_API_KEY=
DEEPSEEK_API_KEY=
ANTHROPIC_API_KEY=

# 配图，任选（对应 scripts/fetch-images.mjs 的 --provider 参数，这个通常还是需要的，
# 是图片检索/生成服务的 key，跟上面的文字模型 key 是两回事）
# 实拍图（推荐，更自然生动，免费商用）：
PEXELS_API_KEY=
UNSPLASH_ACCESS_KEY=
# AI生成图（适合抽象主题/插画风格，找不到合适实拍图时用）：
OPENAI_API_KEY=
EOF

# ---------- 多来源配图脚本（用户本机运行，实拍图优先，AI生图为补充） ----------
cat > scripts/fetch-images.mjs <<'EOF'
#!/usr/bin/env node
/**
 * 多来源配图脚本：优先用真实照片（更自然生动），找不到合适的再用 AI 生图兜底。跨平台（Windows/Mac/Linux 通用）。
 * 用法:
 *   npm run images:fetch -- --provider pexels --config content.config.json
 * 支持的 --provider:
 *   pexels    实拍图，免费商用，需要 PEXELS_API_KEY        https://www.pexels.com/api/
 *   unsplash  实拍图，免费商用，需要 UNSPLASH_ACCESS_KEY    https://unsplash.com/developers
 *   openai    AI生成图 (gpt-image-1)，需要 OPENAI_API_KEY，适合抽象/插画类主题
 *
 * 密钥从项目根目录的 .env.local 自动读取（复制 .env.example 改名即可），不需要手动 export/set。
 *
 * content.config.json 里每个 topic 可以带 images 数组：
 *   "images": [{ "query": "narrow stone alley in Kyoto at dusk", "alt": "...", "filename": "cover.jpg" }]
 * 没写 filename 的默认按顺序命名为 1.jpg, 2.jpg ...；第一张建议 filename 用 "cover.jpg" 作为封面图。
 * 下载结果存到 public/images/<slug>/<filename>，slug 与对应 content/<slug>.mdx 保持一致
 * （需要与 generate-content.mjs 用同一份 slugify 规则，脚本内已内置）。
 */
import fs from "fs";
import path from "path";
import { config as loadEnv } from "dotenv";

loadEnv({ path: ".env.local" });

function getArg(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : def;
}

const PROVIDER = getArg("provider", process.env.IMAGE_PROVIDER || "pexels");
const CONFIG_PATH = getArg("config", "content.config.json");

function slugify(title) {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60);
}

async function downloadBinary(url, destPath, headers = {}) {
  const res = await fetch(url, { headers });
  if (!res.ok) throw new Error(`下载失败 ${res.status}: ${url}`);
  const buf = Buffer.from(await res.arrayBuffer());
  fs.mkdirSync(path.dirname(destPath), { recursive: true });
  fs.writeFileSync(destPath, buf);
}

async function fetchPexels(query) {
  const key = process.env.PEXELS_API_KEY;
  if (!key) throw new Error("缺少 PEXELS_API_KEY");
  const res = await fetch(`https://api.pexels.com/v1/search?query=${encodeURIComponent(query)}&per_page=1&orientation=landscape`, {
    headers: { Authorization: key },
  });
  if (!res.ok) throw new Error(`Pexels API error ${res.status}`);
  const data = await res.json();
  const photo = data.photos?.[0];
  if (!photo) throw new Error(`Pexels 没有找到匹配 "${query}" 的图片`);
  return photo.src.large2x || photo.src.large;
}

async function fetchUnsplash(query) {
  const key = process.env.UNSPLASH_ACCESS_KEY;
  if (!key) throw new Error("缺少 UNSPLASH_ACCESS_KEY");
  const res = await fetch(`https://api.unsplash.com/search/photos?query=${encodeURIComponent(query)}&per_page=1&orientation=landscape`, {
    headers: { Authorization: `Client-ID ${key}` },
  });
  if (!res.ok) throw new Error(`Unsplash API error ${res.status}`);
  const data = await res.json();
  const photo = data.results?.[0];
  if (!photo) throw new Error(`Unsplash 没有找到匹配 "${query}" 的图片`);
  return photo.urls.regular;
}

async function generateOpenAI(query) {
  const key = process.env.OPENAI_API_KEY;
  if (!key) throw new Error("缺少 OPENAI_API_KEY");
  const res = await fetch("https://api.openai.com/v1/images/generations", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify({ model: "gpt-image-1", prompt: query, size: "1536x1024" }),
  });
  if (!res.ok) throw new Error(`OpenAI images API error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const b64 = data.data?.[0]?.b64_json;
  if (!b64) throw new Error("OpenAI 未返回图片数据");
  return { base64: b64 };
}

async function fetchOne(provider, query, destPath) {
  if (provider === "pexels") {
    const url = await fetchPexels(query);
    await downloadBinary(url, destPath);
  } else if (provider === "unsplash") {
    const url = await fetchUnsplash(query);
    await downloadBinary(url, destPath);
  } else if (provider === "openai") {
    const { base64 } = await generateOpenAI(query);
    fs.mkdirSync(path.dirname(destPath), { recursive: true });
    fs.writeFileSync(destPath, Buffer.from(base64, "base64"));
  } else {
    throw new Error(`未知 provider: ${provider}. 可选: pexels, unsplash, openai`);
  }
}

(async () => {
  const config = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
  for (const topic of config.topics || []) {
    if (!topic.images || topic.images.length === 0) continue;
    const slug = slugify(topic.title);
    for (let i = 0; i < topic.images.length; i++) {
      const img = topic.images[i];
      const filename = img.filename || `${i + 1}.jpg`;
      const dest = path.join("public", "images", slug, filename);
      try {
        await fetchOne(PROVIDER, img.query, dest);
        console.log(`✓ public/images/${slug}/${filename}  (via ${PROVIDER}, query: "${img.query}")`);
      } catch (e) {
        console.error(`✗ ${slug}/${filename} 失败: ${e.message}`);
      }
    }
  }
})();
EOF
chmod +x scripts/fetch-images.mjs

echo "SCAFFOLD_DONE: $PROJECT_DIR"
