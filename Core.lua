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
            local idx = ns.pendingLayout
            ns.pendingLayout = nil
            ns.ApplyLayout(idx)
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
        if ok and layoutData then
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

-- Try to append a new slot. Returns slot index if it fit, nil if at cap.
local function tryAppendSlot(imported, name, layoutType)
    local editModeLayouts = C_EditMode.GetLayouts()
    local countBefore = #editModeLayouts.layouts

    imported.layoutName = name
    imported.layoutType = layoutType
    table.insert(editModeLayouts.layouts, imported)

    pcall(C_EditMode.SaveLayouts, editModeLayouts)

    -- SaveLayouts silently drops at cap -- verify by count
    local verify = C_EditMode.GetLayouts()
    if #verify.layouts > countBefore then
        return #verify.layouts
    end
    return nil
end

-- Replace a specific slot's contents (used by claim dialog)
function ns.ReplaceSlot(slotIdx, pendingApplyIdx)
    local entry = ns.db.layouts[pendingApplyIdx]
    if not entry then return end

    local ok, imported = pcall(C_EditMode.ConvertStringToLayoutInfo, entry.importString)
    if not ok or type(imported) ~= "table" then
        print("|cffFF4444LayoutJunkie:|r Invalid layout string for '" .. entry.name .. "'.")
        return
    end

    local editModeLayouts = C_EditMode.GetLayouts()
    local oldSlot = editModeLayouts.layouts[slotIdx]
    if not oldSlot then return end

    -- Auto-save the slot's existing layout before overwriting
    local exportStr = C_EditMode.ConvertLayoutInfoToString(oldSlot)
    if exportStr then
        local origName = oldSlot.layoutName or ("Custom Layout " .. slotIdx)
        local existingNames = {}
        for _, e in ipairs(ns.db.layouts) do
            existingNames[e.name:lower()] = true
        end
        if not existingNames[origName:lower()] then
            table.insert(ns.db.layouts, {
                name = origName,
                importString = exportStr,
            })
            print("|cff00FF00LayoutJunkie:|r Auto-saved '" .. origName .. "' before replacing.")
        end
    end

    -- Overwrite with the new layout, keeping the slot's existing type
    imported.layoutName = entry.name
    imported.layoutType = oldSlot.layoutType or Enum.EditModeLayoutType.Account
    editModeLayouts.layouts[slotIdx] = imported

    local ok2, err2 = pcall(C_EditMode.SaveLayouts, editModeLayouts)
    if not ok2 then
        print("|cffFF4444LayoutJunkie:|r Save failed: " .. tostring(err2))
        return
    end

    pcall(C_EditMode.SetActiveLayout, slotIdx + PRESET_OFFSET)
    print("|cff00FF00LayoutJunkie:|r Applied layout '" .. entry.name .. "'.")
end

function ns.ApplyLayout(index)
    local entry = ns.db.layouts[index]
    if not entry then return end

    if InCombatLockdown() then
        ns.pendingLayout = index
        print("|cffFFD100LayoutJunkie:|r In combat -- layout will apply when combat ends.")
        return
    end

    local ok, imported = pcall(C_EditMode.ConvertStringToLayoutInfo, entry.importString)
    if not ok or type(imported) ~= "table" then
        print("|cffFF4444LayoutJunkie:|r Invalid layout string for '" .. entry.name .. "'.")
        return
    end

    -- If a slot with this name already exists, just activate it (avoid duplicates)
    local editModeLayouts = C_EditMode.GetLayouts()
    for i, l in ipairs(editModeLayouts.layouts) do
        if type(l) == "table" and l.layoutName == entry.name then
            -- Overwrite data so it matches our stored version, then activate
            imported.layoutName = entry.name
            imported.layoutType = l.layoutType or Enum.EditModeLayoutType.Account
            editModeLayouts.layouts[i] = imported
            pcall(C_EditMode.SaveLayouts, editModeLayouts)
            pcall(C_EditMode.SetActiveLayout, i + PRESET_OFFSET)
            print("|cff00FF00LayoutJunkie:|r Applied layout '" .. entry.name .. "'.")
            return
        end
    end

    -- Try an open Account slot first, then Character
    local newIdx = tryAppendSlot(imported, entry.name, Enum.EditModeLayoutType.Account)
    if not newIdx then
        newIdx = tryAppendSlot(imported, entry.name, Enum.EditModeLayoutType.Character)
    end

    if newIdx then
        pcall(C_EditMode.SetActiveLayout, newIdx + PRESET_OFFSET)
        print("|cff00FF00LayoutJunkie:|r Applied layout '" .. entry.name .. "'.")
        return
    end

    -- All slots full -- ask which to replace
    ns.ShowReplaceSlotDialog(index)
end

function ns.ImportFromGame()
    local ok, layoutData = pcall(C_EditMode.GetLayouts)
    if not ok or not layoutData then
        print("|cffFF4444LayoutJunkie:|r Could not read Edit Mode layouts.")
        return
    end

    -- Build a set of existing names to skip duplicates
    local existingNames = {}
    for _, entry in ipairs(ns.db.layouts) do
        existingNames[entry.name:lower()] = true
    end

    local imported = 0
    for i, layout in ipairs(layoutData.layouts) do
        local name = layout.layoutName or ("Custom Layout " .. i)
        if not existingNames[name:lower()] then
            local exportStr = C_EditMode.ConvertLayoutInfoToString(layout)
            if exportStr then
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
    local layoutInfo = C_EditMode.ConvertStringToLayoutInfo(importStr)
    if not layoutInfo then
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
        local name = entry.name
        table.remove(ns.db.layouts, index)
        print("|cff00FF00LayoutJunkie:|r Deleted layout '" .. name .. "'.")
    end
end

function ns.ClearAllLayouts()
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
