# 内容生成指南

内容有两条生产路径，规则通用：
1. **Claude 在对话里直接写 `.mdx`**（默认首批内容走这条，最快）
2. **`scripts/generate-content.mjs`**：用户在本机用 DeepSeek / OpenAI(ChatGPT) / Claude 的 API key 批量生成，读取项目根目录的 `content.config.json` 里的选题列表。Claude 在 Step 3 应该把想到的选题连同一句话角度写进 `content.config.json`（即使这一批文章由 Claude 自己写完了，也顺手把选题记录进去，方便用户以后用这个脚本换个供应商重新生成或扩充）。

生成 `content/*.mdx` 文章时遵循以下要求：

## Frontmatter（必须）
```yaml
---
title: 具体、吸引点击的标题（避免"XX指南"这类空泛标题）
description: 120字以内，概括文章价值，用于列表页和SEO description
date: "YYYY-MM-DD"
tags: ["2-4个具体标签"]
cover: /images/<slug>/cover.jpg   # 见下方"配图"
---
```

## 正文要求
- 每篇 600-1200 字（中文）或 400-800 words（英文），太短无SEO价值，太长影响生成效率
- 开头一段直接给出文章要回答的问题/价值，不要"随着社会的发展"这类套话开场
- 使用 H2/H3 分段，便于扫读和SEO
- 主题涉及具体信息（地点/路线/装备/数据等）时，给出具体细节而非空泛描述——这是内容质量和SEO排名的关键
- 避免与其他文章标题/开头高度重复的模板化写法，每篇要有独特角度

## 文件命名
- slug 用小写英文+连字符，如 `kyoto-autumn-3-days.mdx`，不要用中文文件名（URL 友好、Vercel 兼容性更好）

## 配图（图文并茂，必须做，不是可选项）

每篇文章都要图文并茂：1 张封面图 + 正文中 2-4 张配图，必须**具体贴题、自然生动**，不是随手配几张泛泛的通用图。

- **位置**：图片放在它所配的那段文字旁边，紧跟着提到的具体人事物（某个地标、某道菜、某个操作步骤、某件产品），不要堆在开头当"题图墙"
- **描述要具体到能搜出对的图**：写 "narrow stone alley in Kyoto at dusk" 而不是 "Japan travel"；写 "close-up of pan-seared scallops with brown butter sauce" 而不是 "food"。越具体，实拍图匹配度越高，AI生图效果也越好
- **组件**：`<ArticleImage src="/images/<slug>/1.jpg" alt="具体描述图里有什么" caption="可选一句话图注，呼应正文语气" />`，第一张（封面）`filename` 用 `cover.jpg`，同步写进 frontmatter 的 `cover` 字段
- **实拍 vs AI生图**：人物、真实地点、真实菜品/产品优先用实拍图（Pexels/Unsplash，更自然生动）；抽象概念、示意图、插画风格才用 AI 生图兜底
- 每篇的选题要在 `content.config.json` 对应 topic 下写 `images: [{query, alt, filename}]`（query 用上面的具体描述），交给 `scripts/fetch-images.mjs` 实际取图；Claude 自己直接写文章时同理，也要把这个 images 数组写进 `content.config.json`，正文里 `<ArticleImage>` 的 src 要和这里的 filename 对上

## 数量与批次
- 一次性生成建议 5-15 篇（首批上线量），可后续追加
- 若用户要求"日记"类主题（如旅游日记），可用日期递进的方式组织多篇，形成系列感
