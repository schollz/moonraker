-- moonraker v0.3
-- sequel to goldeneye.
--
-- llllllll.co/t/moonraker
--
--
--
--    ▼ instructions below ▼
--
-- E1 removes/adds instruments
-- E2 changes filter
-- E3 mutes
-- K2 regenerates samples
-- K3 starts/stops
-- K1+E1 changes slot
-- K1+K2 loads in slot
-- K1+K3 saves in slot

if not string.find(package.cpath,"/home/we/dust/code/moonraker/lib/") then
  package.cpath=package.cpath..";/home/we/dust/code/moonraker/lib/?.so"
end
json=require("cjson")
lattice_=require("lattice")
local FilterGraph=require "filtergraph"

local shift=false
engine.name="Moonraker"
local radii={10,10,10,10,10,10,10}
local radii_i=1
local muting=0
message_level=15
message="K2: regenerate"
message_level2=15
message2="K3: blast off"
local save_slot=1
local mc=midi.connect()
local DEFAULT_NOTES={
  -- General MIDI standard
  36,-- Kick
  38,-- Snare
  37,-- Rim
  42,-- Closed hi-hat
  46,-- Open hi-hat
  70,-- Maraca
  56,-- Cowbell
  55,-- Splash
}

-- INCLUDING SAMPLES --
-- you can supply a folder for each type of sample
-- in each of the 8 banks, for example:
sample_folder={
  _path.audio.."moonraker/1/",
  _path.audio.."moonraker/2/",
  _path.audio.."moonraker/3/",
  _path.audio.."moonraker/4/",
  _path.audio.."moonraker/5/",
  _path.audio.."moonraker/6/",
  _path.audio.."moonraker/7/",
  _path.audio.."moonraker/8/",
}
-- OR, you can just set the variable to the folder with your samples:
--sample_folder=_path.audio.."common/808/"

