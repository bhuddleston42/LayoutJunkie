local addon, ns = ...

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

-- ---------------------------------------------------------------------------
-- Saved variables & defaults
-- ---------------------------------------------------------------------------
local defaults = {
    layouts = {},       -- { { name = string, importString = string }, ... }
    minimap = { hide = false },
}

-- ---------------------------------------------------------------------------
-- Event handling
-- ---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addon then
        LayoutJunkieDB = LayoutJunkieDB or {}
        for k, v in pairs(defaults) do
            if LayoutJunkieDB[k] == nil then
                LayoutJunkieDB[k] = v
            end
        end
        ns.db = LayoutJunkieDB
        LDBIcon:Register(addon, ns.dataObj, ns.db.minimap)
        frame:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.pendingLayout then
            local entry = ns.pendingLayout
            ns.pendingLayout = nil
            for idx, saved in ipairs(ns.db.layouts) do
                if saved == entry then ns.ApplyLayout(idx); break end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- LDB data object
-- ---------------------------------------------------------------------------
ns.dataObj = LDB:NewDataObject(addon, {
    type = "launcher",
    text = "LayoutJunkie",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",

    OnClick = function(self, button)
        if button == "LeftButton" then
            ns.ShowLayoutMenu(self)
        elseif button == "RightButton" then
            ns.ShowConfigMenu(self)
        end
    end,

    OnTooltipShow = function(tt)
        tt:SetText("LayoutJunkie")
        tt:AddLine("Infinite Edit Mode Slots for the UI Degenerate", 0.6, 0.6, 0.6)
        tt:AddLine(" ")

        local count = ns.db and #ns.db.layouts or 0
        tt:AddDoubleLine("Saved Layouts:", tostring(count), 1, 0.82, 0, 1, 1, 1)

        -- Show active in-game layout
        local ok, layoutData = pcall(C_EditMode.GetLayouts)
        if ok and type(layoutData) == "table" and type(layoutData.activeLayout) == "number"
            and type(layoutData.layouts) == "table" then
            local activeName = "Unknown"
            local activeIdx = layoutData.activeLayout
            if activeIdx <= 2 then
                local presets = { "Modern", "Classic" }
                activeName = presets[activeIdx] or activeName
            else
                local customIdx = activeIdx - 2
                local custom = layoutData.layouts[customIdx]
                if custom then
                    activeName = custom.layoutName or ("Custom " .. customIdx)
                end
            end
            tt:AddDoubleLine("Active Layout:", activeName, 1, 0.82, 0, 1, 1, 1)
        end

        tt:AddLine(" ")
        tt:AddLine("|cff00ff00Left-Click|r  Switch layout", 0.7, 0.7, 0.7)
        tt:AddLine("|cff00ff00Right-Click|r  Import / manage", 0.7, 0.7, 0.7)
    end,
})

-- ---------------------------------------------------------------------------
-- Layout operations
-- ---------------------------------------------------------------------------
local PRESET_OFFSET = 2 -- Modern + Classic presets

function ns.GetGameLayouts()
    local ok, data = pcall(C_EditMode.GetLayouts)
    if ok and type(data) == "table" and type(data.layouts) == "table" then return data end
    print("|cffFF4444LayoutJunkie:|r Could not read Edit Mode layouts.")
end

local function SaveLayouts(data)
    local ok, err = pcall(C_EditMode.SaveLayouts, data)
    if not ok then print("|cffFF4444LayoutJunkie:|r Save failed: " .. tostring(err)) end
    return ok
end

local function ActivateSlot(index, name)
    local ok, err = pcall(C_EditMode.SetActiveLayout, index + PRESET_OFFSET)
    local data = ok and ns.GetGameLayouts()
    if not ok or not data or data.activeLayout ~= index + PRESET_OFFSET then
        print("|cffFF4444LayoutJunkie:|r Could not activate layout '" .. name .. "'." .. (not ok and (" " .. tostring(err)) or ""))
        return false
    end
    print("|cff00FF00LayoutJunkie:|r Applied layout '" .. name .. "'.")
    return true
