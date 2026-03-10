# Keybind Profiles

Addon that allows creating keybind profiles and assigning them to specs for auto-loading. Also has suitable API for both commands & programatically working with your keybind profilesz.

__NOTE:__ This addon has been rewritten for Midnight and support for classic has been dropped as I am no longer playing Classic.

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

## Additional Info

- The addon operates on the currently selected Blizzard binding set returned by `GetCurrentBindingSet()`.
- Auto-loading currently ships with specialization rules, but the rule schema is designed for future conditions like instance type and difficulty.
- Importing creates a new profile from the pasted string and applies it immediately. If the chosen or exported name already exists, the addon creates a unique imported name instead of overwriting.
