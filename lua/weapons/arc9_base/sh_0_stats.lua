--[[ Class Cache ]]--

SWEP.StatCache = {}
SWEP.PV_CacheLong = {} -- ProcessedStatCache
SWEP.PV_Cache = {} -- ProcessedDynamicStatCache

SWEP.AttTableCache = {}

SWEP.HookCache = {}
SWEP.AffectorsCache = nil
SWEP.HasNoAffectors = {}

SWEP.ExcludeFromRawStats = {
    ["PrintName"] = true,
}

SWEP.DynamicConditions = { -- Never cache these conditions because they will always change
    ["Recoil"] = true,
}

SWEP.PV_Tick = 0
SWEP.PV_Move = 0
SWEP.PV_Shooting = 0
SWEP.PV_Melee = 0

SWEP.WantToInvalidateCache = false



--[[ Variables ]]--

local quickmodifiers = {
    ["DamageMin"] = GetConVar("arc9_mod_damage"),
    ["DamageMax"] = GetConVar("arc9_mod_damage"),
    -- ["SweetSpotDamage"] = GetConVar("arc9_mod_damage"),
    ["Spread"] = GetConVar("arc9_mod_spread"),
    ["DispersionSpread"] = GetConVar("arc9_mod_dispersionspread"),
    ["Recoil"] = GetConVar("arc9_mod_recoil"),
    ["VisualRecoil"] = GetConVar("arc9_mod_visualrecoil"),
    ["AimDownSightsTime"] = GetConVar("arc9_mod_adstime"),
    ["SprintToFireTime"] = GetConVar("arc9_mod_sprinttime"),
    ["DamageRand"] = GetConVar("arc9_mod_damagerand"),
    ["PhysBulletMuzzleVelocity"] = GetConVar("arc9_mod_muzzlevelocity"),
    ["RPM"] = GetConVar("arc9_mod_rpm"),
    ["HeadshotDamage"] = GetConVar("arc9_mod_headshotdamage"),
    ["MalfunctionMeanShotsToFail"] = GetConVar("arc9_mod_malfunction")
}
local quickmodifiers_values = {}

for k, cv in pairs(quickmodifiers) do
    quickmodifiers_values[k] = cv:GetFloat()
    cvars.AddChangeCallback(cv:GetName(), function(_, _, newval)
        quickmodifiers_values[k] = tonumber(newval) or 1
    end, "arc9_qmods_" .. k)
end

local singleplayer = game.SinglePlayer()
local ARC9HeatCapacityGPVOverflow = false



--[[ Helpers ]]--

local Lerp = function(a, v1, v2)
    return v1 + (a * (v2 - v1))
end



--[[ Class Methods ]]--

function SWEP:ClearLongCache() -- would rename this to "ClearProcessedCache" or smth i dunno
    self.PV_Cache = {}
    self.PV_CacheLong = {}
end


function SWEP:InvalidateCache()
    if singleplayer and self:GetOwner():IsPlayer() then
        self:CallOnClient("InvalidateCache")
    end

    self.WantToInvalidateCache = true
end


function SWEP:DoInvalidateCache() -- todo: run this while supermods are being applied so the PV_CacheLong updates properly now
    self.WantToInvalidateCache = false

    self.StatCache = {}
    self:ClearLongCache()

    self.AttTableCache = {}
    
    self.HookCache = {}
    self.AttPosCache = {}
    self.AdvancedCamoCache = nil
    self.AffectorsCache = nil
    self.ElementsCache = nil
    self.ElementTablesCache = nil
    self.RecoilPatternCache = {}
    self.CachedToggleAttsStatus = nil
    -- self.ScrollLevels = {} -- moved to PostModify
    self.HasNoAffectors = {}
    self.ListOfToggleableAttSlots = nil

    self:SetBaseSettings()
end


function SWEP:GetFinalAttTableFromAddress(address)
    return self:GetFinalAttTable(self:LocateSlotFromAddress(address))
end