end

local function CanApply(entry)
    if InCombatLockdown() then
        -- Keep the entry itself: deleting another layout must not change the queued target.
        ns.pendingLayout = entry
        print("|cffFFD100LayoutJunkie:|r In combat -- layout will apply when combat ends.")
        return false
    end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        print("|cffFFD100LayoutJunkie:|r Close Edit Mode before switching layouts.")
        return false
    end
    return true
end

-- Save by content, not just name. A namesake in the library is not a backup.
local function BackupSlot(layout, slotIdx)
    local ok, exportStr = pcall(C_EditMode.ConvertLayoutInfoToString, layout)
    if not ok or type(exportStr) ~= "string" or exportStr == "" then
        print("|cffFF4444LayoutJunkie:|r Could not back up the existing layout; replacement cancelled.")
        return false
    end
    local names = {}
    for _, saved in ipairs(ns.db.layouts) do
        if saved.importString == exportStr then return true end
        names[saved.name:lower()] = true
    end
    local base = layout.layoutName or ("Custom Layout " .. slotIdx)
    local name, suffix = base, 1
    while names[name:lower()] do
        name = base .. " (backup " .. suffix .. ")"
        suffix = suffix + 1
    end
    table.insert(ns.db.layouts, { name = name, importString = exportStr })
    print("|cff00FF00LayoutJunkie:|r Auto-saved '" .. name .. "' before replacing.")
    return true
end

-- Try to append a new slot. Returns slot index if it fit, nil if at cap.
local function tryAppendSlot(imported, name, layoutType)
    local editModeLayouts = ns.GetGameLayouts()
    if not editModeLayouts then return nil, true end
    local countBefore = #editModeLayouts.layouts

    imported.layoutName = name
    imported.layoutType = layoutType
    table.insert(editModeLayouts.layouts, imported)

    if not SaveLayouts(editModeLayouts) then return nil, true end

    -- SaveLayouts silently drops at cap -- verify by count
    local verify = ns.GetGameLayouts()
    if not verify then return nil, true end
    if #verify.layouts > countBefore then
        for i, layout in ipairs(verify.layouts) do
            if layout.layoutName == name and layout.layoutType == layoutType then return i end
        end
    end
    return nil
end

-- Replace a specific slot's contents (used by claim dialog)
function ns.ReplaceSlot(slotIdx, pendingApplyIdx, expectedSlot)
    local entry = ns.db.layouts[pendingApplyIdx]
    if not entry then return end
    if not CanApply(entry) then return end

    local ok, imported = pcall(C_EditMode.ConvertStringToLayoutInfo, entry.importString)
    if not ok or type(imported) ~= "table" then
        print("|cffFF4444LayoutJunkie:|r Invalid layout string for '" .. entry.name .. "'.")
        return
    end

    local editModeLayouts = ns.GetGameLayouts()
    if not editModeLayouts then return end
    local oldSlot = editModeLayouts.layouts[slotIdx]
    if not oldSlot then return end

    -- A menu can remain open while another addon changes the slots.
    local exported, currentSlot = pcall(C_EditMode.ConvertLayoutInfoToString, oldSlot)
    if expectedSlot and (not exported or currentSlot ~= expectedSlot) then
        print("|cffFFD100LayoutJunkie:|r Edit Mode layouts changed; choose a slot again.")
        ns.ShowReplaceSlotDialog(pendingApplyIdx)
        return
    end

    -- Auto-save the slot's existing layout before overwriting
    if not BackupSlot(oldSlot, slotIdx) then return end

    -- Overwrite with the new layout, keeping the slot's existing type
    imported.layoutName = entry.name
    imported.layoutType = oldSlot.layoutType or Enum.EditModeLayoutType.Account
    editModeLayouts.layouts[slotIdx] = imported

    if not SaveLayouts(editModeLayouts) then return end
    ActivateSlot(slotIdx, entry.name)
end

