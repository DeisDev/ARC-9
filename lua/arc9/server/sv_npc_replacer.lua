local arc9_npc_autoreplace = GetConVar("arc9_npc_autoreplace")
local arc9_replace_spawned = GetConVar("arc9_replace_spawned")

function ARC9.ReplaceSpawnedWeapon(ent)
    if CLIENT then return end

    if !(ent:IsNPC() or ent:IsWeapon()) then return end

    -- print("tried to replcae", ent, CurTime())

    -- local fuckingtimer = (CurTime() < 5 and -0.1 or 0)
    local fuckingtimer = (CurTime() < 5) and 0 or 0.1

    if ent:IsNPC() then
        if !arc9_npc_autoreplace:GetBool() then return end

        timer.Simple(fuckingtimer, function()
            if !ent:IsValid() then return end
            local cap = ent:CapabilitiesGet()

            if bit.band(cap, CAP_USE_WEAPONS) != CAP_USE_WEAPONS then return end

            local hiswep = ent:GetActiveWeapon()
            local class = IsValid(hiswep) and hiswep:GetClass()
            if !class then return end
            local weptbl = ARC9.HL2Replacements[class]
            if !weptbl then return end
            local wepcategory = weptbl[math.random(#weptbl)]

            local avib = ARC9.GetWeaponListForHL2Gun(class, wepcategory, true)
            
            if avib and #avib > 0 then
                ent:Give(avib[math.random(#avib)])
            end
        end)
    elseif ent:IsWeapon() then
        if !arc9_replace_spawned:GetBool() then return end
        local class = ent:GetClass()
        if !ARC9.HL2Replacements[class] then return end

        timer.Simple(fuckingtimer, function()
            if !ent:IsValid() then return end
            if IsValid(ent:GetOwner()) then return end
            if ent.ARC9 then return end

            local weptbl = ARC9.HL2Replacements[class]
            if !weptbl then return end
            local wepcategory = weptbl[math.random(#weptbl)]

            local avib = ARC9.GetWeaponListForHL2Gun(class, wepcategory, false)
            
            if avib and #avib > 0 then
                local wepclass = avib[math.random(#avib)]

                local wpnent = ents.Create(wepclass)
                if !wpnent:IsValid() then return end

                wpnent:SetPos(ent:GetPos())
                wpnent:SetAngles(ent:GetAngles())
                wpnent:Spawn()

                timer.Simple(0, function()
                    if !ent:IsValid() then return end
                    wpnent:OnDrop(true)
                    ent:Remove()
                end)
            end
        end)
    end
end

hook.Add("OnEntityCreated", "ARC9_ReplaceSpawnedWeapons", ARC9.ReplaceSpawnedWeapon)

function ARC9.GetWeaponClasses(weptype)
    return ARC9.WeaponClasses[weptype] or {}
end

util.AddNetworkString("arc9_sendnpcblacklist")
util.AddNetworkString("arc9_syncnpcblacklist")
local filenamee = "arc9_npc_blacklist.json"

if file.Exists(filenamee, "DATA") then
    local rawData = file.Read(filenamee, "DATA")
    if rawData then
        ARC9.NPCBlacklist = util.JSONToTable(rawData) or {}
    end
end

net.Receive("arc9_sendnpcblacklist", function(len, ply)
    if IsValid(ply) and !ply:IsAdmin() then return end

    local length = net.ReadUInt(32)
    local data = net.ReadData(length)
    local decomp = util.Decompress(data)

    if decomp and #decomp > 0 then
        ARC9.NPCBlacklist = util.JSONToTable(decomp) or {}
        ARC9.CachedHL2WepReplacements = {} 

        file.Write(filenamee, util.TableToJSON(ARC9.NPCBlacklist, true))

        local json = util.TableToJSON(ARC9.NPCBlacklist)
        local comp = util.Compress(json)

        net.Start("arc9_syncnpcblacklist")
        net.WriteUInt(#comp, 32)
        net.WriteData(comp, #comp)
        net.Broadcast()
    end
end)


hook.Add("PlayerInitialSpawn", "ARC9_PlayerInitialSpawn_SendNPCBlacklist", function(ply)
    -- npc blacklist
    local json = util.TableToJSON(ARC9.NPCBlacklist or {})
    local comp = util.Compress(json)

    net.Start("arc9_syncnpcblacklist")
    net.WriteUInt(#comp, 32)
    net.WriteData(comp, #comp)
    net.Send(ply)
end)

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