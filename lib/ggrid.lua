-- local pattern_time = require("pattern")
local GGrid={}

function GGrid:new(args)
  local m=setmetatable({},{__index=GGrid})
  local args=args==nil and {} or args

  m.grid_on=args.grid_on==nil and true or args.grid_on

  -- initiate the grid
  m.g=grid.connect()
  m.g.key=function(x,y,z)
    if m.grid_on then
      m:grid_key(x,y,z)
    end
  end
  print("grid columns: "..m.g.cols)

  -- setup visual
  m.visual={}
  m.grid_width=16
  for i=1,8 do
    m.visual[i]={}
    for j=1,m.grid_width do
      m.visual[i][j]=0
    end
  end

  -- keep track of pressed buttons
  m.pressed_buttons={}

  -- grid refreshing
  m.grid_refresh=metro.init()
  m.grid_refresh.time=0.03
  m.grid_refresh.event=function()
    if m.grid_on then
      m:grid_redraw()
    end
  end
  m.grid_refresh:start()

  return m
end

function GGrid:grid_key(x,y,z)
  self:key_press(y,x,z==1)
  self:grid_redraw()
end

function GGrid:key_press(row,col,on)
  if on then
    self.pressed_buttons[row..","..col]=true
  else
    self.pressed_buttons[row..","..col]=nil
  end
  if on then
    local m=(row-1)*16+col
    if row==8 and col<=8 then
      global_bank=col
      global_sample=nil
      do return end
    elseif row==8 then
      params:delta("bank_mute"..col-8,1)
    elseif self.pressed_buttons["8,"..global_bank] then
      -- select sample
      global_sample=m
      if params:get("play_on_press")==1 then
        smpl[global_bank][m]:play({amp=0.5})
      end
      do return end
    elseif global_sample==nil then
      -- select sample
      toggle_sample(global_bank,m,not smpl[global_bank][m].active)
      if params:get("play_on_press")==1 then
        smpl[global_bank][m]:play({amp=0.5})
      end
      do return end
    elseif row==1 then
      -- turn off/on mod for current sample
      if smpl[global_bank][global_sample].mods[m]==nil then
        smpl[global_bank][global_sample].mods[m]=true
      else
        smpl[global_bank][global_sample].mods[m]=nil
      end
    elseif row==2 then
      m=m-16
      -- turn off/on mod for current sample
      if smpl[global_bank][global_sample].modsinv[m]==nil then
        smpl[global_bank][global_sample].modsinv[m]=true
      else
        smpl[global_bank][global_sample].modsinv[m]=nil
      end
    elseif row==3 then
      local count=0
      for k in pairs(self.pressed_buttons) do
        count=count+1
      end
      if count==1 then
        smpl[global_bank][global_sample].rate_range={col,col}
      else
        smpl[global_bank][global_sample].rate_range[2]=col
        if smpl[global_bank][global_sample].rate_range[1]>smpl[global_bank][global_sample].rate_range[2] then
          local foo=smpl[global_bank][global_sample].rate_range[1]
          smpl[global_bank][global_sample].rate_range[1]=smpl[global_bank][global_sample].rate_range[2]
          smpl[global_bank][global_sample].rate_range[2]=foo
        end
      end
    elseif row==4 then
      local count=0
      for k in pairs(self.pressed_buttons) do
        count=count+1
      end
      if count==1 then
        smpl[global_bank][global_sample].reverb_range={col,col}
      else
        smpl[global_bank][global_sample].reverb_range[2]=col
        if smpl[global_bank][global_sample].reverb_range[1]>smpl[global_bank][global_sample].reverb_range[2] then
          local foo=smpl[global_bank][global_sample].reverb_range[1]
          smpl[global_bank][global_sample].reverb_range[1]=smpl[global_bank][global_sample].reverb_range[2]
          smpl[global_bank][global_sample].reverb_range[2]=foo
        end
      end
    elseif row==5 then
      local count=0
      for k in pairs(self.pressed_buttons) do
        count=count+1
      end
      if count==1 then
        smpl[global_bank][global_sample].delay_range={col,col}
      else
        smpl[global_bank][global_sample].delay_range[2]=col
        if smpl[global_bank][global_sample].delay_range[1]>smpl[global_bank][global_sample].delay_range[2] then
          local foo=smpl[global_bank][global_sample].delay_range[1]
          smpl[global_bank][global_sample].delay_range[1]=smpl[global_bank][global_sample].delay_range[2]
          smpl[global_bank][global_sample].delay_range[2]=foo
        end
      end
    elseif row==6 then
      local count=0
      for k in pairs(self.pressed_buttons) do
        count=count+1
      end
      if count==1 then
        smpl[global_bank][global_sample].pan_range={col,col}
      else
        smpl[global_bank][global_sample].pan_range[2]=col
        if smpl[global_bank][global_sample].pan_range[1]>smpl[global_bank][global_sample].pan_range[2] then
          local foo=smpl[global_bank][global_sample].pan_range[1]
          smpl[global_bank][global_sample].pan_range[1]=smpl[global_bank][global_sample].pan_range[2]
          smpl[global_bank][global_sample].pan_range[2]=foo
        end
      end
    elseif row==7 then
      local count=0
      for k in pairs(self.pressed_buttons) do
        count=count+1
      end
      if count==1 then
        smpl[global_bank][global_sample].amp_range={col,col}
      else
        smpl[global_bank][global_sample].amp_range[2]=col
        if smpl[global_bank][global_sample].amp_range[1]>smpl[global_bank][global_sample].amp_range[2] then
          local foo=smpl[global_bank][global_sample].amp_range[1]
          smpl[global_bank][global_sample].amp_range[1]=smpl[global_bank][global_sample].amp_range[2]
          smpl[global_bank][global_sample].amp_range[2]=foo
        end
      end
    end
  end
