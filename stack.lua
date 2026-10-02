-- Full-stack and major-stack workspace modes; session state survives reloads.
local stack = {}
local modes, moving, pending = {}, {}, {}
local state_path = assert(os.getenv("XDG_RUNTIME_DIR")) .. "/omarchy-stack-"
  .. assert(os.getenv("HYPRLAND_INSTANCE_SIGNATURE")) .. ".state"
local function encode(s)
  return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end
local function decode(s)
  return (s:gsub("%x%x", function(c) return string.char(tonumber(c,16)) end))
end
local function save()
  local file = assert(io.open(state_path,"w"))
  for name, mode in pairs(modes) do
    file:write(encode(name)," ",mode.kind," ",mode.major or "-"," ",mode.previous or "dwindle","\n")
  end
  file:close()
end
local file = io.open(state_path,"r")
if file then
  for line in file:lines() do
    local name, kind, major, previous = line:match("^(%x+) (%S+) (%S+) (%S+)$")
    if not name and line:match("^%x+$") then name,kind=line,"stack" end
    if name and #name%2==0 and (kind=="stack" or kind=="major") then
      modes[decode(name)]={kind=kind,major=major~="-" and major or nil,previous=previous}
    end
  end
  file:close()
else
  for _, w in ipairs(hl.get_windows()) do
    if w.group and not w.floating then modes[w.workspace.name]={kind="stack"} end
  end
  save()
end

