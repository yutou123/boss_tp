# 聊天页 DOM 结构 + 翻页扫描

## 布局

```
.chat-wrap (1184x654)
  ├── .list-warp.v2 (368px) ← 左栏
  │   └── .chat-user.v2
  │       ├── .boss-search-top (搜索框)
  │       ├── .label-list (筛选标签：全部/未读/新招呼...)
  │       └── .chat-content
  │           └── .user-list
  │               └── .user-list-content ← 滚动容器（overflow-y:auto）
  │                   ├── LI (filter tabs 0-7: 全部/未读/新招呼/仅沟通/更多/有交换/有面试/不感兴趣)
  │                   └── LI (conversations 8+):
  │                       .friend-content-warp
  │                         .friend-content
  │                           .figure (头像)
  │                           .text
  │                             .time
  │                             .title-box ← 点击目标！
  │                               .name-box
  │                                 .name-text (人名)
  │                                 span (公司名)
  │                                 .vline
  │                                 span (职位)
  │                             .gray.last-msg (最后消息预览)
  └── .chat-conversation (812px) ← 右栏
      ├── 空状态: .chat-no-data (未选中时)
      └── 选中后:
          ├── .top-info-content (公司+职位信息)
          ├── .chat-record / .chat-message (聊天消息)
          └── .chat-im.chat-editor (输入区)
```

## 关键选择器

| 目标 | 选择器 | 说明 |
|------|--------|------|
| 左栏容器 | `.user-list-content` | `overflow-y:auto`, 虚拟滚动容器 |
| 对话列表项 | `.user-list-content li` | 含 filter tabs(0-7) + 对话(8+) |
| 对话点击 | `.title-box` | Vue 事件监听挂在这里！ |
| 公司名 | `.name-box span:not(.name-text)` | 人名后的第一个 span |
| 人名 | `.name-text` | |
| 右侧聊天区 | `.chat-conversation` | 主容器 |
| 聊天消息 | `.chat-record`, `.chat-message` | 消息气泡 |
| 浮层面板 | `#bc-chat-log` | 自定义注入（z-index: 9999999） |

## 点击注意事项

**必须点 `.title-box`**，不能点 LI 或 `.friend-content-warp`。Vue 的 `@click` 事件直接绑定在 `.title-box` 元素上。点 LI 虽然 JS 执行成功但不会触发 SPA 路由切换。

## 虚拟滚动翻页

`.user-list-content` 的 `scrollHeight` (7842px) >> `clientHeight` (562px)，但 `overflow-y: auto` 的 scrollbar 不可见（被隐藏或样式覆盖）。滚动该容器后，DOM 始终 ~40 个 LI，但内容被替换（旧的滑出、新的滑入）。

**翻页检测方法**：滚动前后对比最后一个对话的公司名（不是对比总数）。

```javascript
// 翻页：滚动虚拟列表容器
BossChat._scrollPage = function() {
  var el = document.querySelector('.user-list-content');
  if (el) el.scrollTop = el.scrollHeight;
};

// 获取最后一个对话的公司名
BossChat._getLastCompany = function() {
  var items = document.querySelectorAll('.user-list-content li');
  for (var i = items.length - 1; i >= 0; i--) {
    var t = items[i].textContent || '';
    var s = items[i].querySelector('.name-box span:not(.name-text)');
    if (t.length > 5 && s) return (s.textContent || '').trim();
  }
  return '';
};
```

## 拒绝关键词

当前完整列表：
```
不太合适,早日找到满意,不适合,不合适,不匹配,
不太匹配,暂不完全匹配,祝您在BOSS直聘
```

## 浮层配置

```css
position: fixed;
right: 10px;
top: 60px;
width: 380px;
max-height: 75vh;
z-index: 9999999;          /* 必须极高，盖过 .chat-conversation(z-index:9) */
background: rgba(0,0,0,0.9);
border: 2px solid #0f0;
color: #0f0;
font: 13px/1.5 monospace;
```
