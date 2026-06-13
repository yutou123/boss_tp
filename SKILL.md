---
name: bosschat-applescript
description: "Boss直聘自动聊天AppleScript驱动版 — 简历自动读取、岗位匹配、外包过滤、智能打招呼、配额管理。绕过CSP，无需Tampermonkey。"
version: 2.7.0
author: Hermes Agent
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [bosszhipin, applescript, automation, job-search, resume-matching]
    related_skills: [tampermonkey-userscript, applescript-web-automation]
---

# BossChat AppleScript 版

## 概述

用 AppleScript `execute javascript` 驱动 Boss直聘自动化，绕过 CSP/反调试限制。每个操作独立短小，通过 `localStorage` 做状态桥接。

## 核心文件

Skill 内路径（通过 `skill_view(name='bosschat-applescript', file_path='...')` 加载）：

| 文件 | 路径 | 说明 |
|------|------|------|
| 主脚本 | `scripts/bosschat_final_v3.applescript` | 投递+扫描一体化 |
| 投递引擎 | `scripts/bosschat_engine.js` | JS引擎参考代码 |
| 聊天扫描 | `scripts/chat_scan_helpers.js` | 聊天页JS函数（独立注入） |
| 不合适企业名单 | `references/rejected_companies.txt` | 本地文件，一行一个公司名 |

项目目录 `/Users/taro/boss直聘自动聊天/` 是本地工作副本，技能文件在 `~/.hermes/skills/software-development/bosschat-applescript/`。

## 架构

### Part 1: 筛选打招呼流程

```
AppleScript 主控
  ├─ fetchResume()         → 导航到简历页，解析 DOM 存入 localStorage
  ├─ checkQuota()          → 检查 150次/天 配额，跨日自动重置
  ├─ matchJob()            → 提取岗位要求，与简历匹配打分
  ├─ hasOutsourceCompany() → 56家外包黑名单检测
  ├─ useQuota()            → 打招呼后扣减配额
  └─ 主循环                → 遍历搜索结果，6重过滤后打招呼
```

### Part 2: 自动回复流程

```
定时循环（每15秒）
  ├─ getResume()           → 读取 localStorage 简历
  ├─ checkNewMessages()    → 检测未读聊天
  ├─ sendReply()           → 分类回复（问候/提问/邀约面试）
  └─ 持续监听
```

### Part 3: 投递后聊天扫描（不合适企业自动检测 + 翻页虚拟滚动）

主循环结束后（配额用完或所有职位处理完毕），自动跳转到聊天页检测拒绝关键词：

```
Part 3: 聊天扫描
  ├─ 读取 rejected_companies.txt 已有名单
  ├─ 从文件注入 chat_scan_helpers.js（页面切换后 BossChat 丢失）
  ├─ 翻页循环：
  │   ├─ 扫描当前 ~40 个对话（_clickConvo 点 .title-box）
  │   ├─ 每个对话显示 ✅/❌ 到右侧浮层
  │   ├─ 滚动 .user-list-content 容器到底部
  │   ├─ 对比最后一家公司名（_getLastCompany）
  │   └─ 变化则继续翻页，不变则结束
  └─ 完成统计
```

**关键细节：**
- 聊天页用虚拟滚动，DOM 始终 ~40 个 LI，滚动后内容被替换（不是增加）
- 翻页检测：对比最后一家公司名，不是对比总数（总数始终~40）
- 点击目标：`.title-box`（不是 LI，不是 `.friend-content-warp`）
- 拒绝关键词：`不太合适,早日找到满意,不适合,不合适,不匹配,不太匹配,暂不完全匹配,祝您在BOSS直聘`
- 浮层 z-index 必须极高（9999999），防止被 `.chat-conversation` 遮盖

参考 `references/chat-page-dom.md` 获取完整的聊天页 DOM 结构。

## 岗位描述提取

### 问题

Boss直聘 SPA 的 `<body>` 中嵌有大量 JS 初始化代码（`_PAGE` 配置对象）和 CSS，导致 `body.textContent` 的前 2000+ 字符全是基础设施代码，而非岗位描述。

### 解决方案

```javascript
// ✅ 正确
var el = document.querySelector('.job-detail-body') || document.querySelector('.job-sec-text');
var reqText = (el ? el.textContent : '').toLowerCase();
// 去掉 .xxx{...} 样式块
reqText = reqText.replace(/\.[a-zA-Z]+\{[^}]*\}/g, ' ');
```

### 《execute javascript》 missing value 陷阱

`execute active tab of front window javascript "..."` 返回 `missing value` 的**两种原因**：

