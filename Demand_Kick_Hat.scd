(

// execute inside this bracket, rather than the whole file.

o = Server.local.options;
o.memSize = (8192 * 16);
s.boot;

// PITCH VARIATION FOR FM SYNTH NEEDED. GLIS?

// Other than the volumes of the individual sounds the impulse rates are the other important
// parameters. Control messages for these are at the bottom.

s.doWhenBooted({ |
	verb_count = 5,
	verb_node,
	drum_node,
	early_ref_bus = 4,
	tail_level_bus = 5,
	fm_bus = 30 |

	var amp_array, window;

	~kickHat = Group.new(s, 0);
	
	//s.prepareForRecord;


	s.sendMsg(\c_set, early_ref_bus.postln, 0.35);
	s.sendMsg(\c_set, tail_level_bus.postln, 0.65);


	/*
	s.sendMsg(\c_set, 10, 0);
	s.sendMsg(\c_set, 11, 0.2);
	*/

	SynthDef(\verb, { |in = 2, size, time, early_level = 0.25, tail_level = 1, amp = 1|

		// time mul value in GVerb below should extend as impulse rate drops, so that lower impulse
		// rates mean longer reverb times.

		var verb = GVerb.ar(In.ar(in), size, SinOsc.kr(1, 0, 2).abs,
			damping: SinOsc.kr(LFNoise2.ar(0.3, 1, 0.2).abs, 0, 0.8, 0.1).abs,
			earlyreflevel:early_level,
			taillevel:tail_level,
			spread: LFNoise2.kr(1, 25).abs,
			mul:0.4);

		verb = Compander.ar(verb, verb, 0.1, 1, 0.002, 0.001, 0.01, mul:In.kr(11));

		Out.ar([0,20], verb * amp);

	}).add;






	SynthDef(\d_drums, {

		|rate = 1, rate_mod = 6, freq = 294, cut = 22000, tempo_clip_lo = 0.2, tempo_clip_hi = 12, noise_level =
         0.53, hat_level = 1, kick_level = 1, kick_thresh = 0.04, kick_below = 1, kick_above = 0.263,
         kick_clamp = 0.003, kick_release = 0.1, kick_gain = 4.5, amp = 1|

		var imp_freq,impulse, trig, hat, hat_trig, tone_trig, mod, car, kick, noise, comp,
		kick_window, k_thresh, k_above, k_clamp, k_release, k_gain;

		//freq = [1, 1.5, 0.5] * [ 85, 78, 63, 66, 64];
		//freq = [0.5, 1]*[ 55, 58, 63, 66, 68];

		imp_freq = rate * LFNoise2.ar(SinOsc.ar(0.1, 0.1, 10,0.1).abs,rate_mod, 1).abs.clip(tempo_clip_lo, tempo_clip_hi);
		//imp_freq = 9;
		impulse = Impulse.ar(imp_freq);

		// this controls the volume of the reverbs, loud when the pace is slow, quiet when its fast.
		// see whether you miss the reverb sounds during the fast section and if so remove this:

		Out.kr(11, imp_freq.absdif(12)/13);


		a = Demand.ar(impulse, 0, Dwhite(0,1,inf));


		// this sends the impulse out to the FM synths:
		Out.ar(fm_bus, impulse);

		// this modulates the amplitude of the impulses before they're sent out to reverbs:
		i = impulse * a;

		// this chooses randomly which reverb bus to send the click out to. This basically routes a
		// single click out to a number of waiting reverbs.
		Out.ar(Demand.ar(impulse, 0, Diwhite(10,10+verb_count)), LPF.ar(i, cut));


		// this is the pattern and array for the kick:
		d = Dseq(Array.rand(9,0,5), inf);

		// this is the pattern and array for the hat:
		h = Dseq(Array.rand(12,0,10), inf);

		trig = Demand.ar(impulse, 0, d * 0.2) * impulse;

		hat_trig = Demand.ar(impulse, 0, h * 0.15) * impulse;

		kick = Mix.new(
			LPF.ar(
				Formlet.ar(
					trig,
					[62, 52, 66],
					0.0065,
					LFNoise2.kr(0.3, 0, 1/(0.8*imp_freq), 0.1).abs,
					//1.2,
					[0.5, 0.3, 0.2]),
				70));

		kick = Compander.ar(
			kick,
			kick,
			kick_thresh,
			kick_below,
			kick_above,
			kick_clamp,
			kick_release,
			kick_gain * kick_level
		);


		kick = GVerb.ar(kick, 12, 0.25, 0.8, 0.2, drylevel:1, earlyreflevel: 0.4, taillevel:0.3);

		Out.ar(0, Mix.new(kick).dup * amp);

		//Out.ar(0, Compander.ar(kick, kick, 0.15, 1, 0.6, 0.01, 0.07, 2).dup);


		noise = TChoose.ar(Impulse.kr(3),
			[
				WhiteNoise.ar,
				PinkNoise.ar,
				PinkNoise.ar(SinOsc.kr(SinOsc.kr(0.1, 0, 10))),
				WhiteNoise.ar(SinOsc.kr(SinOsc.kr(0.1, 0, 7)))
			]);



		comp = Compander.ar(noise, kick, thresh: 0.05, slopeBelow: 1, slopeAbove: 0.01,
			clampTime: 0.01, relaxTime: 0.26);



		Out.ar(0, Mix.new(comp*LFNoise2.kr(1.5, noise_level)).dup * amp);



		hat = Decay.ar(hat_trig, SinOsc.kr(TRand.kr(0.1, 10, Dust.kr(2)),0,LFNoise0.kr(4,2,0.8)/imp_freq, LFNoise2.kr(1,0.5).abs).abs,
			Splay.ar(
				BPF.ar(WhiteNoise.ar,[14700,17200,8700],SinOsc.kr([0.3,0.1,0.01]).abs,0.42)
				// [
				// 	BPF.ar(WhiteNoise.ar, 14700, SinOsc.kr(0.3).abs),
				// 	BPF.ar(WhiteNoise.ar, 17200, SinOsc.kr(0.1).abs),
				// 	BPF.ar(WhiteNoise.ar, 8700, SinOsc.kr(0.01).abs)
				// ]

				, 1, 3));


		Out.ar(0, hat*hat_level * amp);

	}).add;








	SynthDef(\fm, { |freq, fm_level = 0.85, amp = 1|

		var tone_trig, mod, car, tone, chooser, impulse;

		// this needs replacing with a Demand pattern:

		chooser = TIRand.kr(1,6,Impulse.kr(2));

		impulse = PulseDivider.ar(In.ar(fm_bus), chooser);

		//impulse = Demand.ar(In.ar(fm_bus), 0, );

		tone_trig = Demand.ar(impulse, 0, Drand([1,2,4,6,12], inf));

		mod = SinOsc.ar(freq * TChoose.kr(Impulse.ar(tone_trig/4), (1..10)), 0,
			EnvGen.kr(
				Env.new(
					Array.rand(20, 0, 0.9),
					Array.rand(19, 0.015, 0.5),
					curve:'exponential'
				).circle) * LFNoise2.ar(2, 9000, 200).abs);

		car = SinOsc.ar(freq + mod, 0, 0.12);

		tone = Decay.ar(impulse, LFNoise2.kr(tone_trig, 0.absdif(chooser)).abs, Mix.new(car));

		//tone = Mix.new(car) * EnvGen.ar(Env.new([0,1]++Array.rand(4, 0.01, 0.7)++[0], [0.01]++Array.rand(6, 0.01, 0.1)), impulse, timeScale:1.absdif(chooser));

		tone = Compander.ar(tone, tone, 0.1, 1, 0.01, 0.01, 0.1, 1.6);

		//tone = Decay.ar(impulse, LFNoise2.kr(tone_trig, 1.6).abs, Mix.new(car));

		//tone = Decay.ar(impulse, 0.absdif(chooser) * 0.65, Mix.new(car));

		Out.ar(0,
			Pan2.ar(tone,
				Phasor.ar(
					impulse,
					(1/SampleRate.ir)*4, -1, 1,
					TIRand.ar(-1,1,impulse) * LFNoise0.kr(0.45,0.6)),
				fm_level * amp)
		);

		Out.ar(0,
			Pan2.ar(tone,
				Phasor.ar(
					impulse,
					(1/SampleRate.ir)*4, -1, 1,
					LFNoise0.ar(2, 0.6)),
				fm_level * amp)
		);

	}).add;





	s.sync;




	verb_count.do({ |i|

		s.sendMsg(\s_new, \verb, verb_node = s.nextNodeID, 1,~kickHat.nodeID, \in, (i+10), \size, i+1);
		s.sendMsg(\n_map, verb_node, \early_level, early_ref_bus, \tail_level, tail_level_bus);

	});



	s.sync;


	//s.record;


	s.sendMsg(\s_new, \d_drums, drum_node = s.nextNodeID, 0, ~kickHat.nodeID);
	s.sendMsg(\n_map, drum_node, \kick_level, 0, \hat_level, 1, \noise_level, 2);

	// midi values can also be snet to the fm synths, which could be good if the right chord was
	// found
	//[0.5,1]*[294, 294.25, 294.5].do({ |i|
	// [32, 36, 60, 64].midicps [123, 223, 323, 523, 723]
	// [287, 294.25, 290.5]
	// ([52, 56, 80, 84]).midicps


	[297, 294.25, 290.5].do({ |i| i.postln;
		s.sendMsg(\s_new, \fm, n = s.nextNodeID, 1, ~kickHat.nodeID, \freq, i);
		s.sendMsg(\n_map, n, \fm_level, 3);
		s.sendMsg(\s_new, \fm, n = s.nextNodeID, 1, ~kickHat.nodeID, \freq, i+1.05);
		s.sendMsg(\n_map, n, \fm_level, 3);
	});

	s.sync;

	s.queryAllNodes;


	// SynthDef(\limiter, {
	// 	Out.ar(0, Limiter.ar(In.ar([40, 41]), 0.95, 0.01));
	// }).play;


	// s.sendMsg(\n_order, 1, 1, 1014);


	// window = Window("MIXR", Rect(500, 250, 500, 300));

	// amp_array = Array.newClear(6);

	// 6.do({ |i|
	// 	amp_array.put(i,
	// 		Knob(window, Rect(30*i+3,3,30,290))
	// 		.action_({s.sendMsg(\c_set, i, amp_array[i].value.postln)});
	// 	)
	// });

	// window.front;


MIDIClient.init;
MIDIClient.sources;

MIDIIn.connectAll;

MIDIdef.freeAll;
	
MIDIdef.cc(\mf, {|val,num,chan,src| s.sendMsg(\c_set, num, val.linlin(0,127,0,1))});
	//MIDIdef(\mf).free;


});

)


