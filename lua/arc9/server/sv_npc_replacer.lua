ARC9.WeaponClasses = {}

function ARC9.PopulateWeaponClasses()
    for _, wep in ipairs(weapons.GetList()) do
        if weapons.IsBasedOn(wep.ClassName, "arc9_base") then
            wep = weapons.Get(wep.ClassName)
            if wep.NotForNPCs then continue end
            if wep.AdminOnly then continue end
            local weptype = ARC9.GuessWeaponType(wep)
            ARC9.WeaponClasses[weptype] = ARC9.WeaponClasses[weptype] or {}
            table.insert(ARC9.WeaponClasses[weptype], wep.ClassName)
        end
    end
end

ARC9.PopulateWeaponClasses()

hook.Add("InitPostEntity", "ARC9_PopulateWeaponClasses", ARC9.PopulateWeaponClasses)

local arc9_npc_autoreplace = GetConVar("arc9_npc_autoreplace")
local arc9_replace_spawned = GetConVar("arc9_replace_spawned")

function ARC9.ReplaceSpawnedWeapon(ent)
    if CLIENT then return end

    if !(ent:IsNPC() or ent:IsWeapon()) then return end

    -- print("tried to replcae", ent, CurTime())

    local fuckingtimer = (CurTime() < 5 and -0.1 or 0)

    if ent:IsNPC() then
        if !arc9_npc_autoreplace:GetBool() then return end
        timer.Simple(0.1 + fuckingtimer, function()
            if !ent:IsValid() then return end
            local cap = ent:CapabilitiesGet()

            if bit.band(cap, CAP_USE_WEAPONS) != CAP_USE_WEAPONS then return end

            local class

            if IsValid(ent:GetActiveWeapon()) then
                class = ent:GetActiveWeapon():GetClass()
            end

            if !class then return end
            local weptbl = ARC9.HL2Replacements[class]
            if !weptbl then return end
            local wepcategory = table.Random(weptbl)

            local avib = ARC9.GetWeaponListForHL2Gun(class, wepcategory)
            if avib then
                local wepclass = table.Random(avib)

                if wepclass then
                    ent:Give(wepclass)
                end
            end
        end)
    elseif ent:IsWeapon() then
        if !arc9_replace_spawned:GetBool() then return end
        timer.Simple(0.1 + fuckingtimer, function()
            if !ent:IsValid() then return end
            if IsValid(ent:GetOwner()) then return end
            if ent.ARC9 then return end

            local class = ent:GetClass()
            local weptbl = ARC9.HL2Replacements[class]
            if !weptbl then return end
            local wepcategory = table.Random(weptbl)

            local avib = ARC9.GetWeaponListForHL2Gun(class, wepcategory)
            
            if avib then
                local wepclass = table.Random(avib)

                if wepclass then
                    local wpnent = ents.Create(wepclass)
                    wpnent:SetPos(ent:GetPos())
                    wpnent:SetAngles(ent:GetAngles())

                    -- wpnent:NoOwner_Initialize()

                    wpnent:Spawn()

                    timer.Simple(0, function()
                        if !ent:IsValid() then return end
                        wpnent:OnDrop(true)
                        ent:Remove()
                    end)
                end
            end
        end)
    end
end

hook.Add("OnEntityCreated", "ARC9_ReplaceSpawnedWeapons", ARC9.ReplaceSpawnedWeapon)

local arc9_npc_blacklist = GetConVar("arc9_npc_blacklist")
local arc9_npc_whitelist = GetConVar("arc9_npc_whitelist")

function ARC9.WeaponIsAllowed(class)
    local blacklist = arc9_npc_blacklist:GetString()
    local whitelist = arc9_npc_whitelist:GetString()

    if whitelist == "" then
        -- Check blacklist

        local blacklist_tbl = {}

        for _, v in ipairs(string.Explode(" ", blacklist)) do
            blacklist_tbl[v] = true
        end

        if blacklist_tbl[class] then
            return false
        end

        return true
    else
        -- Check whitelist

        local whitelist_tbl = {}

        for _, v in ipairs(string.Explode(" ", whitelist)) do
            whitelist_tbl[v] = true
        end

        if whitelist_tbl[class] then
            return true
        end

        return false
    end
end

function ARC9.GetWeaponClasses(weptype)
    local weptbl = ARC9.WeaponClasses[weptype]
    local wepclasses = {}

    if weptbl then
        for _, class in ipairs(weptbl) do
            if ARC9.WeaponIsAllowed(class) then
                table.insert(wepclasses, class)
            end
        end
    end

    return wepclasses
end

-- wep giver, not replacer

local arc9_npc_give_weapons = GetConVar("arc9_npc_give_weapons")

net.Receive("arc9_givenpcweapon", function(len, ply)
    local ent = net.ReadEntity()

    if !arc9_npc_give_weapons:GetBool() then return end

    if !ent:IsValid() then return end
    if !ent:IsNPC() then return end

    ARC9.GiveNPCPlayerWeapon(ent, ply)
end)


function ARC9.GiveNPCPlayerWeapon(npc, ply)
    if bit.band(npc:CapabilitiesGet(), CAP_USE_WEAPONS) != CAP_USE_WEAPONS then return end

    if ply:GetPos():DistToSqr(npc:GetPos()) > 40000 then return end

    local weapon = ply:GetActiveWeapon()

    if !weapon.ARC9 or weapon.NotForNPCs then return end

    npc:SetKeyValue("spawnflags", bit.band(npc:GetSpawnFlags(), bit.bnot(SF_NPC_NO_WEAPON_DROP))) -- "Some NPCs on some maps delete their weapons when the weapon is dropped, we don't want that."
    npc:DropWeapon(nil, ply:GetPos())
    npc:Give(weapon:GetClass())

    timer.Simple(0.05, function() 
        if !IsValid(npc) then return end
        local wpn = npc:GetActiveWeapon()
        if !IsValid(wpn) then return end

        wpn.Attachments = weapon.Attachments
        wpn.WeaponWasGiven = true
        wpn:NPC_Initialize()
        wpn:SendWeapon()
        -- wpn:Activate() -- idk what this for
        wpn:SetClip1(weapon:Clip1())

        ply:StripWeapon(weapon:GetClass())
        ply:SetCanZoom(true) -- bandaid fix for 225
    end)
end