| 原因 | 特征 | 修复 |
|------|------|------|
| **JS 语法错误**（转义/太长） | 第一次执行就返回 `missing value` | 见下方调试方法 |
| **页面导航导致上下文失效** | 在 `history.back()` 或 `window.location.href` 导航后，之前注入的全局对象丢失 | 每次导航后重新注入引擎 |

最常见原因：
1. **JS 代码太长/太复杂** — 每行保持简短，单语句
2. **转义错误** — AppleScript 字符串中 `"` 要用 `\"`，`\` 要用 `\\`
3. **JSON.stringify 对象过于复杂** — 先 `JSON.stringify`，如果还是 missing value，改为简单字符串拼接
4. **页面刷新后对象丢失** — SPA 导航或 `history.back()` 会清除所有注入的全局变量

⚠️ **`if md is missing value` 不是 `"missing value"`** — AppleScript 中 JS 返回异常时是特殊类型 `missing value`，不是字符串。比较时必须用 `if r is missing value`（无引号），而不是 `if r is "missing value"`。

调试方法：
```applescript
set r to execute active tab of front window javascript "1+1;"  -- 应为 "2"
set r to execute active tab of front window javascript "document.title;"
```

### 推荐架构：bash + Python 处理 JSON

AppleScript 的 `text item delimiters` 解析 JSON 极其脆弱。推荐用 bash 包装：

```bash
CARD_INFO=$(osascript ... 2>/dev/null)
TITLE=$(echo "$CARD_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))")
```

AppleScript 只负责执行 JS 返回纯 JSON 字符串，bash+Python 负责逻辑、解析和日志。

### 核心工作流（严格按此顺序）

#### 1. 简历获取：仅首次运行（新标签页方案）

**不要**在当前标签页导航到简历页再来回跳转——会跳出 Boss直聘。改为新标签页方案：

```applescript
if rh is "new" then
  tell front window
    set nt to make new tab at end of tabs with properties {URL:"https://www.zhipin.com/web/geek/resume"}
    set active tab index to (count of tabs)
  end tell
  delay 5
  -- 执行 JS 抓取简历 → 存入 localStorage
  close nt   -- 关闭新标签页，当前搜索标签页不受影响
  delay 1
end if
```

`set URL ... to savedURL` 可能跳转到非 Boss直聘页面（如果 `savedURL` 不是搜索页）。**新标签页方案**完全避免了这个问题。

#### 2. 使用当前页面搜索条件

直接从当前页面处理 `li.job-card-box`，不导航、不刷新。

#### 3. 逐个职位：SPA 卡片点击（无需导航）

搜索结果页是左右分栏 SPA。**不要**用 `window.location.href` 导航到独立详情页——应该**点击左侧卡片**，右侧面板自动加载详情。

```applescript
-- ✅ 正确：SPA 卡片点击，右侧面板更新详情
execute active tab of front window javascript "var cards=document.querySelectorAll('li.job-card-box');if(cards[" & idx & "]){cards[" & idx & "].querySelector('a.job-name').click();}"
delay 3

-- ❌ 错误：导航到独立详情页 + history.back()（多余导航、丢失上下文）
```

**优势：**
- 不离开搜索页，无需 `history.back()`
- 引擎（`BossChat` 对象）不会因页面导航而丢失
- 只需在循环开头注入一次引擎，无需每次导航后重新注入
- 去掉所有 `history.back()` 调用和相关延迟

**⚠️ `rd` 是 AppleScript 保留字** — 不能用作变量名。类似地 `me` 也是保留字（上一版本遇到）。用 `rx` / `rdv` / `mev` 替代。

| 保留字 | 替代方案 |
|--------|---------|
| `rd` | `rx` 或 `rdv` |
| `me` | `mev` |
| `rc` | 可用（不是保留字） |

#### 4. 每个职位处理结果必须输出

```
[1/15] 职位名 @ 公司名
  ⏭ 需做题(测评)       ← 或
  ⏭ 外包公司            ← 或
  ⏭ 不活跃              ← 或（新增：活跃检测）
  ⏭ 不匹配(33分)       ← 或
  ✅ 匹配55分 → 打招呼
