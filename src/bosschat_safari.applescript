-- BossChat 最终版
on run
	-- 动态获取项目目录（根据脚本自身路径）
	set scriptPath to POSIX path of (path to me)
	set projectDir to do shell script "dirname \"$(dirname '" & scriptPath & "')\""
	
	tell application "Safari"
		activate
		
		-- 设置日志文件
		set logFile to projectDir & "/run_log.txt"
		do shell script "/bin/echo \"=== BossChat Run ===\" > " & quoted form of logFile
		
		-- 检查/获取简历（新标签页打开，不干扰当前页）
		set rh to do JavaScript "localStorage.getItem('bosschat_resume')?'ok':'new';" in document of front window
				if rh is "new" then
					set savedUrl to do JavaScript "window.location.href" in document of front window
					set URL of current tab of front window to "https://www.zhipin.com/web/geek/resume"
					delay 5
					set rx to do JavaScript "var r={name:'',experience_years:10,education:'本科',skills:[],kw:[]};var pt=document.body.textContent||'';if(pt.indexOf('博士')>=0)r.education='博士';else if(pt.indexOf('硕士')>=0)r.education='硕士';else if(pt.indexOf('本科')>=0)r.education='本科';var ps=document.querySelector('.resume-professional-skill');if(ps){var t=ps.textContent||'';var p=t.split(/[,，、]/);for(var i=0;i<p.length;i++){var s=p[i].trim();var ci=s.indexOf('：');if(ci>=0)s=s.substring(ci+1);ci=s.indexOf(':');if(ci>=0)s=s.substring(ci+1);if(s.length>1&&s.length<30&&s!='编辑删除'&&s!='专业技能')r.skills.push(s)}}var ak='LLM,AI Agent,RAG,Prompt,SEO,GEO,数字人,AIGC,大模型,知识库,智能体,Agent,虚拟空间,元宇宙,工作流,对话,政务,司法,流量,内容管理,数据产品,B端产品,C端产品,G端产品,产品设计,数据分析,搜索引擎优化,生成式引擎优化,AI助手,模型对话,Prompt Engineering'.split(',');for(var i=0;i<ak.length;i++){if(pt.indexOf(ak[i])>=0&&r.skills.indexOf(ak[i])<0)r.skills.push(ak[i])}localStorage.setItem('bosschat_resume',JSON.stringify(r));" in document of front window
					set URL of current tab of front window to savedUrl
					delay 3
				end if
		
		-- 检查搜索结果
		set rc to do JavaScript "document.querySelectorAll('li.job-card-box').length+'';" in document of front window
		if rc is "0" or rc is "" then
			display dialog "请先在 Boss直聘设好筛选条件" buttons {"知道了"} default button 1
			return
		end if
		
		-- 确认
		set qc to do JavaScript "var d=new Date().toDateString();var s=localStorage.getItem('qdate')||'';var c=parseInt(localStorage.getItem('qcount')||'0');if(s!==d){localStorage.setItem('qdate',d);localStorage.setItem('qcount','0');c=0}(150-c)+'';" in document of front window
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
		
		-- 已投递企业名单（本地文件）
		set greetedFile to projectDir & "/greeted_companies.txt"
		set greetedList to {}
		try
			set greetedContent to do shell script "cat " & quoted form of greetedFile & " 2>/dev/null || echo ''"
			set AppleScript's text item delimiters to {return, linefeed}
			set greetedLines to every text item of greetedContent
			set AppleScript's text item delimiters to ""
			repeat with gLine in greetedLines
				set gl to gLine as string
				if gl is not "" then set greetedList to greetedList & {gl}
			end repeat
			log "已投递记录: " & (count of greetedList) & " 条"
		end try
		
		-- 注入引擎（从文件读取，避免Safari字符串长度限制）
		set engineJs to do shell script "cat " & quoted form of (projectDir & "/src/bosschat_engine.js")
		do JavaScript engineJs in document of front window
		set r0 to do JavaScript "window.BossChat?'ok':'fail';" in document of front window
		log "引擎: " & r0
		
				-- 主循环（含翻页）
				set ptc to 0
				set searchUrl to do JavaScript "window.location.href" in document of front window
				-- 续断进度
				set progressFile to projectDir & "/progress.txt"
				set resumeIdx to 0
				try
					set progressData to do shell script "cat " & quoted form of progressFile & " 2>/dev/null || echo ''"
					set AppleScript's text item delimiters to "|"
					set savedUrl to text item 1 of progressData
					set savedIdx to text item 2 of progressData
					set AppleScript's text item delimiters to ""
					if savedUrl is not "" and savedUrl is searchUrl and savedIdx as integer > 0 then
						set resumeIdx to savedIdx as integer
						log "检测到上次进度: 已处理 " & resumeIdx & " 个"
					else
						set resumeIdx to 0
					end if
				end try
				if resumeIdx > 0 then
					display dialog "检测到上次进度(" & resumeIdx & "个已处理)" & return & "继续?" buttons {"重新开始", "继续"} default button 2
					if button returned of result is "继续" then
						set ptc to resumeIdx
						set tc to resumeIdx
					else
						set resumeIdx to 0
					end if
				end if
				repeat
					set sti to ptc
					set ptc to tc
					repeat with i from sti + 1 to ptc
						-- 安全检查：确认仍在搜索页，不在则强制定位回去
						set currentUrl to do JavaScript "window.location.href" in document of front window
						set hasCards to do JavaScript "document.querySelectorAll('li.job-card-box').length+''" in document of front window
						if currentUrl contains "/chat" or (hasCards is "0") then
							log "  ⚠ 不在搜索页，正在返回..."
							set fl to "  ⚠ 不在搜索页，正在返回..."
							do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
							do JavaScript "window.location.href='" & searchUrl & "'" in document of front window
							delay 4
							-- 重新获取卡片数
							set rc to do JavaScript "document.querySelectorAll('li.job-card-box').length+''" in document of front window
							if rc is "0" or rc is "" then exit repeat
							set tc to rc as integer
						end if
				set idx to i - 1
				
				-- 重新注入引擎（从文件读取）
				do JavaScript engineJs in document of front window
				
				-- 配额
				set qc to do JavaScript "BossChat.qt();" in document of front window
				if qc ≤ 0 then exit repeat
				
				-- 卡片
				set ci to do JavaScript "BossChat.gc(" & idx & ");" in document of front window
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
					do JavaScript "BossChat._addLog('" & fl & "')" in document of front window
				else
					log "[" & i & "/" & ptc & "] " & ct & " @ " & cc
					set fl to "[" & i & "/" & ptc & "] " & ct & " @ " & cc
					do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
					do JavaScript "BossChat._addLog('" & fl & "')" in document of front window
					
					-- 点击卡片刷新右侧面板
					do JavaScript "var cards=document.querySelectorAll('li.job-card-box');if(cards[" & idx & "]){cards[" & idx & "].querySelector('a.job-name').click();}" in document of front window
					delay 3
					
					-- 外包检测
					set os to do JavaScript "BossChat.os();" in document of front window
					if os is not "" then
						set soc to soc + 1
						log "  ⏭ 外包(" & os & ")"
						set fl to "  ⏭ 外包(" & os & ")"
						do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
						do JavaScript "BossChat._addLog('" & fl & "')" in document of front window
					else
						-- 活跃检测
						set ac to do JavaScript "BossChat.ac();" in document of front window
						if ac is "no" then
							set smc to smc + 1
							log "  ⏭ 不活跃"
							set fl to "  ⏭ 不活跃"
							do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
							do JavaScript "BossChat._addLog('" & fl & "')" in document of front window
						else
														-- 已投递检查（本地文件）
														set gh to "false"
														repeat with gItem in greetedList
															set gi to gItem as string
															if cc is not "" and (gi contains cc or gi contains ch) then
																set gh to "true"
																exit repeat
															end if
														end repeat
														if gh is "true" then
								set smc to smc + 1
								log "  ⏭ 已投递过"
								set fl to "  ⏭ 已投递过"
								do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
								do JavaScript "BossChat._addLog('" & fl & "')" in document of front window
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
									do JavaScript "BossChat._addLog('" & fl & "')" in document of front window
									else
																		-- AI匹配评分（本地TF-IDF语义匹配）
																		set resumeJson to do JavaScript "localStorage.getItem('bosschat_resume')||'{}'" in document of front window
																		set jdText to do JavaScript "var el=document.querySelector('.job-detail-body')||document.querySelector('.job-sec-text');el?el.textContent.substring(0,3000):''" in document of front window
																		-- 写入临时文件避免shell转义问题
																		do shell script "echo " & quoted form of resumeJson & " > /tmp/bc_resume.json"
																		do shell script "echo " & quoted form of jdText & " > /tmp/bc_jd.txt"
																		set md to do shell script "cat /tmp/bc_jd.txt | python3 -c \"import json,sys; r=json.load(open('/tmp/bc_resume.json')); j=sys.stdin.read(); print(json.dumps({'resume':r,'jd_text':j}))\" | python3 " & projectDir & "/src/ai_match_stdin.py"
									if md is "" then set md to "0|0|0|0|0|不限|AI失败"
									set AppleScript's text item delimiters to "|"
									set mt to text item 1 of md
									set ms to text item 2 of md
									set mev to text item 3 of md
									set mf to text item 4 of md
									set mr to text item 5 of md
									set med to text item 6 of md
									set AppleScript's text item delimiters to ""
									
									try
										log "  ✅ " & mt & "分(" & ms & "+" & mev & "+" & mf & ") 要求" & mr & "年/" & med
										set fl to "  ✅ " & mt & "分(" & ms & "+" & mev & "+" & mf & ") 要求" & mr & "年/" & med
										do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
										do JavaScript "BossChat._addLog('" & fl & "')" in document of front window
																														try
																																		-- 保存当前URL
																																		set su to do JavaScript "window.location.href" in document of front window
																																		-- 点击"立即沟通"
																																		set hb to do JavaScript "BossChat.cb();" in document of front window
																																		delay 3
																																		-- 关键修复：不论 cb() 返回什么，都检查是否跳转到了聊天页
																																		-- （cb() 触发页面跳转后 JS 上下文被销毁，返回值可能丢失）
																																		set cu to do JavaScript "window.location.href" in document of front window
																																		if cu is not equal to su and (cu contains "/chat/" or cu contains "/web/geek/chat") then
																																			log "  ⏭ 已投递过(跳转聊天页)"
																																			set fl to "  ⏭ 已投递过(跳转聊天页)"
																																			do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
																																			do JavaScript "BossChat._addLog('" & fl & "')" in document of front window
																																													-- 标记已投递（本地文件）
																																													if cc is not "" then
																																														set greetedList to greetedList & (cc & "|" & ch)
																																														do shell script "/bin/echo " & quoted form of (cc & "|" & ch) & " >> " & quoted form of greetedFile
																																													end if
																																													do JavaScript "window.location.href='" & searchUrl & "'" in document of front window
																																			delay 3
																																		else if hb is "yes" then
																																			delay 1
																																			do JavaScript "BossChat.sb();BossChat.uq();" in document of front window
																																			delay 1
																																			do JavaScript "BossChat._closePopup();" in document of front window
																																			set gc to gc + 1
																																			log "    ✅ 已打招呼"
																																			set fl to "    ✅ 已打招呼"
																																			do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
																																			do JavaScript "BossChat._addLog('" & fl & "')" in document of front window
																																													-- 标记已投递（本地文件）
																																													if cc is not "" then
																																														set greetedList to greetedList & (cc & "|" & ch)
																																														do shell script "/bin/echo " & quoted form of (cc & "|" & ch) & " >> " & quoted form of greetedFile
																																													end if
																																												end if
																																												end try
																																												end try
																																												end if
																																												end if
																																												end if
																																												end if
																																												end if
																																												end repeat
			
						-- 滚动加载更多
						-- 刷新搜索URL（页数变化等情况）
						set searchUrl to do JavaScript "window.location.href" in document of front window
						do JavaScript "BossChat._scrollToLoad();" in document of front window
						delay 3
						set rc to do JavaScript "document.querySelectorAll('li.job-card-box').length+'';" in document of front window
						if rc as integer ≤ ptc then exit repeat
						set tc to rc as integer
						-- 保存续断进度
						do shell script "/bin/echo " & quoted form of (searchUrl & "|" & ptc) & " > " & quoted form of progressFile
			
			-- 检查配额
			set qc to do JavaScript "BossChat.qt();" in document of front window
			if qc ≤ 0 then exit repeat
			
		end repeat
		
		log ""
		log "=== BossChat 完成 ==="
		log "招呼:" & gc & " 外包:" & soc & " 做题:" & stc & " 不匹配:" & smc
		set fl to "--- 完成 ---"
		do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
		do JavaScript "BossChat._addLog('" & fl & "')" in document of front window
		set fl2 to "招呼:" & gc & " 外包:" & soc & " 做题:" & stc & " 不匹配:" & smc
		do shell script "/bin/echo " & quoted form of fl2 & " >> " & quoted form of logFile
		do JavaScript "BossChat._addLog('" & fl2 & "')" in document of front window
		do shell script "/bin/echo === End === >> " & quoted form of logFile
		do JavaScript "BossChat._addLog('=== End ===')" in document of front window
		
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
		set URL of current tab of front window to "https://www.zhipin.com/web/geek/chat"
		delay 5
		-- 聊天页重新注入（从文件读取，避免AppleScript引号冲突）
		set chatJs to do shell script "cat " & quoted form of (projectDir & "/src/chat_scan_helpers.js")
		do JavaScript "window.BossChat=window.BossChat||{}" in document of front window
		do JavaScript chatJs in document of front window
		set pageNum to 0
		set newRcCount to 0
		set pageLastComp to ""
		set startIdx to 0
		
		-- 翻页循环（虚拟滚动：每次滚动后对比最后的公司名是否变化）
		repeat 20 times
			set cvCount to do JavaScript "BossChat._getConvoCount()" in document of front window
			if cvCount is "" or cvCount ≤ startIdx then exit repeat
			set pageNum to pageNum + 1
			log "--- 第" & pageNum & "页: 索引" & startIdx & "-" & (cvCount as integer - 1) & " ---"
			set startMsg to "--- 第" & pageNum & "页: " & cvCount & "个对话 ---"
			do JavaScript "BossChat._addChatLog('" & startMsg & "')" in document of front window
			
			repeat with cvi from startIdx to (cvCount as integer) - 1
				set cvCompany to do JavaScript "BossChat._clickConvo(" & cvi & ")" in document of front window
				delay 3
				set cvReject to do JavaScript "BossChat._checkRejection()" in document of front window
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
						do JavaScript "BossChat._addChatLog('" & chatMsg & "')" in document of front window
						log "  ❌ 不合适企业: " & cvCompany
						set fl to "  ❌ 不合适企业: " & cvCompany
						do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
						do shell script "/bin/echo " & quoted form of cvCompany & " >> " & quoted form of rcFile
					end if
				else
					set chatMsg to "[" & (cvi + 1) & "] ✅ " & cvCompany & " → 正常"
					do JavaScript "BossChat._addChatLog('" & chatMsg & "')" in document of front window
				end if
			end repeat
			
			-- 翻页：滚动user-list-content加载更早的对话
			set startIdx to cvCount as integer
			do JavaScript "BossChat._addChatLog('↕ 正在翻页...')" in document of front window
			do JavaScript "BossChat._scrollPage()" in document of front window
			delay 3
			set lastComp to do JavaScript "BossChat._getLastCompany()" in document of front window
			if lastComp is pageLastComp then
				do JavaScript "BossChat._addChatLog('✓ 没有更多对话了')" in document of front window
				exit repeat
			end if
			set pageLastComp to lastComp
			set startIdx to 0
		end repeat
		
		set endMsg to "--- 扫描完成，共" & pageNum & "页，新发现不合格企业: " & newRcCount & " 家 ---"
		do JavaScript "BossChat._addChatLog('" & endMsg & "')" in document of front window
		log "新发现不合适企业: " & newRcCount & " 家"
		set fl to "新发现不合适企业: " & newRcCount & " 家"
		do shell script "/bin/echo " & quoted form of fl & " >> " & quoted form of logFile
		
		display dialog "✅ 完成" & return & "招呼:" & gc & " 外包:" & soc & " 做题:" & stc & " 不匹配:" & smc & return & "不合适企业:" & newRcCount & " 家" buttons {"确定"} default button 1
		
	end tell
end run
