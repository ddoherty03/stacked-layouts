# Stacked layouts for Omarchy

A Hyprland Lua extension providing full-stack and major-stack workspace modes.
This repository is a snapshot of the working Saturn configuration, not yet a
packaged Omarchy shell plugin. Tested with Hyprland 0.56.2 and Omarchy's Lua configuration.

## Files

- `stack.lua`: layout behavior and session state.
- `bindings.lua`: stacking-related Omarchy keybindings only.

## Manual setup

Back up your Hyprland configuration first. Copy `stack.lua` to
`~/.config/hypr/stack.lua`, then merge the bindings from `bindings.lua`
into your existing `~/.config/hypr/bindings.lua`. Do not replace your entire
bindings file. The bindings depend on Omarchy's `o.bind` helper.

Review conflicts before merging: Super+S replaces scratchpad, Super+Shift+S
replaces Google Maps, and the arrow, move, and drag shortcuts gain stack-aware
behavior. Scratchpad moves to Super+Ctrl+Alt+S.

Validate after installation:

```sh
hyprctl reload
hyprctl configerrors
```

## Controls

| Shortcut | Behavior |
| --- | --- |
| Super+S | Toggle full-stack; switch from major-stack |
| Super+Shift+S | Toggle major-stack; focused window becomes major |
| Super+Up/Down | Cycle stack with wraparound, including from the major without changing focus |
| Super+Shift+Up/Down | Reorder the focused stack member |
| Super+Left/Right | Focus the left/right region |
| Super+Shift+Right from major | Exchange major with visible minor |
| Super+Shift+Left from minor | Exchange visible minor with major |
| Super+Shift+number | Detach and move selected window to workspace |
| Super+Shift+Alt+number | Move silently; select arrival without following it |
| Super+left-drag | Detach and drag selected member |
| Super+Ctrl+Alt+S | Show/hide scratchpad |
| Super+Alt+S | Move selected window to scratchpad |

A major-stack has a solo major on the left and a title-row stack on the right.
New ordinary windows join the stack; floating windows and dialogs stay outside.
When the major leaves, the visible minor is promoted. A lone major fills the workspace.
The mode persists on empty workspaces and across reloads for the compositor session.

## Status and limitations

Live checks on Saturn covered full/major mode transitions, three-window exchanges,
promotion after moving the major, silent moves, floating-window exclusion, cycling,
reordering, and configuration reloads. Tests used existing windows and restored them.
Actual application dialog/close behavior and cross-monitor dragging still need
hands-on testing on Mercury.

Current implementation changes global Hyprland group and master settings:
automatic native grouping is disabled in favor of the extension's event handlers;
group bars are vertical and show titles; master defaults use left orientation,
a 50/50 split, and new windows as slaves. Review these effects if you already
customize groups or the master layout.

State is stored under `$XDG_RUNTIME_DIR/omarchy-stack-$HYPRLAND_INSTANCE_SIGNATURE.state`.
No session state or personal window identities are included in this repository.
The current API has not been checked against other Hyprland versions.

## Removal

Remove the merged bindings and the corresponding `require("hypr.stack")`,
restore any overridden bindings from your backup, and reload Hyprland.
Keep the module file until no configuration references it.