```

### 两种页面模式选择器

Boss直聘有两种详情布局，选择器必须兼容：

| 元素 | SPA 搜索页（右侧面板） | 独立详情页（/job_detail/） |
|------|----------------------|--------------------------|
| 描述容器 | `.job-detail-body` | `.job-sec-text` |
| 标题 | `.job-name` | `.job-title` |
| 公司 | `.boss-name` | `a[href*="/gongsi/"]`（需过滤导航链接） |
| 沟通按钮 | `.op-btn-chat` | `.btn-startchat` |
| 薪资 | `.job-salary` | `.job-salary` |

### 公司名提取 — 独立详情页

独立详情页的公司名在 `a[href*="/gongsi/"]` 链接中，但该选择器也会匹配导航链接（"查看所有职位""公司""查看更多"），需过滤：

```javascript
var company = '';
var cl = document.querySelector('.boss-name');
if (cl) {
  company = cl.textContent.trim();
} else {
  var links = document.querySelectorAll('a[href*="/gongsi/"]');
  for (var i = 0; i < links.length; i++) {
    var t = links[i].textContent.trim();
    if (t.length > 1 && t.length < 25 && t !== '公司' && t.indexOf('查看') < 0 && t.indexOf('更多') < 0) {
      company = t; break;
    }
  }
}
```

### SPA 导航（卡片点击方案）

搜索结果页是左右分栏 SPA。**千万不要**用 `window.location.href` 导航到独立详情页——应该**点击左侧卡片**，右侧面板自动加载详情。

```applescript
-- ✅ 正确：SPA 卡片点击
execute active tab of front window javascript "var cards=document.querySelectorAll('li.job-card-box');if(cards[" & idx & "]){cards[" & idx & "].querySelector('a.job-name').click();}"
delay 3

-- ❌ 错误：window.location.href 导航到 /job_detail/（多余页面跳转，丢失引擎上下文）
```

**优势（相对于 URL 导航方案）：**
- 不离开搜索页，无需 `history.back()` 往返
- 引擎（`BossChat` 对象）不会因页面导航而丢失——只需在循环开头注入一次
- 去掉所有 `history.back()` 调用和相关延迟，流程更简单
- 速度更快（SPA 局部刷新 vs. 整页加载）
- SPA 右侧面板选择器就是 `.job-detail-body`，与独立详情页的 `.job-sec-text` 作为 fallback

**6重过滤流程（严格顺序）：**

```
① 实习/应届检测  → 标题含"实习"或"应届" → 跳过
② 外包检测 (os)   → 公司名在56家黑名单中 → 跳过
③ 活跃检测 (ac)   → 没有"刚刚活跃"/"今日活跃"/"昨日活跃" → 跳过
④ 已投递检测 (isGreeted) → 已在 localStorage 记录中（href+公司名双重检查） → 跳过
⑤ 不合适企业检测 → 公司名匹配 `rejected_companies.txt` 文件内容（AppleScript 层面用 `repeat with rcl in rcList` 做匹配，非 JS） → 跳过
⑥ 匹配评分 (sc)   → 技能分+经验分+学历分 < 50 → 跳过；≥ 50 → 打招呼
```

**实习/应届岗过滤（在点击卡片前拦截）：**
```applescript
if ct contains "实习" or ct contains "应届" then
  set smc to smc + 1
  -- 跳过该职位的所有后续处理
else
  -- 整个卡片点击+处理代码块
end if
```
需要用 `if...else` 包裹**整个**处理代码块，确保不触发页面操作。

**翻页（无限滚动）：**
搜索结果页滚动到底部自动加载更多。主循环外嵌套分页循环：

```applescript
set ptc to 0
repeat
  set sti to ptc
  set ptc to tc
  repeat with i from sti + 1 to ptc
    -- 处理每个职位
  end repeat
  -- 滚动到底部加载更多
  execute active tab of front window javascript "BossChat._scrollToLoad();"
  delay 3
  -- 检查新卡片数量
  set rc to execute active tab of front window javascript "document.querySelectorAll('li.job-card-box').length+'';"
  if rc as integer ≤ ptc then exit repeat  -- 没新数据→到底了
  set tc to rc as integer
  -- 检查配额
  set qc to execute active tab of front window javascript "BossChat.qt();"
  if qc ≤ 0 then exit repeat
