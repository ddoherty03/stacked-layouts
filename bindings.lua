local stack = require("hypr.stack")
-- SUPER+S was scratchpad; UP/DOWN were directional focus.
hl.unbind("SUPER + S")
hl.unbind("SUPER + UP")
hl.unbind("SUPER + DOWN")
o.bind("SUPER + S", "Toggle workspace stack", function() stack.toggle("stack") end)
-- SUPER+SHIFT+S was Google Maps; shifted arrows retain normal swaps outside major-stack.
hl.unbind("SUPER + SHIFT + S")
hl.unbind("SUPER + SHIFT + RIGHT")
hl.unbind("SUPER + SHIFT + LEFT")
o.bind("SUPER + SHIFT + S", "Toggle major-stack", function() stack.toggle("major") end)
o.bind("SUPER + SHIFT + RIGHT", "Exchange major with minor / swap right", function() stack.exchange("r") end)
o.bind("SUPER + SHIFT + LEFT", "Exchange minor with major / swap left", function() stack.exchange("l") end)
o.bind("SUPER + UP", "Previous stacked window / focus above", function() stack.cycle(-1) end)
o.bind("SUPER + DOWN", "Next stacked window / focus below", function() stack.cycle(1) end)
-- Shifted UP/DOWN previously swapped tiles vertically; retain that outside stacks.
hl.unbind("SUPER + SHIFT + UP")
hl.unbind("SUPER + SHIFT + DOWN")
o.bind("SUPER + SHIFT + UP", "Move stacked window up / swap above", function() stack.reorder(-1) end)
o.bind("SUPER + SHIFT + DOWN", "Move stacked window down / swap below", function() stack.reorder(1) end)
o.bind("SUPER + CTRL + ALT + S", "Toggle scratchpad", hl.dsp.workspace.toggle_special("scratchpad"))

-- Move only the selected window, leaving its former stack in place.
for workspace = 1, 10 do
  local destination = tostring(workspace)
  local key = "code:" .. tostring(workspace + 9)
  hl.unbind("SUPER + SHIFT + " .. key)
  hl.unbind("SUPER + SHIFT + ALT + " .. key)
  o.bind("SUPER + SHIFT + " .. key, "Move window to workspace " .. workspace,
    function() stack.move(destination, true) end)
  o.bind("SUPER + SHIFT + ALT + " .. key, "Move window silently to workspace " .. workspace,
    function() stack.move(destination, false) end)
end
hl.unbind("SUPER + ALT + S")
o.bind("SUPER + ALT + S", "Move window to scratchpad", function()
  stack.move("special:scratchpad", false)
end)
-- SUPER+left-drag used to drag the entire group; now detach its selected window.
hl.unbind("SUPER + mouse:272")
o.bind("SUPER + mouse:272", "Drag selected window out of stack", stack.drag, { mouse = true })
