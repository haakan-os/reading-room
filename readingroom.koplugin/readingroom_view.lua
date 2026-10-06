local InputContainer = require("ui/widget/container/inputcontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local TextBoxWidget = require("ui/widget/textboxwidget")
local ImageWidget = require("ui/widget/imagewidget")
local Font = require("ui/font")
local Device = require("device")
local Blitbuffer = require("ffi/blitbuffer")
local UIManager = require("ui/uimanager")
local Library = require("readingroom_library")
local Integrations = require("readingroom_integrations")
local Screen = Device.screen

local View = InputContainer:extend{ fullscreen = true, section = "library" }

function View:init()
    self.widgets = {}
    self:build()
    self.key_events.Back = {{ "Back" }, { "Esc" }}
end

function View:releaseWidgets()
    for _, item in ipairs(self.widgets or {}) do item.widget:free() end
    self.widgets = {}
end

function View:add(kind, x, y, w, h, options)
    local item = options or {}
    item.kind, item.x, item.y, item.w, item.h = kind, x, y, w, h
    self.display[#self.display + 1] = item
    return item
end

function View:text(text, x, y, w, h, size, style, align)
    return self:add("text", x, y, w, h, {
        text = tostring(text or ""), size = size or 18,
        style = style or "serif", align = align or "left",
    })
end

function View:face(style, size)
    local faces = { serif = "NotoSerif-Regular.ttf", bold = "NotoSerif-Bold.ttf", sans = "cfont" }
    -- A one-pixel sample rounds too heavily on high-DPI screens.
    local font_scale = Screen:scaleBySize(100) / 100
    return Font:getFace(faces[style or "serif"], size * self.scale / font_scale)
end

function View:measure(text, width, size, style, maximum)
    if not text or text == "" then return 0 end
    local widget = TextBoxWidget:new{
        text = tostring(text), face = self:face(style, size),
        width = math.max(1, math.floor(width * self.scale)), line_height = 0.15,
    }
    local height = math.ceil(widget:getSize().h / self.scale)
    widget:free()
    return math.min(height, maximum or height)
end

function View:rule(y, double)
    self:add("rect", 20, y, 560, double and 2 or 1, { color = "ink" })
    if double then self:add("rect", 20, y + 5, 560, 1, { color = "ink" }) end
end

function View:hit(x, y, w, h, callback, hold)
    self.targets[#self.targets + 1] = { x = x, y = y, w = w, h = h, callback = callback, hold = hold }
end

function View:button(label, x, y, w, callback, options)
    options = options or {}
    local h = options.h or 44
    local color = options.disabled and "muted" or (options.accent and "accent" or "ink")
    self:add("outline", x, y, w, h, { color = color })
    local label_item = self:text(label, x + 6, y + 4, w - 12, h - 8, options.size or 17, "sans", "center")
    label_item.color, label_item.center_y, label_item.center_h = color, y, h
    self:hit(x, y, w, h, options.disabled and function()
        Integrations.message("Install and enable this plugin in KOReader first.")
    end or callback)
end

function View:cover(book, x, y, w, h)
    self:add("cover", x, y, w, h, { book = book })
end

function View:progress(book, x, y, w)
    self:add("rect", x, y, w, 4, { color = "light" })
    if book.progress then self:add("rect", x, y, w * book.progress, 4, { color = "accent" }) end
end

function View:header()
    self:text(os.date("%H:%M"), 20, 10, 100, 23, 14, "sans")
    local battery = ""
    local ok, capacity = pcall(function() return Device:getPowerDevice():getCapacity() end)
    if ok and type(capacity) == "number" then battery = string.format("%d%%", capacity) end
    self:text(battery, 480, 10, 100, 23, 14, "sans", "right")
    self:text("THE READING ROOM", 24, 42, 552, 50, 37, "bold", "center")
    self:text("YOUR PERSONAL LIBRARY", 40, 94, 520, 22, 12, "sans", "center")
    self:rule(120, true)
    local tabs = { {"LIBRARY", "library"}, {"COLLECTIONS", "collections"}, {"DISCOVER", "discover"}, {"TOOLS", "tools"} }
    for i, tab in ipairs(tabs) do
        local x = 20 + (i - 1) * 140
        local key = tab[2]
        self:text(tab[1], x, 142, 140, 25, 14, "sans", "center")
        self:hit(x, 130, 140, 44, function() self:switch(key) end)
        if self.section == key then self:add("rect", x + 20, 170, 100, 3, { color = "accent" }) end
    end
    self:rule(178)
end

function View:library()
    local books = self.owner:books()
    local book = books[1]
    if not book then
        self:text("Your next chapter starts here.", 26, 238, 548, 110, 34, "bold", "center")
        self:text("Open a book to start your personal reading room.", 55, 362, 490, 70, 21, "serif", "center")
        self:button("Browse your books →", 120, 458, 360, function() self.owner:closeHome() end)
        return
    end
    self:text("CURRENTLY READING", 20, 195, 560, 22, 12, "sans")
    self:cover(book, 20, 226, 165, 215)
    local title_height = self:measure(book.title, 373, 30, "bold", 78)
    self:text(book.title, 207, 225, 373, title_height, 30, "bold")
    local details_y = 225 + title_height + 10
    if book.author and book.author ~= "" then
        local author_height = self:measure(book.author, 373, 19, "serif", 48)
        self:text(book.author, 207, details_y, 373, author_height, 19)
        details_y = details_y + author_height + 16
    end
    self:text(Library.progressLabel(book), 207, details_y, 373, 25, 16, "sans")
    self:progress(book, 207, details_y + 32, 373)
    local button_y = details_y + 50
    self:button("Continue reading →", 207, button_y, 307, function() self.owner:openBook(book) end, { accent = true })
    self:button("•••", 526, button_y, 54, function() self.owner:bookActions(book) end)
    local divider_y = math.max(441, button_y + 44) + 18
    self:rule(divider_y)
    self:text("On your nightstand", 20, divider_y + 14, 380, 36, 26, "bold")
    self:text("View all →", 450, divider_y + 19, 130, 28, 16, "serif", "right")
    self:hit(440, divider_y + 6, 140, 44, function() self.owner.ui.history:onShowHist() end)
    local row_start = divider_y + 60
    local available = 735 - row_start
    local row_count = math.max(1, math.min(#books - 1, math.floor(available / 72)))
    local row_height = math.min(84, math.floor(available / row_count))
    for i = 2, math.min(#books, row_count + 1) do
        local recent = books[i]
        local y = row_start + (i - 2) * row_height
        local cover_height = math.min(64, row_height - 10)
        self:cover(recent, 20, y + (row_height - cover_height) / 2, 48, cover_height)
        local recent_title_height = self:measure(recent.title, 344, 17, "bold", 42)
        local author_height = self:measure(recent.author, 344, 13, "serif", 18)
        local gap = author_height > 0 and 4 or 0
        local text_y = y + math.max(4, (row_height - recent_title_height - author_height - gap) / 2)
        self:text(recent.title, 84, text_y, 344, recent_title_height, 17, "bold")
        if author_height > 0 then
            self:text(recent.author, 84, text_y + recent_title_height + gap, 344, author_height, 13)
        end
        self:text(recent.progress and string.format("%d%%", math.floor(recent.progress * 100 + 0.5)) or "New",
            450, y + (row_height - 24) / 2, 60, 24, 14, "sans", "right")
        self:hit(20, y, 494, row_height, function() self.owner:openBook(recent) end,
            function() self.owner:bookActions(recent) end)
        self:button("•••", 526, y + (row_height - 44) / 2, 54, function() self.owner:bookActions(recent) end, { h = 44 })
        if i < math.min(#books, row_count + 1) then self:rule(y + row_height) end
    end
end

function View:collections()
    self:text("Your shelves", 20, 201, 560, 60, 35, "bold")
    self:text("A section for every reading mood.", 20, 266, 560, 35, 19)
    local ReadCollection = require("readcollection")
    local names = {}
    for name in pairs(ReadCollection.coll or {}) do names[#names + 1] = name end
    table.sort(names)
    if #names == 0 then
        self:text("Create your first collection in KOReader.", 20, 330, 560, 65, 23)
    end
    for i = 1, math.min(5, #names) do
        local name, y = names[i], 322 + (i - 1) * 67
        local count = 0
        for _ in pairs(ReadCollection.coll[name]) do count = count + 1 end
        self:rule(y)
        local title = self.owner.ui.collections:getCollectionTitle(name)
        self:text(title, 24, y + 14, 400, 37, 25)
        self:text(tostring(count) .. " books →", 430, y + 20, 146, 27, 15, "sans", "right")
        self:hit(20, y + 1, 560, 65, function() self.owner.ui.collections:onShowColl(name) end)
    end
    self:button("Manage all collections →", 20, 674, 560, function() self.owner.ui.collections:onShowCollList() end)
end

function View:discover()
    local available = Integrations.find(self.owner.ui, "zlibrary") ~= nil
    local ao3_available = Integrations.find(self.owner.ui, "ao3") ~= nil
    self:text("Discover", 20, 201, 560, 60, 37, "bold")
    self:text("Find your next read", 20, 265, 560, 35, 22)
    self:button("Search your library →", 20, 312, 560, function() self.owner:searchLocal() end)
    self:text("Z-LIBRARY", 20, 380, 560, 25, 13, "sans")
    self:button("Search Z-library →", 20, 414, 560, function() self.owner:zlibrary() end,
        { accent = true, disabled = not available })
    self:button("Recommended →", 20, 474, 270, function() self.owner:zlibrary(2) end, { disabled = not available })
    self:button("Most popular →", 310, 474, 270, function() self.owner:zlibrary(1) end, { disabled = not available })
    self:button("My books →", 20, 534, 560, function() self.owner:zlibrary("mybooks") end, { disabled = not available })
    self:rule(602, true)
    self:text("Archive of Our Own", 20, 622, 560, 37, 25, "bold")
    self:text("Search, downloads and work updates", 20, 662, 560, 22, 13, "sans")
    self:button("Browse AO3 →", 20, 693, 560, function() self.owner:ao3() end,
        { accent = true, disabled = not ao3_available })
end

function View:tools()
    local buddy = Integrations.find(self.owner.ui, "buddy")
    local book = self.owner:books()[1]
    self:text("Library services", 20, 201, 560, 60, 34, "bold")
    self:text("BUDDYSYNC · BOOKS & NOTES", 20, 278, 560, 25, 13, "sans")
    self:text(buddy and "Send your reading shelf to X3." or "BuddySync is not installed or enabled.", 20, 313, 560, 39, 21)
    self:button("Sync active shelf →", 20, 366, 270, function() self.owner:syncShelf() end, { disabled = not buddy })
    self:button("BuddySync settings", 310, 366, 270, function() self.owner:buddySettings() end, { disabled = not buddy })
    self:rule(430)
    self:text("KOSYNC · READING POSITION", 20, 450, 560, 25, 13, "sans")
    self:text("Progress sync belongs to the open book.", 20, 488, 560, 37, 21)
    self:button("Open book & sync controls →", 20, 541, 560, function()
        if book then self.owner:withBookPlugin(book, "kosync")
        else Integrations.message("Open a book first to use reading-position sync.") end
    end)
    if buddy then
        self:text("Use one plugin for automatic progress updates.", 20, 591, 560, 18, 11, "sans")
    end
    self:rule(612)
    self:text("Reading Room settings", 20, 632, 560, 35, 24, "bold")
    self:button("Home screen & covers →", 20, 684, 560, function() self.owner:options() end)
end

function View:footer()
    self:rule(745, true)
    self:text("Browse files", 20, 767, 180, 25, 14, "sans")
    self:hit(20, 753, 180, 47, function() self.owner:closeHome() end)
    self:text("Refresh", 220, 767, 160, 25, 14, "sans", "center")
    self:hit(220, 753, 160, 47, function() self:refresh() end)
    self:text("Search →", 400, 767, 180, 25, 14, "sans", "right")
    self:hit(400, 753, 180, 47, function() self:switch("discover") end)
end

function View:build()
    self:releaseWidgets()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.scale = math.min(self.dimen.w / 600, self.dimen.h / 800)
    self.offset_x = math.floor((self.dimen.w - 600 * self.scale) / 2)
    self.offset_y = math.floor((self.dimen.h - 800 * self.scale) / 2)
    self.display, self.targets = {}, {}
    self:header()
    self[self.section](self)
    self:footer()
    self.ges_events.Tap = { GestureRange:new{ ges = "tap", range = self.dimen } }
    self.ges_events.Hold = { GestureRange:new{ ges = "hold", range = self.dimen } }
    -- Widgets are cached for this screen, rather than recreated on each repaint.
    for _, item in ipairs(self.display) do
        if item.kind == "text" then
            item.widget = TextBoxWidget:new{
                text = item.text,
                face = self:face(item.style, item.size),
                width = math.max(1, math.floor(item.w * self.scale)),
                height = math.max(1, math.floor(item.h * self.scale)),
                line_height = 0.15,
                height_overflow_show_ellipsis = true,
                alignment = item.align,
                fgcolor = self:color(item.color or "ink"),
            }
            if item.center_y then
                local actual_height = item.widget:getSize().h / self.scale
                item.y = item.center_y + math.max(4, (item.center_h - actual_height) / 2)
            end
            self.widgets[#self.widgets + 1] = item
        elseif item.kind == "cover" then
            if G_reader_settings:nilOrTrue("readingroom_covers") and self.owner.ui.bookinfo then
                local ok, image = pcall(self.owner.ui.bookinfo.getCoverImage, self.owner.ui.bookinfo, nil, item.book.path)
                if ok and image then
                    item.widget = ImageWidget:new{
                        image = image, image_disposable = true,
                        width = math.floor(item.w * self.scale), height = math.floor(item.h * self.scale),
                        scale_factor = 0,
                    }
                    self.widgets[#self.widgets + 1] = item
                end
            end
            if not item.widget then
                item.widget = TextBoxWidget:new{
                    text = item.w < 60 and "BOOK" or item.book.title,
                    face = self:face("serif", item.w < 60 and 9 or 14),
                    width = math.max(1, math.floor((item.w - 8) * self.scale)),
                    height = math.max(1, math.floor((item.h - 12) * self.scale)),
                    height_overflow_show_ellipsis = true, alignment = "center",
                }
                item.fallback = true
                self.widgets[#self.widgets + 1] = item
            end
        end
    end
end

function View:color(name)
    if name == "accent" then
        return Screen:isColorEnabled() and Blitbuffer.ColorRGB32(45, 77, 94, 255) or Blitbuffer.COLOR_BLACK
    end
    if name == "light" then return Blitbuffer.COLOR_LIGHT_GRAY end
    if name == "muted" then return Blitbuffer.COLOR_DARK_GRAY end
    return Blitbuffer.COLOR_BLACK
end

function View:paintTo(bb, x, y)
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    self.dimen.x, self.dimen.y = x, y
    local s = self.scale
    for _, item in ipairs(self.display) do
        local px = x + self.offset_x + math.floor(item.x * s)
        local py = y + self.offset_y + math.floor(item.y * s)
        local w, h = math.floor(item.w * s), math.floor(item.h * s)
        if item.widget then
            if item.fallback then
                self:paintOutline(bb, px, py, w, h, self:color("ink"))
                item.widget:paintTo(bb, px + math.floor(4 * s), py + math.floor(6 * s))
            else item.widget:paintTo(bb, px, py) end
        elseif item.kind == "rect" then bb:paintRect(px, py, w, math.max(1, h), self:color(item.color))
        elseif item.kind == "outline" then self:paintOutline(bb, px, py, w, h, self:color(item.color)) end
    end
    -- Draw control outlines last so text backgrounds cannot erase their edges.
    for _, item in ipairs(self.display) do
        if item.kind == "outline" then
            self:paintOutline(bb, x + self.offset_x + math.floor(item.x * s),
                y + self.offset_y + math.floor(item.y * s), math.floor(item.w * s),
                math.floor(item.h * s), self:color(item.color))
        end
    end
end

function View:paintOutline(bb, x, y, w, h, color)
    local b = math.max(1, math.floor(self.scale))
    bb:paintRect(x, y, w, b, color)
    bb:paintRect(x, y + h - b, w, b, color)
    bb:paintRect(x, y, b, h, color)
    bb:paintRect(x + w - b, y, b, h, color)
end

function View:activate(ges, hold)
    local px = (ges.pos.x - self.dimen.x - self.offset_x) / self.scale
    local py = (ges.pos.y - self.dimen.y - self.offset_y) / self.scale
    for _, target in ipairs(self.targets) do
        if px >= target.x and px < target.x + target.w and py >= target.y and py < target.y + target.h then
            local callback = hold and target.hold or (not hold and target.callback)
            if callback then Integrations.run(callback) end
            return true
        end
    end
    return true
end

function View:onTap(_, ges) return self:activate(ges, false) end
function View:onHold(_, ges) return self:activate(ges, true) end
function View:onBack() self.owner:closeHome(); return true end
function View:onHome() return self:onBack() end
function View:onCloseWidget()
    self:releaseWidgets()
    if self.owner.home == self then self.owner.home = nil end
    UIManager:setDirty(nil, "ui")
end
function View:onShow()
    UIManager:setDirty(self, "full", nil, true)
    return true
end
function View:refresh()
    self:build()
    UIManager:setDirty(self, "full", nil, true)
end
function View:switch(section) self.section = section; self:refresh() end
function View:onSetDimensions() self:refresh(); return true end
function View:onResume() self:refresh(); return true end

return View
