// Engine_Moonraker

// Inherit methods from CroneEngine
Engine_Moonraker : CroneEngine {

	// <Moonraker> 
	var bufMoonraker;
	var synMoonraker;
	var busMain;
	var busReverb;
	var busDelay;
	var synFX;
	var synMain;
	// </Moonraker>

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		// <Moonraker>
		SynthDef("fx",{
			arg inDelay, inReverb, reverb=0.05, reverbAttack=0.1,reverbDecay=0.5, out, secondsPerBeat=0.125,delayBeats=4,delayFeedback=0.5,bufnumDelay, t_trig=1;
			var snd,snd2,y,z;

			// delay
			snd = In.ar(inDelay,2);
			snd = CombC.ar(
				snd,
				2,
				secondsPerBeat*delayBeats,
				secondsPerBeat*delayBeats*LinLin.kr(delayFeedback,0,1,2,128),// delayFeedback should vary between 2 and 128
			);
			Out.ar(out,snd);

			// reverb
			snd2 = In.ar(inReverb,2);
			snd2=FreeVerb2.ar(snd2[0],snd2[1], 1.0, 0.95, 0.15 );
			snd2=Limiter.ar(snd2, 0.95, 0.02);
			// another kind of reverb
			// snd2 = DelayN.ar(snd2, 0.03, 0.03);
			// snd2 = CombN.ar(snd2, 0.1, {Rand(0.01,0.099)}!32, 4);
			// snd2 = SplayAz.ar(2, snd2);
			// snd2 = LPF.ar(snd2, 1500);
			// 5.do{snd2 = AllpassN.ar(snd2, 0.1, {Rand(0.01,0.099)}!2, 3)};
			// snd2 = LPF.ar(snd2, 1500);
			// snd2 = LeakDC.ar(snd2);

			//snd2=snd2*(1-(0.8*EnvGen.ar(Env.perc(reverbAttack,reverbDecay), t_trig)+0.2));

			Out.ar(out,snd2);
		}).add;


		SynthDef("main",{
			arg out,in,amp=1,bitcrush=0,lpf=20000;
			var snd;
			amp=Lag.kr(amp,0.01);
			snd = In.ar(in,2);
			snd = Compander.ar(snd,snd);
			snd=snd*amp;
			snd=SineShaper.ar(snd);
			snd=RHPF.ar(snd,60,1-0.45);
			snd=RLPF.ar(snd,5000,1-0.23);
			snd=SelectX.ar(Lag.kr(bitcrush,0.2),[snd,Decimator.ar(snd,12000,16)]);
			snd=MoogFF.ar(snd,Lag.kr(lpf,0.3),2);
			Out.ar(out,snd.softclip);
		}).add;

		SynthDef("polyperc",{
			arg hz=220,amp=0.5;
			var snd=Pulse.ar([hz,hz+1]);
			snd=MoogFF.ar(snd,hz*1.5,2);
			snd=amp*snd*EnvGen.ar(Env.perc(0.01,0.2),doneAction:2);
			Out.ar(0,snd);
		}).add;


		SynthDef("playerMoonrakerStereo",{ 
			arg bufnum, out=0, amp=0, t_trig=0,
			sampleStart=0,sampleEnd=1,loop=0,
			pan=0,lpf=20,hpf=18000,attack=0.01,decay=4,
			sendReverb=0,outReverb,sendDelay=0,outDelay=0,
			rate=1;

			var snd;
			var frames = BufFrames.kr(bufnum);

			snd = PlayBuf.ar(
				numChannels:2, 
				bufnum:bufnum,
				rate:BufRateScale.kr(bufnum)*rate,
				startPos: ((sampleEnd*(rate<0))*(frames-10))+(sampleStart*frames*(rate>0)),
				trigger:t_trig,
				loop:loop,
				doneAction:2,
			);
			snd = Balance2.ar(snd[0],snd[1],pan);

			snd = LPF.ar(snd,lpf);
			snd = HPF.ar(snd,hpf);

			snd = snd * amp;

			snd = snd * EnvGen.ar(Env.perc(attack,decay),t_trig,doneAction:2);
			DetectSilence.ar(snd,doneAction:2);

			Out.ar(out,snd);
			Out.ar(outReverb,snd*sendReverb);
			Out.ar(outDelay,snd*sendDelay);
		}).add;	

		SynthDef("playerMoonrakerMono",{ 
			arg bufnum, out=0, amp=0, t_trig=0,
			sampleStart=0,sampleEnd=1,loop=0,
			pan=0,lpf=20,hpf=18000,attack=0.01,decay=4,
			sendReverb=0,outReverb,sendDelay=0,outDelay=0,
			rate=1;

			var snd;
			var frames = BufFrames.kr(bufnum);

			snd = PlayBuf.ar(
				numChannels:1, 
				bufnum:bufnum,
				rate:BufRateScale.kr(bufnum)*rate,
				startPos: ((sampleEnd*(rate<0))*(frames-10))+(sampleStart*frames*(rate>0)),
				trigger:t_trig,
				loop:loop,
				doneAction:2,
			);
			snd = Pan2.ar(snd,pan);

			snd = LPF.ar(snd,lpf);
			snd = HPF.ar(snd,hpf);

			snd = snd * amp;

			snd = snd * EnvGen.ar(Env.perc(attack,decay),t_trig,doneAction:2);
			DetectSilence.ar(snd,doneAction:2);

			Out.ar(out,snd);
			Out.ar(outReverb,snd*sendReverb);
			Out.ar(outDelay,snd*sendDelay);
		}).add;	


		bufMoonraker=Dictionary.new(960);
		synMoonraker=Dictionary.new(960);
		busMain=Bus.audio(context.server,2);
		busReverb=Bus.audio(context.server,2);
		busDelay=Bus.audio(context.server,2);
		context.server.sync;
		synMain=Synth.new("main",[\in,busMain,\out,0]);
		context.server.sync;
 		synFX=Synth.before(synMain,"fx",[\out,busMain,\inDelay,busDelay,\inReverb,busReverb]);
		context.server.sync;

		this.addCommand("polyperc","ff",{ arg msg ;
			Synth.new("polyperc",[\amp,msg[1],\hz,msg[2]]);
		});

		this.addCommand("main","fff",{ arg msg ;
			synMain.set(\amp,msg[1],\bitcrush,msg[2],\lpf,msg[3]);
		});

		this.addCommand("fx","fff",{ arg msg; 
			synFX.set(
				\secondsPerBeat,msg[1],
				\delayBeats,msg[2],
				\delayFeedback,msg[3],
			)
		});

		this.addCommand("play","sfffffffffffffii", { arg msg;
			var filename=msg[1];
			var synName="playerMoonrakerMono";
			if (bufMoonraker.at(filename)==nil,{
				// load buffer
				Buffer.read(context.server,filename,action:{
					arg bufnum;
					if (bufnum.numChannels>1,{
						synName="playerMoonrakerStereo";
					});
					bufMoonraker.put(filename,bufnum);
					synMoonraker.put(filename,Synth.before(synFX,synName,[
						\bufnum,bufnum,
						\amp,msg[2],
						\pan,msg[3],
						\attack,msg[4],
						\decay,msg[5],
						\sampleStart,msg[6],
						\sampleEnd,msg[7],
						\loop,msg[8],
						\rate,msg[9],
						\lpf,msg[10],
						\hpf,msg[11],
						\t_trig,msg[12],
						\sendReverb,msg[13],
						\sendDelay,msg[14],
						\outReverb,busReverb,
						\outDelay,busDelay,
						\out,busMain,
					]).onFree({
						NetAddr("127.0.0.1", 10111).sendMsg("freed",msg[15],msg[16]);
					}));
					NodeWatcher.register(synMoonraker.at(filename));
				});
			},{
				// buffer already loaded, just play it
				if (bufMoonraker.at(filename).numChannels>1,{
					synName="playerMoonrakerStereo";
				});
				if (synMoonraker.at(filename).isRunning==true,{
					synMoonraker.at(filename).set(
						\bufnum,bufMoonraker.at(filename),
						\amp,msg[2],
						\pan,msg[3],
						\attack,msg[4],
						\decay,msg[5],
						\sampleStart,msg[6],
						\sampleEnd,msg[7],
						\loop,msg[8],
						\rate,msg[9],
						\lpf,msg[10],
						\hpf,msg[11],
						\t_trig,msg[12],
						\sendReverb,msg[13],
						\sendDelay,msg[14],
						\outReverb,busReverb,
						\outDelay,busDelay,
						\out,busMain,
					);
				},{
					synMoonraker.put(filename,Synth.before(synFX,synName,[
						\bufnum,bufMoonraker.at(filename),
						\amp,msg[2],
						\pan,msg[3],
						\attack,msg[4],
						\decay,msg[5],
						\sampleStart,msg[6],
						\sampleEnd,msg[7],
						\loop,msg[8],
						\rate,msg[9],
						\lpf,msg[10],
						\hpf,msg[11],
						\t_trig,msg[12],
						\sendReverb,msg[13],
						\sendDelay,msg[14],
						\outReverb,busReverb,
						\outDelay,busDelay,
						\out,busMain,
					]).onFree({
						NetAddr("127.0.0.1", 10111).sendMsg("freed",msg[15],msg[16]);
					}));
					NodeWatcher.register(synMoonraker.at(filename));
				});
			});
		});
		// </Moonraker> 

	}

	free {
		// <Moonraker> 
		synMoonraker.keysValuesDo({ arg key, value; value.free; });
		bufMoonraker.keysValuesDo({ arg key, value; value.free; });
		busMain.free;
		busDelay.free;
		busReverb.free;
		synFX.free;
		synMain.free;
		// </Moonraker> 
	}
}