local function getFinalAttTable(self, slot)
    if !slot or !slot.Installed then return {} end
    do
        local cache = self.AttTableCache[slot]
        if cache then
            if cache.ToggleStats then
                table.Merge(cache, cache.ToggleStats[slot.ToggleNum or 1] or {})
            end

            return cache
        end
    end

    local atttbl = table.Copy(ARC9.GetAttTable(slot.Installed) or {})

    if self.AttachmentTableOverrides and self.AttachmentTableOverrides[slot.Installed] then
        atttbl = table.Merge(atttbl, self.AttachmentTableOverrides[slot.Installed])
    end

    self.AttTableCache[slot] = atttbl

    if atttbl.ToggleStats then
        table.Merge(atttbl, atttbl.ToggleStats[slot.ToggleNum or 1] or {})
    end

    return atttbl
end

function SWEP:GetFinalAttTable(slot)
    return getFinalAttTable(self, slot)
end


local getAllAffectors
do
    local cvarArcModifiers = GetConVar("arc9_modifiers")

    getAllAffectors = function(self)
        if self.AffectorsCache then return self.AffectorsCache end

        -- local aff = {table.Copy(self:GetTable())}
        local aff = {self:GetTable()}

        local affLength = 1

        if not ARC9.OverrunSights then
            ARC9.OverrunSights = true
            local originalSightTable = self:GetSight().OriginalSightTable

            if originalSightTable then
                affLength = affLength + 1
                aff[affLength] = originalSightTable
            end

            ARC9.OverrunSights = false
        end

        local subSlotList = self:GetSubSlotList()
        local subSlotListLength = #subSlotList

        for i = 1, subSlotListLength do
            local atttbl = getFinalAttTable(self, subSlotList[i])

            if atttbl then
                affLength = affLength + 1
                aff[affLength] = atttbl
            end
        end

        local config = string.Split(cvarArcModifiers:GetString(), "\\n")
        local configLength = #config
        local c4 = {}

        for i = 1, configLength do
            local swig = string.Split(config[i], "\\t")
            local swig1, swig2 = swig[1], swig[2]
            -- local c2 = c4[swig[1]]
            local swig2Num = tonumber(swig2)

            if swig2Num then
                c4[swig1] = swig2Num
            elseif swig2 == "true" or swig2 == "false" then
                c4[swig1] = swig2 == "true"
            else
                c4[swig1] = swig2
            end
        end

        affLength = affLength + 1
        aff[affLength] = c4

        if not ARC9.OverrunFiremodes then
            ARC9.OverrunFiremodes = true
            affLength = affLength + 1
            aff[affLength] = self:GetCurrentFiremodeTable()
            ARC9.OverrunFiremodes = false
        end

        if not ARC9.OverrunAttElements then
            ARC9.OverrunAttElements = true

            local eles = self:GetAttachmentElements()

            for _, eletable in ipairs(eles) do
                if eletable then
                    affLength = affLength + 1
                    aff[affLength] = eletable
                end
            end

            ARC9.OverrunAttElements = false
        end

        self.AffectorsCache = aff

        return aff
    end
end

function SWEP:GetAllAffectors()
    return getAllAffectors(self)
end


local function runHook(self, val, data)
    local any = false
    local hookCache = self.HookCache[val]

    if hookCache then
        for i = 1, #hookCache do
            local d = hookCache[i](self, data)

            if d ~= nil then
                data = d
            end

            any = true
        end

        data2 = hook.Run("ARC9_" .. val, self, data)
        if data2 ~= nil then
            data = data2
        end

        return data, any
    end

    local cacheLen = 0
    local newCache = {}
    local allAffectors = getAllAffectors(self)
    local affectorsCount = #allAffectors

    for i = 1, affectorsCount do
        local elem = allAffectors[i]
        local mod = elem[val]

        if mod and isfunction(mod) then
            cacheLen = cacheLen + 1
            newCache[cacheLen] = mod

            local d = mod(self, data)
            if d ~= nil then
                data = d
            end
        end
    end

    self.HookCache[val] = newCache
    data2 = hook.Run("ARC9_" .. val, self, data)
    if data2 ~= nil then
        data = data2
    end

    return data, any
end

function SWEP:RunHook(val, data)
    return runHook(self, val, data)
end


