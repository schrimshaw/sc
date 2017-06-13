
//////////////////////////////////////
//
//           MIDI
//
//////////////////////////////////////






MIDIClient.init;

MIDIIn.connectAll;

MIDIdef.freeAll;


/*

	| voice   | tone | Perc | - |
	| v. loop | rate |

*/

MIDIdef.cc(\allControls, {
	|value, number, channel, deviceID|

	// Voice Volume, CC Number 0:
	if(number == 0, {s.sendMsg(\n_set, ~adderNode, \voice_level, value.linlin(0,127,0,0.7))});

	// Tone Volume, CC Number 1:
	if(number == 1, {s.sendMsg(\n_set, ~adderNode, \tone_level, value.linlin(0,127,0,0.87))});

	// Percussion Volume, CC Number, 2:
	if(number == 2, {s.sendMsg(\n_set, ~adderNode,
		\hat_level, value.linlin(0,127,0,0.8),
		\kick_level, value.linlin(0,127,0,0.9))
	});

	// Voice Loop Toggle, CC Number 4, Chan 1.
	if(number == 4, {s.sendMsg(\n_set, ~adderNode, \voiceloop, value.linlin(0,127,0,1))});

	// Trigger Max, CC Number 5.
	if(number == 5, {s.sendMsg(\n_set, ~adderNode, \trig_max, value.linlin(0,127,1,20))});
	
});





//////////////////////////////////////
//
//           SYNTHESIS
//
//////////////////////////////////////





o = Server.local.options;
o.memSize = 8192 * 4;
s.boot;

