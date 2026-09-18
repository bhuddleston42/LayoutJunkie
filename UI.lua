local addon, ns = ...

local LDBIcon = LibStub("LibDBIcon-1.0")

-- ---------------------------------------------------------------------------
-- Left-click menu: pick a layout to apply
-- ---------------------------------------------------------------------------
function ns.ShowLayoutMenu(anchorFrame)
    MenuUtil.CreateContextMenu(anchorFrame, function(_, root)
        root:CreateTitle("LayoutJunkie")

        if #ns.db.layouts == 0 then
            root:CreateButton("|cff888888No saved layouts|r")
            return
        end

        for i, entry in ipairs(ns.db.layouts) do
            local idx = i
            root:CreateButton(entry.name, function()
                ns.ApplyLayout(idx)
            end)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Right-click menu: import / manage
-- ---------------------------------------------------------------------------
function ns.ShowConfigMenu(anchorFrame)
    MenuUtil.CreateContextMenu(anchorFrame, function(_, root)
        root:CreateTitle("LayoutJunkie")

        root:CreateButton("|cff69CCF0Paste Import String...|r", function()
            ns.ShowImportDialog()
        end)

        root:CreateButton("|cff69CCF0Import from Edit Mode|r", function()
            ns.ImportFromGame()
        end)

        if #ns.db.layouts > 0 then
            root:CreateDivider()

            local deleteSub = root:CreateButton("|cffFF4444Delete Layout|r")
            for i, entry in ipairs(ns.db.layouts) do
                local idx = i
                deleteSub:CreateButton(entry.name, function()
                    ns.DeleteLayout(idx)
                end)
            end
            deleteSub:CreateDivider()
            deleteSub:CreateButton("|cffFF4444Clear All|r", function()
                ns.ClearAllLayouts()
            end)
        end

        root:CreateDivider()

        root:CreateCheckbox("Show Minimap Icon", function()
            return not ns.db.minimap.hide
        end, function()
            ns.db.minimap.hide = not ns.db.minimap.hide
            if ns.db.minimap.hide then
                LDBIcon:Hide(addon)
            else
                LDBIcon:Show(addon)
            end
        end)
    end)
end

-- ---------------------------------------------------------------------------
-- Import dialog: two-step StaticPopup (name, then paste string)
-- ---------------------------------------------------------------------------
StaticPopupDialogs["LAYOUTJUNKIE_IMPORT_NAME"] = {
    text = "Enter a name for this layout:",
    button1 = "Next",
    button2 = "Cancel",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(self)
        local name = self:GetEditBox():GetText():trim()
        if name == "" then name = "Unnamed Layout" end
        ns._pendingImportName = name
        StaticPopup_Show("LAYOUTJUNKIE_IMPORT_STRING", name)
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = parent:GetEditBox():GetText():trim()
        if name == "" then name = "Unnamed Layout" end
        ns._pendingImportName = name
        parent:Hide()
        StaticPopup_Show("LAYOUTJUNKIE_IMPORT_STRING", name)
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
}

StaticPopupDialogs["LAYOUTJUNKIE_IMPORT_STRING"] = {
    text = "Paste the Edit Mode import string for '%s':",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    editBoxWidth = 350,
    OnShow = function(self)
        self:GetEditBox():SetMaxLetters(0)
        self:GetEditBox():SetFocus()
    end,
    OnAccept = function(self)
        local str = self:GetEditBox():GetText():trim()
        local name = ns._pendingImportName or "Unnamed Layout"
        ns._pendingImportName = nil
        ns.AddLayoutFromString(name, str)
    end,
    OnCancel = function()
        ns._pendingImportName = nil
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local str = parent:GetEditBox():GetText():trim()
        local name = ns._pendingImportName or "Unnamed Layout"
        ns._pendingImportName = nil
        parent:Hide()
        ns.AddLayoutFromString(name, str)
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
}

function ns.ShowImportDialog()
    StaticPopup_Show("LAYOUTJUNKIE_IMPORT_NAME")
end

-- ---------------------------------------------------------------------------
-- Claim slot dialog: user picks which Edit Mode slot LJ takes over
-- ---------------------------------------------------------------------------
function ns.ShowReplaceSlotDialog(pendingApplyIdx)
    local editModeLayouts = ns.GetGameLayouts()
    if type(editModeLayouts) ~= "table" or type(editModeLayouts.layouts) ~= "table"
       or #editModeLayouts.layouts < 1 then
        print("|cffFF4444LayoutJunkie:|r No Edit Mode layouts found.")
        return
    end

    MenuUtil.CreateContextMenu(UIParent, function(_, root)
        root:CreateTitle("All Edit Mode slots are full")
        root:CreateButton("|cff888888Pick a slot to replace. Its layout|r")
        root:CreateButton("|cff888888will be auto-saved to LayoutJunkie first.|r")
        root:CreateDivider()

        for i, l in ipairs(editModeLayouts.layouts) do
            local slotIdx = i
            local ok, expectedSlot = pcall(C_EditMode.ConvertLayoutInfoToString, l)
            local pendingEntry = ns.db.layouts[pendingApplyIdx]
            local name = l.layoutName or ("Custom Layout " .. i)
            local typeTag = (l.layoutType == Enum.EditModeLayoutType.Character)
                and "|cffFFD100[Character]|r"
                or "|cff69CCF0[Account]|r"
            root:CreateButton(typeTag .. " " .. name, function()
                if not ok or not expectedSlot then return end
                for idx, entry in ipairs(ns.db.layouts) do
                    if entry == pendingEntry then
                        ns.ReplaceSlot(slotIdx, idx, expectedSlot)
                        break
                    end
                end
            end)
        end

        root:CreateDivider()
        root:CreateButton("|cff888888Cancel|r", function() end)
    end)
end

-- ---------------------------------------------------------------------------
-- Addon Compartment (modern addon list button)
-- ---------------------------------------------------------------------------
if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    AddonCompartmentFrame:RegisterAddon({
        text = "LayoutJunkie",
        icon = "Interface\\Icons\\INV_Misc_Gear_01",
        notCheckable = true,
        func = function(_, menuInputData)
            if menuInputData and menuInputData.buttonName == "RightButton" then
                ns.ShowConfigMenu(AddonCompartmentFrame)
            else
                ns.ShowLayoutMenu(AddonCompartmentFrame)
            end
        end,
        funcOnEnter = function(button)
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            ns.dataObj.OnTooltipShow(GameTooltip)
            GameTooltip:Show()
        end,
        funcOnLeave = function()
            GameTooltip:Hide()
        end,
    })
end

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
SLASH_LAYOUTJUNKIE1 = "/lj"
SLASH_LAYOUTJUNKIE2 = "/layoutjunkie"
SlashCmdList["LAYOUTJUNKIE"] = function(msg)
    msg = (msg or ""):trim():lower()

    if msg == "import" then
        ns.ShowImportDialog()

    elseif msg == "game" then
        ns.ImportFromGame()

    elseif msg == "list" then
        if #ns.db.layouts == 0 then
            print("|cffFFD100LayoutJunkie:|r No saved layouts.")
        else
            print("|cffFFD100LayoutJunkie:|r Saved layouts:")
            for i, entry in ipairs(ns.db.layouts) do
                print(format("  |cff00ff00%d.|r %s", i, entry.name))
            end
        end

    elseif msg == "minimap" then
        ns.db.minimap.hide = not ns.db.minimap.hide
        if ns.db.minimap.hide then
            LDBIcon:Hide(addon)
            print("|cffFFD100LayoutJunkie:|r Minimap icon hidden.")
        else
            LDBIcon:Show(addon)
            print("|cffFFD100LayoutJunkie:|r Minimap icon shown.")
        end

    elseif msg == "clear" then
        ns.ClearAllLayouts()

    elseif msg:match("^apply%s+(%d+)$") then
        local idx = tonumber(msg:match("^apply%s+(%d+)$"))
        if idx and ns.db.layouts[idx] then
            ns.ApplyLayout(idx)
        else
            print("|cffFF4444LayoutJunkie:|r Invalid layout index.")
        end

    else
        print("|cffFFD100LayoutJunkie commands:|r")
        print("  /lj import    -- Paste an import string")
        print("  /lj game      -- Import current Edit Mode layouts")
        print("  /lj list      -- List saved layouts")
        print("  /lj apply #   -- Apply layout by number")
        print("  /lj clear     -- Clear all saved layouts")
        print("  /lj minimap   -- Toggle minimap icon")
    end
end
