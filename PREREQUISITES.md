# BossChat — 前置需求

## 系统要求

| 项目 | 要求 | 说明 |
|------|------|------|
| 操作系统 | **macOS** | AppleScript 仅 macOS 可用 |
| 浏览器 | **Google Chrome** | Safari/Firefox 不支持 `execute javascript` |
| Shell | **bash/zsh** | 默认 macOS Shell |

## 账号要求

| 项目 | 说明 |
|------|------|
| Boss直聘账号 | 已登录状态（浏览器保持登录） |
| 简历 | 已完善（脚本自动读取专业技能+工作经历） |
| 搜索结果页 | 已设好筛选条件（薪资、经验、学历等） |

## 文件结构

项目运行需要以下文件（路径按脚本中写死的绝对路径）：

```
/Users/taro/boss直聘自动聊天/
├── src/
│   └── bosschat_final_v3.applescript    ← 主脚本（入口）
│   └── chat_scan_helpers.js              ← 聊天页扫描JS
├── rejected_companies.txt                ← 不合适企业名单（自动创建）
```

**主脚本内写死路径：**
- `logFile = "/Users/taro/boss直聘自动聊天/run_run_log.txt"`
- `rcFile = "/Users/taro/boss直聘自动聊天/rejected_companies.txt"`
- `chatJs = do shell script "cat /Users/taro/boss直聘自动聊天/src/chat_scan_helpers.js"`

如需移动项目位置，必须修改 `bosschat_final_v3.applescript` 中所有路径。

## 运行方式

```bash
# 直接运行
osascript "/Users/taro/boss直聘自动聊天/src/bosschat_final_v3.applescript"

# 输出日志到终端（log 语句走 stderr）
osascript "/Users/taro/boss直聘自动聊天/src/bosschat_final_v3.applescript" 2>&1
```

## 前置检查清单

运行前请确认：

- [ ] macOS 系统（非 Windows/Linux）
- [ ] Google Chrome 已安装并打开
- [ ] Chrome 当前标签页在 Boss直聘搜索结果页（`https://www.zhipin.com/web/geek/job?*`）
- [ ] 搜索结果页已设好筛选条件（职位、薪资、经验等）
- [ ] Boss直聘账号已登录
- [ ] 简历已完善（脚本会自动读取一次并存到 localStorage）
- [ ] `src/bosschat_final_v3.applescript` 文件存在
- [ ] `src/chat_scan_helpers.js` 文件存在
- [ ] `rejected_companies.txt` 文件存在（可为空）

## 运行流程

```
1. 脚本弹出对话框 → 显示职位数 + 今日剩余配额
   → 点击"开始"
2. 自动遍历所有职位（含翻页）：
   实习/应届 → 外包 → 不活跃 → 已投递 → 不合适企业 → 评分 < 50 → 跳过
   评分 ≥ 50 → 打招呼
3. 投递完成后自动跳转聊天页：
   翻页扫描所有对话 → 检测拒绝关键词
   → 匹配则追加到 rejected_companies.txt
4. 弹出完成统计
```

## 风险提示

- Boss直聘有反爬机制，操作间隔 `delay 3` 秒
- 日配额 150 次（Boss直聘限制），脚本自动遵守
- 如触发风控（验证码/封号），脚本不负责
- Chrome 窗口必须在前台运行（osascript 不能后台）
