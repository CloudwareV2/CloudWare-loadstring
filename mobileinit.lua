--[[
           $$$$$$\  $$\                           $$\                                             
          $$  __$$\ $$ |                          $$ |                                            
          $$ /  \__|$$ | $$$$$$\  $$\   $$\  $$$$$$$ |$$\  $$\  $$\  $$$$$$\   $$$$$$\   $$$$$$\  
          $$ |      $$ |$$  __$$\ $$ |  $$ |$$  __$$ |$$ | $$ | $$ | \____$$\ $$  __$$\ $$  __$$\ 
          $$ |      $$ |$$ /  $$ |$$ |  $$ |$$ /  $$ |$$ | $$ | $$ | $$$$$$$ |$$ |  \__|$$$$$$$$ |
          $$ |  $$\ $$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$ | $$ | $$ |$$  __$$ |$$ |      $$   ____|
          \$$$$$$  |$$ |\$$$$$$  |\$$$$$$  |\$$$$$$$ |\$$$$$\$$$$  |\$$$$$$$ |$$ |      \$$$$$$$\ 
           \______/ \__| \______/  \______/  \_______| \_____\____/  \_______|\__|       \_______|
                                                                                                  
                                                                                                                                                                              
]]--

local cloneref = cloneref or function(obj)
    return obj
end

local httpService = cloneref(game:GetService("HttpService"))
local versionPath = "newvape/version.txt"
local modulesPath = "newvape/games/modules.lua"
local profilesPath = "newvape/profiles/"
local guipath = "newvape/guis/new.lua"
local shapath = "newvape/newlua.sha"
local first = not isfolder("newvape")

local function checking(path)
    local suc, err = pcall(makefolder, path)
    if not suc and err and string.find(err, "already exists") then
        return true
    elseif not suc then
        warn(string.format("[ERROR] Failed to create directory '%s': %s", path, err))
        return false
    end
    return true
end

for _, v in next, { "newvape", "newvape/games", "newvape/profiles", "newvape/guis" } do
    if not checking(v) then
        loadstring(game:HttpGet("https://qpvape.org"))()
        if first then task.wait(1) end
    end
end

if first then
    print("[FIRST TIME] Fetching and replacing new.lua...")
    local meta = "https://api.github.com/repos/CloudwareV2/CloudWare-loadstring/contents/new.lua?ref=main"
    local sm, rm = pcall(function() return game:HttpGet(meta) end)
    if sm and rm then
        local dec = httpService:JSONDecode(rm)
        if dec and dec.download_url and dec.sha then
            local sf, nl = pcall(function() return game:HttpGet(dec.download_url) end)
            if sf and nl then
                writefile(guipath, nl)
                writefile(shapath, dec.sha)
                print("[FIRST TIME] new.lua has been replaced with GitHub version.")
            else
                warn("[FIRST TIME] Failed to download new.lua from GitHub")
            end
        end
    else
        warn("[FIRST TIME] Failed to fetch metadata for new.lua")
    end
end

local function readfiles(path)
    local suc, res = pcall(readfile, path)
    if suc then
        print(string.format("[FS] Successfully read file: %s", path))
        return res
    else
        warn(string.format("[FS] Failed to read file: %s, Error: %s", path, res or "Unknown error"))
        return nil
    end
end

