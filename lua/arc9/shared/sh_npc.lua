hook.Add("InitPostEntity", "ARC9_NPCRegister", function()
    for _, wpn in pairs(weapons.GetList()) do
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

if SERVER then
    local arc9_npc_give_weapons = GetConVar("arc9_npc_give_weapons")

    net.Receive("arc9_givenpcweapon", function(len, ply)
        local ent = net.ReadEntity()

        if !arc9_npc_give_weapons:GetBool() then return end

        if !ent:IsValid() then return end
        if !ent:IsNPC() then return end

        ARC9.GiveNPCPlayerWeapon(ent, ply)
    end)
end

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


function ARC9.GetWeaponListForHL2Gun(hl2class, weptype)
    local wepclasses = {}
    local a = SysTime()
    for _, swep in ipairs(weapons.GetList()) do
        local class = swep.ClassName
        if !weapons.IsBasedOn(class, "arc9_base") then continue end
        if !ARC9.WeaponIsAllowed(class) then continue end
        swep = weapons.Get(class)
        if swep.NotForNPCs or swep.NotAWeapon or !swep.Spawnable or swep.AdminOnly then continue end

        local guess = ARC9.GuessWeaponType(swep) == weptype
        local override = ARC9.NPCBlacklist[hl2class] and ARC9.NPCBlacklist[hl2class][class]
        
        local allowed = guess or override == "in"
        if override == "ex" then allowed = false end
        
        if allowed then table.insert(wepclasses, class) end
    end
    print(SysTime()-a)
    -- PrintTable(wepclasses)
    return wepclasses
end



hook.Add("AllowPlayerPickup", "ARC9_AllowPlayerPickup", function(ply, ent)
    local wep = ply:GetActiveWeapon()
    if !wep.ARC9 then return end

    if wep:GetBipod() then return false end
end)

properties.Add( "weapon_arc9_statueify", {
    MenuLabel = "Toggle Weapon Statue",
    Order = 6969,
    MenuIcon = "icon16/control_stop.png",

    Filter = function( self, ent, ply )

        if !ent.ARC9 then return false end

        return true

    end,

    Action = function( self, ent )

        self:MsgStart()
            net.WriteEntity( ent )
        self:MsgEnd()

    end,

    Receive = function( self, length, ply )

        local ent = net.ReadEntity()
        if ( !properties.CanBeTargeted( ent, ply ) ) then return end
        if ( !self:Filter( ent, ply ) ) then return end

        ent.IsStatue = !ent.IsStatue
        ent:SetIsStatue( ent.IsStatue )

    end

} )

hook.Add("PlayerCanPickupWeapon", "ARC9_PlayerCanPickupWeapon_Statue", function(ply, wep)
    if wep.ARC9 and wep.IsStatue then
        return false
    end
end)