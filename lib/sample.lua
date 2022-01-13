local Sample={}

function Sample:new(o)
  o=o or {} -- create object if user does not provide one
  setmetatable(o,self)
  self.__index=self
  o.vars={"filename","amp","pan","attack","decay","sampleStart","sampleEnd","loop","rate","lpf","hpf",
  "sendReverb","sendDelay","bank","id"}
  o.filename=o.filename
  o.mutate=1
  o.amp=0.5
  o.pan=0
  o.attack=0.005
  o.decay=3
  o.sampleStart=0
  o.sampleEnd=1
  o.loop=0
  o.rate=math.random(75,125)/100
  o.rate_range={math.random(11,12),math.random(12,13)}
  if math.random()<0.05 then
    o.rate_range={math.random(4,5),math.random(5,6)}
  end
  o.lpf=math.random(200,10000)
  o.hpf=o.bank==1 and 20 or math.random(20,800)
  o.t_trig=1
  o.reverb_range={math.random(0,1),math.random(1,2)}
  o.delay_range={math.random(0,1),math.random(1,2)}
  o.playing=false
  o.bank=o.bank or 1
  o.id=o.id or 1
  o.row=math.floor(o.id/16-0.00001)+1
  o.col=(o.id-1)%16+1
  o.mods={}
  o.modsinv={}
  o.rot=0--math.random(0,4)
  modchoice={1,2,3,4,4,5,6,6,6,7,8,8,9,9,9,10,11,11,12,13,13,14,15,15,16,16,16}
  o.pan=math.random()-0.5
  for i=1,math.random(1,2) do
    o.mods[modchoice[math.random(1,#modchoice)]]=true
  end
  for i=1,math.random(0,2) do
    o.modsinv[math.random(5,16)]=true
  end
  o.amp_range={math.random(0,4),math.random(4,12)}
  if o.bank==8 then
    o.amp_range={math.random(0,2),math.random(2,5)}
  end
  if o.bank==2 then
    o.amp_range={math.random(0,2),math.random(2,5)}
  end
  local active_prob={0.02,0.01,0.02,0.02,0.005,0.005,0.005,0.005}
  if o.active==nil then
    o.active=math.random()<active_prob[o.bank]*params:get("density")
  end
  o.pan_range={math.random(4,8),math.random(8,12)}
  return o
end

function Sample:dump()
  local d={}
  for _,key in ipairs(self.vars) do
    d[key]=self[key]
  end
  return d
end

function Sample:load(d)
  if d~=nil then
    for _,key in ipairs(self.vars) do
      if d[key]~=nil then
        self[key]=d[key]
      end
    end
  end
end

function Sample:play(o)
  o=o or {}
  self.playing=true
  local ramp=math.random()*(self.amp_range[2]-self.amp_range[1])+self.amp_range[1]
  ramp=util.linlin(1,16,0,1,ramp)
  local rpan=math.random()*(self.pan_range[2]-self.pan_range[1])+self.pan_range[1]
  rpan=util.linlin(1,16,1,-1,rpan)
  local final_amp=o.amp or self.amp*ramp
  local rdelay=math.random()*(self.delay_range[2]-self.delay_range[1])+self.delay_range[1]
  self.sendDelay=util.linlin(1,16,0,0.5,rdelay)
  local rrev=math.random()*(self.reverb_range[2]-self.reverb_range[1])+self.reverb_range[1]
  self.sendReverb=util.linlin(1,16,0,0.5,rrev)
  local rrate=math.random()*(self.rate_range[2]-self.rate_range[1])+self.rate_range[1]
  if rrate>8 then
    self.rate=util.linlin(8,16,0.5,1.5,rrate)
  else
    self.rate=util.linlin(1,8,-1.5,-0.5,rrate)
  end
  engine.play(self.filename,final_amp,self.pan+rpan,self.attack,self.decay,
    self.sampleStart+(math.random()/100),self.sampleEnd,self.loop,self.rate,self.lpf,self.hpf,self.t_trig,
  self.sendReverb,self.sendDelay,self.bank,self.id)
  return final_amp
end

return Sample
