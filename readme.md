# Keybind Profiles

Retail Midnight rewrite of Keybind Profiles using Blizzard APIs only.

## Features

- Account-wide named keybind profiles
- Per-character active profile tracking
- Specialization-based auto-loading
- Optional autosave when bindings are saved through Blizzard UI
- Profile import/export using shareable strings
- Slash commands for manual control

## UI

- `/kbp` opens the addon's standalone configuration window
- Saved profile rows support inline load/save actions, delete with confirmation, and an active-profile indicator icon
- The `Saved Profiles` header supports create, export, and import actions

## Slash Commands

- `/kbp` or `/kbp config` opens settings
- `/kbp load <profile>`
- `/kbp save`
- `/kbp saveas <profile>`
- `/kbp list`
- `/kbp status`
- `/kbp help`

## Addon API

- `KeybindProfiles:LoadProfile(name, opts)`
- `KeybindProfiles:SaveProfile(name)`
- `KeybindProfiles:SaveAsProfile(name)`
- `KeybindProfiles:ListProfiles()`
- `KeybindProfiles:GetActiveProfileName()`
- `KeybindProfiles:EvaluateRules(reason, force)`
- `KeybindProfiles:ExportProfile(name)`
- `KeybindProfiles:ImportProfile(text, overrideName)`
- `KeybindProfiles:Load(name)` compatibility alias

## Notes

- The addon operates on the currently selected Blizzard binding set returned by `GetCurrentBindingSet()`.
- Auto-loading currently ships with specialization rules, but the rule schema is designed for future conditions like instance type and difficulty.
- Importing creates a new profile from the pasted string and applies it immediately. If the chosen or exported name already exists, the addon creates a unique imported name instead of overwriting.
