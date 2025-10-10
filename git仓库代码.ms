-- GitHub文件管理器（稳定版 - 使用插入换行按钮）

-- GitHub API管理器结构体（保持不变）
struct GitHubAPIManager
(
    token = "",
    username = "",
    repo = "",
    baseURL = "https://api.github.com",
    
    fn sendRequest url method:"GET" data:"" =
    (
        print ("========== HTTP请求 ==========")
        print ("URL: " + url)
        print ("方法: " + method)
        if data != "" then
        (
            print ("数据长度: " + (data.count as string) + " 字符")
        )
        
        local request = dotNetObject "System.Net.WebClient"
        request.Headers.Add "Authorization" ("token " + token)
        request.Headers.Add "Accept" "application/vnd.github.v3+json"
        request.Headers.Add "User-Agent" "3dsMax-Client"
        request.Encoding = (dotNetClass "System.Text.Encoding").UTF8
        
        local result = ""
        try
        (
            case method of
            (
                "GET": result = request.DownloadString url
                "PUT": (
                    request.Headers.Add "Content-Type" "application/json"
                    result = request.UploadString url "PUT" data
                )
                "POST": (
                    request.Headers.Add "Content-Type" "application/json"
                    result = request.UploadString url data
                )
                "DELETE": (
                    request.Headers.Add "Content-Type" "application/json"
                    result = request.UploadString url "DELETE" data
                )
            )
            print ("响应成功，长度: " + (result.count as string) + " 字符")
        )
        catch
        (
            local errorMsg = getCurrentException()
            print ("!!! HTTP请求错误: " + errorMsg)
            result = undefined
        )
        
        request.Dispose()
        print ("========== 请求结束 ==========\n")
        return result
    ),
    
    fn getRepoContents path:"" =
    (
        print "\n>>> 获取仓库内容..."
        local url = baseURL + "/repos/" + username + "/" + repo + "/contents/" + path
        sendRequest url
    ),
    
    fn createOrUpdateFile filePath content commitMessage =
    (
        print ("\n>>> 创建/更新文件: " + filePath)
        
        local url = baseURL + "/repos/" + username + "/" + repo + "/contents/" + filePath
        print "检查文件是否已存在..."
        local existingFile = sendRequest url
        local sha = ""
        
        if existingFile != undefined then
        (
            local shaStart = findString existingFile "\"sha\":\""
            if shaStart != undefined then
            (
                shaStart += 7
                local subStr = substring existingFile shaStart (existingFile.count - shaStart + 1)
                local shaEnd = findString subStr "\""
                if shaEnd != undefined then
                (
                    sha = substring existingFile shaStart (shaEnd - 1)
                    print ("找到现有文件SHA: " + sha)
                )
            )
        )
        
        if content == "" then content = " "
        
        try
        (
            local bytes = (dotNetClass "System.Text.Encoding").UTF8.GetBytes content
            local base64 = (dotNetClass "System.Convert").ToBase64String bytes
            
            local jsonData = "{"
            jsonData += "\"message\":\"" + commitMessage + "\","
            jsonData += "\"content\":\"" + base64 + "\""
            if sha != "" then
            (
                jsonData += ",\"sha\":\"" + sha + "\""
            )
            jsonData += "}"
            
            local result = sendRequest url method:"PUT" data:jsonData
            
            if result != undefined then
            (
                print ">>> 文件操作成功!"
            )
            
            return result
        )
        catch
        (
            print ("!!! 编码过程出错: " + getCurrentException())
            return undefined
        )
    ),
    
    fn getFileContent filePath =
    (
        print ("\n>>> 读取文件: " + filePath)
        local url = baseURL + "/repos/" + username + "/" + repo + "/contents/" + filePath
        local response = sendRequest url
        
        if response != undefined then
        (
            local contentStart = findString response "\"content\":\""
            if contentStart != undefined then
            (
                contentStart += 11
                local subStr = substring response contentStart (response.count - contentStart + 1)
                local contentEnd = findString subStr "\""
                if contentEnd != undefined then
                (
                    local base64Content = substring response contentStart (contentEnd - 1)
                    base64Content = substituteString base64Content "\\n" ""
                    
                    try
                    (
                        local bytes = (dotNetClass "System.Convert").FromBase64String base64Content
                        local decodedContent = (dotNetClass "System.Text.Encoding").UTF8.GetString bytes
                        return decodedContent
                    )
                    catch
                    (
                        return ""
                    )
                )
            )
        )
        return ""
    ),
    
    fn deleteFile filePath commitMessage =
    (
        print ("\n>>> 删除文件: " + filePath)
        
        local url = baseURL + "/repos/" + username + "/" + repo + "/contents/" + filePath
        local fileInfo = sendRequest url
        
        if fileInfo != undefined then
        (
            local shaStart = findString fileInfo "\"sha\":\""
            if shaStart != undefined then
            (
                shaStart += 7
                local subStr = substring fileInfo shaStart (fileInfo.count - shaStart + 1)
                local shaEnd = findString subStr "\""
                if shaEnd != undefined then
                (
                    local sha = substring fileInfo shaStart (shaEnd - 1)
                    
                    local jsonData = "{"
                    jsonData += "\"message\":\"" + commitMessage + "\","
                    jsonData += "\"sha\":\"" + sha + "\""
                    jsonData += "}"
                    
                    return sendRequest url method:"DELETE" data:jsonData
                )
            )
        )
        return undefined
    )
)