s.doWhenBooted({
	
	var parts = 11, buf_num;

	~deImmerse = Group.new(s, 0);
	
	//	s.prepareForRecord;

	parts.do({ |i|
		s.sendMsg(\c_set, 100+i, [20, 20000].choose);
	});

	//q = PathName.new("~/Dropbox/SuperCollider/English/");
	//q = PathName.new("~/Dropbox/SuperCollider/French/");
	q = PathName.new("~/Dropbox/SuperCollider/Combined/");
	q.filesDo{ |i, j| x = q.pathOnly++i.fileName; s.sendMsg(\b_allocRead, 100+j, x); buf_num = j.post; " "++x.postln};

	s.sync;

	SynthDef(\line, { |start, end, dur, out|
		var line;
		line = XLine.kr(start, end, dur, doneAction: 2);
		Out.kr(out, line);
	}).add;


	// put amp argument in here:

	SynthDef(\adder, {

		| gate=1, f0, f1, f2, f3, f4, f5, f6, f7, f8, f9, f10,
		trig_min = 1, trig_max = 20, hat_spread = 0.6, hat_level = 0.7,
		kick_level = 0.85, voiceloop = 0, voice_level = 0.65, tone_level = 0.7, amp = 1 |

		var fund = 20.34, freqs, phase, amps, tone, tones, trigger, noise,
		hat, kick, phons, voice, compL, compR, voice_volume = LFNoise2.ar(0.1, voice_level);

		freqs = [f0, f1, f2, f3, f4, f5, f6, f7, f8, f9, f10];

		phase = Array.rand(parts, -2pi, 2pi);

		amps = Array.fill(parts, {
			EnvGen.kr(
				Env.circle(
					Array.rand(parts, 0, parts.reciprocal*2),
					Array.rand(parts-1, 0.001, 1)),
				gate)
		});

		tone = DynKlang.ar(`[freqs, amps, phase]);

		// envelopes for right channel:

		amps = Array.fill(parts,
			{
				EnvGen.kr(Env.circle(
				Array.rand(parts, 0, parts.reciprocal*2),
				Array.rand(parts-1, 0.001, 1)),
				gate, doneAction:2)
			}
		);

		tones = DynKlang.ar(`[freqs+2.2, amps, phase]);

		trigger = Impulse.ar(TRand.ar(trig_min, trig_max, Dust.ar(2.3)));

		noise = WhiteNoise.ar;

		hat =
		Decay.ar(
			// Trigger:
			PulseDivider.ar(trigger, TChoose.kr(Dust.kr(2.5), [1,2])),

			// Decay Time:
			SinOsc.kr(TRand.kr(0.1, 10, Dust.kr(2)),0,0.63).abs,

			// Signal:
			Splay.ar(

				// input:
				BPF.ar(noise, [8700, 17200, 14700] * TRand.ar(0.15, 1.2, trigger), SinOsc.kr([0.01, 0.1, 0.3]).abs),

				// Spread:
				LFNoise2.kr(0.8).abs, hat_level)
		);

		kick = Mix(Formlet.ar(
			PulseDivider.ar(trigger,Select.kr(Stepper.kr(PulseDivider.kr(trigger, 12), 0, 0, 4, 1), [4, 2, 7, 4, 9])),
			// Formlet Frequencies:
			[45, 52, 65], 0.01,
			// Formelt Decay Time:
			SinOsc.kr(0.3, 0, 1, 0.02).abs,
			[0.4, 0.3, 0.3] * kick_level));

		c = TIRand.kr(100,100+buf_num,Dust.kr(3));

		phons = [107, 120, 132, 116, 134]; // exit
		phons = [113, 125, 131, 122]; // form
		phons = [132, 111, 120, 121]; // circle
		phons = [121, 117, 123]; //line
		phons = [107, 120, 132, 116, 134, 113, 125, 131, 122, 132, 111, 120, 121, 121, 117, 123]; // all the above

		//c = Select.kr(Stepper.kr(Dust.kr(3), 0, 0, phons.size, 1), phons);
		c = Select.kr(Stepper.kr(Dust.kr(3), 0, 0, (101..144).size, 1), (101..144));

		voice = PlayBuf.ar(1, c,
			1,
			//TWChoose.kr(trigger, [1, 0.75, 0.5, 1.2], [10, 2, 1, 1].normalizeSum),
			trigger,
			0,
			voiceloop
		) * TChoose.ar(trigger, [
			EnvGen.ar(Env.linen, trigger),
			EnvGen.ar(Env.perc, trigger)
		]);
			

		compL = Compander.ar(tone, voice, thresh: 0.01, slopeBelow: 5, slopeAbove: 0.11,
			clampTime: 0.05, relaxTime: 0.01);

		compR = Compander.ar(tones, voice, thresh: 0.01, slopeBelow: 5, slopeAbove: 0.11,
			clampTime: 0.05, relaxTime: 0.01);

		Out.ar(0, GVerb.ar(kick,
			roomsize: 20,
			revtime: 2.4,
			damping: LFNoise0.ar(0.2).abs,
			inputbw: 1,
			drylevel:1,
			spread:1,
			earlyreflevel:0.26,
			taillevel: 0.1,
			mul: amp
		));

		Out.ar(0, GVerb.ar(hat,
			8,
			1.3,
			damping: 0.87,
			inputbw: 0.9,
			earlyreflevel: 0,
			taillevel: 0.25,
			drylevel: 1,
			mul:0.3 * amp)
		);
		
		//Out.ar(0, Pan2.ar(voice, LFNoise2.kr(2)) * voice_level);
		//Out.ar(0, Pan2.ar(voice, LFNoise2.kr(2), voice_volume));
		Out.ar(0, compL * (tone_level * amp));
		Out.ar(1, compR * (tone_level * amp));
		
		Out.ar(0,
			GVerb.ar(voice, 12, 0.2,
				LFNoise2.ar(1).abs.clip2(1),
				LFNoise2.ar(2).abs.clip2(1),
				drylevel:1,
				spread:LFNoise2.ar(1, 99, 1).abs.clip2(100)) * (voice_volume * amp)
		);

	}).add;
	
	s.sync;
	
	//s.record;

	s.sendMsg(\s_new, \adder, ~adderNode = s.nextNodeID, 0, ~deImmerse.nodeID);

	s.sendMsg(\n_map, ~adderNode,
			\f0, 100,
			\f1, 101,
			\f2, 102,
			\f3, 103,
			\f4, 104,
			\f5, 105,
			\f6, 106,
			\f7, 107,
			\f8, 108,
			\f9, 109,
			\f10, 110
	);
	
	// s.sendBundle(s.latency,
	// 	[\s_new, \adder, ~adderNode = s.nextNodeID, 0, ~deImmerse],
	// 	[\n_map, n,
	// 		\f0, 100,
	// 		\f1, 101,
	// 		\f2, 102,
	// 		\f3, 103,
	// 		\f4, 104,
	// 		\f5, 105,
	// 		\f6, 106,
	// 		\f7, 107,
	// 		\f8, 108,
	// 		\f9, 109,
	// 		\f10, 110
	// 	]
	// );

	//a = Array.fill(11, {|i| 30.34 * (i ** 1.rrand(1.34))});

	~targets = Pseq([0.91, 1.2, 2.2, 1.08, 1.06, 1.91, 1.01], inf).asStream;

	~gliss = Routine.new({
		loop({

			~waittime = 1.rrand(5);

			~array = Array.fill(11, {|i| 40.34 * ((i+1) ** (~targets.next * 1.2))});
			//~array = Array.fill(11, {|i| 40.34 * (i ** 2.83)});

			~array.size.do({ |i|
				//s.sendBundle(s.latency,
				//create line synth, set args and map 'start' to bus 100
				
				s.sendMsg(\s_new, \line, ~lineNode = s.nextNodeID, 0, ~deImmerse.nodeID,
					\end, ~array[i],
					\dur, ~waittime,
					\out, 100+i
				);

				s.sendMsg(\n_map, ~lineNode, \start, 100+i);

			});

			~waittime*2.rrand(10).wait;

		});
	}).play;

	s.sync;


	~deImmerse.set(\amp, 1);
	
	
});

/*
s.queryAllNodes;

s.sendMsg(\n_free, 1000);

	s.stopRecording;

s.meter;

s.plotTree;

~gliss.stop;


s.sendMsg(\n_set, n, \hat_level, 0.75, \kick_level, 1, \voice_level, 1, \tone_level, 0.8, \trig_min, 2, \trig_max, 20, \voiceloop, 0);
s.sendMsg(\n_set, n, \hat_level, 0.75, \kick_level, 1, \voice_level, 0.85, \tone_level, 0.8, \trig_min, 1, \trig_max, 20, \voiceloop, 0);

s.sendMsg();

s.plotTree;

s.sendMsg(\n_order, 0, 1000, 1001);



~deImmerse.free;

*/