end

function GGrid:get_visual()
  -- clear visual
  for row=1,8 do
    for col=1,self.grid_width do
      self.visual[row][col]=self.visual[row][col]-2
      if self.visual[row][col]<0 then
        self.visual[row][col]=0
      end
    end
  end

  local pressing_bank=false 
  for i=1,8 do 
    if self.pressed_buttons["8,"..i]~=nil then
      pressing_bank=true
    end
  end

  if global_sample==nil then
    -- illuminate playing
    for j,smp in ipairs(smpl[global_bank]) do
      if smp.active then
        self.visual[smp.row][smp.col]=smp.playing and 15 or 5
      else
        self.visual[smp.row][smp.col]=2
      end
    end
  else
    -- illuminate the mods that are active
    local smp=smpl[global_bank][global_sample]
    for m,_ in pairs(smp.mods) do
      local row=math.floor(m/16-0.0001)+1
      if row==1 then
        self.visual[row][(m-1)%16+1]=7
      end
    end
    for m,_ in pairs(smp.modsinv) do
      local row=math.floor(m/16-0.0001)+1
      if row==1 then
        self.visual[math.floor(m/16-0.0001)+2][(m-1)%16+1]=7
      end
    end

    for i=smp.rate_range[1],smp.rate_range[2] do
      self.visual[3][i]=7
    end
    for i=smp.reverb_range[1],smp.reverb_range[2] do
      self.visual[4][i]=7
    end
    for i=smp.delay_range[1],smp.delay_range[2] do
      self.visual[5][i]=7
    end
    for i=smp.pan_range[1],smp.pan_range[2] do
      self.visual[6][i]=7
    end
    for i=smp.amp_range[1],smp.amp_range[2] do
      self.visual[7][i]=7
    end
  end

  -- illuminate bank
  self.visual[8][global_bank]=10
  for bank=1,8 do
    self.visual[8][bank]=bank==global_bank and 10 or 2
    for _,smp in ipairs(smpl[bank]) do
      if smp.playing and smp.active then
        self.visual[8][bank]=global_bank==bank and 15 or 5
      end
    end
    if params:get("bank_mute"..bank)==0 then
      self.visual[8][bank+8]=5
    end
  end

  -- illuminate currently pressed button
  for k,_ in pairs(self.pressed_buttons) do
    local row,col=k:match("(%d+),(%d+)")
    self.visual[tonumber(row)][tonumber(col)]=15
  end

  return self.visual
end

function GGrid:grid_redraw()
  self.g:all(0)
  local gd=self:get_visual()
  local s=1
  local e=self.grid_width
  local adj=0
  for row=1,8 do
    for col=s,e do
      if gd[row][col]~=0 then
        self.g:led(col+adj,row,gd[row][col])
      end
    end
  end
  self.g:refresh()
end

return GGrid
