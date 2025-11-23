--***************************************************************
--* FlexibleRetargetTool.ms 
--* Version 1.0 - Flexible Bone Retargeting Tool
--* Modified from AutoBiped to support flexible bone mapping
--* No preset mapping restrictions - user defines bone relationships
--*
--***************************************************************

try(destroyDialog ro_flexibleRetarget)catch()

-- ===============================================
-- GLOBAL VARIABLES AND CONSTANTS
-- ===============================================

global FlexibleRetargetProcessor

-- Biped body parts constants (from original AutoBiped)
global KEY_LARM = 1
global KEY_RARM = 2
global KEY_LHAND = 3
global KEY_RHAND = 4
global KEY_LLEG = 5
global KEY_RLEG = 6
global KEY_LTOES = 7
global KEY_RTOES = 8
global KEY_SPINE = 9
global KEY_TAIL = 10 
global KEY_HEAD = 11                    
global KEY_PELVIS = 12        
global KEY_VERTICAL = 13
global KEY_HORIZONTAL = 14
global KEY_TURN = 15
global KEY_FOOTPRINTS = 16
global KEY_NECK = 17

-- ===============================================
-- MAIN PROCESSOR STRUCTURE
-- ===============================================

struct FlexibleRetargetProcessor (
    
    -- Member variables
    sourceBones = #(),
    targetBones = #(),
    boneMapping = #(),
    
    -- ===============================================
    -- UTILITY FUNCTIONS
    -- ===============================================
    
    fn findObjectsByPattern pattern =
    (
        local result = #()
        for obj in objects do (
            if matchPattern obj.name pattern:pattern then
                append result obj
        )
        return result
    ),
    
    fn getAllBones =
    (
        local allBones = #()
        
        -- Get all bone objects
        for obj in objects do (
            if isKindOf obj BoneGeometry or 
               isKindOf obj Biped_Object or 
               (superClassOf obj == helper and obj.children.count > 0) then
                append allBones obj
        )
        
        -- Sort by name for easier selection
        fn compareBones a b = (
            if a.name < b.name then -1 else if a.name > b.name then 1 else 0
        )
        qsort allBones compareBones
        return allBones
    ),
    
    fn getChildBones parentBone =
    (
        local children = #()
        for child in parentBone.children do (
            if isKindOf child BoneGeometry or 
               isKindOf child Biped_Object or 
               (superClassOf child == helper and child.children.count > 0) then
                append children child
        )
        return children
    ),
    
    fn getBoneHierarchy rootBone =
    (
        local hierarchy = #()
        local boneQueue = #(#(rootBone, 0))  -- array of [bone, level] pairs
        
        while boneQueue.count > 0 do (
            local currentItem = boneQueue[1]
            deleteItem boneQueue 1
            
            local bone = currentItem[1]
            local level = currentItem[2]
            
            local indentStr = ""
            for i = 1 to level do indentStr += "  "
            append hierarchy (indentStr + bone.name)
            
            -- Add children to queue
            for child in bone.children do (
                if isKindOf child BoneGeometry or 
                   isKindOf child Biped_Object or 
                   (superClassOf child == helper and child.children.count > 0) then
                    append boneQueue #(child, level + 1)
            )
        )
        
        return hierarchy
    ),
    
    -- ===============================================
    -- 重置绑定姿势函数
    -- ===============================================
    
    fn resetToBindPose =
    (
        print "正在重置绑定姿势..."
        
        -- 只重置源骨骼和蒙皮网格，不重置目标Biped模板
        local sourceObjects = #()
        
        -- 收集所有源骨骼
        for mapping in this.boneMapping do (
            append sourceObjects mapping[1]
        )
        
        -- 重置源骨骼到绑定姿势
        for obj in sourceObjects do (
            try (
                obj.assumeSkinPose()
                print ("重置源骨骼绑定姿势: " + obj.name)
            ) catch (
                print ("无法重置绑定姿势: " + obj.name)
            )
        )
        
        -- 重置所有几何体（蒙皮网格）到绑定姿势
        local meshObjs = for obj in geometry collect obj
        for obj in meshObjs do (
            try (
                obj.assumeSkinPose()
                print ("重置几何体绑定姿势: " + obj.name)
            ) catch (
                print ("无法重置绑定姿势: " + obj.name)
            )
        )
        
        forceCompleteRedraw()
        print "绑定姿势重置完成！（仅源骨骼和网格）"
        return true
    ),
    
    -- ===============================================
    -- BONE MAPPING FUNCTIONS
    -- ===============================================
    
    fn addBoneMapping sourceBone targetBone =
    (
        local mapping = #(sourceBone, targetBone)
        append this.boneMapping mapping
        print ("添加映射: " + sourceBone.name + " -> " + targetBone.name)
    ),
    
    fn removeBoneMapping index =
    (
        if index > 0 and index <= this.boneMapping.count then (
            local mapping = this.boneMapping[index]
            print ("移除映射: " + mapping[1].name + " -> " + mapping[2].name)
            deleteItem this.boneMapping index
        )
    ),
    
    fn clearBoneMappings =
    (
        this.boneMapping = #()
        print "清除所有骨骼映射"
    ),
    
    fn saveBoneMappings filename =
    (
        try (
            local file = createFile filename
            if file != undefined then (
                format "-- 灵活重定向骨骼映射\n" to:file
                format "-- 源骨骼 -> 目标骨骼\n\n" to:file
                
                for mapping in this.boneMapping do (
                    if mapping.count >= 2 and isValidNode mapping[1] and isValidNode mapping[2] then (
                        format "\"%\" -> \"%\"\n" mapping[1].name mapping[2].name to:file
                    )
                )
                
                close file
                print ("骨骼映射已保存至: " + filename)
                return true
            ) else (
                print ("无法创建文件: " + filename)
                return false
            )
        ) catch (
            print ("保存骨骼映射失败: " + filename + " - " + getCurrentException())
            return false
        )
    ),
    
    fn loadBoneMappings filename =
    (
        try (
            local file = openFile filename
            if file != undefined then (
                this.boneMapping = #()
                local loadedCount = 0
                
                while not eof file do (
                    local line = readLine file
                    if line != undefined and findString line "->" != undefined then (
                        local parts = filterString line "->"
                        if parts.count == 2 then (
                            local sourceName = trimLeft (trimRight (substituteString parts[1] "\"" ""))
                            local targetName = trimLeft (trimRight (substituteString parts[2] "\"" ""))
                            
                            local sourceObj = getNodeByName sourceName
                            local targetObj = getNodeByName targetName
                            
                            if isValidNode sourceObj and isValidNode targetObj then (
                                this.addBoneMapping sourceObj targetObj
                                loadedCount += 1
                            ) else (
                                print ("警告: 找不到骨骼 " + sourceName + " 或 " + targetName)
                            )
                        )
                    )
                )
                
                close file
                print ("从文件加载了 " + loadedCount as string + " 个骨骼映射: " + filename)
                return true
            ) else (
                print ("无法打开文件: " + filename)
                return false
            )
        ) catch (
            print ("加载骨骼映射失败: " + filename + " - " + getCurrentException())
            return false
        )
    ),
    
    -- ===============================================
    -- MATRIX AND ROTATION HELPERS
    -- ===============================================
    
    fn getMatrixFromDir dir =
    (
        local upVector = [0,0,1]
        local y = normalize dir
        local z = normalize (cross y upVector)
        local x = normalize (cross y z)
        return matrix3 x y z [0,0,0]
    ),
    
    -- 原始AutoBiped的getRotationMatrix函数
    fn getRotationMatrix bipedBone =
    (
        local boneId = biped.getIdLink bipedBone
        local tm = bipedBone.transform
        local rotMatrix = matrix3 1
        
        if boneID != undefined then (
            if boneID.x == KEY_PELVIS then
                rotMatrix = matrix3 [1,0,0] [0,0,1] [0,-1,0] [0,0,0]
            else if boneID.x == KEY_SPINE then
                rotMatrix = (matrix3 [0,0,1] [1,0,0] [0,1,0] [0,0,0])
            else if boneID.x == KEY_NECK then
                rotMatrix = (matrix3 [0,0,1] [1,0,0] [0,1,0] [0,0,0])
            else if boneID.x == KEY_HEAD then
                rotMatrix = (matrix3 [0,0,1] [1,0,0] [0,1,0] [0,0,0])
            else if boneID.x == KEY_LARM and boneID.y == 1 then
                rotMatrix = (matrix3 [0,1,0] [1,0,0] [0,0,-1] [0,0,0])
            else if boneID.x == KEY_LARM and (boneID.y == 2 or boneID.y == 3) then
                rotMatrix = (matrix3 [0,1,0] [1,0,0] [0,0,-1] [0,0,0])
            else if boneID.x == KEY_LARM and boneID.y == 4 then
                rotMatrix = (matrix3 [0,0,1] [1,0,0] [0,1,0] [0,0,0])
            else if boneID.x == KEY_LHAND then
                return undefined
            else if boneID.x == KEY_RARM and boneID.y == 1 then
                rotMatrix = (matrix3 [0,-1,0] [1,0,0] [0,0,1] [0,0,0])
            else if boneID.x == KEY_RARM and (boneID.y == 2 or boneID.y == 3) then
                rotMatrix = (matrix3 [0,-1,0] [1,0,0] [0,0,1] [0,0,0])
            else if boneID.x == KEY_RARM and boneID.y == 4 then
                rotMatrix = (matrix3 [0,0,1] [1,0,0] [0,1,0] [0,0,0])
            else if boneID.x == KEY_RHAND then
                return undefined
            else if boneID.x == KEY_LLEG then (
                if boneID.y == 3 then
                    return undefined
                else
                    rotMatrix = (matrix3 [0,0,1] [1,0,0] [0,1,0] [0,0,0])
            ) else if boneID.x == KEY_LTOES then
                return undefined
            else if boneID.x == KEY_RLEG then (
                if boneID.y == 3 then
                    return undefined
                else
                    rotMatrix = (matrix3 [0,0,1] [1,0,0] [0,1,0] [0,0,0])
            ) else if boneID.x == KEY_RTOES then
                return undefined
            else
                rotMatrix = matrix3 1
            
            tm = rotMatrix * bipedBone.transform
            tm.pos = bipedBone.transform.pos
        ) else (
            tm = translate (matrix3 1) bipedBone.transform.pos
        )
        
        return tm
    ),
    
    -- 原始AutoBiped的setBipedFingerRotation函数
    fn setBipedFingerRotation bipedBone sourceBone preRotateAng =
    (
        local sourceChild = undefined
        for child in sourceBone.children do (
            if isKindOf child BoneGeometry or isKindOf child Biped_Object or 
               (superClassOf child == helper and child.children.count > 0) then (
                sourceChild = child
                exit
            )
        )
        
        if sourceChild != undefined then (
            local dir = normalize (sourceChild.transform.pos - sourceBone.transform.pos)
            local upVector = sourceBone.dir
            local x = normalize (cross dir upVector)
            local y = normalize (cross dir x)
            local tm = matrix3 dir x y [0,0,0]
            
            tm = preRotateX tm preRotateAng[1]
            tm = preRotateY tm preRotateAng[2]
            tm = preRotateZ tm preRotateAng[3]
            
            biped.setTransform bipedBone #rotation tm false
        )
    ),
    
    -- 原始AutoBiped的wiggleRotationCloser函数
    fn wiggleRotationCloser bipedBone bipedBoneChild targetBoneChild testValue axis numTestsLeft =
    (
        local startDist = distance bipedBoneChild.transform.position targetBoneChild.transform.position
        
        rotate bipedBone (angleaxis testValue axis)
        local posTest = distance bipedBoneChild.transform.position targetBoneChild.transform.position
        
        rotate bipedBone (angleaxis (-2*testValue) axis)
        local negTest = distance bipedBoneChild.transform.position targetBoneChild.transform.position
        
        rotate bipedBone (angleaxis testValue axis)
        
        if posTest < negTest then (
            if startDist >= posTest then
                rotate bipedBone (angleaxis testValue axis)
            else
                testValue = testValue / 2
        ) else (
            if startDist >= negTest then
                rotate bipedBone (angleaxis (-1*testValue) axis)
            else
                testValue = testValue / 2
        )
        
        if numTestsLeft > 1 then
            this.wiggleRotationCloser bipedBone bipedBoneChild targetBoneChild testValue axis (numTestsLeft-1)
    ),
    
    -- ===============================================
    -- ORIGINAL AUTOBIPED ALIGNMENT LOGIC
    -- ===============================================
    
    -- 原始AutoBiped的对齐逻辑（完全移植）
    fn alignBipedToSource =
    (
        if this.boneMapping.count == 0 then return false
        
        local bipedObj = undefined
        
        -- 找到Biped对象
        for mapping in this.boneMapping do (
            if isKindOf mapping[2] Biped_Object then (
                bipedObj = mapping[2].controller.rootNode
                break
            )
        )
        
        if bipedObj == undefined then return false
        
        print "进入Biped体型模式进行对齐..."
        bipedObj.controller.figureMode = true
        
        -- 步骤1: 定位大腿 (Position thighs) - 原始AutoBiped逻辑
        local lThighSource = undefined
        local rThighSource = undefined
        
        for mapping in this.boneMapping do (
            local sourceBone = mapping[1]
            local targetBone = mapping[2]
            
            if isKindOf targetBone Biped_Object then (
                local boneId = biped.getIdLink targetBone
                if boneId != undefined then (
                    -- 左大腿 (KEY_LLEG = 5, link 1)
                    if boneId.x == KEY_LLEG and boneId.y == 1 then
                        lThighSource = sourceBone
                    -- 右大腿 (KEY_RLEG = 6, link 1)  
                    else if boneId.x == KEY_RLEG and boneId.y == 1 then
                        rThighSource = sourceBone
                )
            )
        )
        
        if lThighSource != undefined and rThighSource != undefined then (
            local pelvis = biped.getNode bipedObj #Pelvis
            local lThighBiped = biped.getNode bipedObj #LLeg link:1
            local rThighBiped = biped.getNode bipedObj #RLeg link:1
            
            -- 定位整个Biped到大腿中心（原始逻辑）
            biped.setTransform bipedObj #pos ((lThighSource.transform.pos + rThighSource.transform.pos) / 2.) true
            
            -- 缩放骨盆以匹配大腿间距（原始逻辑）
            local curScale = biped.getTransform pelvis #scale
            local curDist = distance lThighBiped rThighBiped
            local newDist = distance lThighSource.transform.pos rThighSource.transform.pos
            if curDist > 0.001 then (
                local mult = newDist / curDist
                biped.setTransform pelvis #scale (curScale * [1,1,mult]) true
            )
        )
        
        -- 步骤2: 递归对齐其他骨骼，从骨盆开始（原始AutoBiped方式）
        local startBone = biped.getNode bipedObj #pelvis link:1
        this.alignBonesRecursiveOriginal startBone
        
        bipedObj.controller.figureMode = false
        print "Biped对齐完成！"
    ),
    
    -- 完全移植原始AutoBiped的递归对齐函数
    fn alignBonesRecursiveOriginal bipedBone =
    (
        local sourceBone = this.findSourceBoneForTarget bipedBone
        
        if sourceBone != undefined then (
            -- 缩放骨骼（原始AutoBiped逻辑）
            this.scaleBipedBoneOriginal sourceBone bipedBone
            
            -- 定位骨骼
            biped.setTransform bipedBone #pos sourceBone.transform.pos false
            
            -- 应用旋转（原始AutoBiped的特殊旋转逻辑）
            local boneID = biped.getIdLink bipedBone
            
            if boneID != undefined then (
                -- 脚部旋转处理（KEY_LLEG/KEY_RLEG, link 3）
                if (boneID.x == KEY_LLEG or boneID.x == KEY_RLEG) and boneID.y == 3 then (
                    if sourceBone.children.count > 0 then (
                        local posDiff = (sourceBone.children[1].transform.pos - sourceBone.transform.pos)
                        posDiff.z = abs posDiff.z
                        local dir = normalize posDiff
                        local tm = this.getMatrixFromDir dir
                        local ang = eulerAngles (tm.rotation as eulerAngles).x 90 -90
                        biped.setTransform bipedBone #rotation ang false
                    )
                )
                
                -- 手部旋转处理（KEY_LARM/KEY_RARM, link 4）
                else if (boneID.x == KEY_LARM or boneID.x == KEY_RARM) and boneID.y == 4 then (
                    local newTM = this.getRotationMatrix bipedBone
                    if newTM != undefined then (
                        newTM *= inverse bipedBone.transform
                        newTM = preRotateX newTM -90
                        newTM = preRotateZ newTM -90
                        newTM = newTM * sourceBone.transform
                        biped.setTransform bipedBone #rotation newTM.rotation false
                    )
                )
                
                -- 颈部旋转处理（KEY_NECK = 17）
                else if boneID.x == KEY_NECK then (
                    this.setBipedFingerRotation bipedBone sourceBone [-90,0,0]
                )
                
                -- 脊椎旋转处理（KEY_SPINE = 9）
                else if boneID.x == KEY_SPINE then (
                    local tm = sourceBone.transform
                    local ang = eulerAngles 90 ((tm.rotation as eulerAngles).x*-1) 90
                    biped.setTransform bipedBone #rotation ang false
                )
                
                -- 肩膀旋转处理（KEY_LARM/KEY_RARM, link 1）- 摆动优化
                else if (boneID.x == KEY_LARM or boneID.x == KEY_RARM) and boneID.y == 1 then (
                    if bipedBone.children.count > 0 and sourceBone.children.count > 0 then (
                        local bipedBoneChild = bipedBone.children[1]
                        local sourceBoneChild = sourceBone.children[1]
                        this.wiggleRotationCloser bipedBone bipedBoneChild sourceBoneChild 8 [0,1,0] 20
                        this.wiggleRotationCloser bipedBone bipedBoneChild sourceBoneChild 8 [0,0,1] 20
                        this.wiggleRotationCloser bipedBone bipedBoneChild sourceBoneChild 8 [0,1,0] 20
                        this.wiggleRotationCloser bipedBone bipedBoneChild sourceBoneChild 8 [0,0,1] 20
                    )
                )
                
                -- 手指旋转处理（KEY_LHAND/KEY_RHAND = 3/4）
                else if boneID.x == KEY_LHAND or boneID.x == KEY_RHAND then (
                    this.setBipedFingerRotation bipedBone sourceBone [-90,0,0]
                )
            )
        )
        
        forceCompleteRedraw()
        
        -- 递归处理子骨骼
        for child in bipedBone.children do
            this.alignBonesRecursiveOriginal child
    ),
    
    -- 原始AutoBiped的scaleBipedBone函数（完全移植）
    fn scaleBipedBoneOriginal sourceBone targetBone =
    (
        if not isKindOf targetBone Biped_Object then return false
        
        local bipedRoot = targetBone.controller.RootNode
        local sourceChild = if sourceBone.children.count > 0 then sourceBone.children[1] else undefined
        local targetChild = if targetBone.children.count > 0 then targetBone.children[1] else undefined
        local boneId = biped.getIdLink targetBone
        
        if sourceChild != undefined and targetChild != undefined and boneId != undefined then (
            -- 脚部特殊缩放（KEY_LLEG/KEY_RLEG, link 3）
            if (boneId.x == KEY_LLEG or boneId.x == KEY_RLEG) and boneId.y == 3 then (
                local diff = in coordsys targetBone (sourceChild.pos - sourceBone.pos)
                local oldScale = biped.getTransform targetBone #scale
                local yScale = diff.y / (1.0 - bipedRoot.controller.ankleAttach)
                if diff.x <= 0 then diff.x = 0.1
                local newScale = [diff.x, yScale, oldScale.z]
                biped.setTransform targetBone #scale newScale false
            )
            -- 颈部和手部缩放（KEY_NECK = 17 或 KEY_LARM/KEY_RARM link 4）
            else if boneId.x == KEY_NECK or ((boneId.x == KEY_LARM or boneId.x == KEY_RARM) and boneId.y == 4) then (
                local oldScale = biped.getTransform targetBone #scale
                local dist = distance sourceBone sourceChild
                local newScale = [dist, oldScale.y, oldScale.z]
                biped.setTransform targetBone #scale newScale false
            )
            -- 其他骨骼的标准缩放
            else (
                local currentLength = distance targetBone.transform.pos targetChild.transform.pos
                local newLength = distance sourceBone.transform.pos sourceChild.transform.pos
                if currentLength > 0.001 then (
                    local mult = newLength / currentLength
                    local currentScale = biped.getTransform targetBone #scale
                    biped.setTransform targetBone #scale (currentScale * [mult,1,1]) true
                )
            )
        )
    ),
    
    -- 查找目标骨骼对应的源骨骼
    fn findSourceBoneForTarget targetBone =
    (
        for mapping in this.boneMapping do (
            if mapping[2] == targetBone then
                return mapping[1]
        )
        return undefined
    ),
    
    -- 对于非Biped骨骼的简单对齐
    fn alignSingleBone sourceBone targetBone =
    (
        if isValidNode sourceBone and isValidNode targetBone then (
            targetBone.transform.pos = sourceBone.transform.pos
            
            if sourceBone.children.count > 0 and targetBone.children.count > 0 then (
                local sourceChild = sourceBone.children[1]
                local targetChild = targetBone.children[1]
                local sourceDir = normalize (sourceChild.transform.pos - sourceBone.transform.pos)
                
                local tm = this.getMatrixFromDir sourceDir
                tm.pos = targetBone.transform.pos
                targetBone.transform = tm
            )
            
            print ("对齐标准骨骼: " + sourceBone.name + " -> " + targetBone.name)
        )
    ),
    
    -- ===============================================
    -- MAIN ALIGNMENT FUNCTION
    -- ===============================================
    
    fn alignBones =
    (
        if this.boneMapping.count == 0 then (
            print "未定义骨骼映射！"
            return false
        )
        
        print ("开始对齐 " + this.boneMapping.count as string + " 组骨骼...")
        
        -- 检查是否为Biped目标
        local hasBipedTarget = false
        for mapping in this.boneMapping do (
            if isKindOf mapping[2] Biped_Object then (
                hasBipedTarget = true
                break
            )
        )
        
        if hasBipedTarget then (
            -- 使用原始AutoBiped对齐逻辑
            print "使用原始AutoBiped对齐逻辑..."
            this.alignBipedToSource()
        ) else (
            -- 对于非Biped目标，使用简单对齐
            print "对齐非Biped骨骼..."
            for mapping in this.boneMapping do (
                this.alignSingleBone mapping[1] mapping[2]
            )
        )
        
        print "骨骼对齐完成！"
        return true
    ),
    
    -- ===============================================
    -- SKIN WEIGHTS TRANSFER
    -- ===============================================
    
    fn hasSkinnedMesh obj =
    (
        try (
            for mod in obj.modifiers do (
                if classOf mod == Skin then return true
            )
            return false
        ) catch (
            return false
        )
    ),
    
    fn getSkinModifier obj =
    (
        try (
            for mod in obj.modifiers do (
                if classOf mod == Skin then return mod
            )
            return undefined
        ) catch (
            return undefined
        )
    ),
    
    fn confirmLoadEnvelopes =
    (
        try (
            local hwnd = dialogMonitorOps.getWindowHandle()
            if hwnd != 0 and uiAccessor.getWindowText hwnd == "Load Envelopes" then (
                UIAccessor.PressButtonByName hwnd "Match by Name"
                forceCompleteRedraw()
                UIAccessor.PressButtonByName hwnd "OK"
            )
            return true
        ) catch (
            return true
        )
    ),
    
    fn loadEnvelopes skinMod filename =
    (
        try (
            DialogMonitorOps.Enabled = true
            DialogMonitorOps.RegisterNotification (this.confirmLoadEnvelopes) id:#pressSkinOK
            skinOps.LoadEnvelope skinMod filename
            DialogMonitorOps.unRegisterNotification id:#pressSkinOK
            DialogMonitorOps.Enabled = false
            return true
        ) catch (
            DialogMonitorOps.Enabled = false
            print ("加载包络失败: " + filename)
            return false
        )
    ),
    
    fn transferSkinWeights =
    (
        if this.boneMapping.count == 0 then (
            print "未定义骨骼映射，无法传递蒙皮权重！"
            return false
        )
        
        local skinnedObjects = for obj in geometry where this.hasSkinnedMesh obj collect obj
        
        print ("找到 " + skinnedObjects.count as string + " 个蒙皮对象")
        
        for obj in skinnedObjects do (
            local skinMod = this.getSkinModifier obj
            if skinMod != undefined then (
                print ("正在处理蒙皮权重: " + obj.name)
                this.transferObjectSkinWeights obj skinMod
            )
        )
        
        print "蒙皮权重传递完成！"
        return true
    ),
    
    fn transferObjectSkinWeights obj skinMod =
    (
        undo off (
            try (
                max modify mode
                modPanel.setCurrentObject skinMod
                skinOps.closeWeightTool skinMod
                subobjectLevel = 0
                
                local srcBones = #()
                local destBones = #()
                local hasTransfer = false
                
                local numBones = skinOps.GetNumberBones skinMod
                for i = 1 to numBones do (
                    local boneName = skinOps.GetBoneName skinMod i 0
                    local srcObj = getNodeByName boneName
                    local destObj = srcObj  -- Default to same bone
                    
                    -- Check if this bone should be replaced
                    for mapping in this.boneMapping do (
                        if mapping[1].name == boneName then (
                            destObj = mapping[2]
                            hasTransfer = true
                            exit
                        )
                    )
                    
                    append srcBones srcObj
                    append destBones destObj
                )
                
                if hasTransfer then (
                    print ("正在传递权重: " + obj.name)
                    
                    -- 备份旧骨骼名称并临时重命名
                    local oldJointNames = #()
                    for i = 1 to srcBones.count do (
                        append oldJointNames srcBones[i].name
                        if srcBones[i] != destBones[i] then
                            srcBones[i].name = destBones[i].name
                    )
                    
                    -- 保存当前蒙皮包络
                    local filename = sysInfo.tempDir + "~flexRetarget" + timeStamp() as string + ".env"
                    skinOps.saveEnvelope skinMod filename
                    
                    -- 恢复原始骨骼名称
                    for i = 1 to srcBones.count do
                        srcBones[i].name = oldJointNames[i]
                    
                    -- 移除并重新创建蒙皮修改器
                    local skinModName = skinMod.name
                    deleteModifier obj skinMod
                    skinMod = Skin()
                    addModifier obj skinMod
                    skinMod.name = skinModName
                    
                    -- 将目标骨骼添加到新蒙皮修改器
                    for b in destBones do (
                        if isValidNode b then
                            skinOps.addbone skinMod b 0
                    )
                    
                    -- 加载保存的包络
                    this.loadEnvelopes skinMod filename
                    
                    skinMod.alwaysDeform = true
                    
                    -- 清理临时文件
                    try(deleteFile filename)catch()
                    
                    print ("权重传递成功: " + obj.name)
                ) else (
                    print ("未找到骨骼映射: " + obj.name)
                )
            ) catch (
                print ("传递权重时出错: " + obj.name + " - " + getCurrentException())
            )
        )
        
        gc light:true
    ),
    
    -- ===============================================
    -- AUTO MAPPING FUNCTIONS
    -- ===============================================
    
    fn autoMapByNameSimilarity sourceRoot targetRoot threshold:0.7 =
    (
        this.boneMapping = #()
        
        local sourceBones = #()
        local targetBones = #()
        
        -- Collect all bones from hierarchies using iterative approach
        fn collectBonesFromHierarchy root =
        (
            local boneArray = #()
            local boneQueue = #(root)
            
            while boneQueue.count > 0 do (
                local currentBone = boneQueue[1]
                deleteItem boneQueue 1
                append boneArray currentBone
                
                for child in currentBone.children do (
                    if isKindOf child BoneGeometry or 
                       isKindOf child Biped_Object or 
                       (superClassOf child == helper and child.children.count > 0) then
                        append boneQueue child
                )
            )
            
            return boneArray
        )
        
        sourceBones = collectBonesFromHierarchy sourceRoot
        targetBones = collectBonesFromHierarchy targetRoot
        
        -- Simple name similarity function
        fn nameSimilarity name1 name2 =
        (
            local n1 = toLower name1
            local n2 = toLower name2
            
            -- Check for common patterns
            local commonPatterns = #("left", "right", "l", "r", "arm", "leg", "hand", "foot", "spine", "head", "neck", "thumb", "index", "middle", "ring", "pinky")
            local score = 0.0
            
            for pattern in commonPatterns do (
                if matchPattern n1 pattern:("*" + pattern + "*") and matchPattern n2 pattern:("*" + pattern + "*") then
                    score += 0.3
            )
            
            -- Check direct substring matches
            if findString n1 n2 != undefined or findString n2 n1 != undefined then
                score += 0.5
            
            return score
        )
        
        -- Auto-map bones based on name similarity
        for sourceBone in sourceBones do (
            local bestMatch = undefined
            local bestScore = 0.0
            
            for targetBone in targetBones do (
                local score = nameSimilarity sourceBone.name targetBone.name
                if score > bestScore and score >= threshold then (
                    bestScore = score
                    bestMatch = targetBone
                )
            )
            
            if bestMatch != undefined then
                this.addBoneMapping sourceBone bestMatch
        )
        
        print ("自动映射了 " + this.boneMapping.count as string + " 组骨骼")
    )
    
) -- End FlexibleRetargetProcessor struct

