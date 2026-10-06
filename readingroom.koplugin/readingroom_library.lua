local DocSettings = require("docsettings")
local ReadHistory = require("readhistory")
local lfs = require("libs/libkoreader-lfs")

local Library = {}

function Library:book(path)
    if type(path) ~= "string" or lfs.attributes(path, "mode") ~= "file" then return end
    local ok, settings = pcall(DocSettings.open, DocSettings, path)
    local data = ok and settings and settings.data or {}
    local props = data.doc_props or {}
    local filename = path:match("([^/]+)$") or path
    local progress = tonumber(data.percent_finished)
    if progress then progress = math.max(0, math.min(1, progress)) end
    local authors = props.authors
    if type(authors) == "table" then authors = table.concat(authors, ", ") end
    return {
        path = path,
        title = props.title and props.title ~= "" and props.title or filename:gsub("%.[^%.]+$", ""),
        author = type(authors) == "string" and authors or "",
        progress = progress,
        status = (data.summary or {}).status or "reading",
    }
end

function Library:recent(limit, preferred_path)
    local books, seen = {}, {}
    local function add(path)
        if not path or seen[path] or #books >= limit then return end
        seen[path] = true
        local book = self:book(path)
        if book then books[#books + 1] = book end
    end
    add(preferred_path)
    -- Current KOReader uses hist/file; tolerate older companion formats too.
    for _, entry in ipairs(ReadHistory.hist or ReadHistory.history or {}) do
        add(entry.file or entry.path)
    end
    return books
end

function Library:activeShelf(limit)
    local active = {}
    for _, book in ipairs(self:recent(500)) do
        local extension = book.path:lower():match("%.([^%.]+)$")
        if (extension == "epub" or extension == "txt")
            and book.status ~= "complete" and book.status ~= "abandoned"
            and (book.status == "reading" or (book.progress and book.progress > 0 and book.progress < 0.99)) then
            active[#active + 1] = book
            if #active >= limit then break end
        end
    end
    return active
end

function Library.progressLabel(book)
    if book.progress == nil then return "Not started" end
    return string.format("%d%% complete", math.floor(book.progress * 100 + 0.5))
end

return Library
