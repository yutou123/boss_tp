// bosschat_engine.js — 所有业务逻辑，通过 localStorage 通信
// AppleScript 调用此文件中单个函数，结果存 localStorage

(function(){
  window.BossChat = window.BossChat || {};

  // 检测做题
  BossChat.checkTest = function() {
    var el = document.querySelector('.job-detail-body') || document.querySelector('.job-sec-text');
    if (!el) return '';
    var t = el.textContent.toLowerCase().substring(0, 3000);
    var kws = '笔试,做题,测评,测试题,在线测试,机试,编程题,算法题,线上笔试,上机考试'.split(',');
    for (var i = 0; i < kws.length; i++) {
      if (t.indexOf(kws[i]) >= 0) return kws[i];
    }
    return '';
  };

  // 检测外包
  BossChat.checkOutsource = function() {
    var cn = '';
    var cl = document.querySelector('.boss-name');
    if (cl) { cn = cl.textContent.trim(); }
    else {
      var ls = document.querySelectorAll('a[href*="/gongsi/"]');
      for (var i = 0; i < ls.length; i++) {
        var t = ls[i].textContent.trim();
        if (t.length > 1 && t.length < 25 && t !== '公司' && t.indexOf('查看') < 0 && t.indexOf('更多') < 0) { cn = t; break; }
      }
    }
    var bl = '中软国际,软通动力,文思海辉,东软集团,博彦科技,亚信科技,法本信息,诚迈科技,润和软件,汉得信息,外企德科,中智,科锐国际,华为od,富士康,立讯精密'.split(',');
    for (var i = 0; i < bl.length; i++) {
      if (cn.indexOf(bl[i]) >= 0) return cn;
    }
    return '';
  };

  // 匹配评分
  BossChat.matchScore = function() {
    var r = JSON.parse(localStorage.getItem('bosschat_resume') || '{}');
    var el = document.querySelector('.job-detail-body') || document.querySelector('.job-sec-text');
    if (!el) return '0|0|0|0|0|不限';
    var txt = el.textContent.toLowerCase().substring(0, 5000);
    txt = txt.replace(/\.[a-z]+\{[^}]*\}/g, ' ');
    
    var sk = r.skills || [];
    var mc = 0;
    for (var i = 0; i < sk.length; i++) {
      if (txt.indexOf(sk[i].toLowerCase()) >= 0) mc++;
    }
    var sk2 = r.kw || [];
    for (var i = 0; i < sk2.length; i++) {
      if (txt.indexOf(sk2[i].toLowerCase()) >= 0) mc++;
    }
    var ss = Math.min(50, mc * 8);
    
    // 经验要求
    var hi = document.querySelector('.job-header-info');
    var ht = hi ? hi.textContent : '';
    var em = ht.match(/([0-9]+)年以上/);
    if (!em) em = ht.match(/([0-9]+)[-~]([0-9]+) *年/);
    var nx = em ? [em[2] || em[1]] : null;
    var re = nx ? parseInt(nx[0]) : 0;
    var es = (re > 0) ? (Math.abs(10 - re) <= 1 ? 30 : Math.abs(10 - re) <= 3 ? 20 : 10) : 20;
    
    // 学历
    var ed = txt.indexOf('本科') >= 0 ? '本科' : txt.indexOf('硕士') >= 0 ? '硕士' : '';
    var order = {博士:4, 硕士:3, 本科:2, 大专:1};
    var eduUser = r.education || '本科';
    var eus = ed ? ((order[eduUser] || 0) >= (order[ed] || 0) ? 20 : 5) : 15;
    
    var total = ss + es + eus;
    return total + '|' + ss + '|' + es + '|' + eus + '|' + re + '|' + (ed || '不限');
  };

  // 获取卡片信息
  BossChat.getCard = function(idx) {
    var cards = document.querySelectorAll('li.job-card-box');
    var c = cards[idx];
    if (!c) return '||';
    var ne = c.querySelector('.job-name');
    var ce = c.querySelector('.boss-name');
    var lk = c.querySelector('a.job-name');
    return (ne ? ne.textContent.trim() : '') + '|' + (ce ? ce.textContent.trim() : '') + '|' + (lk ? lk.getAttribute('href') : '');
  };

  // 检查配额
  BossChat.checkQuota = function() {
    var today = new Date().toDateString();
    var saved = localStorage.getItem('qdate') || '';
    var count = parseInt(localStorage.getItem('qcount') || '0');
    if (saved !== today) {
      localStorage.setItem('qdate', today);
      localStorage.setItem('qcount', '0');
      count = 0;
    }
    return (150 - count) + '';
  };

  // 使用配额
  BossChat.useQuota = function() {
    var c = parseInt(localStorage.getItem('qcount') || '0');
    localStorage.setItem('qcount', '' + (c + 1));
  };

  // 打招呼
  BossChat.clickChat = function() {
    var btn = document.querySelector('a.op-btn.op-btn-chat, a.btn.btn-startchat');
    if (btn) btn.click();
  };

  // 留在此页
  BossChat.clickStay = function() {
    var sb = document.querySelector('span.btn.btn-outline.btn-cancel');
    if (sb && sb.textContent.indexOf('留在此页') >= 0) sb.click();
  };

  // 已投递检查
  BossChat.isGreeted = function(href, company) {
    var g = JSON.parse(localStorage.getItem('bosschat_greeted') || '[]');
    for (var i = 0; i < g.length; i++) {
      if (typeof g[i] == 'string' && g[i] == href) return true;
      if (typeof g[i] == 'object' && (g[i].h == href || g[i].c == company)) return true;
    }
    return false;
  };

  // 标记已投递
  BossChat.markGreeted = function(href, company) {
    var g = JSON.parse(localStorage.getItem('bosschat_greeted') || '[]');
    var found = false;
    for (var i = 0; i < g.length; i++) {
      if (typeof g[i] === 'object' && g[i].h === href) { found = true; break; }
    }
    if (!found) {
      g.push({h: href, c: company});
      localStorage.setItem('bosschat_greeted', JSON.stringify(g));
    }
  };

  // ----------- 聊天扫描（投递后检测不合适企业）-----------

  // 获取对话数量（仅统计有公司名的）
  BossChat.getConvoCount = function() {
    var items = document.querySelectorAll('.user-list-content li');
    var c = 0;
    for (var i = 0; i < items.length; i++) {
      var txt = items[i].textContent || '';
      var s = items[i].querySelector('.name-box span:not(.name-text)');
      if (txt.length > 5 && s && s.textContent.trim().length > 0) c++;
    }
    return c + '';
  };

  // 点击第N个对话，返回公司名
  BossChat.clickConvo = function(idx) {
    var items = document.querySelectorAll('.user-list-content li');
    var ri = 0;
    for (var i = 0; i < items.length; i++) {
      var txt = items[i].textContent || '';
      var s = items[i].querySelector('.name-box span:not(.name-text)');
      var cn = s ? s.textContent.trim() : '';
      if (txt.length > 5 && cn.length > 0) {
        if (ri == idx) {
          var tb = items[i].querySelector('.title-box');
          if (tb) tb.click();
          return cn;
        }
        ri++;
      }
    }
    return '';
  };

  // 检查当前聊天是否有拒绝关键词
  BossChat.checkRejection = function() {
    var el = document.querySelector('.chat-conversation');
    if (!el) return 'no';
    var txt = el.textContent;
    var kw = '不太合适,早日找到满意,不适合,不合适,不匹配'.split(',');
    for (var i = 0; i < kw.length; i++) {
      if (txt.indexOf(kw[i]) >= 0) return 'yes';
    }
    return 'no';
  };

  console.log('BossChat engine loaded');
})();
