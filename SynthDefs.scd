/*

All these need to become standalone synths. They need breaking down into their most basic units

They need to either: 

1. take input from an impulse generating synth or 
2. Be setup to be triggered by a SendTrig, with the SendTrigs possibly embedded
in the Impulse synth rather than in individual synths for maximum flexibility.

default impulse_bus = 200;


*/


//////////////////////////////////////////////////////////////////////////
//
// CONTROL DEFS
//
//////////////////////////////////////////////////////////////////////////



	SynthDef(\impulse, { |out_bus, rate_mul = 1|

		var weights, rate_choices, rate, impulse;
		
		weights = Control.names([\weights]).kr([0.7, 0.1, 0.1, 0.1]);
			
		//rate_choices = [1,2,4,8,16];
		//rate_choices = [1,2,4,8,16,32];
		rate_choices = TWChoose.kr(Dust.kr(0.25), [[1,2,4,8,16], [1,2,4,8,16,32]], [0.8, 0.2]);
		
		//rate = TChoose.kr(Impulse.kr(change_rate), rate_choices); // increasing impulse rate here increases chaos
		
		// should also have the option of manually controlling rate from MIDI controller.
		
		rate = TChoose.kr(
			Impulse.kr(
				TWChoose.kr(
					Impulse.kr(0.5), [1,4,9,19], weights, 1)),
			rate_choices);
		
		impulse = Impulse.ar(rate * rate_mul);

		Out.kr(out_bus, rate);
		Out.ar(out_bus, impulse);

		SendTrig.ar(PulseDivider.ar(impulse, 17)); // triggers kick

		SendTrig.ar(PulseDivider.ar(impulse, TChoose.kr(Dust.kr(0.3), [10, 17, 32])), 1); // triggers used for changing pitch.
		
	}).writeDefFile;





SynthDef(\line, { |start, end, dur, out|
	var line;
	line = XLine.kr(start, end, dur, doneAction: 2);
	Out.kr(out, line);
}).writeDefFile;






//////////////////////////////////////////////////////////////////////////
//
// PERC DEFS
//
//////////////////////////////////////////////////////////////////////////



	SynthDef(\snr, { |start = 0.001, end = 0.5, dur = 0.24, freq = 1|

		var freq_array, noise, filter, rq, sr = SampleRate.ir;

		freq_array = [120,230, 290, 310, 430,500,550,630,930,1340,1740]*freq;
		noise = WhiteNoise.ar;
		rq = XLine.kr(start, end, dur, doneAction:2);
		filter = Mix.new(BPF.ar(noise, freq_array, rq, 15));		
		Out.ar(0,Pan2.ar(filter, LFNoise2.kr(23.5, 0.7), LFNoise2.kr(13,0.02)));
	}).writeDefFile;