function init()
  local divisions={1/32,1/24,1/16,1/12,1/10,1/8,1/6,1/4,1/3,1/2}
  local divisions_={"1/32","1/24","1/16","1/12","1/10","1/8","1/6","1/4","1/3","1/2"}

  -- setup midi
  midi_devices={}
  midi_device_list={"none"}
  for _,dev in pairs(midi.devices) do
    table.insert(midi_device_list,dev.name)
    midi_devices[dev.name]=midi.connect(dev.port)
    midi_devices[dev.name].event=function(data)
      if dev.name~=midi_device_list[params:get("midi_in")] then
        do return end
      end
      local msg=midi.to_msg(data)
      if msg.type=="clock" then
        do return end
      end
      if msg.type=="continue" then
        moonraker_start()
      elseif msg.type=="stop" then
        moonraker_stop()
      end
    end
  end

  params:add_group("MOONRAKER MIDI",2+(8*2))
  params:add_option("midi_in","midi in",midi_device_list,1)
  params:add_option("midi_out","midi out",midi_device_list,1)
  for track=1,8 do
    local note_param_id=track.."_midi_note"
    params:add_number(note_param_id,track..": midi note",0,127,DEFAULT_NOTES[track])
    local chan_param_id=track.."_midi_chan"
    params:add_number(chan_param_id,track..": midi chan",1,16,1)
  end
  params:add_option("division","division",divisions_,3)
  params:set_action("division",function(x)
    if pattern~=nil then
      pattern:set_division(divisions[x])
    end
  end)
  params:add_control("lpf","lpf",controlspec.new(20,20000,'exp',50,18000,'Hz',50/20000))
  params:set_action("lpf",function(x)
    engine.main(params:get("drive")/100,params:get("bitcrush")/100,params:get("lpf"))
  end)
  params:add_control("drive","drive",controlspec.new(0.1,1000,'exp',1,100,'%',1/1000))
  params:set_action("drive",function(x)
    engine.main(params:get("drive")/100,params:get("bitcrush")/100,params:get("lpf"))
  end)
  params:add_control("bitcrush","bitcrush",controlspec.new(0,100,'lin',1,0,'%',1/100))
  params:set_action("bitcrush",function(x)
    engine.main(params:get("drive")/100,params:get("bitcrush")/100,params:get("lpf"))
  end)
  params:add_control("mutation_rate","mutation rate",controlspec.new(0,100,'lin',0.1,0.5,'%',0.1/100))
  params:add_control("density","density",controlspec.new(0.1,10,'lin',0.1,1,'x',0.1/10))
  params:add_control("metronome","metronome",controlspec.new(0,1,'lin',0.01,0,'amp',0.01/1))
  params:add_binary("play_on_press","play on press","toggle",1)

  for i=1,8 do
    params:add_binary("bank_mute"..i,"bank "..i.." mute","toggle")
  end
  engine.fx(clock.get_beat_sec()/8,2,0.2)
  sample=include("moonraker/lib/sample")
  ggrid=include("moonraker/lib/ggrid")
  smpl={}
  global_bank=1
  global_sample=nil
  reinit_samples({
    active=false
  })
  -- initialize grid
  g_=ggrid:new()
  -- initialize osc
  osc.event=function(path,args,from)
    if path=="freed" then
      local i=tonumber(args[1])
      local j=tonumber(args[2])
      if smpl[i][j]~=nil then
        smpl[i][j].playing=false
      end
    end
  end

  -- setup lattice
  lattice=lattice_:new()
  global_beat=-1
  global_silence=0
  pattern=lattice:new_pattern{
    action=function(t)
      global_beat=global_beat+1
      play_samples(global_beat)
      if params:get("metronome")>0 then
        if global_beat%16==0 then
          engine.polyperc(params:get("metronome"),440)
        elseif global_beat%4==0 then
          engine.polyperc(params:get("metronome"),220)
        end
      end
    end,
    division=1/16
  }
  lattice_is_playing=false
  reinit_samples()

  -- setup saving and loadstring
  params.action_write=function(filename,name)
    print("write",filename,name)
    local data={}
    data["smpl_active"]=smpl_active
    data["smpl"]={}
    for _,ij in ipairs(smpl_active) do
      -- smpl[ij[1]][ij[2]].mutate=0 -- saving prevents mutation
      table.insert(data["smpl"],smpl[ij[1]][ij[2]]:dump())
    end
    local fname=filename..".json"
    local file=io.open(fname,"w+")
    io.output(file)
    io.write(json.encode(data))
    io.close(file)
  end
  params.action_read=function(filename,silent)
    print("read",filename,silent)
    local fname=filename..".json"
    local f=io.open(fname,"rb")
    local content=f:read("*all")
    f:close()
    local data=json.decode(content)
    for _,ij in ipairs(smpl_active) do
      smpl[ij[1]][ij[2]].active=false
    end
    smpl_active=data["smpl_active"]
    for _,d in ipairs(data["smpl"]) do
      smpl[d.bank][d.id]:load(d)
      smpl[d.bank][d.id].active=true
    end
  end

  if util.file_exists("/home/we/dust/data/moonraker/pset-last.txt") then
    local f=io.open("/home/we/dust/data/moonraker/pset-last.txt","rb")
    if f~=nil then
      local content=f:read("*all")
      f:close()
      if content~=nil then
        save_slot=tonumber(content)
        msg("slot "..save_slot)
      end
    end
  end

  -- redraw screen
  clock.run(function()
    while true do
      clock.sleep(1/10)
      redraw()
    end
  end)
end

function moonraker_start()
  print("moonraker start")
  if lattice_is_playing then
    do return end
  end
  lattice:hard_restart()
  lattice_is_playing=true
end

function moonraker_stop()
  print("moonraker stop")
  if not lattice_is_playing then
    do return end
  end
  lattice:stop()
  lattice_is_playing=false
  global_beat=-1
end

function clock.transport.start()
  print("transport start")
  moonraker_start()
end

function clock.transport.stop()
  print("transport stop")
  moonraker_stop()
end

