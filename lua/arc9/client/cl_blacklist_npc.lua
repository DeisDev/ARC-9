ARC9.NPCBlacklist = ARC9.NPCBlacklist or {}

local hl2weapons = {
    { class = "weapon_pistol",   name = "#weapon_pistol",   targetcat = ARC9.WEAPON_PISTOL },
    { class = "weapon_357",      name = "#weapon_357",      targetcat = ARC9.WEAPON_PISTOL },
    { class = "weapon_smg1",     name = "#weapon_smg1",     targetcat = ARC9.WEAPON_SMG },
    { class = "weapon_ar2",      name = "#weapon_ar2",      targetcat = ARC9.WEAPON_AR },
    { class = "weapon_shotgun",  name = "#weapon_shotgun",  targetcat = ARC9.WEAPON_SHOTGUN },
    { class = "weapon_crossbow", name = "#weapon_crossbow", targetcat = ARC9.WEAPON_SNIPER },
    { class = "weapon_rpg",      name = "#weapon_rpg",      targetcat = ARC9.WEAPON_RPG },

    { class = "weapon_frag",     name = "#weapon_frag",     targetcat = false, sortcat = ARC9.WEAPON_FRAG },
    { class = "weapon_crowbar",  name = "#weapon_crowbar",  targetcat = false, sortcat = ARC9.WEAPON_MELEE },
    { class = "weapon_stunstick",name = "#weapon_stunstick",targetcat = false, sortcat = ARC9.WEAPON_MELEE },
    { class = "weapon_slam",     name = "#weapon_slam",     targetcat = false, sortcat = ARC9.WEAPON_FRAG },
    { class = "weapon_bugbait",  name = "#weapon_bugbait",  targetcat = false, sortcat = ARC9.WEAPON_MISC },
}

local CategoryNames = {
    [ARC9.WEAPON_PISTOL or 1]  = ARC9:GetPhrase("blacklist.npc.pistol") or "pistol",
    [ARC9.WEAPON_SMG or 2]     = ARC9:GetPhrase("blacklist.npc.smg") or "smg",
    [ARC9.WEAPON_AR or 3]      = ARC9:GetPhrase("blacklist.npc.ar") or "ar",
    [ARC9.WEAPON_SHOTGUN or 4] = ARC9:GetPhrase("blacklist.npc.shotgun") or "shotgun",
    [ARC9.WEAPON_SNIPER or 5]  = ARC9:GetPhrase("blacklist.npc.sniper") or "sniper",
    [ARC9.WEAPON_RPG or 6]     = ARC9:GetPhrase("blacklist.npc.rpg") or "rpg",
    [ARC9.WEAPON_FRAG or 6]    = ARC9:GetPhrase("blacklist.npc.frag") or "frag",
    [ARC9.WEAPON_MELEE or 7]   = ARC9:GetPhrase("blacklist.npc.melee") or "melee",
    [ARC9.WEAPON_MISC or 8]    = ARC9:GetPhrase("blacklist.npc.misc") or "misc",
}

local function GetGuessCatName(swepTbl)
    local weptype = swepTbl.ARC9WeaponCategory
    return CategoryNames[weptype] or "Misc", weptype
end


if CLIENT then
    net.Receive("arc9_syncnpcblacklist", function()
        local length = net.ReadUInt(32)
        local data = net.ReadData(length)
        local decompressed = util.Decompress(data)

        if decompressed and #decompressed > 0 then
            ARC9.NPCBlacklist = util.JSONToTable(decompressed) or {}
        end
    end)
end

local srf = surface

local blacklistWindow = nil
local blacklistTbl = {}
local filter = ""
local onlyblacklisted = false
local internalName = false
local selectedHL2gun = "weapon_pistol"
local dragMode = nil

