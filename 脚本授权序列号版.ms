-- ========================================
-- 脚本时间+硬件授权添加系统 - 实时版 v2.7
-- 修复：使用 .NET 对话框实现真正的多文件选择
-- 新增：支持文件拖拽到列表
-- 优化：UI 布局调整
-- ========================================

global g_AuthListURL = "https://raw.githubusercontent.com/2779913057-beep/crispy-spork/main/授权列表.txt"

-- ========================================
-- 工具函数 (核心逻辑保持不变)
-- ========================================

fn getExpireDateByMonths months =
(
    local now = (dotNetClass "System.DateTime").Now
    now.AddMonths months
)

fn formatDateTime dt =
(
    try (dt.ToString "yyyy-MM-dd HH:mm:ss") catch ("时间格式错误")
)

fn encodeToBase64 s =
(
    try
    (
        local c = dotnetclass "System.Convert"
        local b = (dotnetclass "System.Text.Encoding").UTF8.GetBytes s
        c.ToBase64String b
    )
    catch ("")
)

fn readFileContent f =
(
    try
    (
        local fh = openFile f
        local t = ""
        if fh != undefined then
        (
            while not eof fh do t += readLine fh + "\n"
            close fh
            t
        )
    )
    catch (undefined)
)

fn saveFileContent f content =
(
    try
    (
        local io = dotnetclass "System.IO.File"
        local enc = dotnetclass "System.Text.Encoding"
        io.WriteAllText f content enc.UTF8
        true
    )
    catch (false)
)