function reinit_samples(o)
  local function ends_with(str,ending)
    return ending=="" or str:sub(-#ending)==ending
  end

  if type(sample_folder)~="table" then
    local foo={}
    for i=1,8 do
      table.insert(foo,sample_folder)
    end
    sample_folder=foo
  end
  o=o or {}
  -- initialize samples
  smpl_active={}
  for i=1,8 do
    smpl[i]={}
    local files=util.scandir(sample_folder[i])
    j=0
    for _,filename in ipairs(files) do
      filename=sample_folder[i]..filename
      if j<112 and (ends_with(filename,".wav") or ends_with(filename,".flac")) then
        j=j+1
        smpl[i][j]=sample:new({
          filename=filename,
          bank=i,
          id=j,
          active=o.active
        })
        if smpl[i][j].active then
          table.insert(smpl_active,{i,j})
        end
      end
    end
  end
end

function play_samples(beat)
  local mmod={1,2,3,4,5,7,11,8,17,19,23,27,29,31,37,16,43,47}
  local banks_triggered={0,0,0,0,0,0,0,0}
  local banks_found={false,false,false,false,false,false,false,false}
  for bank=1,8 do
    if params:get("bank_mute"..bank)==0 then
      for _,smp in ipairs(smpl[bank]) do
        local amp_played=0
        if (next(smp.mods)~=nil or next(smp.modsinv)~=nil) and smp.active then
          local hit=false
          for m_,_ in pairs(smp.mods) do
            local m=mmod[m_]
            if math.random()<params:get("mutation_rate")/100*smp.mutate then
              m_2=util.clamp(m_+1,1,16)
              if m_2==m_ then
                m_2=m_-2
              end
              if m_2~=m_ then
                smp.mods[m_2]=true
                smp.mods[m_]=nil
              end
            end
            if math.random()<params:get("mutation_rate")/100*smp.mutate then
              m_2=util.clamp(m_-1,1,16)
              if m_2==m_ then
                m_2=m_+2
              end
              if m_2~=m_ then
                smp.mods[m_2]=true
                smp.mods[m_]=nil
              end
            end
            if (beat-smp.rot)%m==0 then
              hit=true
            end
          end
          for m_,_ in pairs(smp.modsinv) do
            local m=mmod[m_]
            if math.random()<params:get("mutation_rate")/100*smp.mutate then
              m_2=util.clamp(m_+1,1,16)
              if m_2==m_ then
                m_2=m_-2
              end
              if m_2~=m_ then
                smp.modsinv[m_2]=true
                smp.modsinv[m_]=nil
              end
            end
            if math.random()<params:get("mutation_rate")/100*smp.mutate then
              m_2=util.clamp(m_-1,1,16)
              if m_2==m_ then
                m_2=m_+2
              end
              if m_2~=m_ then
                smp.modsinv[m_2]=true
                smp.modsinv[m_]=nil
              end
            end
            if (beat-smp.rot)%m==0 then
              hit=not hit
            end
          end
          local_do_hit=hit
          if hit then
            amp_played=smp:play()
            radii[math.floor(radii_i)]=util.linlin(0,0.5,15,40,amp_played)+(math.random(4,12)/radii_i)
            radii_i=radii_i-0.25
            if radii_i<=1 then
              radii_i=#radii
            end
          end
        end
        if smp.active then
          banks_found[bank]=true
          banks_triggered[bank]=amp_played
        end
      end --for _,smp in ipairs(smpl[bank]) do
    end -- if not muted
  end -- for bank=1,8
  -- trigger all the midi
  for bank,amp in ipairs(banks_triggered) do
    if banks_found[bank] and amp>0 then
      if params:get("midi_out")>1 then
        midi_devices[midi_device_list[params:get("midi_out")]]:note_on(
          params:get(bank.."_midi_note"),
          math.floor(util.clamp(util.linlin(0,0.5,0,127,amp),0,127)),
        params:get(bank.."_midi_chan"))
        clock.run(function()
          clock.sleep(0.1)
          midi_devices[midi_device_list[params:get("midi_out")]]:note_off(
          params:get(bank.."_midi_note"),0,params:get(bank.."_midi_chan"))
        end)
      end
    end
  end
end -- end function

function update_screen()
  redraw()
end

function key(k,z)
  if k==1 then
    shift=z==1
    if shift then
      msg("load  /  save")
      msg2("E1 select")
    end
  end
  if z==0 then
    do return end
  end
  if shift then
    if k==1 then
    elseif k==2 then
      params:read(save_slot)
      msg("loaded "..save_slot)
    elseif k==3 then
      params:write(save_slot)
      msg("saved "..save_slot)
    end
  else
    if k==1 then
    elseif k==2 then
      reinit_samples()
    elseif k==3 then
      if lattice_is_playing then
        moonraker_stop()
      else
        moonraker_start()
      end
    end
  end
end

function enc(k,d)
  if d==0 then
    do return end
  end
  if shift then
    if k==1 then
      save_slot=util.clamp(save_slot+d,1,30)
      msg("slot "..save_slot)
    elseif k==2 then
    elseif k==3 then
    end
  else
    if k==1 then
      d=d>0 and 1 or-1
      if d<0 then
        if next(smpl_active)~=nil then
          local ij=table.remove(smpl_active)
          smpl[ij[1]][ij[2]].active=false
        end
      else
        local bank=math.random(1,8)
        local i=math.random(1,#smpl[bank])
        toggle_sample(bank,i,true)      
      end
    elseif k==2 then
      params:delta("lpf",d)
    elseif k==3 then
      muting=util.clamp(muting-d,0,255)
      for i,bit in ipairs(toBits(muting,8)) do
        params:set("bank_mute"..i,bit)
      end
    end
  end
end

function toggle_sample(bank,i,active)
  smpl[bank][i].active=active 
  if active then
    table.insert(smpl_active,{bank,i})
  else
    -- remove it from smpl_active
    local foo={}
    for _, v in ipairs(smpl_active) do
      if v[1]==bank and v[2]==i then
      else
        table.insert(foo,v)
      end
    end
    smpl_active=foo
  end
end

-- function show_sample()
--   local s=smpl[1][1]
--   screen.move(1,10)
--   screen.aa(0)
--   screen.text(s.bank.."/"..s.id)
--   filter = FilterGraph.new(nil,nil,nil,nil,"lowpass",12,s.lpf)
--   filter:set_position_and_size(5, 5, 64, 32)
--   filter:redraw()
--   filter = FilterGraph.new(nil,nil,nil,nil,"highpass",12,s.hpf)
--   filter:set_position_and_size(5, 5, 64, 32)
--   filter:redraw()
-- end

function redraw()
  screen.clear()
  local xx=lattice_is_playing and gaussian(0,2) or 0
  local yy=lattice_is_playing and gaussian(0,1) or 0
  screen.display_png(_path.code.."moonraker/lib/spaceship.png",98+xx,18+yy)
  screen.update()
  --show_sample()

  screen.aa(1)
  screen.blend_mode(2)
  for i=1,#radii do
    screen.level(i)
    screen.circle(3+i*14-9,32,radii[i])
    radii[i]=radii[i]-2
    if radii[i]<5 then
      radii[i]=5
    end
    screen.fill()
    screen.update()
  end
  screen.aa(0)
  for i=1,8 do
    if params:get("bank_mute"..i)==0 then
      screen.rect(76+i*6-1,60-1,5,5)
      screen.fill()
    else
      screen.rect(76+i*6,60,4,4)
      screen.stroke()
    end
  end

  for i=1,#smpl_active do
    screen.rect(i*6-5,3-1,5,5)
    screen.fill()

  end
  -- screen.move(1,10)
  -- screen.text(#smpl_active)
  if message_level>0 and message~="" then
    message_level=message_level-1
    screen.move(1,64)
    screen.level(message_level)
    screen.text(message)
  end
  if message_level2>0 and message2~="" then
    message_level2=message_level2-1
    screen.move(128,10)
    screen.level(message_level2)
    screen.text_right(message2)
  end
  screen.update()
end

function msg(s)
  message=s
  message_level=15
end
function msg2(s)
  message2=s
  message_level2=15
end

function gaussian (mean,variance)
  return math.sqrt(-2*variance*math.log(math.random()))*
  math.cos(2*math.pi*math.random())+mean
end

function rerun()
  norns.script.load(norns.state.script)
end

function toBits(num,bits)
  -- returns a table of bits, most significant first.
  bits=bits or math.max(1,select(2,math.frexp(num)))
  local t={} -- will contain the bits
  for b=bits,1,-1 do
    t[b]=math.fmod(num,2)
    num=math.floor((num-t[b])/2)
  end
  local n=#t
  local i=1
  while i<n do
    t[i],t[n]=t[n],t[i]
    i=i+1
    n=n-1
  end
  return t
end
