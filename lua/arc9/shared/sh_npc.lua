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

ARC9.SpawnableWeapons = ARC9.SpawnableWeapons or {}
ARC9.WeaponClasses = ARC9.WeaponClasses or {}
ARC9.CachedHL2WepReplacements = ARC9.CachedHL2WepReplacements or {}

function ARC9.GetWeaponListForHL2Gun(hl2class, weptype, fornpc)
    ARC9.CachedHL2WepReplacements[hl2class] = ARC9.CachedHL2WepReplacements[hl2class] or {}
    ARC9.CachedHL2WepReplacements[hl2class][weptype] = ARC9.CachedHL2WepReplacements[hl2class][weptype] or {}
    
    local poolKey = fornpc and "npc" or "ground"
    if ARC9.CachedHL2WepReplacements[hl2class][weptype][poolKey] then
        return ARC9.CachedHL2WepReplacements[hl2class][weptype][poolKey]
    end

    local wepclasses = {}
    local overrides = ARC9.NPCBlacklist and ARC9.NPCBlacklist[hl2class] or {}
    
    for class, wtype in pairs(ARC9.SpawnableWeapons) do
        local sweptbl = weapons.Get(class)
        local isNotForNPCs = sweptbl and sweptbl.NotForNPCs or false

        if fornpc and isNotForNPCs then continue end

        local override = overrides[class]
        
        local defaultAllowed = (wtype == weptype) and !isNotForNPCs
        local allowed = defaultAllowed or (override == "in")
        if override == "ex" then allowed = false end
        
        if allowed then table.insert(wepclasses, class) end
    end
    
    ARC9.CachedHL2WepReplacements[hl2class][weptype][poolKey] = wepclasses
    return wepclasses
end

local classlocscache = {}
for _, v in ipairs( { "en", "de", "es-es", "ru", "sv-se", "zh-cn", "ko", "uk", "uwu" } ) do
    for k2, v2 in pairs(ARC9.PhraseTable[v] or {}) do
        if string.find(k2, "class_") then
            classlocscache[v2] = k2
        end
    end
end

local classtotype_direct = {
    ["csgo_class_weapon_lmg"]       = ARC9.WEAPON_AR,
    ["csgo_class_weapon_shotgun"]   = ARC9.WEAPON_SHOTGUN,
    ["csgo_class_weapon_smg"]       = ARC9.WEAPON_SMG,
    ["csgo_class_weapon_sniper"]    = ARC9.WEAPON_SNIPER,
    ["csgo_class_weapon_special"]   = ARC9.WEAPON_MISC,
    ["csgo_class_weapon_explosive"] = ARC9.WEAPON_RPG,
    ["csgo_class_weapon_grenade"]   = ARC9.WEAPON_FRAG,
    ["csgo_class_weapon_proximity"]   = ARC9.WEAPON_FRAG,
    ["csgo_class_weapon_pistols"]   = ARC9.WEAPON_PISTOL,
    
    ["eft_class_weapon_carb"]       = ARC9.WEAPON_AR,
    ["eft_class_weapon_lmg"]        = ARC9.WEAPON_AR,
    ["eft_class_weapon_autosg"]     = ARC9.WEAPON_SHOTGUN,
    ["eft_class_weapon_boltsg"]     = ARC9.WEAPON_SHOTGUN,
    ["eft_class_weapon_semisg"]     = ARC9.WEAPON_SHOTGUN,
    ["eft_class_weapon_dbsg"]       = ARC9.WEAPON_SHOTGUN,
    ["eft_class_weapon_dualsg"]     = ARC9.WEAPON_SHOTGUN,
    ["eft_class_weapon_smg"]        = ARC9.WEAPON_SMG,
    ["eft_class_weapon_megapist"]   = ARC9.WEAPON_PISTOL,
    ["eft_class_weapon_pist"]       = ARC9.WEAPON_PISTOL,
    ["eft_class_weapon_revol"]      = ARC9.WEAPON_PISTOL,
    ["eft_class_weapon_pumpsg"]     = ARC9.WEAPON_SHOTGUN,
    ["eft_class_weapon_boltsnip"]   = ARC9.WEAPON_SNIPER,
    ["eft_class_weapon_singleshot"] = ARC9.WEAPON_SNIPER,
    ["eft_class_weapon_melee"]      = ARC9.WEAPON_MELEE,
    ["eft_class_weapon_grenadelauncher"] = ARC9.WEAPON_RPG,
    ["eft_class_weapon_toy"]        = ARC9.WEAPON_MISC,
    ["eft_class_weapon_smoke"]      = ARC9.WEAPON_FRAG,
    ["eft_class_weapon_stun"]       = ARC9.WEAPON_FRAG,
    ["eft_class_weapon_flashbang"]  = ARC9.WEAPON_FRAG,
    
    ["mw19_class_weapon_ar"]        = ARC9.WEAPON_AR,
    ["mw19_class_weapon_launcher"]  = ARC9.WEAPON_RPG,
    ["mw19_class_weapon_marksman"]  = ARC9.WEAPON_SNIPER,
    ["mw19_class_weapon_sniper"]    = ARC9.WEAPON_SNIPER,
    ["mw19_class_weapon_lethal"]    = ARC9.WEAPON_FRAG,
    ["mw19_class_weapon_melee"]     = ARC9.WEAPON_MELEE,
    
    ["smorg_class_weapon_ar"]       = ARC9.WEAPON_AR,
    ["smorg_class_weapon_br"]       = ARC9.WEAPON_AR,
    ["smorg_class_weapon_mg"]       = ARC9.WEAPON_AR,
    ["smorg_class_weapon_pc"]       = ARC9.WEAPON_SMG,
    ["smorg_class_weapon_smg"]      = ARC9.WEAPON_SMG,
    ["smorg_class_weapon_pis"]      = ARC9.WEAPON_PISTOL,
    ["smorg_class_weapon_atr"]      = ARC9.WEAPON_SNIPER,
    ["smorg_class_weapon_gl"]       = ARC9.WEAPON_RPG,
    ["smorg_class_weapon_ia"]       = ARC9.WEAPON_MELEE,
    
    ["uplp_class_weapon_ar"]        = ARC9.WEAPON_AR,
    ["uplp_class_weapon_mg"]        = ARC9.WEAPON_AR,
    ["uplp_u_class_weapon_rifle"]   = ARC9.WEAPON_AR,
    ["uplp_class_weapon_dmr"]       = ARC9.WEAPON_SNIPER,
    ["uplp_class_weapon_lever"]     = ARC9.WEAPON_SNIPER,
    ["uplp_class_weapon_machinepistol"] = ARC9.WEAPON_PISTOL,
    ["uplp_class_weapon_melee"]     = ARC9.WEAPON_MELEE,
    
    ["Personal Defense Weapon"]         = ARC9.WEAPON_SMG,
    ["PDW"]                             = ARC9.WEAPON_SMG,
    ["Anti-Materiel Precision Rifle"]   = ARC9.WEAPON_SNIPER,
    ["Anti-materiel rifle"]             = ARC9.WEAPON_SNIPER,
    ["Antimateriel Rifle"]              = ARC9.WEAPON_SNIPER,
    ["Automatic Rifle"]                 = ARC9.WEAPON_AR,
    ["Machine gun"]                     = ARC9.WEAPON_AR,
    ["Machine Gun"]                     = ARC9.WEAPON_AR
}

