if (frontApp = "Safari") or (frontApp = "Webkit") then
    using terms from application "Safari"
        tell application frontApp to set currentTabUrl to URL of front document
        tell application frontApp to set currentTabTitle to name of front document
    end using terms from
    else if (frontApp = "Google Chrome") or (frontApp = "Google Chrome Canary") or (frontApp = "Chromium") then
    using terms from application "Google Chrome"
        tell application frontApp to set currentTabUrl to URL of active tab of front window
        tell application frontApp to set currentTabTitle to title of active tab of front window
    end using terms from
    else
    return "You need a supported browser as your frontmost app"
end if

return currentTabUrl & "\n" & currentTabTitle
