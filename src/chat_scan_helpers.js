// chat_scan_helpers.js — injected into chat page
BossChat._addChatLog=function(t){
  var el=document.getElementById('bc-chat-log');
  if(!el){
    el=document.createElement('div');
    el.id='bc-chat-log';
    el.style.cssText='position:fixed;top:60px;right:10px;width:380px;max-height:75vh;overflow-y:auto;background:rgba(0,0,0,0.9);color:#0f0;font:13px/1.5 monospace;padding:12px;border-radius:8px;z-index:9999999;white-space:pre-wrap;border:2px solid #0f0';
    document.body.appendChild(el);
  }
  var d=document.createElement('div');
  d.textContent=t;
  d.style.cssText='padding:3px 0;border-bottom:1px solid rgba(0,255,0,0.1)';
  el.appendChild(d);
  el.scrollTop=el.scrollHeight;
};
BossChat._getConvoCount=function(){
  var items=document.querySelectorAll('.user-list-content li');
  var c=0;
  for(var i=0;i<items.length;i++){
    var t=items[i].textContent||'';
    var s=items[i].querySelector('.name-box span:not(.name-text)');
    if(t.length>5&&s&&s.textContent.trim().length>0)c++;
  }
  return c+'';
};
BossChat._getLastCompany=function(){
  var items=document.querySelectorAll('.user-list-content li');
  for(var i=items.length-1;i>=0;i--){
    var t=items[i].textContent||'';
    var s=items[i].querySelector('.name-box span:not(.name-text)');
    if(t.length>5&&s)return (s.textContent||'').trim();
  }
  return'';
};
BossChat._clickConvo=function(idx){
  var items=document.querySelectorAll('.user-list-content li');
  var ri=0;
  for(var i=0;i<items.length;i++){
    var t=items[i].textContent||'';
    var s=items[i].querySelector('.name-box span:not(.name-text)');
    var cn=s?s.textContent.trim():'';
    if(t.length>5&&cn.length>0){
      if(ri==idx){
        items[i].scrollIntoView({block:'center'});
        var tb=items[i].querySelector('.title-box');
        if(tb)tb.click();
        return cn.trim();
      }
      ri++;
    }
  }
  return '';
};
BossChat._scrollPage=function(){
  var el=document.querySelector('.user-list-content');
  if(el)el.scrollTop=el.scrollHeight;
};
BossChat._checkRejection=function(){
  var el=document.querySelector('.chat-conversation');
  if(!el)return'no';
  var txt=el.textContent;
  var kw='不太合适,早日找到满意,不适合,不合适,不匹配,不太匹配,暂不完全匹配,祝您在BOSS直聘'.split(',');
  for(var i=0;i<kw.length;i++){
    if(txt.indexOf(kw[i])>=0)return'yes';
  }
  return'no';
};