// which of these kicks to keep / how to distinguish?


	SynthDef(\kick1, {

		|max_decay = 2, out_bus|
		
		var tone, freqs = [40, 35, 66, 45, 50, 55, 60];
		
		tone = DynKlang.ar(
			`[
				freqs,
				Array.fill(freqs.size, { |i|
					EnvGen.kr(Env.perc(0.01, 0.025.rrand(max_decay), 0.65/(i+1)))
				}),
				
				//Array.rand(freqs.size, -pi, pi);
				
				[ 2.274517503378, -1.4681611776633, 0.69986899729009, -2.5503861215447, 2.9857602791173,
					-2.6126269268, -2.1086273681537, -2.4784665408455 ]
			]
		);
		
		DetectSilence.ar(tone, doneAction:2);
		
		Out.ar(0, HPF.ar(tone, freqs.minItem-2, 0.4).dup);
		Out.ar(out_bus, tone);
	}).writeDefFile;



	SynthDef(\kick2, {

		|max_decay = 2, side_comp_out = 30, kick_vol = 0.5|
		
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
		
		Out.ar([0,1], HPF.ar(tone, freqs.minItem-2, kick_vol));
		Out.ar(side_comp_out, tone);
	}).writeDefFile;




SynthDef(\kick3, {

	|impulse_bus = 200, pulse_divs = #[32,64], freqs = #[32, 45, 60, 70, 89],
	attack = 0.025, decay = 2.7, amp = 0.35|
	
	var impulse, kick;

	impulse = In.ar(impulse_bus);
	
	kick = Mix(
		Formlet.ar(
			PulseDivider.ar(
				impulse, TChoose.kr(impulse, pulse_divs)), freqs, attack, decay, amp));
	
	Out.ar(0,
		Compander.ar(
			kick, kick, 0.01, 1,0.001, 0.01, 0.03
		)*2.dup
	);
	
}).writeDefFile;




SynthDef(\feed_snare, {

	|impulse_bus = 200, filter_freqs = #[220, 340, 680, 910, 1324, 2475, 3100]|

	var impulse, snr, feed;

	impulse = In.ar(impulse_bus);
	
	snr = Decay.ar(PulseDivider.ar(impulse, TChoose.kr(Dust.kr(2), [32, 16])),
		LFNoise0.kr(3, 2, 0.15).abs,
		BPF.ar(
			WhiteNoise.ar,
			filter_freqs*LFNoise0.kr(0.5, 4, 1).abs,
			LFNoise2.kr(1,0,0.1).abs
		)
	);
	
	snr = Mix(snr);
	
	feed = LocalIn.ar(2)+snr;
	feed = Splay.ar(
		DelayN.ar(feed, 1.2,
			[
				LFNoise0.kr(0.1).abs, LFNoise0.kr(0.2).abs, LFNoise0.kr(0.3).abs,
				LFNoise0.kr(0.2).abs, LFNoise0.kr(0.1).abs, LFNoise0.kr(0.41).abs,
				LFNoise0.kr(0.5).abs
			] , 1, snr));
	
	LocalOut.ar(HPF.ar(feed*LFNoise2.kr(1,0.7,0.1).abs, 20));
	
	Out.ar(0, feed*0.35);
		
}).writeDefFile;




SynthDef(\clicker,
	{
		|in_bus, out_bus|
		
		var rate, impulse, clicker, good;
		rate = In.kr(in_bus);
		impulse = In.ar(in_bus);
		
		clicker =
		Decay.ar(impulse,
			TRand.kr(0.01, 0.55, Impulse.kr(6)),
			Mix(
				BPF.ar(
					WhiteNoise.ar(0.8),
					[600, 800,1200, 1602, 1801, 2002] * TIRand.kr(0.5,8,Impulse.kr(4)),
					// rq:
					LFNoise0.kr(0.75,1,0.001).abs,
					0.85)
			)
		);
		
		// this checks for nan, inf and so on, and closes the gate if it finds one:
		good = Gate.ar(clicker, CheckBadValues.ar(clicker,0,0)<=0); 			
		
		Out.ar(0,
			GVerb.ar(
				good,
				[6,10],
				0.25,
				0.9,
				LFNoise0.kr(1).abs,
				spread: LFNoise2.kr(4, 25, 1).abs,
				drylevel: 1,
				taillevel: 1,
				earlyreflevel:0,
				mul: LFNoise2.kr(0.2, 0.4);
			));
				
		Out.ar(0, Pan2.ar(good, SinOsc.kr(4, 0, LFNoise0.kr(0.5, 0.85)), 0.35));
		
	}).writeDefFile;




//////////////////////////////////////////////////////////////////////////
//
// NOISE DEFS
//
//////////////////////////////////////////////////////////////////////////



	SynthDef(\noise, { |decay = 3, in_bus|

		var env, comp, pulse, noise;

		pulse = SinOsc.kr(2, 0, 4, 3).abs;
		noise = TChoose.ar(Impulse.kr(pulse),
			[
				WhiteNoise.ar,
				PinkNoise.ar,
				PinkNoise.ar(SinOsc.kr(SinOsc.kr(0.1, 0, 10))),
				WhiteNoise.ar(SinOsc.kr(SinOsc.kr(0.1, 0, 10)))
			]);
		
		comp = Compander.ar(noise,
			In.ar(in_bus), thresh: 0.05, slopeBelow: 1, slopeAbove: 0.01,
			clampTime: 0.01, relaxTime: 0.1);
		
		env = EnvGen.kr(Env.perc(0.01, decay), doneAction:2);
		
		Out.ar(0, Pan2.ar(comp, LFNoise2.kr(4), env*0.8));
		
	}).writeDefFile;





SynthDef(\noise_swipe, {

	|duration = 0.3, hi = 19000, lo = 300, pan = 1, rq = 0.7, start_pan = -1, end_pan = 1|

	var noise, line, filt, freq_map, rq_map, freq_array;
	
	noise = WhiteNoise.ar(SinOsc.kr(TRand.kr(2, 15, Dust.kr(3))));
	
	line = Line.kr(0, 1, duration);

	freq_map = EnvGen.kr(Env.new(Array.rand(18, lo, hi), Array.rand(17, 0.05, 0.1)));
	
	rq_map = LinExp.kr(line, 0, 1, rq, 1);

	freq_array = [
		freq_map,
		freq_map*0.5,
		freq_map*1.12,
		freq_map*1.62,
		freq_map*2.32,
		freq_map*1.45,
		freq_map*1.5
	];
	
	filt = Mix(BPF.ar(noise, freq_array, rq_map, freq_array.size.reciprocal));
	
	Out.ar(0, Pan2.ar(filt, LinLin.kr(line, 0, 1, start_pan, end_pan), EnvGen.kr(Env.linen(0.0001, duration/3, duration, 0.7), doneAction:2)));
	
}).writeDefFile;





	SynthDef(\swipe, { |duration = 0.2, freq_mul = 1|
		var rq, freqs, freq, noise;
		rq = XLine.kr(2, 0.005, duration);
		//rq = LFNoise2.kr(40, 0.8).abs;
		freqs = [12000, 12100, 10000,1000, 4200, 8000, 500]*freq_mul;
		noise = Mix(
			BPF.ar(WhiteNoise.ar(mul:SinOsc.kr(TIRand.kr(3, 20, Dust.kr(2)))),
				freqs,
				rq,
				EnvGen.kr(Env.perc)*freqs.size.reciprocal));

		noise = Compander.ar(noise, noise, 0.12, 1, 0.001, 0.001, 0.01) * 2.2;
		DetectSilence.ar(noise, doneAction: 2);
		Out.ar(0, Pan2.ar(noise, noise, 0.85));
	}).writeDefFile;




//////////////////////////////////////////////////////////////////////////
//
// TONE DEFS
//
//////////////////////////////////////////////////////////////////////////



SynthDef(\saw_fuzz,{
	
	|freq = 80, side_comp_bus = 100, filter_high = 1200, filter_rate = 0.8 |

	// Works particularly well as low frequency bass line type synth.

	var tone, noise;

	tone =
	RLPF.ar(
		Saw.ar([freq/2, freq, freq+1.05, freq*2.041, freq*3.012]),
		SinOsc.kr(TRand.kr(0.1, filter_rate, Dust.kr(0.5)), 0,
			Phasor.ar(1, 30/SampleRate.ir, 30, filter_high), 25
		).abs,

		rq: SinOsc.kr(2, 0, 0.4, 0.6),
		mul: 0.2);
	
	tone = Compander.ar(Mix(tone), In.ar(side_comp_bus), 0.15, 1, 0.01, 0.02, 0.03);


	noise = PinkNoise.ar(
		SinOsc.kr(
			TRand.kr(2, 10, Dust.kr(4)), 0, tone.abs.absdif(1)
		)*LFNoise2.kr(1,0.05)
	);
	
	noise = Mix(noise);

	Out.ar(0, Pan2.ar(noise, noise));		
	Out.ar(0, Pan2.ar(tone, tone, 0.1));
	Out.ar(0, tone.dup * 0.8);
	
}).writeDefFile;








SynthDef(\bd, { |max_segment_duration = 0.3|

	// not really a bass drum, more a toneful or harmonic / melodic type thing
	
	var freq, amp, levels, tone;
	
	//freq = [40, 51]++([30, 31.4, 56, 72, 83, 102, 122, 129, 203, 222, 222.6, 301, 302.2] * 2.76);
	
	freq = Control.names([\freq]).kr([40]++Array.fill(1.rrand(9), {|i| [50, 60].choose*(1+i.rrand(2*(1+i)))}));
	
	amp = Array.fill(freq.size, {
		EnvGen.kr(
			Env.new(

				levels =
				[0, freq.size.reciprocal] ++ Array.exprand(6.rrand(9), 0.001, freq.size.reciprocal) ++ [0],
				times:[0.0023]++Array.exprand(levels.size - 2, 0.03, max_segment_duration),
				curve:\sin
				
			));
		
	});
	
	tone = DynKlang.ar(`[freq, amp, Array.rand(freq.size, -pi, pi)], freqscale: 1) * 0.55;
	
	DetectSilence.ar(tone, doneAction:2);
	
	Out.ar(0, tone.dup*0.3);
	Out.ar(0, Pan2.ar(tone, SinOsc.kr(TRand.kr(1, 14, Dust.kr(3))), 0.7));
	
}).writeDefFile;



	
	





