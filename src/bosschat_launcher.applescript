-- BossChat 启动器 — 选择浏览器后执行对应版本
set projectDir to do shell script "dirname \"$(dirname '" & POSIX path of (path to me) & "')\""

display dialog "选择浏览器:" buttons {"Chrome (推荐)", "Safari", "取消"} default button 1 with title "BossChat"
set btn to button returned of result

if btn is "Chrome (推荐)" then
	do shell script "osascript " & quoted form of (projectDir & "/src/bosschat_final_v3.applescript") & " &"
else if btn is "Safari" then
	display dialog "Safari 使用前要求:" & return & return & "1. Safari > 设置 > 高级 > 勾选 [开发菜单]" & return & "2. 开发 > 允许Apple事件中的JavaScript" & return & return & "确认已启用?" buttons {"取消", "已启用"} default button 2
	if button returned of result is "已启用" then
		do shell script "osascript " & quoted form of (projectDir & "/src/bosschat_safari.applescript") & " &"
	end if
end if