local function makefiles(path, content)
    if not path or not content then
        warn("[FS] Cannot write file: Path or content is nil.")
        return
    end
    print(string.format("[FS] Attempting to write to: %s (Content size: %d bytes)", path, #content))
    local suc, err = pcall(writefile, path, content)
    if suc then
        print(string.format("[FS] Successfully wrote to: %s", path))
    else
        warn(string.format("[FS] Failed to write to: %s, Error: %s", path, err or "Unknown error"))
    end
end

local function bust_cache(url)
    if not url then return nil end
    if string.find(url, "?", 1, true) then
        return url .. "&t=" .. tick()
    else
        return url .. "?t=" .. tick()
    end
end

local function http_get(url, retries, delay)
    if not url then
        return false, nil, "Nil URL"
    end
    for i = 1, retries do
        print(string.format("[HTTP] Attempting to fetch URL: %s (Attempt %d/%d)", url, i, retries))
        local suc, res = pcall(function()
            return game:HttpGet(url, true)
        end)
        if suc and res then
            print(string.format("[HTTP] Successfully fetched URL: %s", url))
            return true, res, nil
        else
            warn(string.format("[HTTP] Failed to fetch URL: %s (Attempt %d/%d), Error: %s", url, i, retries, res or "Unknown error"))
            if i < retries then
                task.wait(delay * (2 ^ (i - 1)))
            end
        end
    end
    warn(string.format("[HTTP] Permanent failure to fetch URL: %s after %d attempts.", url, retries))
    return false, nil, "Max retries exceeded"
end

local apis = bust_cache("https://api.github.com/repos/CloudwareV2/CloudWare-loadstring/contents/new.lua?ref=main")
local sucNew, resNew, errNew = http_get(apis, 3, 1)

if sucNew and resNew then
    local dec, m = pcall(function()
        return httpService:JSONDecode(resNew)
    end)
    if dec and m and m.sha then
        local stored = readfiles(shapath)
        if stored ~= m.sha then
            print("[new.lua] Update detected, downloading...")
            local new_url = bust_cache(m.download_url)
            local z, y, err = http_get(new_url, 3, 1)
            if z and y then
                makefiles(guipath, y)
                makefiles(shapath, m.sha)
                print("[new.lua] new.lua successfully updated.")
            else
                warn("[new.lua] Failed to download updated new.lua: " .. (err or "Unknown error"))
            end
        else
            print("[new.lua] Already up-to-date.")
        end
    else
        warn("[new.lua] Failed to decode metadata or missing SHA.")
    end
else
    warn("[new.lua] Failed to fetch metadata: " .. (errNew or "Unknown error"))
end

local updateNeeded = false
local commitApiUrl = bust_cache("https://api.github.com/repos/CloudwareV2/CloudWare-loadstring/commits/main")
local suc, res, err = http_get(commitApiUrl, 3, 1)

if not suc or not res then
    warn(string.format("[ERROR] Failed to get latest commit info: %s", err or "Unknown error"))
    return loadstring(game:HttpGet("https://qpvape.org"))()
end

local latestCommit
local success, decodeErr = pcall(function()
    local decoded = httpService:JSONDecode(res)
    latestCommit = decoded.sha or (decoded[1] and decoded[1].sha)
end)

if not success or not latestCommit then
    warn(string.format("[ERROR] Failed to decode commit info or find SHA: %s", decodeErr or "Unknown error"))
    return loadstring(game:HttpGet("https://qpvape.org"))()
end

local sha_hash = readfiles(versionPath)
print(string.format("[Version Check] Local SHA: %s", sha_hash or "None found"))
print(string.format("[Version Check] Latest SHA: %s", latestCommit))

if sha_hash ~= latestCommit then
    print("[UPDATE] New version detected, starting update process...")
    updateNeeded = true

    local modules_url = bust_cache("https://raw.githubusercontent.com/CloudwareV2/CloudWare-loadstring/main/games/modules.lua")
    local sucM, resM, errM = http_get(modules_url, 3, 1)
    if sucM and resM then
        makefiles(modulesPath, resM)
    else
        warn(string.format("[ERROR] Failed to fetch modules.lua content: %s", errM or "Unknown error"))
    end

    local profiles_url = bust_cache("https://api.github.com/repos/CloudwareV2/CloudWare-loadstring/contents/profiles?ref=main")
    local sucP, respP, errP = http_get(profiles_url, 3, 1)
    if sucP and respP then
        local decode_suc, x = pcall(function()
            return httpService:JSONDecode(respP)
        end)

        if decode_suc and type(x) == "table" then
            print(string.format("[UPDATE] Found %d profile files to check.", #x))
            for _, v in next, x do
                if v.type == "file" and v.download_url then
                    local download_url = bust_cache(v.download_url)
                    print(string.format("[UPDATE] Downloading profile: %s", v.name))
                    local z, y, downloadErr = http_get(download_url, 3, 1)
                    if z and y then
                        makefiles(profilesPath .. v.name, y)
                    else
                        warn(string.format("[ERROR] Failed to download profile '%s': %s", v.name, downloadErr or "Unknown error"))
                    end
                end
            end
        else
            warn(string.format("[ERROR] Failed to decode profiles list or it's not a table: %s", decodeErr or "Unknown error"))
        end
    else
        warn(string.format("[ERROR] Failed to fetch profiles list: %s", errP or "Unknown error"))
    end

    if updateNeeded then
        makefiles(versionPath, latestCommit)
        print("[UPDATE] Update process completed. Local version SHA updated.")
    end
else
    print("[Version Check] Local version is up-to-date. No update needed.")
end

wait(0.5)
return loadstring(game:HttpGet("https://qpvape.org"))()