-- cache_add["Damage"]["Sights"])
local function stringcache(prefix, suffix)
    return setmetatable({}, {
        __index = function(t, val)
            local subTbl = setmetatable({}, {
                __index = function(t2, condition)
                    local str = (prefix or "") .. val .. (suffix or "") .. condition
                    t2[condition or "nil"] = str
                    return str
                end
            })
            t[val] = subTbl
            return subTbl
        end
    })
end

local cache_cond = stringcache("", "")
local cache_priority = stringcache("", "")
local cache_override = stringcache("", "Override")
local cache_add = stringcache("", "Add")
local cache_mult = stringcache("", "Mult")
local cache_hook = stringcache("", "Hook")


local function getValue(self, val, base, condition, amount, donotcache) -- preventing .__index overhead i guess
    condition = condition or ""
    amount = amount or 1

    local stat
    if base ~= nil then
        stat = base
    else
        -- stat = self:GetTable()[val]
        stat = self[val]
    end

    local valContCondition = cache_cond[val][condition]
    if self.HasNoAffectors[valContCondition] then return stat end

    local unaffected = true
    
    local baseContValContCondition = base and cache_cond[tostring(base)][valContCondition] or valContCondition

    if not self.DynamicConditions[condition] and not donotcache then
        local cache = self.StatCache[baseContValContCondition]
    
        if cache ~= nil then
            local hookstat = runHook(self, cache_hook[val][condition], cache) -- whats the point of this though
            -- its not being cached so you want it to be dynamic
            -- but its not gonna be dynamic since you have cache inside GetProcessedValue too, which lasts like 60 seconds or whatever, i forgor
            -- + affectors are getting cached too
            -- im leaving this as it is temporarily
            if hookstat ~= nil then cache = hookstat end

            if quickmodifiers[val] and type(cache) == "number" then
                local convarvalue = quickmodifiers_values[val]

                if val == "MalfunctionMeanShotsToFail" then -- dont kill me for this pls
                    cache = cache / math.max(0.00000001, convarvalue)
                else
                    cache = cache * convarvalue
                end
            end
            
            return cache
        end
    end

    if type(stat) == "table" then stat.BaseClass = nil end

    local priority = 0
    local allAffectors = getAllAffectors(self)
    local affectorsCount = #allAffectors

    if not self.ExcludeFromRawStats[val] then -- whatever tf this is
        for i = 1, affectorsCount do
            local elem = allAffectors[i]
            local att_priority = elem[cache_priority[val]] or 1
            
            local mod = elem[valContCondition]
            if mod == nil then continue end

            -- if type(mod) == type(stat) then
            if mod ~= nil then
                if att_priority >= priority then
                    stat = mod
                    priority = att_priority
                    unaffected = false
                end
            -- else
            --     print("Invalid affector value: " .. valContCondition)
            end
        end
    end

    for i = 1, affectorsCount do -- overriding
        local elem = allAffectors[i]
        local keyName = cache_override[val][condition]
        local mod = elem[keyName]
        local att_priority = elem[cache_priority[keyName]] or 1
        
        -- if type(mod) == type(stat) then
        if mod ~= nil then
            if att_priority >= priority then
                stat = mod
                priority = att_priority
                unaffected = false
            end
        -- else
        --     print("Invalid affector value: " .. keyName)
        end
    end

    if type(stat) == "number" then
        for i = 1, affectorsCount do -- addition
            local elem = allAffectors[i]
            local mod = elem[cache_add[val][condition]]
            if type(mod) == type(stat) then
                stat = stat + mod * amount
            
                unaffected = false
            -- else
            --     print("Invalid affector value: " .. val .. "Add" .. condition)
            end
        end

        for i = 1, affectorsCount do -- multiplication
            local elem = allAffectors[i]
            local mod = elem[cache_mult[val][condition]]
            if type(mod) == type(stat) then
                stat = stat * (amount == 1 and mod or (mod ^ amount))

                unaffected = false
            -- else
            --     print("Invalid affector value: " .. val .. "Mult" .. condition)
            end
        end
    end

    if type(stat) == 'table' then stat.BaseClass = nil end -- ???

    local hookstat, any = runHook(self, cache_hook[val][condition], stat) -- wtf is "any"
    if hookstat ~= nil then stat = hookstat end
    if any then unaffected = false end
    local ughhh = not self.DynamicConditions[condition] and not donotcache

    if ughhh then
        self.StatCache[baseContValContCondition] = stat
    end

    if quickmodifiers[val] and type(val) == 'number' then
        local convarvalue = quickmodifiers[val]:GetFloat()

        if val == "MalfunctionMeanShotsToFail" then  -- dont kill me for this pls
            stat = stat / math.max(0.00000001, convarvalue)
        else
            stat = stat * convarvalue
        end

        unaffected = false
    end

    if ughhh then
        self.HasNoAffectors[valContCondition] = unaffected
    end

    return stat
