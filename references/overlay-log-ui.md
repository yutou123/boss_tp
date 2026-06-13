# 页面浮层日志 UI

在 Boss直聘搜索页右侧创建实时日志浮层，替代终端日志输出。

## 实现

### 引擎内嵌函数

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

### AppleScript 调用

```applescript
execute active tab of front window javascript "BossChat._addLog('" & fl & "')"
```

### 注意事项

1. `fl` 不能包含单引号（JS 字符串用 `'` 包裹）。日志文本是状态消息，不会出现单引号。
2. SPA 页面不刷新（卡片点击方案），浮层全程可见。
3. `d.textContent = t` (非 innerHTML) 防止 XSS。
4. `el.scrollTop = el.scrollHeight` 自动滚到底部。
5. 黑底绿字，与终端风格一致。
6. 若需同时写入文件：AppleScript 的 `write` 命令输出 MacRoman 编码，中文会乱码。改用 `do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile` 解决。注意 `quoted form of` 对含 `'` 的字符串会出错——日志文本不含 `'` 则安全。