/*

s.plotTree
s.makeGui;
s.meter;
s.freqscope;

s.stopRecording;


	| kick | hat | noise | tones |
	| ref  | rev |


s.sendMsg(\n_set, 1005, \tempo_clip_lo, 0.2, \tempo_clip_hi, 8);
s.sendMsg(\n_set, 1005, \rate, 1, \rate_mod, 2);
s.sendMsg(\n_set, 1005, \rate, 0);

s.queryAllNodes;

~kickHat.free;

	// Volume for the whole group:

~kickHat.set(\amp, 0);

*/



(

// tempo related settings:

s.sendMsg(\n_set, 1005, \rate, 1, \rate_mod, 6, \tempo_clip_lo, 0.2, \tempo_clip_hi, 12);

//volumes:

[0.212, 0.68, 0.09, 0, 0.8,0.64].do({|v,i| s.sendMsg(\c_set, i, v)});
)


(
s.sendBundle(nil,
	[\n_set, 1005, \rate, 13, \rate_mod, 0, \tempo_clip_lo, 0.2, \tempo_clip_hi, 8],
	[\c_set, 0, 0.74],
	[\c_set, 1, 0],
	[\c_set, 2, 0],
	[\c_set, 3, 0.488]
);
)

(
s.sendBundle(nil,
	[\n_set, 1005, \rate, 13, \rate_mod, 0, \tempo_clip_lo, 0.2, \tempo_clip_hi, 8],
	[\c_set, 0, 0.74],
	[\c_set, 1, 0.22],
	[\c_set, 2, 0.2283],
	[\c_set, 3, 0.488]
);
)

(
s.sendBundle(nil,
	[\n_set, 1005, \rate, 1, \rate_mod, 5, \tempo_clip_lo, 0.2, \tempo_clip_hi, 8],
	[\c_set, 0, 0.74],
	[\c_set, 1, 0.22],
	[\c_set, 2, 0.2283],
	[\c_set, 3, 0.488]
);
)

(

// tempo related settings:
s.sendMsg(\n_set, 1005, \rate, 1, \rate_mod, 5, \tempo_clip_lo, 0.2, \tempo_clip_hi, 8);

//volumes:
[0.85,0.78,0.086,0,0.8,0].do({|v,i| s.sendMsg(\c_set, i, v)});
)


(
s.sendMsg(\n_set, 1005, \rate, 20, \rate_mod, 0, \tempo_clip_lo, 0.2, \tempo_clip_hi, 12);
[0.62,0.5,0.023,0,1,0].do({|v,i| s.sendMsg(\c_set, i, v)});
)


s.sendMsg(\n_set, 1005, \rate, 7);
s.sendMsg(\n_set, 1005, \rate, 1, \rate_mod, 0.5);

s.queryAllNodes;

s.sendMsg(\n_free, 1078);