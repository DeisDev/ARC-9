hook.Add("InitPostEntity", "ARC9_NPCRegister", function()
    for _, wpn in ipairs(weapons.GetList()) do
        local tbl = weapons.Get(wpn.ClassName)

        if !tbl.ARC9 then continue end
        if tbl.NotForNPCs then continue end
        if !tbl.Spawnable then continue end

        list.Add("NPCUsableWeapons",
            {
                class = wpn.ClassName or "Missing ARC9 ClassName",
                title = wpn.PrintName or "Missing ARC9 PrintName"
            }
        )
    end
end)

local pistolammotypes = {
    ["pistol"] = true,
    ["357"] = true
}

local rpgammotypes = {
    ["rpg_round"] = true,
    ["smg1_grenade"] = true,
    ["grenade"] = true
}

local sniperammotypes = {
    ["SniperRound"] = true,
    ["SniperPenetratedRound"] = true
}

function ARC9.GuessWeaponType(swep)
    if swep.ARC9WeaponCategory then return swep.ARC9WeaponCategory end

    if swep.NotAWeapon or swep.Throwable then
        return ARC9.WEAPON_MISC
    elseif swep.PrimaryBash then
        return ARC9.WEAPON_MELEE
    elseif swep.ShootEnt or rpgammotypes[swep.Ammo] then
        return ARC9.WEAPON_RPG
    elseif (swep.Num or 1) > 1 or swep.Ammo == "Buckshot" then
        return ARC9.WEAPON_SHOTGUN
    elseif sniperammotypes[swep.Ammo] then
        return ARC9.WEAPON_SNIPER
    end

    local bestfiremode = 1

    for _, mode in ipairs(swep.Firemodes or {}) do
        if mode.Mode ~= 1 and mode.Mode ~= 0 then
            bestfiremode = mode.Mode
            break
        end
    end

    if bestfiremode == 1 then
        if pistolammotypes[swep.Ammo] then
            return ARC9.WEAPON_PISTOL
        else
            return ARC9.WEAPON_SNIPER
        end
    else
        if pistolammotypes[swep.Ammo] then
            return ARC9.WEAPON_SMG
        else
            return ARC9.WEAPON_AR
        end
    end

    return ARC9.WEAPON_MISC
end

ARC9.SpawnableWeapons = ARC9.SpawnableWeapons or {}
ARC9.WeaponClasses = ARC9.WeaponClasses or {}
ARC9.CachedHL2WepReplacements = ARC9.CachedHL2WepReplacements or {}

function ARC9.GetWeaponListForHL2Gun(hl2class, weptype)
    ARC9.CachedHL2WepReplacements[hl2class] = ARC9.CachedHL2WepReplacements[hl2class] or {}
    
    if ARC9.CachedHL2WepReplacements[hl2class][weptype] then
        return ARC9.CachedHL2WepReplacements[hl2class][weptype]
    end

    local wepclasses = {}
    local overrides = ARC9.NPCBlacklist and ARC9.NPCBlacklist[hl2class] or {}
    
    for class, wtype in pairs(ARC9.SpawnableWeapons) do
        local override = overrides[class]
        
        local allowed = (wtype == weptype) or (override == "in")
        if override == "ex" then allowed = false end
        
        if allowed then table.insert(wepclasses, class) end
    end
    
    ARC9.CachedHL2WepReplacements[hl2class][weptype] = wepclasses
    return wepclasses
end

function ARC9.PopulateWeaponClasses()
    ARC9.SpawnableWeapons = {}
    ARC9.WeaponClasses = {}
    ARC9.CachedHL2WepReplacements = {}

    for _, swep in ipairs(weapons.GetList()) do
        local class = swep.ClassName
        if !weapons.IsBasedOn(class, "arc9_base") then continue end
        swep = weapons.Get(class)
        if swep.NotForNPCs or swep.NotAWeapon or !swep.Spawnable or swep.AdminOnly then continue end
        
        local weptype = ARC9.GuessWeaponType(swep)
        
        ARC9.SpawnableWeapons[class] = weptype
        ARC9.WeaponClasses[weptype] = ARC9.WeaponClasses[weptype] or {}
        table.insert(ARC9.WeaponClasses[weptype], class)
    end
end

ARC9.PopulateWeaponClasses()
hook.Add("InitPostEntity", "ARC9_PopulateWeaponClasses", ARC9.PopulateWeaponClasses)