end repeat
```

```javascript
BossChat._scrollToLoad = function() {
  window.scrollTo(0, document.body.scrollHeight);  // 直接到底，scrollBy不够
  return document.querySelectorAll('li.job-card-box').length + '';
};
```

**活跃检测实现：**
```javascript
BossChat.ac = function() {
  var el = document.querySelector('.boss-active-time');
  if (!el) return 'no';
  var t = el.textContent;
  if (t.indexOf('今日活跃') >= 0) return 'today';
  if (t.indexOf('昨日活跃') >= 0) return 'yesterday';
  return 'no';
};
```

HR 面板位于 `.job-detail-body .job-boss-info`，活跃状态在 `<span class="boss-active-time">今日活跃</span>`。

**页面浮层日志：**
在搜索结果页右侧创建半透明黑色浮层显示实时日志：
```javascript
BossChat._addLog = function(t) {
  var el = document.getElementById('bc-log-panel');
  if (!el) {
    el = document.createElement('div');
    el.id = 'bc-log-panel';
    el.style.cssText = 'position:fixed;top:60px;right:10px;width:360px;max-height:70vh;overflow-y:auto;background:rgba(0,0,0,0.85);color:#0f0;font:12px/1.5 monospace;padding:10px;border-radius:6px;z-index:99999;white-space:pre-wrap';
    document.body.appendChild(el);
  }
  var d = document.createElement('div');
  d.textContent = t;
  el.appendChild(d);
  el.scrollTop = el.scrollHeight;
};
```
从 AppleScript 调用: `execute active tab of front window javascript "BossChat._addLog('" & fl & "')"`

## 简历数据

简历数据从简历页面 `.resume-item` 区块提取。参考 `references/bosszhipin-dom.md` 中的完整 DOM 结构。

关键提取位置：
- **个人优势**: `.advantage-show .advantage-text` (data-scroll="userDesc")
- **专业技能**: `.item-primary` 下含"专业技能"文本的 `.advantage-text`
- **工作经历**: `.resume-item` 中的 `li` 元素内的 `.text-block-main`
- **教育信息**: 文本匹配 "教育经历" + "信息管理/计算机"
- **技能标签**: `.keywords span` 中的文本

## 引擎架构

### 函数名缩短原则

所有引擎函数用 2 字母命名，避免长 JS 代码在 AppleScript 字符串中转义困难：

```javascript
window.BossChat = {
  gc: function() { ... },   // getCard — 读职位卡片信息
  qt: function() { ... },   // quota — 查看配额
  uq: function() { ... },   // useQuota — 扣减配额
  tf: function() { ... },   // testFound — 检测需做题
  os: function() { ... },   // outsource — 外包检测
  ac: function() { ... },   // activeCheck — 活跃检测：返回 'today'/'yesterday'/'no'
  sc: function() { ... },   // score — 匹配打分（5字段pipe分隔）
  cb: function() { ... },   // clickBtn — 点击沟通按钮
  sb: function() { ... },   // stayBtn — 点击"留在此页"（兼容新旧两版弹窗）
  _addLog: function() {...},// 页面右侧浮层日志输出（黑底绿字）
  _isGreeted: function(h,c) {...},// 检查是否已投递过（localStorage, href+公司名双重检查）
  _markGreeted: function(h,c){...},// 标记已投递（存{h, c}对象）
  _closePopup: function() {...},  // 关闭"已向BOSS发送消息"弹窗（旧版）或新版X按钮
};

// ⚠️ 以下函数仅用于聊天页（Part 3），从 chat_scan_helpers.js 文件注入。
// （set URL 切换页面会清除 BossChat 对象，所以用独立文件注入）
//   _addChatLog(t)      — 聊天页右侧浮层日志（z-index: 9999999）
//   _getConvoCount()    — 获取左侧有效对话数 → "40"
//   _clickConvo(idx)    — 点击第N个对话的 .title-box，返回公司名 → "南京智影"
//   _getLastCompany()   — 获取最后一家公司名（用于翻页检测）
//   _scrollPage()       — 滚动 .user-list-content 容器底部（虚拟滚动翻页）
//   _checkRejection()   — 检测拒绝关键词 → "yes"/"no"
//      关键词: 不太合适,早日找到满意,不适合,不合适,不匹配,不太匹配,暂不完全匹配,祝您在BOSS直聘
```

### 返回值格式

避免 JSON（AppleScript 解析困难），改用 pipe 分隔：

| 字段 | 格式 | 示例 |
|------|------|------|
| 匹配分 | `总分\|技能分\|经验分\|学历分\|要求经验\|要求学历` | `40\|5\|20\|15\|3\|本科` |
| 旗帜 | `"true"`/`"false"` 字符串 | `"true"` 表示是外包 |
| 卡片信息 | `公司名|职位名|薪资|链接` | `字节跳动|前端|20k-40k|/job_detail/xxx` |

AppleScript 解析：
```applescript
set r to execute active tab of front window javascript "BossChat.sc();"
if r is not missing value then
  set AppleScript's text item delimiters to "|"
  set mt to text item 1 of r
  set ms to text item 2 of r
  set AppleScript's text item delimiters to ""
end if
```

⚠️ **`text item delimiters` 使用后立即重置为 `""`**，否则后续所有字符串操作异常。

### Python 生成 AppleScript

长 JS 引擎代码嵌入 AppleScript 时转义极其繁琐（双引号、反斜杠嵌套）。推荐用 Python 脚本生成 .applescript 文件：

```python
# gen_final_v3.py — 生成 AppleScript
js_engine = """"use strict";
window.BossChat={...}"""  # 原始 JS