-- ===============================================
-- USER INTERFACE
-- ===============================================

rollout ro_flexibleRetarget "灵活骨骼重定向工具 v1.0" width:400 height:650
(
    group "源骨骼与目标骨骼选择" (
        pickButton btnPickSource "选择源根骨骼" width:180 height:25 across:2
        pickButton btnPickTarget "选择目标根骨骼" width:180 height:25
        label lblSource "源骨骼: 未选择" align:#left
        label lblTarget "目标骨骼: 未选择" align:#left
    )
    
    group "手动骨骼映射" (
        pickButton btnPickSourceBone "选择源骨骼" width:175 height:25 across:2
        pickButton btnPickTargetBone "选择目标骨骼" width:175 height:25
        button btnAddMapping "添加映射" width:360 height:25
        
        multiListBox lstMappings "当前映射列表:" height:12 width:360
        button btnRemoveMapping "移除选中" width:175 height:25 across:2
        button btnClearMappings "清除全部" width:175 height:25
    )
    
    group "操作" (
        button btnResetPose "重置绑定姿势" width:360 height:25
        button btnAlignBones "对齐骨骼" width:360 height:30
        button btnTransferWeights "传递蒙皮权重" width:360 height:30
        button btnDoAll "对齐骨骼 + 传递权重" width:360 height:35
    )
    
    group "保存/加载映射" (
        button btnSaveMappings "保存映射..." width:175 height:25 across:2
        button btnLoadMappings "加载映射..." width:175 height:25
    )
    
    -- 变量
    local sourceRoot = undefined
    local targetRoot = undefined
    local sourceBone = undefined
    local targetBone = undefined
    
    -- 初始化处理器
    local processor = FlexibleRetargetProcessor()
    
    -- 更新映射列表显示
    fn updateMappingList =
    (
        local mappingStrings = #()
        for mapping in processor.boneMapping do (
            append mappingStrings (mapping[1].name + " -> " + mapping[2].name)
        )
        lstMappings.items = mappingStrings
    )
    
    -- 源根骨骼选择
    on btnPickSource picked obj do (
        sourceRoot = obj
        lblSource.text = "源骨骼: " + obj.name
        btnPickSource.text = obj.name
    )
    
    -- 目标根骨骼选择
    on btnPickTarget picked obj do (
        targetRoot = obj
        lblTarget.text = "目标骨骼: " + obj.name
        btnPickTarget.text = obj.name
    )
    
    -- 自动映射
    --[[
    on btnAutoMap pressed do (
        if sourceRoot != undefined and targetRoot != undefined then (
            processor.autoMapByNameSimilarity sourceRoot targetRoot threshold:spnThreshold.value
            updateMappingList()
        ) else (
            messageBox "请先选择源骨骼和目标骨骼根节点！"
        )
    )
    --]]
    
    -- 手动骨骼选择
    on btnPickSourceBone picked obj do (
        sourceBone = obj
        btnPickSourceBone.text = obj.name
    )
    
    on btnPickTargetBone picked obj do (
        targetBone = obj
        btnPickTargetBone.text = obj.name
    )
    
    -- 添加手动映射
    on btnAddMapping pressed do (
        if sourceBone != undefined and targetBone != undefined then (
            processor.addBoneMapping sourceBone targetBone
            updateMappingList()
            sourceBone = undefined
            targetBone = undefined
            btnPickSourceBone.text = "选择源骨骼"
            btnPickTargetBone.text = "选择目标骨骼"
        ) else (
            messageBox "请先选择源骨骼和目标骨骼！"
        )
    )
    
    -- 移除映射
    on btnRemoveMapping pressed do (
        local selIndices = lstMappings.selection as array
        if selIndices.count > 0 then (
            -- 按倒序排序以避免索引移位问题
            sort selIndices
            for i = selIndices.count to 1 by -1 do (
                processor.removeBoneMapping selIndices[i]
            )
            updateMappingList()
        ) else (
            messageBox "请选择要移除的映射！"
        )
    )
    
    -- 清除所有映射
    on btnClearMappings pressed do (
        processor.clearBoneMappings()
        updateMappingList()
    )
    
    -- 重置绑定姿势
    on btnResetPose pressed do (
        processor.resetToBindPose()
    )
    
    -- 对齐骨骼
    on btnAlignBones pressed do (
        processor.alignBones()
    )
    
    -- 传递权重
    on btnTransferWeights pressed do (
        processor.transferSkinWeights()
    )
    
    -- 执行所有操作
    on btnDoAll pressed do (
        processor.alignBones()
        processor.transferSkinWeights()
    )
    
    -- 保存映射
    on btnSaveMappings pressed do (
        if processor.boneMapping.count == 0 then (
            messageBox "没有骨骼映射可保存！"
            return false
        )
        
        local filename = getSaveFileName caption:"保存骨骼映射" types:"映射文件 (*.txt)|*.txt|所有文件 (*.*)|*.*"
        if filename != undefined then (
            local result = processor.saveBoneMappings filename
            if result then (
                messageBox ("成功保存 " + processor.boneMapping.count as string + " 个骨骼映射到文件！") title:"保存成功"
            ) else (
                messageBox "保存失败，请检查文件路径和权限！" title:"保存失败"
            )
        )
    )
    
    -- 加载映射
    on btnLoadMappings pressed do (
        local filename = getOpenFileName caption:"加载骨骼映射" types:"映射文件 (*.txt)|*.txt|所有文件 (*.*)|*.*"
        if filename != undefined then (
            local result = processor.loadBoneMappings filename
            if result then (
                updateMappingList()
                messageBox ("成功加载 " + processor.boneMapping.count as string + " 个骨骼映射！") title:"加载成功"
            ) else (
                messageBox "加载失败，请检查文件格式和路径！" title:"加载失败"
            )
        )
    )
)

-- ===============================================
-- MAIN EXECUTION
-- ===============================================

createDialog ro_flexibleRetarget

print "灵活骨骼重定向工具加载成功！"
print "此工具允许您："
print "1. 手动定义骨骼映射关系"
print "2. 将目标骨骼对齐到源骨骼位置"
print "3. 在骨骼层次之间传递蒙皮权重"
print "4. 保存和加载映射配置"
print "5. 独立的重置绑定姿势功能"
print "6. 完全移植原始AutoBiped的对齐逻辑"
print ""
print "建议使用流程："
print "1. 选择源根骨骼和目标根骨骼（可选）"
print "2. 手动添加骨骼映射关系"
print "3. 点击'重置绑定姿势'（如需要）"
print "4. 点击'对齐骨骼'"
print "5. 点击'传递蒙皮权重'（如需要）"
print "6. 可保存映射配置供以后使用"