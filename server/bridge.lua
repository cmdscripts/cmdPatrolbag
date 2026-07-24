Bridge = {}

local frameworks = {
    qbx = {
        resource = 'qbx_core',

        init = function() return true end,

        getJob = function(_, src)
            local player = exports.qbx_core:GetPlayer(src)
            local job = player and player.PlayerData and player.PlayerData.job

            if not job then return end

            return job.name, (job.grade and job.grade.level) or 0
        end,

        getOwner = function(_, src)
            local player = exports.qbx_core:GetPlayer(src)
            return player and player.PlayerData and player.PlayerData.citizenid
        end,

        onPlayerLoaded = function(_, cb)
            AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
                local src = player and player.PlayerData and player.PlayerData.source
                if src then cb(src) end
            end)
        end,
    },

    esx = {
        resource = 'es_extended',

        init = function(self)
            self.core = exports.es_extended:getSharedObject()
            return self.core ~= nil
        end,

        getJob = function(self, src)
            local player = self.core.GetPlayerFromId(src)
            local job = player and player.getJob()

            if not job then return end

            return job.name, job.grade or 0
        end,

        getOwner = function(self, src)
            local player = self.core.GetPlayerFromId(src)
            return player and player.getIdentifier()
        end,

        onPlayerLoaded = function(_, cb)
            AddEventHandler('esx:playerLoaded', function(src) cb(src) end)
        end,
    },
}

local function detect()
    local forced = Shared.framework

    if frameworks[forced] then return forced end

    for name, framework in pairs(frameworks) do
        if GetResourceState(framework.resource):find('start') then
            return name
        end
    end
end

local active

function Bridge.getJob(src)
    return active:getJob(src)
end

function Bridge.getOwner(src)
    return active:getOwner(src) or false
end

---@param src number
---@param jobs? table<string, number>
---@return boolean
function Bridge.hasAccess(src, jobs)
    if not jobs or not next(jobs) then return true end

    local name, grade = Bridge.getJob(src)

    if not name then return false end

    local required = jobs[name]

    return required ~= nil and grade >= required
end

---@param cb fun(src: number)
function Bridge.onPlayerLoaded(cb)
    AddEventHandler('cmdPatrolbag:frameworkReady', function()
        active:onPlayerLoaded(cb)
    end)
end

CreateThread(function()
    -- lib.waitFor wirft bei Timeout, statt nil zurueckzugeben.
    local ok, name = pcall(lib.waitFor, detect, 'framework', 10000)

    if not ok or not name then
        lib.print.error(locale('error.no_framework'))
        return StopResource(cache.resource)
    end

    active = frameworks[name]

    if not active:init() then
        lib.print.error(locale('error.framework_init', name))
        return StopResource(cache.resource)
    end

    Bridge.framework = name

    lib.print.info(('framework: %s'):format(name))

    TriggerEvent('cmdPatrolbag:frameworkReady', name)
end)