# 替换引号
apple_safe = js_engine.replace('\\', '\\\\\\\\').replace('"', '\\\\"')

script = f'''set engine to "{apple_safe}"
tell application "Google Chrome"
  execute active tab of front window javascript engine
end tell'''

with open('output.applescript', 'w') as f:
    f.write(script)
```

### 已投递追踪（localStorage + 公司名双重检查）

**关键问题：同一公司不同职位会被重复投递。** 原因是旧版只存 href，不同职位 href 不同。

升级为对象数组，同时存储 href 和**公司名**：

```javascript
BossChat._isGreeted = function(h, c) {
  var g = JSON.parse(localStorage.getItem('bosschat_greeted') || '[]');
  for (var i = 0; i < g.length; i++) {
    if (typeof g[i] == 'string' && g[i] == h) return true;  // 向下兼容旧格式
    if (typeof g[i] == 'object' && (g[i].h == h || g[i].c == c)) return true;
  }
  return false;
};

BossChat._markGreeted = function(h, c) {
  var g = JSON.parse(localStorage.getItem('bosschat_greeted') || '[]');
  var found = false;
  for (var i = 0; i < g.length; i++) {
    if (typeof g[i] == 'object' && g[i].h == h) { found = true; break; }
  }
  if (!found) { g.push({h: h, c: c}); localStorage.setItem('bosschat_greeted', JSON.stringify(g)); }
};
```

**AppleScript 调用必须同时传 href 和公司名：**
```applescript
set gh to execute active tab of front window javascript "BossChat._isGreeted('" & ch & "','" & cc & "')"
execute active tab of front window javascript "BossChat._markGreeted('" & ch & "','" & cc & "')"
```

⚠️ **公司名提取选择器是 `.boss-info` 不是 `.boss-name`** — 搜索结果卡片的公司名在 `a.boss-info` 元素里。如果用了 `.boss-name`，`cc` 会是空字符串，已投递检查永远不通过。

**双重防护：**
1. **事前检查** — 在点击"立即沟通"前调用 `_isGreeted(ch, cc)`，命中则直接跳过（公司名匹配命中同一公司所有职位）
2. **事后检测** — 点击后检测 URL 是否跳转到 `/web/geek/chat`，检测到则 `markGreeted` + 跳回搜索页

### 已投递判定流程

```applescript
-- 事前检查（推荐，避免页面跳转）
set gh to execute active tab of front window javascript "BossChat._isGreeted('" & ch & "','" & cc & "')"
if gh is "true" then skip this job

-- 事后防护（fallback — 检测聊天页跳转）
execute active tab of front window javascript "BossChat._su=window.location.href"  -- ⚠️ 在cb()前保存！
set hb to execute active tab of front window javascript "BossChat.cb();"
if hb is "yes" then
  delay 3
  set cp to execute active tab of front window javascript "BossChat._checkChatPage();"
  if cp is "yes" then
    execute active tab of front window javascript "BossChat._markGreeted('" & ch & "','" & cc & "')"
    -- 用保存的URL直接导航回去，比 history.back() 更可靠
    execute active tab of front window javascript "if(window.BossChat&&BossChat._su)window.location.href=BossChat._su;else window.history.back();"
    delay 3
  end if
end if
```

⚠️ **`_su` 必须在 `cb()` 之前保存**，否则如果 `cb()` 导致页面跳转，保存的是聊天页 URL。\n⚠️ **`delay 3` 对于聊天页跳转检测至关重要** — SPA 跳转需要时间，1秒不够。

---

_This skill references `references/bosszhipin-autochat-dom.md` (search/detail/resume DOM) and `references/chat-page-dom.md` (chat page DOM + rejection scanning). Old session-specific files (`latest-20260613-session.md`, `session-20260613-new-selectors.md`) have been consolidated into these two references._\n\n## 不合适企业名单（被拒绝的企业 — 本地文件版）\n\n被企业回复"不合适/不匹配"后，将该公司加入名单，后续运行自动跳过该公司的所有职位。\n\n### 存储方式\n\n**本地文件**而非 localStorage，方便手动编辑：\n\n- 路径：`rejected_companies.txt`（项目根目录）\n- 格式：一行一个公司名，`#` 开头的行为注释\n- 匹配方式：AppleScript 层面做模糊匹配（`cc contains rcl2 or rcl2 contains cc`）\n\n### AppleScript 读取与检查\n\n```applescript\n-- 读取文件\nset rcList to {}\nset rcFile to "/path/to/rejected_companies.txt"\ntry\n  set rcContent to do shell script "cat " & quoted form of rcFile & " 2>/dev/null || echo ''"\n  set AppleScript's text item delimiters to linefeed\n  set rcLines to every text item of rcContent\n  set AppleScript's text item delimiters to ""\n  repeat with rcLine in rcLines\n    set rl to rcLine as string\n    if rl is not "" and first character of rl is not "#" then\n      set rcList to rcList & {rl}\n    end if\n  end repeat\nend try\n\n-- 检查（在主循环中）\nset rh to "false"\nrepeat with rcl in rcList\n  set rcl2 to rcl as string\n  if cc contains rcl2 or rcl2 contains cc then\n    set rh to "true"\n    exit repeat\n  end if\nend repeat\nif rh is "true" then -- 跳过\n```\n\n### 手动编辑\n\n用任何文本编辑器打开 `rejected_companies.txt`，添加/删除/注释公司名。\n\n### 向后兼容\n\n旧版 localStorage `bosschat_rejected` 数据不再使用，但不会主动清除。新增数据只写文件。\n```

