# boss_tp — Boss直聘自动聊天

> 一个 AppleScript 驱动的 Boss直聘自动化工具，自动遍历职位、过滤外包/不活跃/不合适企业、匹配评分后打招呼，完成后自动扫描聊天检测拒绝企业。

## 功能

### 🔍 智能搜索遍历
- 在搜索结果页面自动遍历每个职位
- 使用页面已有的筛选条件（薪资、经验、学历、公司规模、融资阶段）

### 🚫 做题检测
- 自动检测职位描述中是否包含「笔试」「做题」「测评」「机试」等关键词
- 内置 20+ 做题相关关键词
- 检测到需做题的职位自动跳过，节省时间

### 💬 聊天状态追踪
- 自动记录每个职位的沟通状态
- 已被明确拒绝的职位自动跳过，不重复打扰
- 正在聊天中的职位标记为跟进状态
- 未聊过的职位自动发起沟通
- 状态通过 GM_setValue 持久化，跨会话保存

### 📩 自动打招呼
- 点击「立即沟通」后自动发送预设的打招呼消息
- 支持自定义打招呼内容
- 处理弹窗中的「留在此页，继续沟通」选项

### 📊 实时面板
- 右下角浮动控制面板
- 实时显示扫描数、沟通数、跳过统计
- 一键启动/停止
- 防误触：每日沟通上限设置

## 前置需求

详见 [PREREQUISITES.md](PREREQUISITES.md)

## 安装

```bash
git clone git@github.com:yutou123/boss_tp.git
cd boss_tp
```

## 使用方法

```bash
osascript "src/bosschat_final_v3.applescript"
```

详见 `PREREQUISITES.md` 中的完整检查清单。

## 过滤机制

### 做题检测关键词
笔试、做题、测评、测试题、在线测试、机试、代码测试、编程题、算法题、线上笔试、专业笔试、综合测评、性格测试、心理测试、能力测试、技术笔试、机考、在线编程、技术测评、专业测评、上机考试

### 拒绝检测关键词
不太合适、早日找到满意、不适合、不合适、不匹配、不太匹配、暂不完全匹配、祝您在BOSS直聘

## 数据存储

- `rejected_companies.txt` — 不合适企业名单（本地文件，可手动编辑）
- 浏览器 localStorage — 已投递记录、简历缓存、每日配额

**隐私说明：** 所有数据仅存储在你的本地，不发送到任何服务器。

## 项目结构

```
boss_tp/
├── PREREQUISITES.md                          ← 前置需求
├── SKILL.md                                  ← Hermes 技能文档
├── README.md
├── LICENSE
├── rejected_companies.txt                    ← 不合适企业名单
├── src/
│   ├── bosschat_final_v3.applescript         ← 主脚本
│   ├── bosschat_engine.js                    ← 投递引擎JS参考
│   └── chat_scan_helpers.js                  ← 聊天扫描JS
└── references/
    └── *.md                                  ← DOM 结构参考
```

## License

MIT
