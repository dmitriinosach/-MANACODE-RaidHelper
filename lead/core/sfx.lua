local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local SOUNDS = {
    open     = "igSpellBookOpen",
    tab      = "igCharacterInfoTab",
    click    = "igCharacterInfoTab",
    checkOn  = "igMainMenuOptionCheckBoxOn",
    checkOff = "igMainMenuOptionCheckBoxOff",
}
ns.Sfx = {}
function ns.Sfx.Ui(kind)
    local ref = SOUNDS[kind or "click"]
    if ref then ns.Compat.PlaySound(ref) end
end