## 弹窗处理

打招呼后 Boss直聘 可能弹出多个弹窗，需逐一处理：

### 1. "已向BOSS发送消息" 弹窗

DOM 结构：

```html
<div class="greet-boss-dialog">
  <div class="greet-boss-header">
    <h3>已向BOSS发送消息</h3>
    <span class="close"><i class="icon-close"></i></span>
  </div>
  <div class="greet-boss-footer">
    <a class="default-btn cancel-btn">留在此页</a>
    <a class="default-btn sure-btn">继续沟通</a>
  </div>
</div>
```

关闭按钮选择器：`.greet-boss-header .close`

### 2. 旧版弹窗

旧版弹窗的"留在此页"按钮选择器：`span.btn.btn-outline.btn-cancel`（包含文本"留在此页"）

### 3. 弹窗关闭函数

```javascript
BossChat._closePopup = function() {
  // 新版 X 按钮 + 旧版关闭按钮
  var btns = document.querySelectorAll('[ka=dialog_close],.greet-boss-header .close,.dialog-header .close,.popup-close,.close-btn');
  for (var i = 0; i < btns.length; i++) {
    if (btns[i].offsetParent !== null) { btns[i].click(); return 'closed'; }
  }
  return 'nopopup';
};
```

### 4. "留在此页" 按钮

需同时支持新旧两版：

```javascript
BossChat.sb = function() {
  var sb = document.querySelector('span.btn.btn-outline.btn-cancel');
  if (sb && sb.textContent.indexOf('留在此页') >= 0) sb.click();
  else {
    var sb2 = document.querySelector('.greet-boss-footer .cancel-btn');
    if (sb2) sb2.click();
  }
};
```

### 完整打招呼子流程

```
cb() → 点击"立即沟通"
  → 检测聊天页跳转（已投递过则 history.back() + markGreeted）
  → sb() → 点击"留在此页"（兼容新旧版）
  → delay 1
  → _closePopup() → 点击 X 关闭"已向BOSS发送消息"弹窗
  → _markGreeted(ch) → 记录已投递
  → uq() → 扣减当日配额
```

## 聊天页检测（重复投递防护）

对于已投递过的企业，点击"立即沟通"不会弹出对话框，而是直接跳转到 `/web/geek/chat` 聊天页面。需要检测并用 `history.back()` 返回：

```javascript
BossChat._checkChatPage = function() {
  var u = window.location.href;
  if (u.indexOf('/chat/') >= 0 || u.indexOf('/im/') >= 0 || u.indexOf('/web/geek/chat') >= 0) return 'yes';
  return 'no';
};
```

⚠️ **点击后必须等待 3 秒再检测**，SPA 导航需要时间完成。

## 工作经验提取

从搜索结果页的头部信息（非详情描述中）提取：

```javascript
var hi = document.querySelector('.job-header-info');
var ht = hi ? hi.textContent : '';
// "10年以上" → 10
var em = ht.match(/([0-9]+)年以上/);
// "3-5年" → 5（取上限）
if (!em) em = ht.match(/([0-9]+)[-~]([0-9]+) *年/);
var re = em ? (parseInt(em[2] || em[1]) || 0) : 0;
```

`.job-header-info` 中的文本格式：`职位名 薪资 城市工作年限学历`（如 `数据库产品经理 10-40K 北京10年以上本科`）。

⚠️ **AppleScript 中不能使用 `\d` 和 `\s` 等正则简写** — AppleScript 的字符串解释器将 `\d` 视为未定义转义序列，导致编译错误。必须使用 `[0-9]` 和空格等显式字符类。

## 简历技能提取

从简历 DOM 中提取技能和行业关键词：