end

function SWEP:GetValue(val, base, condition, amount, donotcache)
    return getValue(self, val, base, condition, amount, donotcache)
end


do
    local cvarArc9Truenames = GetConVar("arc9_truenames")

    function SWEP:GetProcessedValue(val, isstatic, base)
        local swepDt = self.dt

        if swepDt.Jammed and val == "Malfunction" then return true
        elseif swepDt.HeatLockout and val == "Overheat" then return true
        end
        
        local processedValueName = base and val .. tostring(base) or val
        local ticks

        if isstatic and not self.DynamicConditions[val] then
            local cache = self.PV_CacheLong[processedValueName]
            if cache ~= nil then return cache end

        else
            ticks = engine.TickCount()
            
            if self.PV_Tick >= ticks then
                local tempcache = self.PV_Cache[processedValueName]
                if tempcache ~= nil then return tempcache end

            elseif next(self.PV_Cache) ~= nil then
                self.PV_Cache = {}
            end
        end

        local stat = getValue(self, val, base)
        -- if true then return stat end

        local curTime = CurTime()
        local owner = self:GetOwner()
        local isOwnerValid = owner:IsValid()
        local isOwnerNPC = owner:IsNPC()

        if isOwnerNPC then
            stat = getValue(self, val, stat, "NPC", nil, isstatic) -- isstatic to avoid caching unnecessary data, since the processed value will be cached itself
        end

        if cvarArc9Truenames:GetBool() then
            stat = getValue(self, val, stat, "True", nil, isstatic)
        end

        if not swepDt.UBGL then
            if getValue(self, "Silencer") then stat = getValue(self, val, stat, "Silenced", nil, isstatic) end
        else
            stat = getValue(self, val, stat, "UBGL", nil, isstatic)
        end

        if not isstatic and not isOwnerNPC then -- nobody is gonna fucking notice that npcs process these stats either way
            if swepDt.BurstCount == 0 then
                stat = getValue(self, val, stat, "FirstShot")
            end

            if swepDt.NthShot % 2 == 0 then
                stat = getValue(self, val, stat, "EvenShot")
            else
                stat = getValue(self, val, stat, "OddShot")
            end

            if self:Clip1() == 0 then
                stat = getValue(self, val, stat, "Empty")
            end

            if swepDt.UBGL and self:Clip2() == 0 then
                stat = getValue(self, val, stat, "EmptyUBGL")
            end

            if swepDt.Reloading then
                stat = getValue(self, val, stat, "Reload")
            end

            if swepDt.NthReload % 2 == 0 then
                stat = getValue(self, val, stat, "EvenReload")
            else
                stat = getValue(self, val, stat, "OddReload")
            end

            if swepDt.Bipod then
                stat = getValue(self, val, stat, "Bipod")
            end

            -- if self:GetBlindFire() then
            --     stat = getValue(self, val, stat, "BlindFire")
            -- end

            if not self.HasNoAffectors[val .. "Sights"] or not self.HasNoAffectors[val .. "HipFire"] then
                local sightAmount = swepDt.SightAmount

                if type(stat) == 'number' then
                    if sightAmount >= 1 and not self.HasNoAffectors[val .. "Sighted"] then
                        stat = getValue(self, val, stat, "Sighted")
                    else
                        stat = Lerp(sightAmount, getValue(self, val, stat, "HipFire"), getValue(self, val, stat, "Sights"))
                    end

                else
                    if sightAmount >= 1 then
                        if not self.HasNoAffectors[val .. "Sighted"] then
                            stat = getValue(self, val, stat, "Sighted")
                        else
                            stat = getValue(self, val, stat, "Sights")
                        end
                    else
                        stat = getValue(self, val, stat, "HipFire")
                    end
                end
            end

            if not ARC9HeatCapacityGPVOverflow and (not self.HasNoAffectors[val .. "Hot"] or not self.HasNoAffectors[val .. "Heated"]) then
                local heatAmount = swepDt.HeatAmount
                local hasHeat = heatAmount > 0

                if hasHeat and base ~= "HeatCapacity" then
                    ARC9HeatCapacityGPVOverflow = true
                    local cap = self:GetProcessedValue("HeatCapacity")
                    ARC9HeatCapacityGPVOverflow = false

                    if type(stat) == 'number' then
                        local hot = getValue(self, val, stat, "Hot")

                        if heatAmount >= cap then
                            stat = getValue(self, val, stat, "Heated")
                        elseif hasHeat then
                            stat = Lerp(heatAmount / cap, stat, hot)
                        end

                    else
                        if heatAmount >= cap then
                            stat = getValue(self, val, stat, "Heated")
                        elseif hasHeat then
                            stat = getValue(self, val, stat, "Hot")
                        end
                    end
                end
            end

            local lastMeleeTime = swepDt.LastMeleeTime
            if not self.HasNoAffectors[val .. "Melee"] and lastMeleeTime < curTime then
                local pft = curTime - lastMeleeTime
                local d = pft / (getValue(self, "PreBashTime") + getValue(self, "PostBashTime"))
                d = 1 - math.Clamp(d, 0, 1)

                if type(stat) == 'number' then
                    stat = Lerp(d, stat, getValue(self, val, stat, "Melee"))
                elseif d > 0 then
                    stat = getValue(self, val, stat, "Melee")
                end
            end

            if not self.HasNoAffectors[val .. "Shooting"] then
                local nextPrimaryFire = self:GetNextPrimaryFire()

                if nextPrimaryFire + 0.1 > curTime then
                    local pft = (nextPrimaryFire + 0.1) - curTime
                    local d = math.Clamp(pft / 0.1, 0, 1)

                    if type(stat) == 'number' then
                        stat = Lerp(d, stat, getValue(self, val, stat, "Shooting"))
                    elseif d > 0 then
                        stat = getValue(self, val, stat, "Shooting")
                    end
                end
            end

            if val ~= "RecoilModifierCap" and not self.HasNoAffectors[val .. "Recoil"] then
                local recoilAmount = math.min(self:GetProcessedValue("RecoilModifierCap"), swepDt.RecoilAmount)
                if recoilAmount > 0 then stat = getValue(self, val, stat, "Recoil", recoilAmount) end
            end

            if --[[not isOwnerNPC and]] isOwnerValid then
                if owner:OnGround() and owner:GetMoveType() ~= MOVETYPE_NOCLIP then
                    if owner:IsSprinting() and !self:StillWaiting() then
                        stat = getValue(self, val, stat, "Sprint")
                    elseif owner:Crouching() then
                        stat = getValue(self, val, stat, "Crouch")
                    end
                    
                else
                    stat = getValue(self, val, stat, "MidAir")
                end
            end

            if not self.HasNoAffectors[val .. "Move"] and isOwnerValid then
                local spd = self.PV_Move
                local maxspd = owner:IsPlayer() and owner:GetWalkSpeed() or 250

                --if singleplayer or CLIENT or self.PV_Tick ~= UnPredictedCurTime() then
                    spd = math.min(owner:GetAbsVelocity():Length2D(), maxspd) / maxspd
                    self.PV_Move = spd
                --end

                if type(stat) == 'number' then
                    stat = Lerp(spd, stat, getValue(self, val, stat, "Move"))
                else
                    if spd > 0 then
                        stat = getValue(self, val, stat, "Move")
                    end
                end
            end

            if swepDt.GrenadeTossing then
                stat = getValue(self, val, stat, "Toss")
            end
        end

        if isstatic and not self.DynamicConditions[val] then
            self.PV_CacheLong[processedValueName] = stat
        else
            self.PV_Cache[processedValueName] = stat
            if self.PV_Tick < ticks then self.PV_Tick = ticks + (isOwnerNPC and 16 or 0) end
        end

        return stat
    end
end