local classtotype_find = {
    ["assault"]     = ARC9.WEAPON_AR,
    ["machine gun"] = ARC9.WEAPON_AR,
    ["carbine"]     = ARC9.WEAPON_AR,
    ["battle"]      = ARC9.WEAPON_AR,
    ["rifle"]       = ARC9.WEAPON_AR,
    ["launcher"]    = ARC9.WEAPON_RPG,
    ["mine"]        = ARC9.WEAPON_FRAG,
    ["grenade"]     = ARC9.WEAPON_FRAG,
    ["_gren"]       = ARC9.WEAPON_FRAG,
    ["throw"]       = ARC9.WEAPON_FRAG,
    ["tactical"]    = ARC9.WEAPON_FRAG,
    ["smg"]         = ARC9.WEAPON_SMG,
    ["shotgun"]     = ARC9.WEAPON_SHOTGUN,
    ["marksman"]    = ARC9.WEAPON_SNIPER,
    ["bolt"]        = ARC9.WEAPON_SNIPER,
    ["knife"]       = ARC9.WEAPON_MELEE,
    ["blade"]       = ARC9.WEAPON_MELEE,
    ["melee"]       = ARC9.WEAPON_MELEE,
    ["wonder"]      = ARC9.WEAPON_MISC,
}

function ARC9.GuessWeaponTypeByClass(raw)
    if classlocscache[raw] then raw = classlocscache[raw] end

    if classtotype_direct[raw] then return classtotype_direct[raw] end

    local lowerr = string.lower(raw)
    for needle, probtype in pairs(classtotype_find) do
        if string.find(lowerr, needle, 0, true) then
            classtotype_direct[raw] = probtype
            return probtype
        end
    end

    classtotype_direct[raw] = ARC9.WEAPON_MISC
    return ARC9.WEAPON_MISC
end

function ARC9.PopulateWeaponClasses()
    ARC9.SpawnableWeapons = {}
    ARC9.WeaponClasses = {}
    ARC9.CachedHL2WepReplacements = {}

    for _, swep in ipairs(weapons.GetList()) do
        local class = swep.ClassName
        if !weapons.IsBasedOn(class, "arc9_base") then continue end
        swep = weapons.Get(class)
        -- if swep.NotForNPCs or swep.NotAWeapon or !swep.Spawnable or swep.AdminOnly then continue end
        if swep.NotAWeapon or !swep.Spawnable or swep.AdminOnly then continue end

        local weptype = ARC9.WEAPON_MISC

        if !swep.ARC9WeaponCategory then
            weptype = ARC9.GuessWeaponTypeByClass(swep.Class)
            weapons.GetStored(class).ARC9WeaponCategory = weptype
        end
        
        ARC9.SpawnableWeapons[class] = swep.ARC9WeaponCategory or weptype
        ARC9.WeaponClasses[weptype] = ARC9.WeaponClasses[weptype] or {}
        table.insert(ARC9.WeaponClasses[weptype], class)
    end
end

ARC9.PopulateWeaponClasses()
hook.Add("InitPostEntity", "ARC9_PopulateWeaponClasses", ARC9.PopulateWeaponClasses)