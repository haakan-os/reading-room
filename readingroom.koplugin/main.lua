local plugin_dir = debug.getinfo(1, "S").source:match("^@(.*/)")
package.path = package.path .. ";" .. plugin_dir .. "?.lua"

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local Dispatcher = require("dispatcher")
local Library = require("readingroom_library")
local Integrations = require("readingroom_integrations")
local FileManagerUtil = require("apps/filemanager/filemanagerutil")
local ButtonDialog = require("ui/widget/buttondialog")

local ReadingRoom = WidgetContainer:extend{
    name = "readingroom",
    is_doc_only = false,
}

function ReadingRoom:init()
    self.ui.menu:registerToMainMenu(self)
    self:onDispatcherRegisterActions()
    if not self.ui.document and self.ui.registerPostInitCallback then
        self.ui:registerPostInitCallback(function()
            UIManager:nextTick(function()
                if G_reader_settings:isTrue("readingroom_home") and not self.ui.tearing_down then
                    self:onReadingRoom()
                end
            end)
        end)
    end
end

function ReadingRoom:onDispatcherRegisterActions()
    Dispatcher:registerAction("readingroom_home", {
        category = "none", event = "ReadingRoom", title = "The Reading Room", general = true,
    })
end

function ReadingRoom:addToMainMenu(items)
    items.readingroom = {
        text = "The Reading Room",
        sorting_hint = "tools",
        sub_item_table = {
            { text = "Open The Reading Room", callback = function() self:onReadingRoom() end },
            {
                text = "Use as library home",
                checked_func = function() return G_reader_settings:isTrue("readingroom_home") end,
                callback = function() G_reader_settings:flipNilOrFalse("readingroom_home") end,
            },
            {
                text = "Show book covers",
                checked_func = function() return G_reader_settings:nilOrTrue("readingroom_covers") end,
                callback = function() G_reader_settings:flipNilOrTrue("readingroom_covers") end,
            },
        },
    }
end

function ReadingRoom:onReadingRoom()
    self:closeHome()
    local View = require("readingroom_view")
    self.home = View:new{ owner = self, section = "library" }
    UIManager:show(self.home)
    return true
end

function ReadingRoom:closeHome()
    if self.home then UIManager:close(self.home); self.home = nil end
end

function ReadingRoom:onCloseWidget()
    self:closeHome()
end

function ReadingRoom:books()
    local path = self.ui.document and self.ui.document.file or G_reader_settings:readSetting("lastfile")
    local books = Library:recent(4, path)
    -- Prefer live reader progress when this home is opened over an active book.
    if self.ui.document and books[1] and books[1].path == self.ui.document.file then
        local data = self.ui.doc_settings and self.ui.doc_settings.data or {}
        if data.doc_props then
            books[1].title = data.doc_props.title or books[1].title
            local authors = data.doc_props.authors
            if type(authors) == "table" then authors = table.concat(authors, ", ") end
            if type(authors) == "string" then books[1].author = authors end
        end
        local module = self.ui.rolling or self.ui.paging
        if module and module.getLastPercent then
            local ok, progress = pcall(module.getLastPercent, module)
            if ok and type(progress) == "number" then books[1].progress = math.max(0, math.min(1, progress)) end
        end
    end
    return books
end

function ReadingRoom:openBook(book, after_open)
    if not book then return end
    if not Library:book(book.path) then
        Integrations.message("This book is no longer available. Refresh the library.")
        return
    end
    self:closeHome()
    if self.ui.document and self.ui.document.file == book.path then
        if after_open then UIManager:nextTick(function() after_open(self.ui) end) end
        return
    end
    FileManagerUtil.openFile(self.ui, book.path, nil, true, after_open and function(reader)
        UIManager:nextTick(function() after_open(reader) end)
    end)
end

function ReadingRoom:withBookPlugin(book, kind, method)
    self:openBook(book, function(reader)
        local plugin = Integrations.find(reader, kind)
        if not plugin then
            Integrations.message(kind == "buddy" and "Install and enable BuddySync first." or "Enable KOReader's Progress sync plugin first.")
            return
        end
        Integrations.run(function()
            if method then plugin[method](plugin) else Integrations.menu(plugin) end
        end)
    end)
end

function ReadingRoom:bookActions(book)
    local dialog
    local function action(callback)
        return function() UIManager:close(dialog); callback() end
    end
    local buddy = Integrations.find(self.ui, "buddy")
    dialog = ButtonDialog:new{
        title = book.title,
        buttons = {
            {{ text = "Read", callback = action(function() self:openBook(book) end) }},
            {{ text = "Book information", callback = action(function() self.ui.bookinfo:show(book.path) end) }},
            {{ text = "Add to collection", callback = action(function()
                self.ui.collections:onShowCollList(book.path)
            end) }},
            {{ text = "Send to X3", enabled = buddy ~= nil,
                callback = action(function() self:withBookPlugin(book, "buddy", "sendCurrentBook") end) }},
            {{ text = "Send notes to X3", enabled = buddy ~= nil,
                callback = action(function() self:withBookPlugin(book, "buddy", "sendCurrentNotes") end) }},
            {{ text = "Progress sync…", callback = action(function() self:withBookPlugin(book, "kosync") end) }},
            {{ text = "Close", callback = function() UIManager:close(dialog) end }},
        },
    }
    UIManager:show(dialog)
end

function ReadingRoom:searchLocal()
    self.ui.filesearcher:onShowFileSearch()
end

function ReadingRoom:zlibrary(tab)
    local plugin = Integrations.find(self.ui, "zlibrary")
    if not plugin then Integrations.message("Install and enable zlibrary.koplugin first."); return end
    Integrations.run(function()
        if tab == "settings" then Integrations.menu(plugin)
        elseif tab == "mybooks" then plugin:showMyBooksDialog(1)
        else plugin:showMultiSearchDialog(tab) end
    end)
end

function ReadingRoom:syncShelf()
    local buddy = Integrations.find(self.ui, "buddy")
    if not buddy then Integrations.message("Install and enable BuddySync first."); return end
    Integrations.run(function() Integrations.syncShelf(buddy) end)
end

function ReadingRoom:ao3()
    if not Integrations.find(self.ui, "ao3") then
        Integrations.message("Install and enable AO3Downloader.koplugin first.")
        return
    end
    if self.ui.document then
        -- AO3 Downloader expects the file manager. Switch first, then use the
        -- freshly loaded plugin instance instead of the closed reader instance.
        self:closeHome()
        self.ui:onHome()
        UIManager:nextTick(function()
            local filemanager = require("apps/filemanager/filemanager").instance
            if not filemanager or not filemanager.file_chooser then
                Integrations.message("Open AO3 from The Reading Room in the file browser.")
                return
            end
            Integrations.run(function() Integrations.openAO3(filemanager) end)
        end)
    else
        Integrations.run(function() Integrations.openAO3(self.ui) end)
    end
end

function ReadingRoom:buddySettings()
    local buddy = Integrations.find(self.ui, "buddy")
    if not buddy then Integrations.message("Install and enable BuddySync first."); return end
    Integrations.run(function() Integrations.menu(buddy) end)
end

function ReadingRoom:options()
    Integrations.run(function() Integrations.menu(self) end)
end

return ReadingRoom