-- ========================================
-- 获取硬盘序列号
-- ========================================
fn GetHardDiskSerial =
(
    local result = #()
    local tempFile = (GetDir #temp) + "\\disk_serial_" + (random 100000 999999) as string + ".txt"
    local psCommand = "powershell -NoProfile -ExecutionPolicy Bypass -Command \"Get-CimInstance -ClassName Win32_PhysicalMedia -ErrorAction SilentlyContinue | ForEach-Object {$_.SerialNumber}\" > \"" + tempFile + "\" 2>nul"
    
    HiddenDOSCommand psCommand
    
    local timeout = 30
    while timeout > 0 and not (doesFileExist tempFile) do (sleep 0.1; timeout -= 1)
    
    if doesFileExist tempFile then
    (
        try (
            local fs = openFile tempFile
            if fs != undefined then (
                while not eof fs do (
                    local line = trimLeft (trimRight (readLine fs))
                    if line != "" and line != " " do append result line
                )
                close fs
            )
        ) catch()
        try(deleteFile tempFile) catch()
    )
    
    if result.count > 0 then result[1] else ""
)

-- ========================================
-- 实时获取GitHub内容
-- ========================================
fn GetGitHubContentRealtime url =
(
    local randNum = random 100000000 999999999
    local cacheBypassURL = url + "?t=" + (randNum as string)
    
    try
    (
        local webClient = dotNetObject "System.Net.WebClient"
        webClient.Encoding = (dotNetClass "System.Text.Encoding").UTF8
        webClient.Headers.Add "User-Agent" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        webClient.Headers.Add "Cache-Control" "no-cache, no-store, must-revalidate"
        webClient.Headers.Add "Pragma" "no-cache"
        
        local content = webClient.DownloadString cacheBypassURL
        webClient.Dispose()
        
        return content
    )
    catch err
    (
        return undefined
    )
)

-- ========================================
-- 生成授权脚本
-- ========================================
fn generateAuthWrapperCN fileName base64Code expireDateTime authURL =
(
    local expStr = formatDateTime expireDateTime
    local encodedURL = encodeToBase64 authURL

    local t = ""
    t += "-- ========================================\n"
    t += "-- 授权脚本: " + fileName + "\n"
    t += "-- 有效期至: " + expStr + "\n"
    t += "-- ========================================\n\n"

    t += "fn GetHardDiskSerial =\n"
    t += "(\n"
    t += "    local result = #()\n"
    t += "    local tempFile = (GetDir #temp) + \"\\\\disk_serial_\" + (random 100000 999999) as string + \".txt\"\n"
    t += "    local psCommand = \"powershell -NoProfile -ExecutionPolicy Bypass -Command \\\"Get-CimInstance -ClassName Win32_PhysicalMedia -ErrorAction SilentlyContinue | ForEach-Object {$_.SerialNumber}\\\" > \\\"\" + tempFile + \"\\\" 2>nul\"\n"
    t += "    HiddenDOSCommand psCommand\n"
    t += "    local timeout = 30\n"
    t += "    while timeout > 0 and not (doesFileExist tempFile) do (sleep 0.1; timeout -= 1)\n"
    t += "    if doesFileExist tempFile then\n"
    t += "    (\n"
    t += "        try (\n"
    t += "            local fs = openFile tempFile\n"
    t += "            if fs != undefined then (\n"
    t += "                while not eof fs do (\n"
    t += "                    local line = trimLeft (trimRight (readLine fs))\n"
    t += "                    if line != \"\" and line != \" \" do append result line\n"
    t += "                )\n"
    t += "                close fs\n"
    t += "            )\n"
    t += "        ) catch()\n"
    t += "        try(deleteFile tempFile) catch()\n"
    t += "    )\n"
    t += "    if result.count > 0 then result[1] else \"\"\n"
    t += ")\n\n"

    t += "fn DecodeAuthURL =\n"
    t += "(\n"
    t += "    try\n"
    t += "    (\n"
    t += "        local encoded = \"" + encodedURL + "\"\n"
    t += "        local bytes = (dotNetClass \"System.Convert\").FromBase64String encoded\n"
    t += "        (dotNetClass \"System.Text.Encoding\").UTF8.GetString bytes\n"
    t += "    )\n"
    t += "    catch (undefined)\n"
    t += ")\n\n"

    t += "fn GetAuthorizationList =\n"
    t += "(\n"
    t += "    local baseURL = DecodeAuthURL()\n"
    t += "    if baseURL == undefined then return undefined\n"
    t += "    local randNum = random 100000000 999999999\n"
    t += "    local url = baseURL + \"?t=\" + (randNum as string)\n"
    t += "    try\n"
    t += "    (\n"
    t += "        local webClient = dotNetObject \"System.Net.WebClient\"\n"
    t += "        webClient.Encoding = (dotNetClass \"System.Text.Encoding\").UTF8\n"
    t += "        webClient.Headers.Add \"User-Agent\" \"Mozilla/5.0\"\n"
    t += "        webClient.Headers.Add \"Cache-Control\" \"no-cache\"\n"
    t += "        webClient.Headers.Add \"Pragma\" \"no-cache\"\n"
    t += "        local content = webClient.DownloadString url\n"
    t += "        webClient.Dispose()\n"
    t += "        return content\n"
    t += "    )\n"
    t += "    catch (return undefined)\n"
    t += ")\n\n"

    t += "fn VerifyHardDiskAuth =\n"
    t += "(\n"
    t += "    local localSerial = GetHardDiskSerial()\n"
    t += "    if localSerial == \"\" then\n"
    t += "    (\n"
    t += "        messageBox \"无法获取硬盘序列号\" title:\"授权验证失败\"\n"
    t += "        return false\n"
    t += "    )\n"
    t += "    local authList = GetAuthorizationList()\n"
    t += "    if authList == undefined then\n"
    t += "    (\n"
    t += "        messageBox \"无法获取授权列表，请检查网络\" title:\"授权验证失败\"\n"
    t += "        return false\n"
    t += "    )\n"
    t += "    local lines = filterString authList \"\\n\"\n"
    t += "    for line in lines do\n"
    t += "    (\n"
    t += "        local clean = trimLeft (trimRight line)\n"
    t += "        if clean != \"\" and (clean == localSerial or (stricmp clean localSerial == 0)) then\n"
    t += "            return true\n"
    t += "    )\n"
    t += "    messageBox (\"此设备未获授权\\n\\n序列号: \" + localSerial) title:\"授权验证失败\"\n"
    t += "    return false\n"
    t += ")\n\n"

    t += "fn getWebTime =\n"
    t += "(\n"
    t += "    try\n"
    t += "    (\n"
    t += "        local req = (dotNetClass \"System.Net.WebRequest\").Create \"https://www.baidu.com\"\n"
    t += "        req.Method = \"HEAD\"\n"
    t += "        req.Timeout = 5000\n"
    t += "        local resp = req.GetResponse()\n"
    t += "        local h = resp.GetResponseHeader \"Date\"\n"
    t += "        resp.Close()\n"
    t += "        if h != undefined and h != \"\" then\n"
    t += "            return ((dotNetClass \"System.DateTime\").Parse h).ToLocalTime()\n"
    t += "        return undefined\n"
    t += "    )\n"
    t += "    catch\n"
    t += "    (\n"
    t += "        messageBox \"网络连接失败\" title:\"错误\"\n"
    t += "        return undefined\n"
    t += "    )\n"
    t += ")\n\n"

    t += "fn verifyAuthAndRun =\n"
    t += "(\n"
    t += "    if not VerifyHardDiskAuth() then return()\n"
    t += "    \n"
    t += "    local nowT = getWebTime()\n"
    t += "    if nowT == undefined then return()\n"
    t += "    local expT = (dotNetClass \"System.DateTime\").ParseExact \"" + expStr + "\" \"yyyy-MM-dd HH:mm:ss\" undefined\n"
    t += "    if (expT.CompareTo nowT) < 0 then\n"
    t += "    (\n"
    t += "        messageBox \"授权已过期!\" title:\"授权过期\"\n"
    t += "        return()\n"
    t += "    )\n"
    t += "    \n"
    t += "    try\n"
    t += "    (\n"
    t += "        local bytes = (dotNetClass \"System.Convert\").FromBase64String \"" + base64Code + "\"\n"
    t += "        local code = (dotNetClass \"System.Text.Encoding\").UTF8.GetString bytes\n"
    t += "        execute code\n"
    t += "    )\n"
    t += "    catch (messageBox \"脚本解码失败\" title:\"错误\")\n"
    t += ")\n\n"
    t += "verifyAuthAndRun()\n"

    t
)

-- ========================================
-- Rollout UI - 批量处理版
-- ========================================
try(destroyDialog authWrapperCNRollout) catch()

rollout authWrapperCNRollout "脚本授权添加器 v2.7 (批量加强版)" width:380 height:540
(
    -- 界面变量
    local scriptFiles = #()
    local expireDateTime = undefined
    local outputFolder = ""

    group "1. 脚本列表 (支持多选/拖拽)"
    (
        dotNetControl scriptListBox "System.Windows.Forms.ListBox" width:350 height:140
        button addScriptsBtn "添加脚本文件..." width:170 height:26 across:2 align:#left
        button removeSelectedBtn "移除选中项" width:170 height:26 align:#right
        button clearAllBtn "清空所有" width:350 height:20
    )
    
    group "2. 授权配置"
    (
        label lbl_url "授权列表URL (TXT格式):" align:#left
        edittext authURLEdit "" fieldWidth:345 height:20
        
        label lbl_time "授权时长:" align:#left across:3
        spinner monthsSpinner "月:" range:[0,120,1] type:#integer fieldWidth:40 offset:[15,0]
        spinner daysSpinner "天:" range:[0,365,0] type:#integer fieldWidth:40 offset:[-20,0]
        
        label expireLabel "截止日期: ----" align:#left style_sunkenedge:true width:345 height:18
        
        checkbox manualDateChk "手动指定日期" checked:false align:#left
        edittext manualDateInput "" fieldWidth:345 enabled:false text:"2025-12-31 23:59:59"
    )
    
    group "3. 输出设置"
    (
        radiobuttons outputMode labels:#("保存到原文件夹 (文件名+_授权版)", "指定输出文件夹") columns:1 align:#left
        edittext outputFolderEdit "" fieldWidth:290 across:2 enabled:false
        button selectOutputFolderBtn "..." width:40 height:20 enabled:false
    )
    
    group "4. 执行生成"
    (
        button wrapScriptBtn "开始批量生成" width:350 height:35
        progressbar wrapProgress value:0 width:350 height:10
        label statusLabel "准备就绪" align:#left
    )
    
    button testAuthBtn "🛠 测试本机授权状态" width:350 height:26
    
    -- ========================================
    -- UI 逻辑函数
    -- ========================================
    
    fn updateExpireLabel =
    (
        if expireDateTime != undefined then
            expireLabel.text = " 截止: " + (formatDateTime expireDateTime)
    )
    
    fn calcDateFromSpinners = 
    (
        local now = (dotNetClass "System.DateTime").Now
        expireDateTime = (now.AddMonths monthsSpinner.value).AddDays daysSpinner.value
        updateExpireLabel()
        manualDateInput.text = formatDateTime expireDateTime
    )
    
    fn updateListBox =
    (
        scriptListBox.Items.Clear()
        for f in scriptFiles do
        (
            scriptListBox.Items.Add (getFilenameFile f)
        )
        statusLabel.text = "列表文件数: " + (scriptFiles.count as string)
    )

    -- ========================================
    -- 事件处理
    -- ========================================

    on authWrapperCNRollout open do
    (
        calcDateFromSpinners()
        authURLEdit.text = g_AuthListURL
        
        -- 设置 ListBox 属性
        scriptListBox.SelectionMode = (dotNetClass "System.Windows.Forms.SelectionMode").MultiExtended
        scriptListBox.HorizontalScrollbar = true
        scriptListBox.AllowDrop = true -- 启用拖拽
    )
    
    -- 处理拖拽事件
    on scriptListBox DragEnter e do
    (
        if e.Data.GetDataPresent (dotNetClass "System.Windows.Forms.DataFormats").FileDrop then
            e.Effect = (dotNetClass "System.Windows.Forms.DragDropEffects").Copy
        else
            e.Effect = (dotNetClass "System.Windows.Forms.DragDropEffects").None
    )
    
    on scriptListBox DragDrop e do
    (
        local droppedFiles = e.Data.GetData (dotNetClass "System.Windows.Forms.DataFormats").FileDrop
        if droppedFiles != undefined then
        (
            for f in droppedFiles do
            (
                -- 简单的后缀名检查
                if (toLower (getFilenameType f)) == ".ms" then
                (
                    local exists = false
                    for sf in scriptFiles do (if sf == f then (exists = true; exit))
                    if not exists then append scriptFiles f
                )
            )
            updateListBox()
        )
    )

    on addScriptsBtn pressed do
    (
        -- === 核心修改：使用 .NET OpenFileDialog 实现真正的多选 ===
        local dlg = dotNetObject "System.Windows.Forms.OpenFileDialog"
        dlg.Title = "选择脚本文件 (按住 Ctrl/Shift 可多选)"
        dlg.Multiselect = true
        dlg.Filter = "MAXScript (*.ms)|*.ms|所有文件 (*.*)|*.*"
        
        local result = dlg.ShowDialog()
        if result.Equals (dotNetClass "System.Windows.Forms.DialogResult").OK then
        (
            local files = dlg.FileNames
            for f in files do
            (
                local exists = false
                for sf in scriptFiles do (if sf == f then (exists = true; exit))
                if not exists then append scriptFiles f
            )
            updateListBox()
        )
    )
    
    on removeSelectedBtn pressed do
    (
        local selectedIndices = scriptListBox.SelectedIndices
        if selectedIndices.Count > 0 then
        (
            local toRemove = #()
            -- 倒序收集索引，避免删除时索引错位
            for i = selectedIndices.Count - 1 to 0 by -1 do
                append toRemove (selectedIndices.Item[i] + 1) -- max 数组从1开始
            
            -- 对Max数组进行删除操作
            -- 这里使用一个小技巧：复制一份新的列表，排除掉要删除的
            local newFiles = #()
            for i = 1 to scriptFiles.count do
            (
                if (findItem toRemove i) == 0 then append newFiles scriptFiles[i]
            )
            scriptFiles = newFiles
            updateListBox()
        )
    )
    
    on clearAllBtn pressed do
    (
        scriptFiles = #()
        updateListBox()
    )
    
    on monthsSpinner changed val do if not manualDateChk.checked then calcDateFromSpinners()
    on daysSpinner changed val do if not manualDateChk.checked then calcDateFromSpinners()
    
    on manualDateChk changed state do
    (
        manualDateInput.enabled = state
        monthsSpinner.enabled = not state
        daysSpinner.enabled = not state
        
        if not state then calcDateFromSpinners() -- 切回自动时重新计算
    )
    
    on manualDateInput entered txt do
    (
        if manualDateChk.checked and txt != "" then
        (
            try 
            (
                expireDateTime = (dotNetClass "System.DateTime").ParseExact txt "yyyy-MM-dd HH:mm:ss" undefined
                updateExpireLabel()
            )
            catch 
            (
                messageBox "日期格式错误!\n\n正确格式: 2025-12-31 23:59:59" title:"错误"
            )
        )
    )
    
    on outputMode changed state do
    (
        local useCustomFolder = (state == 2)
        outputFolderEdit.enabled = useCustomFolder
        selectOutputFolderBtn.enabled = useCustomFolder
    )
    
    on selectOutputFolderBtn pressed do
    (
        local folder = getSavePath caption:"选择输出文件夹"
        if folder != undefined then
        (
            outputFolder = folder
            outputFolderEdit.text = folder
        )
    )

    on wrapScriptBtn pressed do
    (
        if scriptFiles.count == 0 then (messageBox "列表为空，请先添加脚本文件" title:"提示"; return())
        if authURLEdit.text == "" then (messageBox "请设置授权URL" title:"提示"; return())
        
        -- 如果是手动模式，确保时间解析了
        if manualDateChk.checked then
        (
             try (expireDateTime = (dotNetClass "System.DateTime").ParseExact manualDateInput.text "yyyy-MM-dd HH:mm:ss" undefined)
             catch (messageBox "手动日期格式无效" title:"错误"; return())
        )
        
        if outputMode.state == 2 and outputFolderEdit.text == "" then
        (
            messageBox "请选择输出文件夹" title:"提示"
            return()
        )
        
        local successCount = 0
        local failCount = 0
        local totalCount = scriptFiles.count
        
        wrapProgress.value = 0
        
        for i = 1 to totalCount do
        (
            local scriptPath = scriptFiles[i]
            local fname = getFilenameFile scriptPath
            
            statusLabel.text = "正在处理: " + fname
            
            local code = readFileContent scriptPath
            if code == undefined then
            (
                failCount += 1
                format "Read Error: %\n" scriptPath
            )
            else
            (
                local b64 = encodeToBase64 code
                local wrapped = generateAuthWrapperCN fname b64 expireDateTime authURLEdit.text
                
                local outPath = ""
                if outputMode.state == 1 then
                    outPath = (getFilenamePath scriptPath) + fname + "_授权版.ms"
                else
                    outPath = outputFolderEdit.text + "\\" + fname + "_授权版.ms"
                
                if saveFileContent outPath wrapped then
                    successCount += 1
                else
                    failCount += 1
            )
            
            wrapProgress.value = (i as float / totalCount * 100) as integer
        )
        
        wrapProgress.value = 100
        statusLabel.text = "全部完成"
        
        messageBox ("处理完成!\n\n成功: " + successCount as string + "\n失败: " + failCount as string) title:"结果"
    )
    
    on testAuthBtn pressed do
    (
        if authURLEdit.text == "" then (messageBox "请先填写授权URL"; return())
        
        local serial = GetHardDiskSerial()
        local content = GetGitHubContentRealtime authURLEdit.text
        
        if content != undefined then
        (
            local lines = filterString content "\n"
            local found = false
            
            for line in lines do
            (
                local clean = trimLeft (trimRight line)
                if clean == serial or (stricmp clean serial == 0) then (found = true; exit)
            )
            
            local status = if found then "✅ 已授权" else "❌ 未授权"
            messageBox ("硬盘序列号: " + serial + "\n\n状态: " + status) title:"授权测试"
        )
        else
        (
            messageBox "无法连接到授权列表 URL，请检查网络或地址。" title:"连接错误"
        )
    )
)

createDialog authWrapperCNRollout