function ns.ApplyLayout(index)
    local entry = ns.db.layouts[index]
    if not entry then return end

    if not CanApply(entry) then return end

    local ok, imported = pcall(C_EditMode.ConvertStringToLayoutInfo, entry.importString)
    if not ok or type(imported) ~= "table" then
        print("|cffFF4444LayoutJunkie:|r Invalid layout string for '" .. entry.name .. "'.")
        return
    end

    -- If a slot with this name already exists, just activate it (avoid duplicates)
    local editModeLayouts = ns.GetGameLayouts()
    if not editModeLayouts then return end
    for i, l in ipairs(editModeLayouts.layouts) do
        if type(l) == "table" and l.layoutName == entry.name then
            -- Overwrite data so it matches our stored version, then activate
            imported.layoutName = entry.name
            imported.layoutType = l.layoutType or Enum.EditModeLayoutType.Account
            editModeLayouts.layouts[i] = imported
            if not BackupSlot(l, i) then return end
            if not SaveLayouts(editModeLayouts) then return end
            ActivateSlot(i, entry.name)
            return
        end
    end

    -- Try an open Account slot first, then Character
    local newIdx, failed = tryAppendSlot(imported, entry.name, Enum.EditModeLayoutType.Account)
    if failed then return end
    if not newIdx then
        newIdx, failed = tryAppendSlot(imported, entry.name, Enum.EditModeLayoutType.Character)
        if failed then return end
    end

    if newIdx then
        ActivateSlot(newIdx, entry.name)
        return
    end

    -- All slots full -- ask which to replace
    ns.ShowReplaceSlotDialog(index)
end

function ns.ImportFromGame()
    local layoutData = ns.GetGameLayouts()
    if not layoutData then return end

    -- Build a set of existing names to skip duplicates
    local existingNames = {}
    for _, entry in ipairs(ns.db.layouts) do
        existingNames[entry.name:lower()] = true
    end

    local imported = 0
    for i, layout in ipairs(layoutData.layouts) do
        local name = layout.layoutName or ("Custom Layout " .. i)
        if not existingNames[name:lower()] then
            local ok, exportStr = pcall(C_EditMode.ConvertLayoutInfoToString, layout)
            if ok and type(exportStr) == "string" and exportStr ~= "" then
                table.insert(ns.db.layouts, {
                    name = name,
                    importString = exportStr,
                })
                existingNames[name:lower()] = true
                imported = imported + 1
            end
        end
    end

    if imported > 0 then
        print("|cff00FF00LayoutJunkie:|r Imported " .. imported .. " layout(s) from Edit Mode.")
    else
        print("|cffFFD100LayoutJunkie:|r No new layouts found to import.")
    end
end

function ns.AddLayoutFromString(name, importStr)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then name = "Unnamed Layout" end
    local ok, layoutInfo = pcall(C_EditMode.ConvertStringToLayoutInfo, importStr)
    if not ok or type(layoutInfo) ~= "table" then
        print("|cffFF4444LayoutJunkie:|r Invalid import string.")
        return false
    end

    table.insert(ns.db.layouts, {
        name = name,
        importString = importStr,
    })
    print("|cff00FF00LayoutJunkie:|r Saved layout '" .. name .. "'.")
    return true
end

function ns.DeleteLayout(index)
    local entry = ns.db.layouts[index]
    if entry then
        if ns.pendingLayout == entry then ns.pendingLayout = nil end
        local name = entry.name
        table.remove(ns.db.layouts, index)
        print("|cff00FF00LayoutJunkie:|r Deleted layout '" .. name .. "'.")
    end
end

function ns.ClearAllLayouts()
    ns.pendingLayout = nil
    local count = #ns.db.layouts
    wipe(ns.db.layouts)
    print("|cff00FF00LayoutJunkie:|r Cleared " .. count .. " saved layout(s).")
end

function ns.RenameLayout(index, newName)
    local entry = ns.db.layouts[index]
    if entry then
        local oldName = entry.name
        entry.name = newName
        print("|cff00FF00LayoutJunkie:|r Renamed '" .. oldName .. "' to '" .. newName .. "'.")
    end
end