local color_bred = Color(150, 50, 50, 255)
local color_lred = Color(125, 25, 25, 150)
local color_dred = Color(75, 0, 0, 150)
local color_dtbl = Color(0, 0, 0, 200)
local color_guessed = Color(70, 150, 230, 255)
local color_notnpc = Color(46, 41, 6, 200)

local arc9_hud_scale = GetConVar("arc9_hud_scale")
if !ARC9.ScreenScale then ARC9.ScreenScale = function(size) return size * (ScrW() / 640) * arc9_hud_scale:GetFloat() * 0.9 end end -- idk
local ARC9ScreenScale = ARC9.ScreenScale

local arc9logo_layer1 = Material("arc9/logo/logo_bottom.png", "mips smooth")
local arc9logo_layer2 = Material("arc9/logo/logo_middle.png", "mips smooth")

local function SaveNPCBlacklist()
    local cleanTbl = {}
    for hl2class, overrides in pairs(blacklistTbl) do
        if !table.IsEmpty(overrides) then
            cleanTbl[hl2class] = overrides
        end
    end
    blacklistTbl = cleanTbl

    local json = util.TableToJSON(blacklistTbl)
    local comp = util.Compress(json)

    net.Start("arc9_sendnpcblacklist")
    net.WriteUInt(#comp, 32)
    net.WriteData(comp, #comp)
    net.SendToServer()
end

local function CreateWeaponButton(parent, wepClass, swepTbl, itemWidth, targetcat)
    local wepBtn = vgui.Create("DButton", parent)
    wepBtn:SetFont("ARC9_8")
    wepBtn:SetText("")
    wepBtn:SetSize(itemWidth, ARC9ScreenScale(26))
    wepBtn.wepClass = wepClass
    wepBtn.notForNPCs = swepTbl.NotForNPCs

    local guessedCatName, guessedGunType = GetGuessCatName(swepTbl)
    local isGuessedMatch = (guessedGunType == targetcat) and !swepTbl.NotForNPCs

    local matPath = swepTbl.IconOverride or ("entities/" .. (swepTbl.ClassName or "ahmad") .. ".png")
    local iconMat = Material(matPath, "mips smooth")
    if iconMat:IsError() then
        iconMat = Material("arc9/ahmad.png", "mips smooth")
    end

    wepBtn.Paint = function(spaa, w, h)
        local selectedHL2guntbl = blacklistTbl[selectedHL2gun] or {}
        local override = selectedHL2guntbl[wepClass]

        local isEnabled = isGuessedMatch
        if override == "ex" then isEnabled = false end
        if override == "in" then isEnabled = true end
        local blisted = !isEnabled

        local hovered = spaa:IsHovered()
        local blackhov = blisted and hovered

        local Bfg_col = blackhov and color_bred or blisted and color_bred or hovered and color_black or color_white
        local Bbg_col = blackhov and color_lred or blisted and color_dred or hovered and color_white or color_dtbl

        if spaa.notForNPCs and Bbg_col == color_dtbl then
            Bbg_col = color_notnpc
        end

        srf.SetDrawColor(Bbg_col)
        srf.DrawRect(0, 0, w, h)

        local iconSize = ARC9ScreenScale(22)
        srf.SetMaterial(iconMat)
        srf.SetDrawColor(Bfg_col)
        srf.DrawTexturedRect(ARC9ScreenScale(2), ARC9ScreenScale(2), iconSize, iconSize)

        local txt = swepTbl.PrintName or wepClass
        if internalName then txt = string.Replace(string.upper(wepClass), "ARC9_", "") end
        
        srf.SetTextColor(Bfg_col)
        srf.SetTextPos(ARC9ScreenScale(28), ARC9ScreenScale(3))
        srf.SetFont("ARC9_12")
        srf.DrawText(txt)

        srf.SetTextColor(hovered and color_black or color_guessed)
        srf.SetFont("ARC9_10")
        srf.SetTextPos(ARC9ScreenScale(28), ARC9ScreenScale(14))
        srf.DrawText(guessedCatName .. (spaa.notForNPCs and (ARC9:GetPhrase("blacklist.npc.notfornpc") or " no npc") or ""))
    end

    wepBtn.OnMousePressed = function(spaa, kc)
        local currentOverride = blacklistTbl[selectedHL2gun] and blacklistTbl[selectedHL2gun][wepClass]
        local currentEnabled = isGuessedMatch
        if currentOverride == "ex" then currentEnabled = false end
        if currentOverride == "in" then currentEnabled = true end

        local newEnabled = !currentEnabled

        blacklistTbl[selectedHL2gun] = blacklistTbl[selectedHL2gun] or {}
        if newEnabled == isGuessedMatch then
            blacklistTbl[selectedHL2gun][wepClass] = nil
            if table.IsEmpty(blacklistTbl[selectedHL2gun]) then blacklistTbl[selectedHL2gun] = nil end
        else
            blacklistTbl[selectedHL2gun][wepClass] = newEnabled and "in" or "ex"
        end

        dragMode = newEnabled

        hook.Add("Think", "ARC9_NPCBlacklistDrag", function()
            if !input.IsMouseDown(MOUSE_LEFT) then
                dragMode = nil
                hook.Remove("Think", "ARC9_NPCBlacklistDrag")
            end
        end)
    end

    wepBtn.OnCursorEntered = function(spaa, kc)
        if dragMode != nil and input.IsMouseDown(MOUSE_LEFT) then
            blacklistTbl[selectedHL2gun] = blacklistTbl[selectedHL2gun] or {}
            if dragMode == isGuessedMatch then
                blacklistTbl[selectedHL2gun][wepClass] = nil
                if table.IsEmpty(blacklistTbl[selectedHL2gun]) then blacklistTbl[selectedHL2gun] = nil end
            else
                blacklistTbl[selectedHL2gun][wepClass] = dragMode and "in" or "ex"
            end
        end
    end

    return wepBtn
end

local clicksound = "arc9/newui/uimouse_click_return.ogg"
local arc9_hud_lightmode = GetConVar("arc9_hud_lightmode")

function ARC9_NPCBlacklistMenu()
    if blacklistWindow then blacklistWindow:Remove() end

    local bg = vgui.Create("DFrame")
    bg:SetPos(0, 0)
    bg:SetSize(ScrW(), ScrH())
    bg:SetTitle("")
    bg:SetDraggable(false)
    bg:ShowCloseButton(false)        -- set to false when done please!!
    bg:SetAlpha(0)
    bg:AlphaTo(255, 0.2, 0, nil)
    bg:SetBackgroundBlur(true)
    bg:MakePopup()

    bg.Paint = function(self2, w, h)
        if !arc9_hud_lightmode:GetBool() then
            surface.SetDrawColor(58, 58, 58, 206)
        else
            surface.SetDrawColor(20, 20, 20, 224)
        end
        surface.DrawRect(0, 0, w, h)
    end


    blacklistTbl = {}

    blacklistTbl = table.Copy(ARC9.NPCBlacklist)

    blacklistWindow = vgui.Create("DFrame", bg)
    blacklistWindow:SetSize(ScrW() * 0.40 + ARC9ScreenScale(200), ScrH() * 0.9)
    blacklistWindow:Center()
    blacklistWindow:SetTitle("")
    blacklistWindow:SetDraggable(false)
    blacklistWindow:SetVisible(true)
    blacklistWindow:ShowCloseButton(false )
    blacklistWindow:MakePopup()
    blacklistWindow:SetAlpha(0)
    blacklistWindow:AlphaTo(255, 0.2, 0, nil)

    blacklistWindow.OnRemove = function() bg:Remove() end

    local cornercut = ARC9ScreenScale(3.5)

    blacklistWindow.Paint = function(self, w, h)
        draw.NoTexture()

        srf.SetDrawColor(ARC9.GetHUDColor("bg"))
        srf.DrawPoly({{x = cornercut, y = h}, {x = 0, y = h-cornercut}, {x = 0, y = ARC9ScreenScale(26)}, {x = w, y = ARC9ScreenScale(26)}, {x = w, y = h-cornercut}, {x = w-cornercut, y = h}})
        srf.DrawPoly({{x = 0, y = ARC9ScreenScale(24)},{x = 0, y = cornercut},{x = cornercut, y = 0}, {x = w-cornercut, y = 0}, {x = w, y = cornercut}, {x = w, y = ARC9ScreenScale(24)}})

        srf.SetDrawColor(ARC9.GetHUDColor("hi"))
        srf.DrawPoly({{x = cornercut, y = h}, {x = 0, y = h-cornercut}, {x = cornercut, y = h-cornercut*.5}})
        srf.DrawPoly({{x = w, y = h-cornercut}, {x = w-cornercut, y = h}, {x = w-cornercut, y = h-cornercut*.5}})
        srf.DrawPoly({{x = cornercut, y = h-cornercut*.5}, {x = w-cornercut, y = h-cornercut*.5}, {x = w-cornercut, y = h}, {x = cornercut, y = h}})

        do
            local x, y, s = ARC9ScreenScale(4), ARC9ScreenScale(2), ARC9ScreenScale(20)
            srf.SetDrawColor(255, 255, 255)
            srf.SetMaterial(arc9logo_layer1)
            srf.DrawTexturedRect(x, y, s, s)

            srf.SetDrawColor(ARC9.GetHUDColor("hi"))
            srf.SetMaterial(arc9logo_layer2)
            srf.DrawTexturedRect(x, y, s, s)
        end

        srf.SetFont("ARC9_16")
        srf.SetTextColor(ARC9.GetHUDColor("fg"))
        srf.SetTextPos(ARC9ScreenScale(30), ARC9ScreenScale(4))
        srf.DrawText(ARC9:GetPhrase("blacklist.npc.title") or "blacklist.npc.title")
    end

    local close = vgui.Create("ARC9TopButton", blacklistWindow)
    close:SetPos(blacklistWindow:GetWide() - ARC9ScreenScale(23), ARC9ScreenScale(2))
    close:SetIcon(Material("arc9/ui/close.png", "mips smooth"))
    close.DoClick = function(self2)
        surface.PlaySound(clicksound)
        blacklistWindow:AlphaTo(0, 0.1, 0, nil)
        bg:AlphaTo(0, 0.1, 0, function()
            bg:Remove()
            blacklistWindow:Remove()
        end)
    end

    bg.OnMousePressed = function(self2, keycode)
        close.DoClick()
    end

    local sidebar = vgui.Create("DPanel", blacklistWindow)
    sidebar:Dock(LEFT)
    sidebar:SetWidth(ARC9ScreenScale(130))
    sidebar:DockMargin(ARC9ScreenScale(8), ARC9ScreenScale(30), 0, ARC9ScreenScale(28))
    
    sidebar.Paint = function(spaa, w, h)
        srf.SetDrawColor(0, 0, 0, 80)
        srf.DrawRect(0, 0, w, h)
    end

    local mainPanel = vgui.Create("DPanel", blacklistWindow)
    mainPanel:Dock(FILL)
    mainPanel:DockMargin(ARC9ScreenScale(8), ARC9ScreenScale(30), ARC9ScreenScale(8), ARC9ScreenScale(28))
    mainPanel.Paint = function() end

    local wepList = vgui.Create("ARC9ScrollPanel", mainPanel)
    wepList:SetText("")
    wepList:Dock(FILL)
    -- wepList:DockMargin(ARC9ScreenScale(14), 0, ARC9ScreenScale(16), ARC9ScreenScale(28))
    wepList:SetContentAlignment(5)
    wepList.Paint = function(span, w, h) end

    local sbar = wepList:GetVBar()
    sbar:SetWide(ARC9ScreenScale(15))
    sbar.Paint = function(panel) 
        panel:AddScroll(0)
    end
    sbar.btnUp.Paint = function(span, w, h) end
    sbar.btnDown.Paint = function(span, w, h) end
    sbar.btnGrip.Paint = function(span, w, h)
        srf.SetDrawColor(color_white)
        srf.DrawRect(0, 0, w, h)
    end

    local wepGrid = vgui.Create("DIconLayout", wepList)
    wepGrid:Dock(TOP)
    wepGrid:SetSpaceX(ARC9ScreenScale(4))
    wepGrid:SetSpaceY(ARC9ScreenScale(4))

    local togglebtn
    local allunselected = false 

    local function refreshWeaponList()
        wepGrid:Clear()
        blacklistTbl[selectedHL2gun] = blacklistTbl[selectedHL2gun] or {}

        local availibwidth = (ScrW() * 0.40) - ARC9ScreenScale(130) - ARC9ScreenScale(50) + ARC9ScreenScale(200)
        local itemWidth = math.floor((availibwidth - ARC9ScreenScale(8)) / 3)

        local targetcat = ARC9.WEAPON_PISTOL
        local sortcat = nil
        for _, v in ipairs(hl2weapons) do
            if v.class == selectedHL2gun then targetcat = v.targetcat sortcat = v.sortcat break end
        end

        local sortableWeps = {}
        for _, swep in ipairs(weapons.GetList()) do
            if !weapons.IsBasedOn(swep.ClassName, "arc9_base") then continue end
            swep = weapons.Get(swep.ClassName)
            -- if swep.NotForNPCs or swep.NotAWeapon or !swep.Spawnable or swep.AdminOnly then continue end
            if swep.NotAWeapon or !swep.Spawnable or swep.AdminOnly then continue end

            local weptype = swep.ARC9WeaponCategory or ARC9.WEAPON_MISC
            local isBlacklisted = false
            local override = blacklistTbl[selectedHL2gun][swep.ClassName]
            if override == "ex" then isBlacklisted = true end
            if override == "in" then isBlacklisted = false end
            if override == nil then isBlacklisted = (weptype != targetcat) or (swep.NotForNPCs == true) end
            if onlyblacklisted and !isBlacklisted then continue end

            if filter != "" and !(string.find((swep.PrintName or swep.ClassName):lower(), filter) or string.find(swep.ClassName:lower(), filter)) then
                continue
            end

            table.insert(sortableWeps, {
                swep = swep,
                class = swep.ClassName,
                cat = weptype,
                isTarget = (weptype == (sortcat or targetcat)) and 0 or 1,
                notForNPC = swep.NotForNPCs and 1 or 0
            })
        end

        table.sort(sortableWeps, function(a, b) -- gross
            if a.notForNPC != b.notForNPC then
                return a.notForNPC < b.notForNPC
            elseif a.isTarget != b.isTarget then
                return a.isTarget < b.isTarget
            elseif a.cat != b.cat then
                return a.cat < b.cat
            else
                return a.class < b.class
            end
        end)

        for _, data in ipairs(sortableWeps) do
            CreateWeaponButton(wepGrid, data.class, data.swep, itemWidth, targetcat)
        end

        if togglebtn then
            allunselected = true
            for _, data in ipairs(sortableWeps) do
                local override = blacklistTbl[selectedHL2gun] and blacklistTbl[selectedHL2gun][data.class]
                local isEnabled = (data.isTarget == 0) and !data.swep.NotForNPCs
                if override == "ex" then isEnabled = false end
                if override == "in" then isEnabled = true end
                if isEnabled then allunselected = false break end
            end

            togglebtn:SetText(allunselected and (ARC9:GetPhrase("blacklist.npc.select") or "SELECT ALL") or (ARC9:GetPhrase("blacklist.npc.deselect") or "DESELECT ALL"))
        end
    end

    for _, tabdata in ipairs(hl2weapons) do
        local tabhl2 = vgui.Create("DButton", sidebar)
        tabhl2:SetText(tabdata.name)
        tabhl2:SetFont("ARC9_12")
        tabhl2:SetHeight(ARC9ScreenScale(20))
        tabhl2:Dock(TOP)
        tabhl2:DockMargin(ARC9ScreenScale(2), ARC9ScreenScale(2), ARC9ScreenScale(2), 0)

        tabhl2.Paint = function(spaa, w, h)
            local isSel = selectedHL2gun == tabdata.class
            local hov = spaa:IsHovered()

            srf.SetDrawColor(isSel and ARC9.GetHUDColor("hi") or hov and color_white or color_dtbl)
            srf.DrawRect(0, 0, w, h)

            spaa:SetTextColor(isSel and color_black or hov and color_black or color_white)
        end

        tabhl2.DoClick = function()
            selectedHL2gun = tabdata.class
            refreshWeaponList()
        end
    end
    
    local cvarsss = {
        { ARC9:GetPhrase("settings.server.npc.npc_autoreplace.title") or "npc", "arc9_npc_autoreplace" },
        { ARC9:GetPhrase("settings.server.npc.replace_spawned.title") or "ground", "arc9_replace_spawned" },
    }
    
    for _, tabdata in ipairs(cvarsss) do
        local wroof = vgui.Create("DButton", sidebar)
        wroof:SetText(tabdata[1])
        wroof:SetFont("ARC9_12")
        wroof:SetHeight(ARC9ScreenScale(20))
        wroof:Dock(BOTTOM)
        wroof:DockMargin(ARC9ScreenScale(2), ARC9ScreenScale(2), ARC9ScreenScale(2), 0)

        wroof.Paint = function(spaa, w, h)
            local isSel = GetConVar(tabdata[2]):GetBool()
            local hov = spaa:IsHovered()

            srf.SetDrawColor(isSel and ARC9.GetHUDColor("hi") or hov and color_white or color_dtbl)
            srf.DrawRect(0, 0, w, h)

            spaa:SetTextColor(isSel and color_black or hov and color_black or color_white)
        end

        wroof.DoClick = function()
            RunConsoleCommand(tabdata[2], GetConVar(tabdata[2]):GetBool() and 0 or 1)
        end
    end


    local FilterPanel = vgui.Create("DPanel", mainPanel)
    FilterPanel:Dock(TOP)
    FilterPanel:SetHeight(ARC9ScreenScale(16))
    FilterPanel:DockMargin(0, 0, 0, ARC9ScreenScale(4))
    FilterPanel.Paint = function() end

    local guessbtn = vgui.Create("DButton", FilterPanel)
    guessbtn:SetFont("ARC9_8")
    guessbtn:SetText(ARC9:GetPhrase("blacklist.npc.reset") or "RESET")
    guessbtn:SetWide(ARC9ScreenScale(60))
    guessbtn:Dock(RIGHT)
    guessbtn:DockMargin(ARC9ScreenScale(2), 0, 0, 0)

    guessbtn.Paint = function(spaa, w, h)
        local hov = spaa:IsHovered()
        srf.SetDrawColor(hov and color_guessed or color_dtbl)
        srf.DrawRect(0, 0, w, h)
        spaa:SetTextColor(hov and color_black or color_white)
    end

    guessbtn.DoClick = function()
        blacklistTbl[selectedHL2gun] = nil
        refreshWeaponList()
    end

    togglebtn = vgui.Create("DButton", FilterPanel)
    togglebtn:SetFont("ARC9_8")
    togglebtn:SetText(ARC9:GetPhrase("blacklist.npc.deselect") or "DESELECT ALL")
    togglebtn:SetWide(ARC9ScreenScale(60))
    togglebtn:Dock(RIGHT)
    togglebtn:DockMargin(ARC9ScreenScale(2), 0, 0, 0)

    togglebtn.Paint = function(spaa, w, h)
        local hov = spaa:IsHovered()
        srf.SetDrawColor(hov and color_bred or color_dtbl)
        srf.DrawRect(0, 0, w, h)
        spaa:SetTextColor(hov and color_white or color_white)
    end

    togglebtn.DoClick = function()
        blacklistTbl[selectedHL2gun] = blacklistTbl[selectedHL2gun] or {}
        
        local targetcat = ARC9.WEAPON_PISTOL
        for _, v in ipairs(hl2weapons) do
            if v.class == selectedHL2gun then targetcat = v.targetcat break end
        end

        for _, swep in ipairs(wepGrid:GetChildren()) do
            local sweptbl = weapons.Get(swep.wepClass)
            local isGuessedMatch = (sweptbl.ARC9WeaponCategory == targetcat) and !sweptbl.NotForNPCs
            
            if allunselected then
                blacklistTbl[selectedHL2gun][swep.wepClass] = isGuessedMatch and nil or "in"
            else
                blacklistTbl[selectedHL2gun][swep.wepClass] = isGuessedMatch and "ex" or nil
            end
        end

        refreshWeaponList()
    end

    local NameButton = vgui.Create("DButton", FilterPanel)
    NameButton:SetFont("ARC9_8")
    NameButton:SetText("")
    NameButton:SetWide(ARC9ScreenScale(30))
    NameButton:Dock(RIGHT)
    NameButton:DockMargin(ARC9ScreenScale(2), 0, 0, 0)

    NameButton.OnMousePressed = function(spaa, kc)
        internalName = !internalName
        refreshWeaponList()
    end

    NameButton.Paint = function(spaa, w, h)
        local hovered = spaa:IsHovered()

        local Bfg_col = hovered and color_black or color_white
        local Bbg_col = hovered and color_white or color_dtbl

        srf.SetDrawColor(Bbg_col)
        srf.DrawRect(0, 0, w, h)

        spaa:SetTextColor(Bfg_col)
        spaa:SetText(internalName and ARC9:GetPhrase("blacklist.id") or ARC9:GetPhrase("blacklist.name"))
    end


    local FilterEntry = vgui.Create("DTextEntry", FilterPanel)
    FilterEntry:Dock(FILL)
    FilterEntry:SetFont("ARC9_12")
    FilterEntry:SetValue(filter)
    FilterEntry.OnChange = function(self)
        filter = self:GetValue():lower()

        refreshWeaponList()
    end

    local savebtntext = ARC9:GetPhrase("customize.presets.save")
    local savebtn = vgui.Create("ARC9TopButton", blacklistWindow)
    surface.SetFont("ARC9_16")
    local tw = surface.GetTextSize(savebtntext)
    savebtn:SetPos(blacklistWindow:GetWide()/2-(ARC9ScreenScale(29)+tw)/2, blacklistWindow:GetTall() - ARC9ScreenScale(26))
    -- savebtn:Dock(BOTTOM)
    -- savebtn:DockMargin(blacklistWindow:GetWide()/2-ARC9ScreenScale(29)-tw, 0, blacklistWindow:GetWide()/2-ARC9ScreenScale(40), ARC9ScreenScale(4))
    savebtn:SetSize(ARC9ScreenScale(29)+tw, ARC9ScreenScale(22))
    savebtn:SetButtonText(savebtntext, "ARC9_16")
    savebtn:SetIcon(Material("arc9/ui/apply.png", "mips smooth"))
    savebtn.DoClick = function(self2)
        surface.PlaySound(clicksound)

        SaveNPCBlacklist()
        blacklistWindow:Close()
        blacklistWindow:Remove()
    end

    refreshWeaponList()
end

if CLIENT then
concommand.Add("arc9_blacklist_npc", function()
    if LocalPlayer():IsAdmin() then ARC9_NPCBlacklistMenu() end
end)
end