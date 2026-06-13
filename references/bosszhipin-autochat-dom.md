# Boss直聘 自动聊天 — 实战笔记

> 捕获于 2026-06-04 项目「boss直聘自动聊天」
> 已验证的实际 DOM 结构和选择器

## 搜索页（左右分栏）

URL: `/web/geek/jobs?...`

### 左栏：职位卡片

```
li.job-card-box
  ├── .job-info
  │   ├── .job-title > a.job-name （职位名，href="/job_detail/xxx.html"）
  │   └── span.job-salary （薪资，如"30-50K"）
  └── .job-card-footer
      ├── a.boss-info > span.boss-name （公司名）
      └── span.company-location （城市）
```

### 右栏：职位详情面板

```
.job-detail-body （仅搜索页存在，独立详情页没有此元素）
  ├── CSS 噪音（需要正则去掉）
  ├── 职位描述正文
  └── 右上角 a.op-btn.op-btn-chat（立即沟通）
```

## 独立详情页（/job_detail/xxx.html）

URL: `/job_detail/<id>.html`

```
.job-sec-text → 岗位描述（搜索页的 job-detail-body 不存在于此）
.job-title    → 职位名（搜索页的 .job-name 不存在于此）
a.btn.btn-startchat → 立即沟通（搜索页的 .op-btn-chat 不存在于此）
a[href*="/gongsi/"] → 公司名（需过滤"查看所有职位""公司""查看更多"等导航链接）
```

## 弹窗流程

点击「立即沟通」后：

1. Boss直聘**自动发送**预设打招呼消息
2. 弹出 `div.dialog-wrap.greet-pop`，包含：
   - `div.dialog-title`: "已向BOSS发送消息"
   - `div.dialog-con`: 打招呼内容
   - `div.dialog-footer > .btns >`
     - `span.btn.btn-outline.btn-cancel` → 「留在此页」（继续遍历）
     - `span.btn.btn-sure` → 「继续沟通」（打开聊天窗口）

## 简历页（/web/geek/resume）

### 区块结构

```
.resume-item（多个）
  ├── .item-primary → 标签（如"个人优势""专业技能"）
  ├── .primary-info
  │   ├── .info-text-block / .text-block-main → 内容区域
  │   └── .info-text / .advantage-text → 文本内容
  └── .keywords → 技能标签
```

### 关键数据位置

| 数据 | 选择器 / 定位方式 |
|------|-------------------|
| 个人优势 | `.advantage-show .advantage-text` 或 `data-scroll="userDesc"` 所在区块 |
| 专业技能 | `.item-primary` 下含"专业技能"文本的 `.advantage-text` |
| 工作经历 | `.resume-item` 中 `li` 内的 `.text-block-main`、`.info-text-block` |
| 教育信息 | 文本匹配"教育经历"后 200 字符内找"信息管理"/"计算机"等 |
| 技能标签 | `.keywords span` 中的文本 |

### 专业技能字段解析策略

原文格式：`产品设计：Axure 、XMind、Modao、VISO,数据分析：SQL、Google Analytics,开发基础：Python 、PHP、Golang`

解析步骤：
1. 按 `,` 逗号分割 → ["产品设计：Axure 、XMind...", "数据分析：SQL、Google Analytics", "开发基础：Python 、PHP、Golang"]
2. 每段按 `：` 冒号分割 → 取右边部分
3. 按 `、` 顿号/空格分割 → 单个技能名
4. 合并 `Google` + `Analytics` → `Google Analytics`
5. 从个人优势中提取领域关键词（LLM, AI Agent, RAG, SEO等）补充到技能列表

## 工作经历提取

直接从 `.resume-item` 中 `li` 内的 `.text-block-main` 提取。5段工作经历的详细内容包含：

- 公司名 + 职位 + 时间段
- 项目描述（"项目描述：\n..."）
- 主要职责（"主要职责：\n1. ..."）
- 工作成绩（"工作成绩：\n1. ..."）

全部拼接为一个字符串数组，存入 `bosschat_resume.work_history`。

## 匹配算法

```
技能分 = min(50, round(matchCount / max(skills.length, 5) * 50))
经验分 = diff <= 1 ? 30 : diff <= 3 ? 20 : diff <= 5 ? 10 : 0  （无要求则 20 基础分）
学历分 = 学历 >= 要求 ? 20 : 5  （无要求则 15 基础分）
总分 = 技能分 + 经验分 + 学历分
阈值：≥50 分 → 打招呼
```

### 实战匹配分观察

19项技能中通常仅 1-4 项出现在岗位描述中，技能分 3-10 分，总分常在 30-48 之间。