SynthDef(\mel, { |impulse_bus = 200|

		var freq, noise, env, envArray, impulse, kick, snr, feed;
		envArray = Array.newClear(5);
		
		5.do({ |i|
			e = Array.rand(12, 0, 0.9);
			t = Array.rand(11, 0.05, 0.2);
			env = Env(e,t, \exponential).circle;
			envArray.put(i, EnvGen.kr(env));
			
		});
		
		f = EnvGen.kr(
			Env(
				[60, 80, 120, 140, 160].permute(7).stutter,
				[1,1.5,0.5,1, 1]*2,
				\exponential).circle
		);
		
		a = `[
			[f, f*1.5, f*3, f*4.5, f*7],
			envArray*0.2,
			nil
		];
		
		impulse = In.ar(impulse_bus);
				
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
			)
		);
		
	}).writeDefFile;
			


	SynthDef(\adder, {

		| gate=1, in_bus, imp_bus, drone_vol = 0, pulse_divs = #[1, 2]|

		var parts = 13, freqs, phase, amps, trigger, decay_time;
		
		//freqs = Control.names([\freqs]).kr(Array.fill(parts, {|i| 24.34 * (i**0.rrand(1.5))}));

		freqs = In.kr(((0..parts)+100));
		phase = Array.rand(parts, -2pi, 2pi);

		// envelopes for left channel:
		amps = Array.fill(parts, {
			EnvGen.kr(Env.circle(Array.rand(parts, 0, parts.reciprocal*2), Array.rand(parts-1, 0.001, 1)), gate)
		});

		trigger = PulseDivider.ar(In.ar(imp_bus), TChoose.kr(In.ar(imp_bus), pulse_divs));

		decay_time = LFNoise0.kr(0.5, 0.6, 0.05).abs;

		Out.ar(0,
			Decay2.ar(trigger, 0.01, decay_time, 
				Compander.ar(
					DynKlang.ar(`[freqs, amps, phase]),
					In.ar(in_bus),
					0.05,
					1,
					0.003,
					0.01,
					0.065
				)));
		

		
		// envelopes for right channel:
		amps = Array.fill(parts, {
			EnvGen.kr(Env.circle(Array.rand(parts, 0, parts.reciprocal*2), Array.rand(parts-1, 0.001, 1)), gate, doneAction:2)
		});
			
			Out.ar(1,
				Decay2.ar(trigger, 0.01, decay_time, 
				Compander.ar(
					DynKlang.ar(`[freqs+2.2, amps, phase]),
					In.ar(in_bus),
					0.05,
					1,
					0.003,
					0.01,
					0.065
				)));
		
		
		Out.ar(0,
			Compander.ar(
				DynKlang.ar(`[freqs+2.2, amps, phase]),
				In.ar(in_bus),
				0.05,
				1,
				0.003,
				0.01,
				0.065
			).dup * drone_vol);
		//* SinOsc.kr(LFNoise2.kr(0.6, 14).abs) .dup);
		
	}).writeDefFile;	
	






	SynthDef(\voice_filters, { |imp_bus, out_bus|

		// add some feedback here into the filters!
		
		var impulse, player;
		impulse = In.ar(imp_bus);
		
		player = PlayBuf.ar(1,
			TIRand.kr(0,1,Dust.kr(3)),
			LFNoise2.kr(TRand.kr(0.1, 4, impulse), 2, 0.05).abs,
			PulseDivider.ar(impulse, TWChoose.kr(Dust.kr(2), [1, 3, 5, 7], [0.6, 0.2, 0.1, 0.1])),
			loop:TIRand.kr(0,1,impulse)
		);
				
		Out.ar([0, out_bus], 
			Splay.ar(
				HPF.ar(
					Formlet.ar(player*0.05, [1200, 800, 500, 300, 150, 80, 62, 50] *
						LFNoise0.kr(TRand.kr(0.1, 2, Dust.kr(4)), 5, 0.001).abs;
						//LFNoise2.kr(TRand.kr(0.1, 5, Dust.kr(4)), 5, 0.001).abs;
						//TChoose.kr(Dust.kr(2.5), [0.5,1,2,3,4])

						, 0.1, LFNoise0.kr(0.5, 0.2).abs)
					,40)
				,level:0.25)
		);
		
		Out.ar(0, Pan2.ar(HPF.ar(player, 20), player, LFNoise0.kr(3, 0.55)));
		
	}).writeDefFile;