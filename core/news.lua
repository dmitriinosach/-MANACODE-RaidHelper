local _, ns = ...
local News = {}
ns.News = News
local due = false
local function Saved()
    local db = ns.GetDB()
    local s = type(db) == "table" and db.settings
    if type(s) ~= "table" then return nil end
    return s
end
local function HasIso()
    local D = ns.news
    for i = 1, #(D and D.steps or {}) do
        if D.steps[i].where == "iso" then return true end
    end
    return false
end
function News.Due(seen, cur, after)
    local V = ns.Version
    if not (seen and cur and after) then return false end
    local a, b = V.Compare(seen, after), V.Compare(after, cur)
    return a ~= nil and b ~= nil and a <= 0 and b < 0
end
function News.Login(prev)
    local V = ns.Version
    local s, cur = Saved(), V.Mine()
    due = false
    if not s or not cur then return end
    local seen = V.Parse(s.newsSeen) and s.newsSeen or nil
    if not seen and V.Parse(prev) then seen = prev end
    if not seen then
        s.newsSeen, s.newsIso = cur, nil
        return
    end
    s.newsSeen = seen
    local D = ns.news
    if D and #D.rows > 0 and News.Due(seen, cur, D.after) then
        due = true
        s.newsIso = HasIso() and cur or nil
        return
    end
    if s.newsIso ~= cur then s.newsIso = nil end
    if (V.Compare(cur, seen) or 0) > 0 then s.newsSeen = cur end
end
function News.Pending()
    return due
end
function News.Seen()
    due = false
    local s, cur = Saved(), ns.Version.Mine()
    if s and cur then s.newsSeen = cur end
end
function News.IsoPending()
    local s, cur = Saved(), ns.Version.Mine()
    return s ~= nil and cur ~= nil and s.newsIso == cur
end
function News.IsoSeen()
    local s = Saved()
    if s then s.newsIso = nil end
end
ns.OnReady(function()
    News.Login(ns.PrevAddon and ns.PrevAddon())
end)
