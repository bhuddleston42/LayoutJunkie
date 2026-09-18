local realPrint, output = print, {}
print = function(s) output[#output + 1] = tostring(s) end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
string.trim = function(s) return s:match("^%s*(.-)%s*$") end
format = string.format
local function clone(t)
    if type(t) ~= "table" then return t end
    local out = {}; for k, v in pairs(t) do out[k] = clone(v) end; return out
end
local combat, failSave, failExport, failActivate, full = false, false, false, false, false
local state, saves = { activeLayout = 1, layouts = {} }, 0
Enum = { EditModeLayoutType = { Account = 1, Character = 2 } }
InCombatLockdown = function() return combat end
local strings, serial = {}, 0
local function export(layout)
    if failExport then error("export failed") end
    for s, l in pairs(strings) do
        if l.layoutName == layout.layoutName and l.layoutType == layout.layoutType and l.payload == layout.payload then return s end
    end
    serial = serial + 1
    local s = "layout-" .. serial; strings[s] = clone(layout); return s
end
C_EditMode = {
    GetLayouts = function() return clone(state) end,
    ConvertLayoutInfoToString = export,
    ConvertStringToLayoutInfo = function(s) assert(strings[s], "invalid string"); return clone(strings[s]) end,
    SaveLayouts = function(data)
        saves = saves + 1
        if failSave then error("save failed") end
        if full and #data.layouts > #state.layouts then return end
        state = clone(data)
        -- Account layouts precede character layouts; appended index is not stable.
        table.sort(state.layouts, function(a, b) return a.layoutType < b.layoutType end)
    end,
    SetActiveLayout = function(index) if not failActivate then state.activeLayout = index end end,
}
local libs = {
    ["LibDataBroker-1.1"] = { NewDataObject = function(_, _, data) return data end },
    ["LibDBIcon-1.0"] = { Register = function() end, Hide = function() end, Show = function() end },
}
LibStub = function(name) return libs[name] end
local frame
CreateFrame = function()
    frame = { RegisterEvent = function() end, UnregisterEvent = function() end,
        SetScript = function(self, _, fn) self.onEvent = fn end }
    return frame
end
local ns = {}
assert(loadfile("Core.lua"))("LayoutJunkie", ns)
frame.onEvent(frame, "ADDON_LOADED", "LayoutJunkie")
local requestedReplacement
ns.ShowReplaceSlotDialog = function(index) requestedReplacement = index end
local a = export({layoutName = "A", layoutType = 1, payload = "A-new"})
local b = export({layoutName = "B", layoutType = 1, payload = "B-new"})
assert(not ns.AddLayoutFromString("bad", "broken"))
assert(#ns.db.layouts == 0)
assert(ns.AddLayoutFromString("A", a))
assert(ns.AddLayoutFromString("B", b))
combat = true; ns.ApplyLayout(2)
ns.DeleteLayout(1)
assert(saves == 0, "saved during combat")
combat = false; frame.onEvent(frame, "PLAYER_REGEN_ENABLED")
assert(state.layouts[1].layoutName == "B", "queue followed shifted index")
assert(state.activeLayout == 3)
combat = true; ns.ApplyLayout(1); ns.DeleteLayout(1)
combat = false; frame.onEvent(frame, "PLAYER_REGEN_ENABLED")
assert(ns.pendingLayout == nil)
ns.AddLayoutFromString("A", a)
state = { activeLayout = 1, layouts = {{layoutName = "A", layoutType = 1, payload = "old"}} }
ns.ApplyLayout(1)
assert(state.layouts[1].payload == "A-new")
assert(#ns.db.layouts == 2 and ns.db.layouts[2].name == "A (backup 1)")
assert(strings[ns.db.layouts[2].importString].payload == "old", "namesake lost original")
state.layouts[1].payload = "unsaved"
failExport = true
local before = saves; ns.ApplyLayout(1); assert(saves == before)
failExport = false; failSave = true; output = {}
ns.ApplyLayout(1)
assert(not table.concat(output):find("Applied layout", 1, true), "false save success")
failSave = false; failActivate = true; state.activeLayout = 1; output = {}
ns.ApplyLayout(1)
assert(not table.concat(output):find("Applied layout", 1, true), "false activation success")
failActivate = false
state = {activeLayout = 1, layouts = {{layoutName = "Character", layoutType = 2, payload = "char"}}}
ns.ApplyLayout(1)
assert(state.activeLayout == 3 and state.layouts[1].layoutName == "A", "wrong appended slot")
full = true; ns.AddLayoutFromString("B", b)
ns.ApplyLayout(#ns.db.layouts)
assert(requestedReplacement == #ns.db.layouts)
local expected = export(state.layouts[1]); state.layouts[1].payload = "changed"
before = saves; ns.ReplaceSlot(1, 1, expected); assert(saves == before, "stale slot replaced")
combat = true; ns.ReplaceSlot(1, 1); assert(saves == before)
combat = false; ns.ClearAllLayouts(); assert(not ns.pendingLayout)

-- Use only the current popup methods: obsolete .editBox/.text fields are absent.
StaticPopupDialogs, SlashCmdList, UIParent = {}, {}, {}
local shown, compartment
StaticPopup_Show = function(which, name) shown = {which, name} end
AddonCompartmentFrame = {RegisterAddon = function(_, data) compartment = data end}
MenuUtil = {CreateContextMenu = function() end}
assert(loadfile("UI.lua"))("LayoutJunkie", ns)
local text = " Popup name "
local popup = {GetEditBox = function() return {GetText = function() return text end,
    SetMaxLetters = function(_, n) assert(n == 0) end, SetFocus = function() end} end}
StaticPopupDialogs.LAYOUTJUNKIE_IMPORT_NAME.OnAccept(popup)
assert(shown[1] == "LAYOUTJUNKIE_IMPORT_STRING" and shown[2] == "Popup name")
text = a
StaticPopupDialogs.LAYOUTJUNKIE_IMPORT_STRING.OnShow(popup)
StaticPopupDialogs.LAYOUTJUNKIE_IMPORT_STRING.OnAccept(popup)
assert(ns.db.layouts[1].name == "Popup name")
local clicked
ns.ShowConfigMenu = function(anchor) assert(anchor == AddonCompartmentFrame); clicked = "right" end
ns.ShowLayoutMenu = function(anchor) assert(anchor == AddonCompartmentFrame); clicked = "left" end
compartment.func(nil, {buttonName = "RightButton"}); assert(clicked == "right")
compartment.func(nil, {buttonName = "LeftButton"}); assert(clicked == "left")
realPrint("LayoutJunkie regression checks passed")