hl.config({
  group={auto_group=false,groupbar={enabled=true,stacked=true,render_titles=true}},
  master={new_status="slave",mfact=0.5,orientation="left",always_keep_position=false},
})
local function workspace() return hl.get_active_special_workspace() or hl.get_active_workspace() end
function stack.enabled(ws) return ws and modes[ws.name]~=nil end
function stack.mode(ws) return ws and modes[ws.name] and modes[ws.name].kind end
local function eligible(w) return w.mapped and not w.floating and not w.pinned end
local function windows(ws)
  local result={}
  for _, w in ipairs(hl.get_windows({workspace=ws})) do
    if eligible(w) then result[#result+1]=w end
  end
  return result
end
local function tile(w)
  hl.dispatch(hl.dsp.window.fullscreen_state({window=w,internal=0,client=0,action="set"}))
  hl.dispatch(hl.dsp.window.float({window=w,action="disable"}))
end
local function set_layout(ws,layout)
  hl.workspace_rule({workspace=ws.id>0 and tostring(ws.id) or ws.name,layout=layout})
  hl.exec_scheduled_prop_refresh_immediately()
end
local function restore_focus(w,ws)
  if w and w.mapped and (not ws or w.workspace==ws) then hl.dispatch(hl.dsp.focus({window=w}))
  elseif ws and ws.name then hl.dispatch(hl.dsp.focus({workspace=ws.name})) end
end
local function dissolve(ws)
  for _, w in ipairs(hl.get_windows({workspace=ws})) do
    if w.group then
      local members=w.group.members
      hl.dispatch(hl.dsp.group.toggle({window=w}))
      for _, member in ipairs(members) do tile(member) end
    end
  end
end
local function select_member(group,w)
  for i, member in ipairs(group.members) do
    if member==w then hl.dispatch(hl.dsp.group.active({window=w,index=i})); return end
  end
end
local function collect(list,selected)
  if #list==0 then return end
  local first=list[1]
  if not first.group then hl.dispatch(hl.dsp.group.toggle({window=first})) end
  local group=first.group
  if not group or group.locked then return end
  for _, w in ipairs(list) do
    if w.group~=group then tile(w); group:add(w) end
  end
  if selected and selected.group==group then select_member(group,selected) end
  return group
end

-- Reconcile membership and the left-hand major without changing the user's focus.
local function arrange(ws,preferred,selected)
  local mode=modes[ws.name]
  if not mode then return end
  local list=windows(ws)
  if #list==0 then return end
  local active,oldws=hl.get_active_window(),workspace()
  if mode.kind=="stack" then
    collect(list,selected or active)
  else
    if ws.tiled_layout~="master" then set_layout(ws,"master") end
    local major
    for _, w in ipairs(list) do
      if w.address==mode.major then major=w; break end
    end
    if preferred and eligible(preferred) and preferred.workspace==ws then major=preferred end
    if not major then
      -- When the old major leaves, promote the currently visible stack member.
      for _, w in ipairs(list) do
        if w.group then major=w.group.current; break end
      end
      major=major or list[1]
    end
    if mode.major~=major.address then mode.major=major.address; save() end
    if major.group then major.group:remove(major) end
    local minors={}
    for _, w in ipairs(list) do if w~=major then minors[#minors+1]=w end end
    collect(minors,selected)
    -- Grouping can change the master's layout target; explicitly put the solo major left.
    if major.layout and not major.layout.is_master then
      hl.dispatch(hl.dsp.focus({window=major}))
      hl.dispatch(hl.dsp.layout("swapwithmaster"))
    end
  end
  restore_focus(active,oldws)
end

function stack.toggle(requested)
  requested=requested or "stack"
  local ws=workspace()
  if not ws then return end
  local active=hl.get_active_window()
  local old=modes[ws.name]
  local previous=old and old.previous or ws.tiled_layout
  modes[ws.name]=nil -- Pending arrivals must not rebuild a mode being removed.
  dissolve(ws)
  if old and old.kind=="major" then set_layout(ws,previous or "dwindle") end
  if not old or old.kind~=requested then
    modes[ws.name]={kind=requested,previous=previous}
    if requested=="major" then set_layout(ws,"master") end
    arrange(ws,requested=="major" and active or nil,active)
    if requested=="major" and #windows(ws)>0 then
      local focus=hl.get_active_window()
      hl.dispatch(hl.dsp.focus({window=windows(ws)[1]}))
      hl.dispatch(hl.dsp.layout("orientationleft"))
      hl.dispatch(hl.dsp.layout("mfact exact 0.5"))
      restore_focus(focus,ws)
    end
  end
  save()
  restore_focus(active,ws)
end

function stack.exchange(direction)
  local w=hl.get_active_window()
  local ws=w and w.workspace
  local mode=ws and modes[ws.name]
  if not mode or mode.kind~="major" or not eligible(w) then
    hl.dispatch(hl.dsp.window.swap({direction=direction}))
    return
  end
  local major,group
  for _, other in ipairs(windows(ws)) do
    if other.address==mode.major then major=other
    elseif other.group then group=other.group end
  end
  if not major or not group then return end
  if not ((direction=="r" and w==major) or (direction=="l" and w.group==group)) then return end
  local minor=group.current
  local index=group.current_index
  group:remove(minor)
  if group.size and group.size>0 then group:add(major,index)
  else hl.dispatch(hl.dsp.group.toggle({window=major})) end
  mode.major=minor.address
  save()
  arrange(ws,minor,major)
  hl.dispatch(hl.dsp.focus({window=w}))
end

function stack.cycle(step)
  local w=hl.get_active_window()
  if w and w.group then
    local g=w.group
    hl.dispatch(hl.dsp.group.active({window=w,index=((g.current_index-1+step)%g.size)+1}))
  elseif w and stack.mode(w.workspace)=="major" then
    local mode=modes[w.workspace.name]
    if w.address~=mode.major then return end
    for _, minor in ipairs(windows(w.workspace)) do
      if minor.group then
        local g=minor.group
        hl.dispatch(hl.dsp.group.active({window=minor,index=((g.current_index-1+step)%g.size)+1}))
        return -- Selecting a member of the other group leaves focus on the major.
      end
    end
  else hl.dispatch(hl.dsp.focus({direction=step>0 and "d" or "u"})) end
end

function stack.reorder(step)
  local w=hl.get_active_window()
  if w and w.group then
    if w.group.size>1 then
      hl.dispatch(hl.dsp.group.move_window({forward=step>0}))
    end
  elseif w and stack.mode(w.workspace)=="major" then
    return -- Reordering the solo major must not swap the two layout regions.
  else
    hl.dispatch(hl.dsp.window.swap({direction=step>0 and "d" or "u"}))
  end
end

function stack.move(destination,follow)
  local w=hl.get_active_window()
  if not w then return end
  local ws=hl.get_workspace(destination)
  if ws and w.workspace==ws then return end
  if w.group then hl.dispatch(hl.dsp.window.move({window=w,out_of_group=true})) end
  moving[w.address]={follow=follow}
  hl.dispatch(hl.dsp.window.move({window=w,workspace=destination,follow=follow}))
  moving[w.address]=nil
end
function stack.drag()
  local w=hl.get_active_window()
  if w and w.group then hl.dispatch(hl.dsp.window.move({window=w,out_of_group=true})) end
  hl.dispatch(hl.dsp.window.drag())
end
local function repair_major_workspaces()
  for _, ws in ipairs(hl.get_workspaces()) do
    if stack.mode(ws)=="major" then arrange(ws) end
  end
end
local function arrival(w,ws,follow)
  if not w or not ws then return end
  local address,token=w.address,{}
  pending[address]=token
  hl.timer(function()
    if pending[address]~=token then return end
    pending[address]=nil
    if w.mapped and w.workspace==ws and eligible(w) then
      local focus=follow
      if focus==nil then focus=hl.get_active_window()==w end
      arrange(ws,nil,w)
      if focus then hl.dispatch(hl.dsp.focus({window=w})) end
    end
    repair_major_workspaces()
  end,{timeout=1,type="oneshot"})
end
hl.on("window.move_to_workspace",function(w,ws)
  local intent=w and moving[w.address]
  local follow
  if intent then follow=intent.follow end
  arrival(w,ws,follow)
end)
hl.on("window.open",function(w) arrival(w,w.workspace,nil) end)
hl.on("window.close",function(w)
  pending[w.address]=nil
  hl.timer(repair_major_workspaces,{timeout=1,type="oneshot"})
end)
hl.on("config.reloaded",function()
  hl.timer(repair_major_workspaces,{timeout=1,type="oneshot"})
end)
return stack
