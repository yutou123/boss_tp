-- BossChat 最终版
on run
	-- 动态获取项目目录（根据脚本自身路径）
	set scriptPath to POSIX path of (path to me)
	set projectDir to do shell script "dirname \"$(dirname '" & scriptPath & "')\""
	
	tell application "Google Chrome"
		activate
		
		-- 设置日志文件
		set logFile to projectDir & "/run_log.txt"
		do shell script "/bin/echo \"=== BossChat Run ===\" > " & quoted form of logFile
		
		-- 检查/获取简历（新标签页打开，不干扰当前页）
		set rh to execute active tab of front window javascript "localStorage.getItem('bosschat_resume')?'ok':'new';"
		if rh is "new" then
			tell front window
				set nt to make new tab at end of tabs with properties {URL:"https://www.zhipin.com/web/geek/resume"}
				set active tab index to (count of tabs)
			end tell
			delay 5
			set rx to execute active tab of front window javascript "var r={name:'',experience_years:10,education:'本科',skills:[],kw:[]};var pt=document.body.textContent||'';if(pt.indexOf('博士')>=0)r.education='博士';else if(pt.indexOf('硕士')>=0)r.education='硕士';else if(pt.indexOf('本科')>=0)r.education='本科';var ps=document.querySelector('.resume-professional-skill');if(ps){var t=ps.textContent||'';var p=t.split(/[,，、]/);for(var i=0;i<p.length;i++){var s=p[i].trim();var ci=s.indexOf('：');if(ci>=0)s=s.substring(ci+1);ci=s.indexOf(':');if(ci>=0)s=s.substring(ci+1);if(s.length>1&&s.length<30&&s!='编辑删除'&&s!='专业技能')r.skills.push(s)}}var ak='LLM,AI Agent,RAG,Prompt,SEO,GEO,数字人,AIGC,大模型,知识库,智能体,Agent,虚拟空间,元宇宙,工作流,对话,政务,司法,流量,内容管理,数据产品,B端产品,C端产品,G端产品,产品设计,数据分析,搜索引擎优化,生成式引擎优化,AI助手,模型对话,Prompt Engineering'.split(',');for(var i=0;i<ak.length;i++){if(pt.indexOf(ak[i])>=0&&r.skills.indexOf(ak[i])<0)r.skills.push(ak[i])}localStorage.setItem('bosschat_resume',JSON.stringify(r));"
			close last tab of front window
			delay 1
		end if
		
		-- 检查搜索结果
		set rc to execute active tab of front window javascript "document.querySelectorAll('li.job-card-box').length+'';"
		if rc is "0" or rc is "" then
			display dialog "请先在 Boss直聘设好筛选条件" buttons {"知道了"} default button 1
			return
		end if
		
		-- 确认
		set qc to execute active tab of front window javascript "var d=new Date().toDateString();var s=localStorage.getItem('qdate')||'';var c=parseInt(localStorage.getItem('qcount')||'0');if(s!==d){localStorage.setItem('qdate',d);localStorage.setItem('qcount','0');c=0}(150-c)+'';"
		display dialog "BossChat" & return & "职位:" & rc & " 剩余:" & qc & return & "开始?" buttons {"取消","开始"} default button 2
		if button returned of result is "取消" then return
		
		set tc to rc as integer
		set gc to 0
		set stc to 0
		set smc to 0
		set soc to 0
		set rcList to {} -- 不合适企业名单
		set rcFile to projectDir & "/rejected_companies.txt"
		try
			set rcContent to do shell script "cat " & quoted form of rcFile & " 2>/dev/null || echo ''"
			set AppleScript's text item delimiters to {return, linefeed}
			set rcLines to every text item of rcContent
			set AppleScript's text item delimiters to ""
			repeat with rcLine in rcLines
				set rl to rcLine as string
				if rl is not "" and first character of rl is not "#" then
					set rcList to rcList & {rl}
				end if
			end repeat
			log "不合适名单: " & (count of rcList) & " 家"
		end try
		
		-- 注入引擎（完整版）
		execute active tab of front window javascript "window.BossChat={};BossChat.gc=function(idx){var c=document.querySelectorAll('li.job-card-box')[idx];if(!c)return'||';var ne=c.querySelector('.job-name');var ce=c.querySelector('.boss-info');var lk=c.querySelector('a.job-name');return(ne?ne.textContent.trim():'')+'|'+(ce?ce.textContent.trim():'')+'|'+(lk?lk.getAttribute('href'):'')};BossChat.qt=function(){var d=new Date().toDateString();var s=localStorage.getItem('qdate')||'';var c=parseInt(localStorage.getItem('qcount')||'0');if(s!==d){localStorage.setItem('qdate',d);localStorage.setItem('qcount','0');c=0}return(150-c)+''};BossChat.uq=function(){var c=parseInt(localStorage.getItem('qcount')||'0');localStorage.setItem('qcount',''+(c+1))};BossChat.tf=function(){var el=document.querySelector('.job-detail-body')||document.querySelector('.job-sec-text');if(!el)return'';var t=el.textContent.toLowerCase().substring(0,3000);var k='笔试,做题,测评,测试题,在线测试,机试,编程题,算法题,线上笔试,上机考试'.split(',');for(var i=0;i<k.length;i++){if(t.indexOf(k[i])>=0)return k[i]}return''};BossChat.os=function(){var cn='';var cl=document.querySelector('.boss-name');if(cl)cn=cl.textContent.trim();else{var ls=document.querySelectorAll('a[href*=\"/gongsi/\"]');for(var i=0;i<ls.length;i++){var t=ls[i].textContent.trim();if(t.length>1&&t.length<25&&t!='公司'&&t.indexOf('查看')<0&&t.indexOf('更多')<0){cn=t;break}}}var bl='中软国际,软通动力,文思海辉,东软集团,博彦科技,亚信科技,法本信息,诚迈科技,润和软件,汉得信息,外企德科,中智,科锐国际,华为od,富士康,立讯精密'.split(',');for(var i=0;i<bl.length;i++){if(cn.indexOf(bl[i])>=0)return cn}return''};BossChat.ac=function(){var el=document.querySelector('.boss-active-time');if(!el)return'no';var t=el.textContent;if(t.indexOf('刚刚活跃')>=0)return'today';if(t.indexOf('今日活跃')>=0)return'today';if(t.indexOf('昨日活跃')>=0)return'yesterday';return'no'};BossChat.sc=function(){try{var r=JSON.parse(localStorage.getItem('bosschat_resume')||'{}');var el=document.querySelector('.job-detail-body')||document.querySelector('.job-sec-text');if(!el)return'0|0|0|0|0|?';var txt=el.textContent.toLowerCase().substring(0,5000);var sk=r.skills||[];var mc=0;for(var i=0;i<sk.length;i++){if(txt.indexOf(sk[i].toLowerCase())>=0)mc++};var sk2=r.kw||[];for(var i=0;i<sk2.length;i++){if(txt.indexOf(sk2[i].toLowerCase())>=0)mc++};var ss=Math.min(50,mc*8);var hi=document.querySelector('.job-header-info');var ht=hi?hi.textContent:'';var em=ht.match(/([0-9]+)年以上/);if(!em)em=ht.match(/([0-9]+)[-~]([0-9]+) *年/);var nx=em?[em[2]||em[1]]:null;var re=nx?parseInt(nx[0]):0;var es=re>0?(Math.abs(10-re)<=1?30:Math.abs(10-re)<=3?20:10):20;var ed=txt.indexOf('本科')>=0?'本科':txt.indexOf('硕士')>=0?'硕士':'';var order={博士:4,硕士:3,本科:2,大专:1};var eu=r.education||'本科';var eus=ed?((order[eu]||0)>=(order[ed]||0)?20:5):15;return(ss+es+eus)+'|'+ss+'|'+es+'|'+eus+'|'+re+'|'+(ed||'?')}catch(e){return'0|0|0|0|0|err'}};BossChat.cb=function(){var btn=document.querySelector('a.op-btn.op-btn-chat,a.btn.btn-startchat');if(btn){btn.click();return'yes'}return'no'};BossChat.sb=function(){var sb=document.querySelector('span.btn.btn-outline.btn-cancel');if(sb&&sb.textContent.indexOf('留在此页')>=0)sb.click();else{var sb2=document.querySelector('.greet-boss-footer .cancel-btn');if(sb2)sb2.click()}};BossChat._addLog=function(t){var el=document.getElementById('bc-log-panel');if(!el){el=document.createElement('div');el.id='bc-log-panel';el.style.cssText='position:fixed;top:60px;right:10px;width:360px;max-height:70vh;overflow-y:auto;background:rgba(0,0,0,0.85);color:#0f0;font:12px/1.5 monospace;padding:10px;border-radius:6px;z-index:99999;white-space:pre-wrap';document.body.appendChild(el)}var d=document.createElement('div');d.textContent=t;el.appendChild(d);el.scrollTop=el.scrollHeight};BossChat._isGreeted=function(h,c){var g=JSON.parse(localStorage.getItem('bosschat_greeted')||'[]');for(var i=0;i<g.length;i++){if(typeof g[i]=='string'&&g[i]==h)return true;if(typeof g[i]=='object'&&(g[i].h==h||g[i].c==c))return true}return false};BossChat._markGreeted=function(h,c){var g=JSON.parse(localStorage.getItem('bosschat_greeted')||'[]');var found=false;for(var i=0;i<g.length;i++){if(typeof g[i]=='object'&&g[i].h==h){found=true;break}}if(!found){g.push({h:h,c:c});localStorage.setItem('bosschat_greeted',JSON.stringify(g))}};BossChat._scrollToLoad=function(){window.scrollTo(0,document.body.scrollHeight);return document.querySelectorAll('li.job-card-box').length+''};BossChat._closePopup=function(){var btns=document.querySelectorAll('[ka=dialog_close],.greet-boss-header .close,.dialog-header .close,.popup-close,.close-btn');for(var i=0;i<btns.length;i++){if(btns[i].offsetParent!==null){btns[i].click();return'closed'}}return'nopopup'};BossChat._scrollToLoad=function(){window.scrollTo(0,document.body.scrollHeight);return document.querySelectorAll('li.job-card-box').length+''};BossChat._closePopup"
		set r0 to execute active tab of front window javascript "window.BossChat?'ok':'fail';"
		log "引擎: " & r0
		
		-- 主循环（含翻页）
		set ptc to 0
		repeat
			set sti to ptc
			set ptc to tc
			repeat with i from sti + 1 to ptc
				set idx to i - 1
				
				-- 重新注入引擎
				execute active tab of front window javascript "window.BossChat={};BossChat.gc=function(idx){var c=document.querySelectorAll('li.job-card-box')[idx];if(!c)return'||';var ne=c.querySelector('.job-name');var ce=c.querySelector('.boss-info');var lk=c.querySelector('a.job-name');return(ne?ne.textContent.trim():'')+'|'+(ce?ce.textContent.trim():'')+'|'+(lk?lk.getAttribute('href'):'')};BossChat.qt=function(){var d=new Date().toDateString();var s=localStorage.getItem('qdate')||'';var c=parseInt(localStorage.getItem('qcount')||'0');if(s!==d){localStorage.setItem('qdate',d);localStorage.setItem('qcount','0');c=0}return(150-c)+''};BossChat.uq=function(){var c=parseInt(localStorage.getItem('qcount')||'0');localStorage.setItem('qcount',''+(c+1))};BossChat.tf=function(){var el=document.querySelector('.job-detail-body')||document.querySelector('.job-sec-text');if(!el)return'';var t=el.textContent.toLowerCase().substring(0,3000);var k='笔试,做题,测评,测试题,在线测试,机试,编程题,算法题,线上笔试,上机考试'.split(',');for(var i=0;i<k.length;i++){if(t.indexOf(k[i])>=0)return k[i]}return''};BossChat.os=function(){var cn='';var cl=document.querySelector('.boss-name');if(cl)cn=cl.textContent.trim();else{var ls=document.querySelectorAll('a[href*=\"/gongsi/\"]');for(var i=0;i<ls.length;i++){var t=ls[i].textContent.trim();if(t.length>1&&t.length<25&&t!='公司'&&t.indexOf('查看')<0&&t.indexOf('更多')<0){cn=t;break}}}var bl='中软国际,软通动力,文思海辉,东软集团,博彦科技,亚信科技,法本信息,诚迈科技,润和软件,汉得信息,外企德科,中智,科锐国际,华为od,富士康,立讯精密'.split(',');for(var i=0;i<bl.length;i++){if(cn.indexOf(bl[i])>=0)return cn}return''};BossChat.ac=function(){var el=document.querySelector('.boss-active-time');if(!el)return'no';var t=el.textContent;if(t.indexOf('刚刚活跃')>=0)return'today';if(t.indexOf('今日活跃')>=0)return'today';if(t.indexOf('昨日活跃')>=0)return'yesterday';return'no'};BossChat.sc=function(){try{var r=JSON.parse(localStorage.getItem('bosschat_resume')||'{}');var el=document.querySelector('.job-detail-body')||document.querySelector('.job-sec-text');if(!el)return'0|0|0|0|0|?';var txt=el.textContent.toLowerCase().substring(0,5000);var sk=r.skills||[];var mc=0;for(var i=0;i<sk.length;i++){if(txt.indexOf(sk[i].toLowerCase())>=0)mc++};var sk2=r.kw||[];for(var i=0;i<sk2.length;i++){if(txt.indexOf(sk2[i].toLowerCase())>=0)mc++};var ss=Math.min(50,mc*8);var hi=document.querySelector('.job-header-info');var ht=hi?hi.textContent:'';var em=ht.match(/([0-9]+)年以上/);if(!em)em=ht.match(/([0-9]+)[-~]([0-9]+) *年/);var nx=em?[em[2]||em[1]]:null;var re=nx?parseInt(nx[0]):0;var es=re>0?(Math.abs(10-re)<=1?30:Math.abs(10-re)<=3?20:10):20;var ed=txt.indexOf('本科')>=0?'本科':txt.indexOf('硕士')>=0?'硕士':'';var order={博士:4,硕士:3,本科:2,大专:1};var eu=r.education||'本科';var eus=ed?((order[eu]||0)>=(order[ed]||0)?20:5):15;return(ss+es+eus)+'|'+ss+'|'+es+'|'+eus+'|'+re+'|'+(ed||'?')}catch(e){return'0|0|0|0|0|err'}};BossChat.cb=function(){var btn=document.querySelector('a.op-btn.op-btn-chat,a.btn.btn-startchat');if(btn){btn.click();return'yes'}return'no'};BossChat.sb=function(){var sb=document.querySelector('span.btn.btn-outline.btn-cancel');if(sb&&sb.textContent.indexOf('留在此页')>=0)sb.click();else{var sb2=document.querySelector('.greet-boss-footer .cancel-btn');if(sb2)sb2.click()}};BossChat._addLog=function(t){var el=document.getElementById('bc-log-panel');if(!el){el=document.createElement('div');el.id='bc-log-panel';el.style.cssText='position:fixed;top:60px;right:10px;width:360px;max-height:70vh;overflow-y:auto;background:rgba(0,0,0,0.85);color:#0f0;font:12px/1.5 monospace;padding:10px;border-radius:6px;z-index:99999;white-space:pre-wrap';document.body.appendChild(el)}var d=document.createElement('div');d.textContent=t;el.appendChild(d);el.scrollTop=el.scrollHeight};BossChat._isGreeted=function(h,c){var g=JSON.parse(localStorage.getItem('bosschat_greeted')||'[]');for(var i=0;i<g.length;i++){if(typeof g[i]=='string'&&g[i]==h)return true;if(typeof g[i]=='object'&&(g[i].h==h||g[i].c==c))return true}return false};BossChat._markGreeted=function(h,c){var g=JSON.parse(localStorage.getItem('bosschat_greeted')||'[]');var found=false;for(var i=0;i<g.length;i++){if(typeof g[i]=='object'&&g[i].h==h){found=true;break}}if(!found){g.push({h:h,c:c});localStorage.setItem('bosschat_greeted',JSON.stringify(g))}};BossChat._scrollToLoad=function(){window.scrollTo(0,document.body.scrollHeight);return document.querySelectorAll('li.job-card-box').length+''};BossChat._closePopup=function(){var btns=document.querySelectorAll('[ka=dialog_close],.greet-boss-header .close,.dialog-header .close,.popup-close,.close-btn');for(var i=0;i<btns.length;i++){if(btns[i].offsetParent!==null){btns[i].click();return'closed'}}return'nopopup'};BossChat._scrollToLoad=function(){window.scrollTo(0,document.body.scrollHeight);return document.querySelectorAll('li.job-card-box').length+''};BossChat._closePopup"
				
				-- 配额
				set qc to execute active tab of front window javascript "BossChat.qt();"
				if qc ≤ 0 then exit repeat
				
				-- 卡片
				set ci to execute active tab of front window javascript "BossChat.gc(" & idx & ");"
				if ci is "" then exit repeat
				set AppleScript's text item delimiters to "|"
				set ct to text item 1 of ci
				set cc to text item 2 of ci
				set ch to text item 3 of ci
				set AppleScript's text item delimiters to ""
				if ch is "" then exit repeat
				
				-- 跳过实习/应届
				if ct contains "实习" or ct contains "应届" then
					set smc to smc + 1
					log "  ⏭ 实习/应届"
					set fl to "  ⏭ 实习/应届"
					do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
					execute active tab of front window javascript "BossChat._addLog('" & fl & "')"
				else
					log "[" & i & "/" & ptc & "] " & ct & " @ " & cc
					set fl to "[" & i & "/" & ptc & "] " & ct & " @ " & cc
					do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
					execute active tab of front window javascript "BossChat._addLog('" & fl & "')"
					
					-- 点击卡片刷新右侧面板
					execute active tab of front window javascript "var cards=document.querySelectorAll('li.job-card-box');if(cards[" & idx & "]){cards[" & idx & "].querySelector('a.job-name').click();}"
					delay 3
					
					-- 外包检测
					set os to execute active tab of front window javascript "BossChat.os();"
					if os is not "" then
						set soc to soc + 1
						log "  ⏭ 外包(" & os & ")"
						set fl to "  ⏭ 外包(" & os & ")"
						do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
						execute active tab of front window javascript "BossChat._addLog('" & fl & "')"
					else
						-- 活跃检测
						set ac to execute active tab of front window javascript "BossChat.ac();"
						if ac is "no" then
							set smc to smc + 1
							log "  ⏭ 不活跃"
							set fl to "  ⏭ 不活跃"
							do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
							execute active tab of front window javascript "BossChat._addLog('" & fl & "')"
						else
							-- 已投递检查
							set gh to execute active tab of front window javascript "BossChat._isGreeted('" & ch & "','" & cc & "')"
							if gh is "true" then
								set smc to smc + 1
								log "  ⏭ 已投递过"
								set fl to "  ⏭ 已投递过"
								do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
								execute active tab of front window javascript "BossChat._addLog('" & fl & "')"
							else
								-- 不合适企业检查（本地文件）
								set rh to "false"
								repeat with rcl in rcList
									set rcl2 to rcl as string
									if cc contains rcl2 or rcl2 contains cc then
										set rh to "true"
										exit repeat
									end if
								end repeat
								if rh is "true" then
									set smc to smc + 1
									log "  ⏭ 不合适企业(" & cc & ")"
									set fl to "  ⏭ 不合适企业(" & cc & ")"
									do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
									execute active tab of front window javascript "BossChat._addLog('" & fl & "')"
									else
									-- 匹配评分
									set md to execute active tab of front window javascript "BossChat.sc();"
									if md is missing value then set md to "0|0|0|0|0|err"
									set AppleScript's text item delimiters to "|"
									set mt to text item 1 of md
									set ms to text item 2 of md
									set mev to text item 3 of md
									set mf to text item 4 of md
									set mr to text item 5 of md
									set med to text item 6 of md
									set AppleScript's text item delimiters to ""
									
									try
										if (mt as integer) ≥ 50 then
											log "  ✅ " & mt & "分(" & ms & "+" & mev & "+" & mf & ") 要求" & mr & "年/" & med
											set fl to "  ✅ " & mt & "分(" & ms & "+" & mev & "+" & mf & ") 要求" & mr & "年/" & med
											do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
											execute active tab of front window javascript "BossChat._addLog('" & fl & "')"
											set su to execute active tab of front window javascript "window.location.href"
											set hb to execute active tab of front window javascript "BossChat.cb();"
											if hb is "yes" then
												delay 3
												set cu to execute active tab of front window javascript "window.location.href"
												if cu is not equal to su and (cu contains "/chat/" or cu contains "/web/geek/chat") then
													log "  ⏭ 已投递过(跳转聊天页)"
													set fl to "  ⏭ 已投递过(跳转聊天页)"
													do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
													execute active tab of front window javascript "BossChat._addLog('" & fl & "')"
													execute active tab of front window javascript "BossChat._markGreeted('" & ch & "','" & cc & "')"
													execute active tab of front window javascript "window.location.href='" & su & "'"
													delay 3
												else
													delay 1
													execute active tab of front window javascript "BossChat.sb();BossChat.uq();"
													delay 1
													execute active tab of front window javascript "BossChat._closePopup();"
													set gc to gc + 1
													log "    ✅ 已打招呼"
													set fl to "    ✅ 已打招呼"
													do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
													execute active tab of front window javascript "BossChat._addLog('" & fl & "')"
													execute active tab of front window javascript "BossChat._markGreeted('" & ch & "','" & cc & "')"
												end if
											end if
										else
											set smc to smc + 1
											log "  ⏭ " & mt & "分(技能" & ms & " 经验" & mev & " 学历" & mf & ") 要求" & mr & "年/" & med
											set fl to "  ⏭ " & mt & "分(技能" & ms & " 经验" & mev & " 学历" & mf & ") 要求" & mr & "年/" & med
											do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
											execute active tab of front window javascript "BossChat._addLog('" & fl & "')"
										end if
									end try
								end if
							end if
						end if
					end if
				end if
			end repeat
			
			-- 滚动加载更多
			execute active tab of front window javascript "BossChat._scrollToLoad();"
			delay 3
			set rc to execute active tab of front window javascript "document.querySelectorAll('li.job-card-box').length+'';"
			if rc as integer ≤ ptc then exit repeat
			set tc to rc as integer
			
			-- 检查配额
			set qc to execute active tab of front window javascript "BossChat.qt();"
			if qc ≤ 0 then exit repeat
			
		end repeat
		
		log ""
		log "=== BossChat 完成 ==="
		log "招呼:" & gc & " 外包:" & soc & " 做题:" & stc & " 不匹配:" & smc
		set fl to "--- 完成 ---"
		do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
		execute active tab of front window javascript "BossChat._addLog('" & fl & "')"
		set fl2 to "招呼:" & gc & " 外包:" & soc & " 做题:" & stc & " 不匹配:" & smc
		do shell script "/bin/echo " & quoted form of fl2 & " >> " & quoted form of logFile
		execute active tab of front window javascript "BossChat._addLog('" & fl2 & "')"
		do shell script "/bin/echo === End === >> " & quoted form of logFile
		execute active tab of front window javascript "BossChat._addLog('=== End ===')"
		
		-- 投递后扫描聊天，检测不合适企业
		log "=== 扫描聊天 ==="
		set fl to "=== 扫描聊天 ==="
		do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
		set rcList to {}
		set rcFile to projectDir & "/rejected_companies.txt"
		try
			set rcContent to do shell script "cat " & quoted form of rcFile & " 2>/dev/null || echo ''"
			set AppleScript's text item delimiters to {return, linefeed}
			set rcLines to every text item of rcContent
			set AppleScript's text item delimiters to ""
			repeat with rcLine in rcLines
				set rl to rcLine as string
				if rl is not "" and first character of rl is not "#" then
					set rcList to rcList & {rl}
				end if
			end repeat
		end try
		set newRcCount to 0
		set URL of active tab of front window to "https://www.zhipin.com/web/geek/chat"
		delay 5
		-- 聊天页重新注入（从文件读取，避免AppleScript引号冲突）
		set chatJs to do shell script "cat " & quoted form of (projectDir & "/src/chat_scan_helpers.js")
		execute active tab of front window javascript "window.BossChat=window.BossChat||{}"
		execute active tab of front window javascript chatJs
		set pageNum to 0
		set newRcCount to 0
		set pageLastComp to ""
		set startIdx to 0
		
		-- 翻页循环（虚拟滚动：每次滚动后对比最后的公司名是否变化）
		repeat 20 times
			set cvCount to execute active tab of front window javascript "BossChat._getConvoCount()"
			if cvCount is "" or cvCount ≤ startIdx then exit repeat
			set pageNum to pageNum + 1
			log "--- 第" & pageNum & "页: 索引" & startIdx & "-" & (cvCount as integer - 1) & " ---"
			set startMsg to "--- 第" & pageNum & "页: " & cvCount & "个对话 ---"
			execute active tab of front window javascript "BossChat._addChatLog('" & startMsg & "')"
			
			repeat with cvi from startIdx to (cvCount as integer) - 1
				set cvCompany to execute active tab of front window javascript "BossChat._clickConvo(" & cvi & ")"
				delay 3
				set cvReject to execute active tab of front window javascript "BossChat._checkRejection()"
				if cvReject is "yes" then
					set alreadyInList to false
					repeat with rcl in rcList
						set rcl2 to rcl as string
						if cvCompany contains rcl2 or rcl2 contains cvCompany then
							set alreadyInList to true
							exit repeat
						end if
					end repeat
					if not alreadyInList then
						set rcList to rcList & {cvCompany}
						set newRcCount to newRcCount + 1
						set chatMsg to "[" & (cvi + 1) & "] ❌ " & cvCompany & " → 不合适"
						execute active tab of front window javascript "BossChat._addChatLog('" & chatMsg & "')"
						log "  ❌ 不合适企业: " & cvCompany
						set fl to "  ❌ 不合适企业: " & cvCompany
						do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
						do shell script "/bin/echo " & quoted form of cvCompany & " >> " & quoted form of rcFile
					end if
				else
					set chatMsg to "[" & (cvi + 1) & "] ✅ " & cvCompany & " → 正常"
					execute active tab of front window javascript "BossChat._addChatLog('" & chatMsg & "')"
				end if
			end repeat
			
			-- 翻页：滚动user-list-content加载更早的对话
			set startIdx to cvCount as integer
			execute active tab of front window javascript "BossChat._addChatLog('↕ 正在翻页...')"
			execute active tab of front window javascript "BossChat._scrollPage()"
			delay 3
			set lastComp to execute active tab of front window javascript "BossChat._getLastCompany()"
			if lastComp is pageLastComp then
				execute active tab of front window javascript "BossChat._addChatLog('✓ 没有更多对话了')"
				exit repeat
			end if
			set pageLastComp to lastComp
			set startIdx to 0
		end repeat
		
		set endMsg to "--- 扫描完成，共" & pageNum & "页，新发现不合格企业: " & newRcCount & " 家 ---"
		execute active tab of front window javascript "BossChat._addChatLog('" & endMsg & "')"
		log "新发现不合适企业: " & newRcCount & " 家"
		set fl to "新发现不合适企业: " & newRcCount & " 家"
		do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
		
		display dialog "✅ 完成" & return & "招呼:" & gc & " 外包:" & soc & " 做题:" & stc & " 不匹配:" & smc & return & "不合适企业:" & newRcCount & " 家" buttons {"确定"} default button 1
		
	end tell
end run
