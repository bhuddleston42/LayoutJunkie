# LayoutJunkie

Stores Edit Mode layout exports beyond the built-in slot limit, then imports them into an available account or character slot. If every slot is full, you choose which existing layout to replace.

The 1.1.0 update targets Retail 12.1 (interface 120100), uses current popup and addon-compartment callbacks, updates LibDBIcon to upstream v12.0.3, handles invalid imports and failed saves, and preserves replacement backups even when their names collide. Queued combat selections keep the selected entry if the list changes. Close Edit Mode before applying a layout.

Commands: `/lj import`, `/lj game`, `/lj list`, `/lj apply #`, `/lj clear`, and `/lj minimap`. Left-click the minimap or addon-compartment entry to switch layouts; right-click to manage them. Layout strings only contain Blizzard Edit Mode settings, not other addons' profiles.

## Installation and releases

Download the addon ZIP from GitHub Releases and extract the LayoutJunkie folder into `World of Warcraft/_retail_/Interface/AddOns`. Fully restart the game after a first installation. Existing saved variables are retained.

GitHub Actions runs Lua 5.1 parsing, regression checks, and TOC validation on pushes and pull requests. Push a tag matching the TOC version (for example `v1.1.0`) to publish a BigWigs-packaged addon ZIP and `release.json` for addon managers such as WoWUp. Manual workflow runs build an artifact without publishing. GitHub Actions publishes the GitHub release using the automatic GITHUB_TOKEN. CurseForge packages tagged commits through its connected GitHub repository and an active push webhook. The webhook URL contains the CurseForge publishing token; no CurseForge Actions secret is required. The TOC carries the CurseForge project ID; GitHub packaging uses -p 0 to avoid duplicate CurseForge uploads.

## Validation

Run `lua tests/regression.lua` and `python tests/validate_toc.py` from the repository root. Tests mock the WoW APIs; actual protected-frame, secret-value, and Edit Mode behavior still requires an in-game check.

## Bundled libraries

LibStub, CallbackHandler-1.0, and LibDataBroker-1.1 are included for a standalone broker feed. LibDBIcon-1.0 provides the minimap icon (upstream v12.0.3 from the CurseForge source repository). Third-party libraries retain their upstream ownership and licenses.
