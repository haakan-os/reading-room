local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local TouchMenu = require("ui/widget/touchmenu")
local Device = require("device")

local Integrations = {}

function Integrations.find(ui, kind)
    local fields = { buddy = "buddysync", zlibrary = "zlibrary", kosync = "kosync", ao3 = "AO3Downloader" }
    local signatures = { buddy = "sendCurrentBook", zlibrary = "showMultiSearchDialog", kosync = "getDocumentDigest", ao3 = "DownloadFanfic" }
    if ui[fields[kind]] then return ui[fields[kind]] end
    for _, module in ipairs(ui) do
        if type(module) == "table" and type(module[signatures[kind]]) == "function" then return module end
    end
end

function Integrations.message(text)
    UIManager:show(InfoMessage:new{ text = text })
end

function Integrations.run(fn)
    local ok = pcall(fn)
    if not ok then
        -- Do not display/log an arbitrary plugin exception: it may contain account data.
        Integrations.message("The plugin action could not be opened. Check the plugin version and its settings.")
    end
    return ok
end

function Integrations.menu(plugin)
    if not plugin then return end
    local items = {}
    plugin:addToMainMenu(items)
    local entry
    for _, value in pairs(items) do
        if value.sub_item_table then entry = value; break end
    end
    if not entry then
        Integrations.message("Open this plugin from KOReader's standard menu.")
        return
    end
    local tab = { icon = "appbar.settings" }
    for _, item in ipairs(entry.sub_item_table) do tab[#tab + 1] = item end
    UIManager:show(TouchMenu:new{
        width = Device.screen:getWidth(),
        tab_item_table = { tab },
    })
end

function Integrations.syncShelf(buddy)
    -- BuddySync owns its history compatibility, transfer behavior and settings.
    return buddy:syncActiveShelf()
end

function Integrations.openAO3(ui)
    local plugin = Integrations.find(ui, "ao3")
    if not plugin then
        Integrations.message("Install and enable AO3Downloader.koplugin first.")
        return false
    end
    -- This handler may be a callable HandlerSandbox, not a plain function.
    -- Use the native entry point to retain its menu stack and update behavior.
    plugin:onOpenAO3DownloaderMenu()
    return true
end

return Integrations
