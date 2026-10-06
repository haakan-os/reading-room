"""Run with LuaJIT via lupa. UI doubles validate behavior, not device rendering."""
import json
import os
from pathlib import Path
import sys

if os.environ.get("READINGROOM_TEST_DEPS"):
    sys.path.insert(0, os.environ["READINGROOM_TEST_DEPS"])
from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "readingroom.koplugin"
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
local Class = {}
function Class:extend(values) return setmetatable(values or {}, { __index = self }) end
function Class:new(values)
    local obj = self:extend(values or {})
    if obj._init then obj:_init() end
    if obj.init then obj:init() end
    return obj
end
function Class:_init() self.key_events = {}; self.ges_events = {} end
function Class:free() assert(not self.freed, "Double free"); self.freed = true end
package.preload["ui/widget/container/widgetcontainer"] = function() return Class end
package.preload["ui/widget/container/inputcontainer"] = function() return Class end
package.preload["ui/geometry"] = function() return Class end
package.preload["ui/gesturerange"] = function() return Class end
local text = Class:extend()
function text:init()
    assert(self.width > 0 and (not self.height or self.height > 0))
    assert(type(self.text) == "string")
    local lines = math.max(1, math.ceil(#self.text * self.face.size * .52 / self.width))
    self.rendered_height = math.min(lines * self.face.size * 1.15, self.height or math.huge)
end
function text:getSize() return {w=self.width, h=self.rendered_height} end
function text:paintTo() end
package.preload["ui/widget/textboxwidget"] = function() return text end
package.preload["ui/widget/imagewidget"] = function() return text end
package.preload["ui/font"] = function() return {getFace = function(_, name, size) return {name=name, size=screen:scaleBySize(size)} end} end
settings_data = {}
G_reader_settings = {
    readSetting = function(_, key, fallback) local value=settings_data[key]; if value == nil then return fallback end; return value end,
    saveSetting = function(_, key, value) settings_data[key]=value end,
    isTrue = function(_, key) return settings_data[key] == true end,
    nilOrTrue = function(_, key) return settings_data[key] ~= false end,
    flipNilOrTrue = function(_, key) settings_data[key] = settings_data[key] == false end,
    flipNilOrFalse = function(_, key) settings_data[key] = settings_data[key] ~= true end,
}
screen = {
    width=1264, height=1680,
    getWidth=function(self) return self.width end,
    getHeight=function(self) return self.height end,
    scaleBySize=function(_, size) return size * 2 end,
    isColorEnabled=function() return true end,
}
package.preload["device"] = function() return {screen=screen, getPowerDevice=function() return {getCapacity=function() return 82 end} end} end
local ui = {shown={}, closed={}, dirty={}}
function ui:show(widget) self.shown[#self.shown+1]=widget end
function ui:close(widget) self.closed[#self.closed+1]=widget; if widget.onCloseWidget then widget:onCloseWidget() end end
function ui:nextTick(fn) fn() end
function ui:scheduleIn(_, fn) fn() end
function ui:setDirty(...) self.dirty[#self.dirty+1]={...} end
package.preload["ui/uimanager"] = function() return ui end
UI = ui
package.preload["ui/widget/infomessage"] = function() return Class end
package.preload["ui/widget/touchmenu"] = function() return Class end
package.preload["ui/widget/buttondialog"] = function() return Class end
package.preload["dispatcher"] = function() return {registerAction=function() end} end
package.preload["ffi/blitbuffer"] = function() return {COLOR_WHITE="white", COLOR_BLACK="ink", COLOR_LIGHT_GRAY="light", COLOR_DARK_GRAY="muted", ColorRGB32=function() return "accent" end} end
metadata = {}
files = {}
package.preload["libs/libkoreader-lfs"] = function() return {attributes=function(path) return files[path] and "file" or nil end} end
package.preload["docsettings"] = function() return {open=function(_, path) return {data=metadata[path] or {}} end} end
history = {hist={}}
package.preload["readhistory"] = function() return history end
collections = {coll={}}
package.preload["readcollection"] = function() return collections end
opened = {}
package.preload["apps/filemanager/filemanagerutil"] = function() return {
    openFile=function(ui, path, _, _, callback)
        opened[#opened+1]=path
        if callback then callback(next_reader) end
    end,
} end
function makeUI()
    return {
        menu={registerToMainMenu=function() end},
        registerPostInitCallback=function(self, fn) self.post_init=fn end,
        file_chooser={},
        history={onShowHist=function() last_action="history" end},
        bookinfo={getCoverImage=function() return nil end, show=function() last_action="info" end},
        collections={
            getCollectionTitle=function(_, name) return name end,
            onShowColl=function(_, name) last_action=name end,
            onShowCollList=function() last_action="collections" end,
        },
        filesearcher={onShowFileSearch=function() last_action="local_search" end},
    }
end
function sampleBooks()
    metadata = {}; files = {}; history.hist = {}
    local entries = {
        {"The Dispossessed", "Ursula K. Le Guin", .42},
        {"Piranesi", "Susanna Clarke", .18},
        {"A Psalm for the Wild-Built", "Becky Chambers", .67},
        {"The Left Hand of Darkness", "Ursula K. Le Guin", .12},
    }
    for i, values in ipairs(entries) do
        local path="/books/"..i..".epub"
        files[path]=true
        metadata[path]={doc_props={title=values[1], authors=values[2]}, percent_finished=values[3], summary={status="reading"}}
        history.hist[i]={file=path}
    end
    settings_data.lastfile="/books/1.epub"
    collections.coll={ ["Science fiction"]={["/books/1.epub"]=true,["/books/4.epub"]=true}, ["On my nightstand"]={["/books/2.epub"]=true}, ["Finished"]={} }
end
''')
lua.execute(f'package.path = package.path .. ";{PLUGIN}/?.lua"')
lua.globals().ReadingRoom = lua.execute((PLUGIN / "main.lua").read_text(), name="@" + str(PLUGIN / "main.lua"))

def check(name, source):
    lua.execute(source)
    print("PASS", name)

check("history, missing files, duplicate removal, progress clamp", '''
sampleBooks()
local Library=require("readingroom_library")
history.hist[5]={file="/books/missing.epub"}
history.hist[6]={file="/books/1.epub"}
assert(#Library:recent(20, "/books/1.epub") == 4)
metadata["/books/2.epub"].percent_finished=2
assert(Library:book("/books/2.epub").progress==1)
metadata["/books/2.epub"].percent_finished=-1
assert(Library:book("/books/2.epub").progress==0)
assert(Library:book("/books/missing.epub")==nil)
metadata["/books/3.epub"].summary.status="complete"
assert(#Library:activeShelf(5)==3)
assert(#Library:activeShelf(1)==1)
''')
check("all screens, hit targets, rotation and paint", '''
sampleBooks()
owner=ReadingRoom:new{ui=makeUI()}
owner:onReadingRoom()
for _, dimensions in ipairs({{1264,1680},{600,800},{1680,1264}}) do
    screen.width, screen.height=dimensions[1], dimensions[2]
    for _, section in ipairs({"library","collections","discover","tools"}) do
        owner.home:switch(section)
        for _, target in ipairs(owner.home.targets) do
            assert(target.w>=44 and target.h>=44, "Small touch target")
            assert(target.x>=0 and target.y>=0 and target.x+target.w<=600 and target.y+target.h<=800, "Target outside screen")
        end
        owner.home:paintTo({paintRect=function(_, x,y,w,h) assert(w>=0 and h>=0) end},0,0)
    end
end
screen.width, screen.height=1264,1680
owner.home:switch("library")
owner.home:onTap(nil,{pos={x=480*owner.home.scale+owner.home.offset_x,y=151*owner.home.scale+owner.home.offset_y}})
assert(owner.home.section=="tools")
owner:closeHome()
assert(owner.home==nil)
''')
check("empty library and stale-book handling", '''
metadata={}; files={}; history.hist={}; settings_data.lastfile=nil
owner:onReadingRoom()
assert(owner.home.display[1])
owner:openBook({path="missing"})
assert(owner.home~=nil)
owner:closeHome()
''')
check("measured titles, missing authors and fractional DPI keep library rows within bounds", '''
sampleBooks()
local old_scale = screen.scaleBySize
screen.scaleBySize=function(_, value) return math.floor(value*2.63+.5) end
metadata["/books/1.epub"].doc_props.title="A Very Long Book Title That Needs To Wrap Across Several Lines Of The Feature"
metadata["/books/1.epub"].doc_props.authors="One Author With A Long Name And Another Author With A Long Name"
metadata["/books/4.epub"].doc_props.authors=""
owner:onReadingRoom()
local title, author, progress
for _, item in ipairs(owner.home.display) do
    if item.text==metadata["/books/1.epub"].doc_props.title then title=item end
    if item.text==metadata["/books/1.epub"].doc_props.authors then author=item end
    if item.text=="42% complete" then progress=item end
    if item.kind=="text" then
        assert(item.widget:getSize().h/owner.home.scale <= item.h+1, "Text exceeds allocated height")
        assert(math.abs(item.widget.face.size-item.size*owner.home.scale)<=1, "DPI rounding changed font size")
    end
    if item.kind=="cover" then assert(item.y+item.h<=735) end
end
assert(title.y+title.h<=author.y and author.y+author.h<=progress.y)
owner:closeHome()
sampleBooks(); metadata["/books/4.epub"].doc_props.authors=""
owner:onReadingRoom()
for _, item in ipairs(owner.home.display) do
    assert(item.kind~="text" or item.text~="", "Empty author should not reserve a text box")
end
owner:closeHome()
screen.scaleBySize=old_scale
''')
check("missing plugins and local search", '''
owner:zlibrary()
assert(UI.shown[#UI.shown].text:find("Install"))
owner:syncShelf()
assert(UI.shown[#UI.shown].text:find("Install"))
owner:searchLocal(); assert(last_action=="local_search")
''')
check("Z-library tabs and settings reuse", '''
owner.ui.zlibrary={
    showMultiSearchDialog=function(_, tab) last_tab=tab or "search" end,
    showMyBooksDialog=function(_, tab) last_tab="mybooks" end,
    addToMainMenu=function(_, items) items.zlibrary={sub_item_table={{text="Settings"}}} end,
}
owner:zlibrary(); assert(last_tab=="search")
owner:zlibrary(2); assert(last_tab==2)
owner:zlibrary(1); assert(last_tab==1)
owner:zlibrary("mybooks"); assert(last_tab=="mybooks")
owner:zlibrary("settings"); assert(UI.shown[#UI.shown].tab_item_table[1][1].text=="Settings")
''')
check("AO3 missing-plugin guidance and native callable-handler delegation", '''
owner:ao3()
assert(UI.shown[#UI.shown].text:find("AO3Downloader"))
local plugin={DownloadFanfic=function() end}
plugin.onOpenAO3DownloaderMenu=setmetatable({}, {__call=function(_, self)
    assert(self==plugin); last_action="ao3_menu"
end})
owner.ui.AO3Downloader=plugin
owner:ao3(); assert(last_action=="ao3_menu")
local bridge=require("readingroom_integrations")
assert(bridge.find({plugin},"ao3")==plugin)
''')
check("AO3 from a reader uses the new file-manager plugin instance", '''
local current=makeUI()
local stale={DownloadFanfic=function() end, onOpenAO3DownloaderMenu=function() error("Stale reader instance") end}
current.document={file="/books/1.epub"}; current.file_chooser=nil; current.AO3Downloader=stale
local filemanager=makeUI()
filemanager.AO3Downloader={onOpenAO3DownloaderMenu=function() last_action="fresh_ao3" end}
local manager={instance=nil}
package.preload["apps/filemanager/filemanager"]=function() return manager end
current.onHome=function() manager.instance=filemanager; last_action="returned_home" end
local reader_owner=ReadingRoom:new{ui=current}
reader_owner:onReadingRoom()
reader_owner:ao3()
assert(reader_owner.home==nil and last_action=="fresh_ao3")
''')
check("BuddySync shelf action is delegated without compatibility patches", '''
sampleBooks()
local buddy={settings={shelf_sync_limit=2}, syncActiveShelf=function(self) shelf_called=self end}
local Integrations=require("readingroom_integrations")
Integrations.syncShelf(buddy)
assert(shelf_called==buddy)
assert(buddy.getCurrentlyReadingBooks==nil and history.history==nil)
''')
check("open selected book then invoke reader's BuddySync or KOSync", '''
sampleBooks()
next_reader=makeUI()
next_reader.buddysync={sendCurrentBook=function() last_action="sent" end}
next_reader.kosync={addToMainMenu=function(_, items) items.kosync={sub_item_table={{text="Progress sync"}}} end}
owner:withBookPlugin({path="/books/2.epub"},"buddy","sendCurrentBook")
assert(opened[#opened]=="/books/2.epub" and last_action=="sent")
owner:withBookPlugin({path="/books/2.epub"},"kosync")
assert(UI.shown[#UI.shown].tab_item_table[1][1].text=="Progress sync")
owner.ui.document={file="/books/2.epub"}
owner.ui.buddysync=next_reader.buddysync
last_action=nil
owner:withBookPlugin({path="/books/2.epub"},"buddy","sendCurrentBook")
assert(last_action=="sent")
owner.ui.document=nil
''')
check("startup remains opt-in and persisted settings toggle", '''
settings_data.readingroom_home=nil
local fresh=ReadingRoom:new{ui=makeUI()}
fresh.ui.post_init(); assert(fresh.home==nil)
local menu={}; fresh:addToMainMenu(menu)
menu.readingroom.sub_item_table[2].callback()
fresh.ui.post_init(); assert(fresh.home~=nil)
fresh:closeHome(); settings_data.readingroom_home=nil
''')
check("exceptions are contained without exposing account details", '''
local bridge=require("readingroom_integrations")
assert(not bridge.run(function() error("secret-session-token") end))
assert(not UI.shown[#UI.shown].text:find("secret"))
''')

if len(sys.argv) > 1:
    buddy_source = Path(sys.argv[1])
    lua.execute('''
    local Class=package.loaded["ui/widget/container/widgetcontainer"]
    for _, name in ipairs({"ui/widget/inputdialog","ui/widget/notification"}) do
        package.preload[name]=function() return Class end
    end
    package.preload["luasettings"]=function() return {} end
    package.preload["datastorage"]=function() return {} end
    package.preload["logger"]=function() return {warn=function() end,dbg=function() end} end
    package.preload["gettext"]=function() return function(s) return s end end
    for _, name in ipairs({"epub_optimizer","sync_client","notes_exporter"}) do
        package.preload[name]=function() return {} end
    end
    ''')
    lua.globals().ActualBuddy = lua.execute(buddy_source.read_text(), name="@" + str(buddy_source))
    check("updated BuddySync source reads current history and receives delegated shelf action", '''
    sampleBooks()
    local uploaded={}
    local buddy=ActualBuddy:extend{
        settings={shelf_sync_limit=2,optimize_epub=false,sync_notes_with_books=false},
        client={uploadBookToX3=function(_, path) uploaded[#uploaded+1]=path; return true end},
    }
    owner.ui.buddysync=buddy
    owner:syncShelf()
    assert(#uploaded==2 and uploaded[1]=="/books/1.epub" and uploaded[2]=="/books/2.epub")
    assert(history.history==nil)
    ''')

# Export the plugin's own display list for the standalone preview.
lua.execute('''sampleBooks(); owner=ReadingRoom:new{ui=makeUI()};
owner.ui.buddysync={settings={shelf_sync_limit=5},sendCurrentBook=function() end};
owner.ui.zlibrary={showMultiSearchDialog=function() end};
owner.ui.AO3Downloader={DownloadFanfic=function() end}; owner:onReadingRoom()''')
scenes = {}
for section in ("library", "collections", "discover", "tools"):
    lua.execute(f'owner.home:switch("{section}")')
    items = []
    for _, item in lua.globals().owner.home.display.items():
        entry = {k: item[k] for k in ("kind", "x", "y", "w", "h", "text", "size", "style", "align", "color") if item[k] is not None}
        if item["book"]:
            entry["title"] = item["book"]["title"]
        items.append(entry)
    targets = []
    for _, target in lua.globals().owner.home.targets.items():
        targets.append({k: target[k] for k in ("x", "y", "w", "h")})
    scenes[section] = {"items": items, "targets": targets}
(ROOT / "preview-scenes.json").write_text(json.dumps(scenes, ensure_ascii=False, indent=2))
print("Exported preview scenes from native Lua layout.")