```javascript
// 1. 专业技能区：.resume-professional-skill
//    内容格式："产品设计：Axure 、XMind、Modao、VISO,数据分析：SQL、Google Analytics"
var ps = document.querySelector('.resume-professional-skill');
if (ps) {
  var t = ps.textContent || '';
  var p = t.split(/[,，、]/);
  for (var i = 0; i < p.length; i++) {
    var s = p[i].trim();
    var ci = s.indexOf('：'); if (ci >= 0) s = s.substring(ci + 1);
    ci = s.indexOf(':'); if (ci >= 0) s = s.substring(ci + 1);
    if (s.length > 1 && s.length < 30 && s != '编辑删除' && s != '专业技能') r.skills.push(s);
  }
}

// 2. 行业关键词（从工作经历+个人优势中提取的已知关键词列表）
var ak = 'LLM,AI Agent,RAG,Prompt,SEO,GEO,数字人,AIGC,大模型,知识库,智能体,Agent,虚拟空间,元宇宙,工作流,对话,政务,司法,流量,内容管理,数据产品,B端产品,C端产品,G端产品,产品设计,数据分析,搜索引擎优化,生成式引擎优化,AI助手,模型对话,Prompt Engineering'.split(',');
for (var i = 0; i < ak.length; i++) {
  if (pt.indexOf(ak[i]) >= 0 && r.skills.indexOf(ak[i]) < 0) r.skills.push(ak[i]);
}
```

## 匹配算法

`BossChat.sc()` 返回 pipe 分隔的 6 字段：`总分|技能分|经验分|学历分|要求经验|要求学历`

- **技能匹配 (50分)**: `min(50, matchCount * 8)` — 每个匹配技能8分（非比例制，避免技能列表太长导致分太低）
- **经验匹配 (30分)**: |简历经验 - 岗位要求| ≤1年=30分, ≤3年=20分, ≤5年=10分，无要求给20基础分
- **学历匹配 (20分)**: 博士4>硕士3>本科2>大专1，简历≥要求得20分，低于得5分，无要求15分
- **招呼阈值**: ≥50分

### 实战匹配分偏低

19项技能中通常仅 1-4 项出现在岗位描述中，旧版比例分制下技能分 1-6 分，总分常在 35-48 分。新版改为 `mc*8` 后，3-5个匹配技能即可拿到 24-40 分，结合经验分30+学历分20，更容易达到 50 分。

如需调整：
1. 降低/提高阈值（当前50分）
2. 修改 `mc*8` 的倍数（8→10 更激进，8→5 更保守）
3. 增加工作经历关键词到技能列表

## 关键实现

### 绕过 CSP
Boss直聘 CSP 禁止 eval/new Function/动态 script。每个操作通过独立 `execute...javascript` 调用。

### 外包检测
56家黑名单，检测公司名和页面全文。

### 每日配额
150次/天，`bosschat_quota_date` + `bosschat_quota_count`，跨日重置。

## 用法

```bash
osascript /path/to/bosschat_workflow_v3.applescript   # Part 1
osascript /path/to/bosschat_reply.applescript           # Part 2
```

## 关键工作流（用户偏好）

### 简历获取策略

**简历只需获取一次。** 每次运行都重新获取是错误的工作流：

```
❌ 错误：每次运行都 fetchResume() → 跳转到简历页 → 再跳回搜索页
✅ 正确：首次运行 fetch 存入 localStorage → 后续直接读 localStorage
```

**新标签页方案（推荐）：** 不要在当前标签页导航到简历页再后退。`set URL ... to savedURL`（后退）可能跳转到非 Boss直聘页面，导致脚本上下文丢失。应该在新标签页打开简历页，抓取完成后关闭标签。

```
❌ 错误：当前标签页 → 简历页 → set URL to 搜索页（可能跳出Boss直聘）
✅ 正确：当前标签页不动 → 新标签打开简历页 → 抓取 → 关闭新标签页
```

AppleScript 新标签页实现：

```applescript
if rh is "new" then
  tell front window
    set nt to make new tab at end of tabs with properties {URL:"https://www.zhipin.com/web/geek/resume"}
    set active tab index to (count of tabs)
  end tell
  delay 5
  -- 执行 JS 抓取简历 → 存入 localStorage
  close nt
  delay 1
end if
```

### 使用当前页面搜索条件

**不要导航到搜索页。** 用户已在当前页面设好筛选条件，脚本应直接使用：

```
❌ 错误：set URL to \"https://www.zhipin.com/web/geek/jobs\" → 丢失用户筛选
✅ 正确：直接从当前页面读取 li.job-card-box 并处理
```

### 完整工作流

