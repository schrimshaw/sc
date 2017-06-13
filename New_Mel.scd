o = Server.local.options;
o.memSize = 8192 * 10;
o.sampleRate = 96000;
o.numBuffers = 6000;
o.numWireBufs = 128*2;

s.boot;

s.doWhenBooted({ |comp_bus = 100|
	
	var xline_start_end;

	~newMel = Group.new(s, 0);
	
	SynthDef(\snr, { |start = 0.001, end = 0.5, length = 0.24|
		var sr = SampleRate.ir;
		f = [120,230, 290, 310, 430,500,550,630,930,1340,1740]*1;
		w = WhiteNoise.ar;
		l = XLine.kr(start, end, length, doneAction:2);
		b = Mix.new(BPF.ar(w, f, l, 15));		
		Out.ar(0,Pan2.ar(b, LFNoise2.kr(23.5, 0.7), LFNoise2.kr(13,0.02)));
	}).add;
	
	
	SynthDef(\kick0, {

		|max_decay = 2, out_bus, kick_vol = 0.5, amp = 1|
		
		var tone, freqs = [40, 35, 66, 45, 50, 55, 60];
		
		tone = DynKlang.ar(
			`[
				freqs,
				Array.fill(freqs.size, { |i|
					EnvGen.kr(Env.perc(0.01, 0.025.rrand(max_decay), 0.65/(i+1)))
				}),
				
				//Array.rand(freqs.size, -pi, pi);
				
				[ 2.274517503378, -1.4681611776633, 0.69986899729009, -2.5503861215447,
				2.9857602791173, -2.6126269268, -2.1086273681537, -2.4784665408455 ] ] );
		
		DetectSilence.ar(tone, doneAction:2);
		
		Out.ar([0,1], HPF.ar(tone, freqs.minItem-2, kick_vol) * amp);
		Out.ar(comp_bus, tone);
	}).add;

	
	
	SynthDef(\mel, { | bass_filter_high = 1200, bass_filter_rate = 0.4, amp = 1 |

		var freq, tone, noise, env, envArray, impulse, kick, snr, feed;
		envArray = Array.newClear(5);
		
		5.do({ |i|
			e = Array.rand(12, 0, 0.9);
			t = Array.rand(11, 0.05, 0.2);
			env = Env(e,t, \exponential).circle;
			envArray.put(i, EnvGen.kr(env));
			
		});
		
		//EnvGen.kr(env);
		//	f = TChoose.kr(Dust.kr(2),[60, 80, 120, 140, 160]);
		f = EnvGen.kr(
			Env(
				[60, 80, 120, 140, 160].permute(7).stutter,
				[1,1.5,0.5,1, 1]*2,
				\exponential).circle
		);

		// 3
		
		a = `[
			[f, f*1.5, f*3, f*4.5, f*7],
			envArray*0.2,
			nil
		];

		// Bass Synth Noise:
		
		tone =
		RLPF.ar(
			Saw.ar([f/2, f, f+1.05, f*2.041, f*3.012]),
			SinOsc.kr(TRand.kr(0.1, bass_filter_rate, Dust.kr(0.5)), 0,
				//Phasor.ar(1, 30/SampleRate.ir, 30, bass_filter_high)
				LFTri.ar(1/30, mul: bass_filter_high), 25).abs,
			// RQ:
			SinOsc.kr(2, 0, 0.4, 0.6),
			mul: 0.2);
		
		noise = PinkNoise.ar(
			SinOsc.kr(
				TRand.kr(2, 10, Dust.kr(4)), 0, tone.abs.absdif(1)
			)*LFNoise2.kr(1,0.05)
		);
		
		//SendTrig.kr(PulseDivider.kr(Impulse.kr(2), TChoose.kr(Impulse.kr(1), [1,2,4,8])), 0); // snr

		SendTrig.kr(PulseDivider.kr(Impulse.kr(2), TChoose.kr(Impulse.kr(0.25), [4,8])), 1); // kick

		tone = Compander.ar(Mix(tone), In.ar(comp_bus), 0.15, 1, 0.01, 0.02, 0.03);
		//tone = Mix(tone);
		Out.ar(0, (tone.dup * 0.8) * amp);
		Out.ar(0, Pan2.ar(tone, tone, 0.1 * amp));
		noise = Mix(noise);
		Out.ar(0, Pan2.ar(noise, noise, amp));		
		
		impulse = Impulse.ar(TRand.ar(0.5, 15, Dust.ar(3)));
		
		SendTrig.ar( // this one used to trigger external snare
			PulseDivider.ar(impulse,
				TWChoose.kr(impulse,
					//[3,1,1],
					[1, 12, 28],
					[0.25, 0.375, 0.375]
				)
			), 2);

		kick = Mix(
				Formlet.ar(
					PulseDivider.ar(
						impulse, TChoose.kr(impulse, [32,64])), [32, 45, 60, 70, 89], 0.025, 2.7, 0.35));
		Out.ar(0,

			//kick.dup
			Compander.ar(
				kick, kick, 0.01, 1,0.001, 0.01, 0.03
			)*2.dup * amp
		);

		snr = Decay.ar(PulseDivider.ar(impulse, TChoose.kr(Dust.kr(2), [32, 16])),
			LFNoise0.kr(3, 2, 0.15).abs,
			BPF.ar(
				WhiteNoise.ar,
				[220, 340, 680, 910, 1324, 2475, 3100]*LFNoise0.kr(0.5, 4, 1).abs,
				LFNoise2.kr(1,0,0.1).abs
			)
		);

		feed = LocalIn.ar(2)+snr;
		feed = Splay.ar(
			DelayN.ar(feed, 1.2,
				[
					LFNoise0.kr(0.1).abs, LFNoise0.kr(0.2).abs, LFNoise0.kr(0.3).abs,
					LFNoise0.kr(0.2).abs, LFNoise0.kr(0.1).abs, LFNoise0.kr(0.41).abs,
					LFNoise0.kr(0.5).abs
				] , 1, snr));
		
		LocalOut.ar(HPF.ar(feed*LFNoise2.kr(1,0.7,0.1).abs, 20));
		
		Out.ar(0, (feed*0.35) * amp);
		
		Out.ar(0,
			GVerb.ar(
				Decay.ar(impulse, LFNoise2.kr(1,1.5,0.11).abs, DynKlang.ar(a)),
				roomsize:7,
				revtime:1,
				damping:0.31,
				inputbw:0.95,
				spread: 25,
				drylevel: LFNoise2.ar(0.05, 0.3, 0.3).abs,
				earlyreflevel:0,
				taillevel:LFNoise2.kr(0.5, 0.18).abs
			) * amp
		);
		
	}).add;

	s.sync;
	
	s.sendMsg(\s_new, \mel, s.nextNodeID, 0, ~newMel.nodeID, \amp, 1);

	s.sync;

	Pdef(\snare,
		Pbind(\instrument, \snr, \start, 0.5, \end, 0.001, \length, Pwhite(0.025, 0.65), \dur,
			Pwhite(0.05, 5), \group, ~newMel.nodeID)
	).stop;

	Pdef(\kick0, 
		Pbind(\instrument, \kick0, \max_decay, Pwhite(0.55, 3.5), \dur, Pwhite(3, 8), \group, ~newMel.nodeID)
	).stop;
	
});

/*

	~newMel.set(\amp, 0);
	~newMel.free;

Pdef(\kick0).stop;
Pdef(\snare).stop;

	o.free
	s.sendMsg(\s_new, \kick, s.nextNodeID, 0, 1);
	s.queryAllNodes;
	s.sendMsg(\n_set, 1002, \bass_filter_high, 1300);
	s.sendMsg(\n_set, 1002, \bass_filter_rate, 0.86);
	s.meter;
	s.plotTree;
~newMel.free;
*/

