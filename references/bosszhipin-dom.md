# Boss直聘 DOM 结构参考（2026-06 实测）

## 搜索结果页（左右分栏）

URL: `/web/geek/jobs?city=...&query=...`

### 左侧列表
```
li.job-card-box               ← 每条职位卡片（15条/页）
  ├── .job-info
  │   ├── .job-title
  │   │   ├── a.job-name      ← 职位名称（href="/job_detail/xxx.html"）
  │   │   └── span.job-salary ← 薪资（"30-50K"）
  │   └── ul.tag-list
  │       ├── li              ← 经验要求（"5-10年"）
  │       └── li              ← 学历要求（"本科"）
  └── .job-card-footer
      └── a.boss-info
          └── span.boss-name  ← 公司名称
```

### 右侧详情面板
```
.job-detail-container
  └── .job-detail-box
      └── .job-detail-body    ← 岗位描述文本（含 CSS 噪音）

.job-detail-op.clearfix       ← 操作栏（右上角）
  ├── a.op-btn.op-btn-like    ← "收藏"
  └── a.op-btn.op-btn-chat    ← "立即沟通"
```

### 打招呼后弹窗
```
.dialog-wrap.greet-pop
  └── .dialog-container (395,272 460x199)
      ├── .dialog-title         "已向BOSS发送消息"
      ├── .dialog-con           打招呼内容
      └── .dialog-footer
          └── .btns
              ├── span.btn.btn-outline.btn-cancel   ← "留在此页"
              └── span.btn.btn-sure                 ← "继续沟通"
```

## 独立详情页（/job_detail/xxx.html）

```
.job-detail-section
  └── .job-sec-text               ← 岗位描述文本

.job-banner
  ├── .job-title                  ← 职位名称
  ├── .job-salary                 ← 薪资
  └── a.btn.btn-startchat        ← "立即沟通"

公司名称在 a[href*='/gongsi/'] 中，需过滤导航链接
```

## 简历页面

URL: `/web/geek/resume`

```
.resume-item                     ← 每个区块
  ├── .item-primary              ← 区块标题
  │   └── h3.title               ← 区块名
  └── .primary-info
      ├── .info-text             ← 文本内容
      ├── .info-text-block       ← 带格式文本
      └── .text-block-main       ← 主要文本块

.advantage-show
  └── .advantage-text            ← 优势/技能详情

.keywords span                   ← 技能标签
```

### data-scroll 锚点
- `data-scroll="baseInfo"` — 基本信息
- `data-scroll="userDesc"` — 个人优势/专业技能
- `data-scroll="expectList"` — 期望职位
- `data-scroll="expList"` — 工作经历

### 公司名提取（跨页面通用）
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