```
用户设置筛选条件 → 停留在搜索结果页 → 运行脚本
  → 检查 localStorage 是否有简历
    → 无 → 新标签页打开简历页面 → 抓取 → 关闭新标签页（不干扰当前搜索页）
    → 有 → 直接使用
  → 读取当前页面的 li.job-card-box（不导航、不刷新）
  → 逐个职位：点击左侧卡片 → 右侧面板更新详情 → 7重过滤（实习/应届→外包→活跃→已投递→不合适企业→匹配）→ 打招呼
  → Part 3：跳转聊天页 → 扫描拒绝关键词 → 自动加入不合适企业名单
  → 完成统计
```

## 坑点

### AppleScript 字符串中 `]` 导致编译错误

当 AppleScript 字符串中同时包含 `]` 和变量拼接时，编译器会报 `Expected end of line but found "]"`。**不要**在 JS 代码中嵌入 `]` 和 AppleScript 变量拼接：

```applescript
-- ❌ 错误：AppleScript 无法解析这个字符串
execute active tab of front window javascript "BossChat._addChatLog('[" & idx & "] " & company & "')"

-- ✅ 正确：先拼接完整变量，再传给 JS
set chatMsg to "[" & idx & "] " & company
execute active tab of front window javascript "BossChat._addChatLog('" & chatMsg & "')"
```

原理：AppleScript 的词法分析器在解析字符串字面量时，遇到 `"]`（紧随变量后的 `]`）会提前结束字符串，误以为 `]` 是代码。将其放在变量中即可绕过。

### 长 JS 代码用独立文件注入

当 JS 代码过长（>500字符）或包含复杂的引号嵌套时，直接用 AppleScript 字符串嵌入会导致转义地狱。改用独立文件 + `do shell script`：

```applescript
-- chat_scan_helpers.js 文件包含完整 JS 代码
set chatJs to do shell script "cat /path/to/chat_scan_helpers.js"
execute active tab of front window javascript "window.BossChat=window.BossChat||{}"
execute active tab of front window javascript chatJs
```

文件本身是标准 JS，无需任何 AppleScript 转义。适用于：聊天页专用函数、复杂 DOM 操作、长引擎代码。

### 聊天页点击必须点 LI，不能点子元素: 在聊天页选择对话时，必须 `items[i].click()`（直接点 LI）。`.friend-content-warp.click()` 虽然 JS 执行成功但**不触发 SPA 右侧面板加载**，右侧一直显示占位文字。实际 Vue 事件监听挂在 LI 上，不是子元素。
- **AppleScript 保留字**: `rd` 和 `me` 是 AppleScript 保留字，不能用作变量名。用 `rx` / `rdv` / `mev` 替代。
- **AppleScript 字符串转义**: 双引号用 `\"`，反斜杠用 `\\`。长 JS 用 Python 生成 .applescript 文件。
- **AppleScript 正则简写陷阱**: 在 AppleScript `"..."` 字符串中，`\d` 和 `\s` 等正则简写会触发编译错误 `Expected "\"" but found unknown token`。必须使用 `[0-9]`（代替 `\d`）和空格（代替 `\s`）。
- **`missing value` 陷阱**: 复杂 JS 返回 missing value 可能来自语法错误或页面导航后上下文丢失。用 `if r is missing value`（无引号）判断。
- **JSON 解析**: 不要用 AppleScript 的 `text item delimiters`。用 bash + Python 解析。
- **SPA 等待**: `delay 3s` 足够右侧面板加载。
- **`hasOutsourceCompany` 返回值**: 返回字符串 `"true"`/`"false"`，用 `contains "true"` 判断。
- **简历页面**: 使用 `data-scroll` 属性做滚动锚点（如 `data-scroll="userDesc"`）。
- **新标签页方案**: 简历抓取用新标签页，避免当前标签页来回跳转跳出 Boss直聘。
- **`text item delimiters` 泄漏**: 每次用完立即重置为 `""`。
- **`if md is missing value` 不能加引号**: AppleScript 特殊类型，不是字符串。`if md is "missing value"` 永不匹配。
- **引擎只需注入一次**: SPA 卡片点击方案不离开搜索页，`BossChat` 对象不会被销毁。循环开头注入一次即可。
- **后台不可用**: `osascript` 的 UI 操作只能在**前台终端会话**中运行。`terminal(background=true)` 静默失败。

## 参考文件

- `references/bosszhipin-autochat-dom.md` — Boss直聘搜索页、详情页、简历页的完整 DOM 结构和选择器（实战验证）
- `references/bosszhipin-dom.md` — 屏蔽公司项目中的 Boss直聘 API 端点参考
- `references/overlay-log-ui.md` — 页面浮层日志 UI 实现（黑底绿字浮层 + AppleScript 调用方法）
- `references/chat-page-dom.md` — 聊天页 DOM 结构 + 拒绝关键词检测函数（实战验证）