-- UI界面
rollout GitHubFileManager "GitHub文件管理器" width:450 height:570
(
    group "GitHub设置"
    (
        edittext edtToken "访问令牌:" width:380 across:2 align:#left
        button btnConnect "连接" width:60 height:20 align:#right offset:[0,0]
        
        edittext edtUsername "用户名:" width:380 align:#left
        edittext edtRepo "仓库名:" width:380 align:#left
    )
    
    group "文件列表"
    (
        dropdownlist ddlFiles "" width:380 across:2 align:#left
        button btnRefresh "刷新" width:60 height:20 align:#right offset:[0,0]
    )
    
    group "文件编辑"
    (
        edittext edtFileName "文件名:" width:380 align:#left
        label lblContent "文件内容:" align:#left
        
        -- 使用RichTextBox
        dotNetControl edtContent "System.Windows.Forms.RichTextBox" width:430 height:200 align:#center
        
        -- 编辑辅助按钮
        label lblEditHelp "编辑工具:" align:#left
        button btnInsertNewLine "插入换行 ↵" width:90 height:22 across:4 align:#left
        button btnClearContent "清空内容" width:90 height:22 align:#center offset:[-10,0]
        button btnInsertTab "插入Tab →" width:90 height:22 align:#center offset:[0,0]
        button btnPasteText "粘贴文本" width:90 height:22 align:#right
    )
    
    group "操作"
    (
        edittext edtCommitMsg "提交说明:" width:380 align:#left
        
        button btnLoad "加载文件" width:100 height:25 across:4 align:#left
        button btnSave "保存文件" width:100 height:25 align:#center offset:[-5,0]
        button btnCreate "创建新文件" width:100 height:25 align:#center offset:[5,0]
        button btnDelete "删除文件" width:100 height:25 align:#right
    )
    
    button btnClearLog "清空侦听器" width:100 height:20 across:2 align:#left
    button btnShowHelp "显示帮助" width:100 height:20 align:#right
    
    local gitHub = GitHubAPIManager()
    local fileList = #()
    
    fn parseFileList jsonStr =
    (
        print "\n>>> 解析文件列表..."
        fileList = #()
        local files = #()
        
        if jsonStr == "[]" then
        (
            print "仓库中暂无文件"
            ddlFiles.items = #("<空仓库>")
            return #()
        )
        
        local pos = 1
        while true do
        (
            local nameStart = substring jsonStr pos -1
            local namePos = findString nameStart "\"name\":\""
            if namePos == undefined then exit
            
            pos = pos + namePos + 7
            
            local restStr = substring jsonStr pos -1
            local nameEnd = findString restStr "\""
            
            if nameEnd != undefined then
            (
                local fileName = substring jsonStr pos (nameEnd - 1)
                
                local checkStr = substring jsonStr pos 500
                if findString checkStr "\"type\":\"file\"" != undefined then
                (
                    append files fileName
                    append fileList fileName
                    print ("  找到文件: " + fileName)
                )
                
                pos = pos + nameEnd
            )
            else
            (
                exit
            )
        )
        
        print (">>> 共找到 " + fileList.count as string + " 个文件")
        
        if files.count > 0 then
            ddlFiles.items = files
        else
            ddlFiles.items = #("<无文件>")
            
        return files
    )
    
    on GitHubFileManager open do
    (
        -- 设置RichTextBox属性
        edtContent.Multiline = true
        edtContent.WordWrap = true
        edtContent.ScrollBars = (dotNetClass "System.Windows.Forms.RichTextBoxScrollBars").Both
        edtContent.Font = dotNetObject "System.Drawing.Font" "Consolas" 10
        edtContent.DetectUrls = false
        edtContent.ShortcutsEnabled = true
        
        -- 尝试让控件接受Tab键（不报错的话）
        try (edtContent.AcceptsTab = true) catch()
        
        clearListener()
        print "======================================"
        print "GitHub文件管理器 - 稳定版"
        print "======================================"
        print "编辑提示："
        print "1. 使用'插入换行'按钮添加换行"
        print "2. Ctrl+C/V 复制粘贴"
        print "3. Ctrl+A 全选"
        print "======================================"
    )
    
    on btnConnect pressed do
    (
        if edtToken.text != "" and edtUsername.text != "" and edtRepo.text != "" then
        (
            gitHub.token = trimLeft (trimRight edtToken.text)
            gitHub.username = trimLeft (trimRight edtUsername.text)
            gitHub.repo = trimLeft (trimRight edtRepo.text)
            
            print "\n>>> 连接GitHub..."
            
            local contents = gitHub.getRepoContents()
            if contents != undefined then
            (
                print ">>> 连接成功!"
                parseFileList contents
            )
        )
        else
        (
            print "\n!!! 请填写完整的GitHub信息"
        )
    )
    
    on btnRefresh pressed do
    (
        local contents = gitHub.getRepoContents()
        if contents != undefined then
        (
            parseFileList contents
        )
    )
    
    on btnLoad pressed do
    (
        if ddlFiles.selection > 0 and fileList.count > 0 then
        (
            local fileName = fileList[ddlFiles.selection]
            local content = gitHub.getFileContent fileName
            if content != undefined then
            (
                edtContent.Text = content
                edtFileName.text = fileName
                print (">>> 文件加载完成: " + fileName)
                
                -- 计算行数
                local lines = filterString content "\n"
                print (">>> 文件包含 " + (lines.count as string) + " 行")
            )
        )
        else
        (
            print "!!! 请选择要加载的文件"
        )
    )
    
    on btnSave pressed do
    (
        if edtFileName.text != "" and edtCommitMsg.text != "" then
        (
            local content = edtContent.Text
            
            print "\n>>> 准备保存文件..."
            print ("文件名: " + edtFileName.text)
            
            -- 显示内容信息
            local lines = filterString content "\n"
            print ("内容: " + (lines.count as string) + " 行, " + (content.count as string) + " 字符")
            
            local result = gitHub.createOrUpdateFile edtFileName.text content edtCommitMsg.text
            if result != undefined then
            (
                edtCommitMsg.text = ""
                btnRefresh.pressed()
            )
        )
        else
        (
            print "!!! 请输入文件名和提交信息"
        )
    )
    
    on btnCreate pressed do
    (
        if edtFileName.text != "" and edtCommitMsg.text != "" then
        (
            if findString edtFileName.text "." == undefined then
            (
                edtFileName.text += ".txt"
            )
            
            local content = edtContent.Text
            
            local result = gitHub.createOrUpdateFile edtFileName.text content edtCommitMsg.text
            if result != undefined then
            (
                edtCommitMsg.text = ""
                btnRefresh.pressed()
            )
        )
        else
        (
            print "!!! 请输入文件名和提交信息"
        )
    )
    
    on btnDelete pressed do
    (
        if ddlFiles.selection > 0 and fileList.count > 0 then
        (
            if edtCommitMsg.text != "" then
            (
                local fileName = fileList[ddlFiles.selection]
                if queryBox ("确定要删除文件 \"" + fileName + "\" 吗？") then
                (
                    local result = gitHub.deleteFile fileName edtCommitMsg.text
                    if result != undefined then
                    (
                        edtContent.Text = ""
                        edtFileName.text = ""
                        edtCommitMsg.text = ""
                        btnRefresh.pressed()
                    )
                )
            )
            else
            (
                print "!!! 请输入提交信息"
            )
        )
        else
        (
            print "!!! 请选择要删除的文件"
        )
    )
    
    -- 插入换行按钮（已确认工作）
    on btnInsertNewLine pressed do
    (
        -- 获取当前光标位置
        local curPos = edtContent.SelectionStart
        local curText = edtContent.Text
        
        -- 在光标位置插入换行符
        if curPos == 0 then
        (
            edtContent.Text = "\n" + curText
            edtContent.SelectionStart = 1
        )
        else if curPos >= curText.count then
        (
            edtContent.Text = curText + "\n"
            edtContent.SelectionStart = edtContent.Text.count
        )
        else
        (
            edtContent.Text = (substring curText 1 curPos) + "\n" + (substring curText (curPos + 1) -1)
            edtContent.SelectionStart = curPos + 1
        )
        
        edtContent.SelectionLength = 0
        edtContent.Focus()
    )
    
    -- 清空内容
    on btnClearContent pressed do
    (
        if queryBox "确定要清空编辑器内容吗？" then
        (
            edtContent.Text = ""
            print "编辑器内容已清空"
        )
    )
    
    -- 插入Tab
    on btnInsertTab pressed do
    (
        local curPos = edtContent.SelectionStart
        local curText = edtContent.Text
        
        edtContent.Text = (substring curText 1 curPos) + "\t" + (substring curText (curPos + 1) -1)
        edtContent.SelectionStart = curPos + 1
        edtContent.Focus()
    )
    
    -- 粘贴文本
    on btnPasteText pressed do
    (
        try
        (
            local clipText = (dotNetClass "System.Windows.Forms.Clipboard").GetText()
            if clipText != undefined and clipText != "" then
            (
                local curPos = edtContent.SelectionStart
                local curText = edtContent.Text
                
                edtContent.Text = (substring curText 1 curPos) + clipText + (substring curText (curPos + 1) -1)
                edtContent.SelectionStart = curPos + clipText.count
                edtContent.Focus()
                
                print "已粘贴剪贴板内容"
            )
            else
            (
                print "剪贴板为空"
            )
        )
        catch
        (
            print "粘贴失败"
        )
    )
    
    on btnClearLog pressed do
    (
        clearListener()
        print "侦听器已清空"
    )
    
    on btnShowHelp pressed do
    (
        print "\n======================================"
        print "使用帮助:"
        print "======================================"
        print "1. 填写GitHub信息:"
        print "   - 访问令牌: GitHub个人访问令牌"
        print "   - 用户名: 您的GitHub用户名"
        print "   - 仓库名: 要操作的仓库名称"
        print ""
        print "2. 编辑文本:"
        print "   - 点击'插入换行'按钮添加换行"
        print "   - 使用Ctrl+C/V复制粘贴"
        print "   - 点击'清空内容'清除编辑器"
        print ""
        print "3. 文件操作:"
        print "   - 加载: 选择文件后加载内容"
        print "   - 保存: 更新已存在的文件"
        print "   - 创建: 创建新文件"
        print "   - 删除: 删除选中的文件"
        print "======================================"
    )
)

-- 创建并显示对话框
createDialog GitHubFileManager

print "\n>>> 界面已加载完成"
print ">>> 使用'插入换行'按钮来添加换行"
print ">>> 点击'显示帮助'查看详细说明"