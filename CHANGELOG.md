# 1.1.1

Connect CurseForge project 1526333 to automated tagged releases. Add CurseForge project metadata for addon managers. No gameplay changes.

# 1.1.0

Stores Edit Mode layout exports beyond the built-in slot limit, then imports them into an available account or character slot. If every slot is full, you choose which existing layout to replace.

The 1.1.0 update targets Retail 12.1 (interface 120100), uses current popup and addon-compartment callbacks, updates LibDBIcon to upstream v12.0.3, handles invalid imports and failed saves, and preserves replacement backups even when their names collide. Queued combat selections keep the selected entry if the list changes. Close Edit Mode before applying a layout.

Commands: `/lj import`, `/lj game`, `/lj list`, `/lj apply #`, `/lj clear`, and `/lj minimap`. Left-click the minimap or addon-compartment entry to switch layouts; right-click to manage them. Layout strings only contain Blizzard Edit Mode settings, not other addons' profiles.
