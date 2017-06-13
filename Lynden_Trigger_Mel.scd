
/*

1. Introduction
1.1 tick clock dur 0.25
1.2 kick decay 8, amp 1

2. Ramp Up
2.1 build tick clock up to 8 (1,2,4,8)
2.2 kick decay 0.8, amp 0.55 once tick clock > 2
2.3 switch to div clock

3. Merger
3.1 switch to tick clock, rate 8.
3.2 kick decay 0.55, amp 0.5
3.3 build tick clock rate 8, 16, 20, 30
3.4 cycle rate between 20 & 30
3.5 turn noise on
3.6 descelerate tick clock 20, 16, 10, 8, 4, 2

4. End
4.1 tick clock rate 0.25
4.2 Organ release time 3.5
4.3 Organ release time 0.25
*/



/*

Need to implement this:

g = PdefGui(Pdef(\organ), 3);    // with an envirgui for 3 items

g.close;
*/


(

o = Server.local.options;
o.memSize = 8192 * 10;
o.sampleRate = 96000;
o.numBuffers = 6000;
o.numWireBufs = 128*2;
s.boot;

s.doWhenBooted({

	SynthDef(\noise, {

		arg out = 0, side_chain_in = 10, rate = 0, switch_rate = 1, amp = 0.3;

		var noise, comp;

		noise = TChoose.ar(Impulse.kr(switch_rate),
			[
				WhiteNoise.ar(0.25),
				PinkNoise.ar,
				PinkNoise.ar(SinOsc.kr(SinOsc.kr(0.1, 0, 10))),
				WhiteNoise.ar(SinOsc.kr(SinOsc.kr(0.1, 0, 10), 0, 0.25))
			]);

		comp = Compander.ar(
			noise, In.ar(side_chain_in), thresh: 0.05, slopeBelow: 1, slopeAbove: 0.01,
			clampTime: 0.05, relaxTime: 0.1, mul: amp);

		Out.ar(out, comp!2)

	}).add;


	SynthDef(\kick, {
		arg trigger_in = 100, out = 0, side_chain_out = 10, decay = 0.25, amp = 0.6;
		var tone, seq, trig;

		tone = Mix.new(
			Formlet.ar(
				In.ar(trigger_in),
				// Frequencies:

				[40, 50, 62],

				0.01, decay,

				// Amps:
				[0.6, 0.25, 0.15] * amp;

			)
		);

		//tone = Compander.ar(tone, tone, 0.01, 1, 0.1, mul:5);

		Out.ar([out, side_chain_out], Limiter.ar(tone, 0.9) ! 2);

	}).add;



	
	SynthDef(\div_clock, {
		arg out = 100;
		var tick = Impulse.ar(TChoose.kr(Impulse.kr(2), [2,4,8, 16]));
		Out.ar(out, tick);
	}).add;




	
	SynthDef(\tick_clock, {
		arg out = 100, rate = 1;
		var tick = Impulse.ar(rate);
		Out.ar(out, tick);
	}).add;



	SynthDef(\trigger_tone, {

		arg out = 0, freq = 100, amp = 1, trigger_in = 100, release_time = 0.25,
		done = 0, thresh = 0.1, above = 0.1, attack = 0.01, compressor_release = 0.1,
		gain = 1;

		var tone, env; env = EnvGen.ar(

			// A PERCUSSIVE ENVELOPE WITH VARYING RELEASE TIMES
			Env.perc(releaseTime:SinOsc.kr(0.25,0,release_time, 0.01).abs),

			// THIS RETRIGGERS THE ENVELOPE
			In.ar(trigger_in),
			//Impulse.ar(TChoose.kr(Impulse.kr(2), [2,4,8, 16])),
			doneAction: done,

		// THIS LINE CONTROLS THE OVERALL VOLUME
			levelScale:amp);

		tone = Mix.new(
			BPF.ar(
				LFSaw.ar([freq/2,freq, freq*3, freq*6]),
				env.absdif(1) * (freq * 3),
				LFNoise2.ar(0.3, 0.6, 0.4).abs,
				env)
		);

		tone = GVerb.ar(tone, 17.5, 2.6,
			inputbw: 1,
			damping: SinOsc.ar(0.5,0,0.8, 0.01).abs,
			taillevel:0.4, earlyreflevel: 0.12,
			spread: LFNoise0.ar(1, 100, 1).abs,
			mul: amp
		);

		tone = Compander.ar(tone, tone, thresh, 1, above, attack, compressor_release, gain);

		Out.ar(out, tone);

	}).add;



	SynthDef(\clap1, {
		arg trigger_in = 100, out = 0, amp = 1, pos = 0, freq = 110, delay = 1, dur = 0.2,
		delay_div = 2;

		var trig, pat, noise, env, feed;

		trig = In.ar(trigger_in);
		//trig = Impulse.ar(3);
		
		pat = Drand([
			//Dwhite(0, 1, 8),
			Dseq([1,1,1,0,0,1,1,0], 4),
			Dseq([1,0,0,0,1,0,0,1], 4)
		], inf);
		
		noise = Mix.new(
			BPF.ar(
				WhiteNoise.ar, [14,44,59,74,89, 114]*freq,
				
				//Line.kr(0.5, 0.001, 0.15),
				//EnvGen.ar(Env.new([0.5, 0.001], [0.15]), trig),
				Decay2.ar(trig, 0.001, 0.12, 1, 1),
				
				Array.fill(5, {|i| i}).exp.normalizeSum.reverse));
		
		noise = Compander.ar(noise, noise, 0.003, 1, 0.4, mul:13);
		
		env = EnvGen.ar(
			Env.perc(releaseTime:dur/2),
			trig,
			//amp,
			Demand.ar(trig, 0, pat),
			doneAction:0
		);
		
		noise = noise * env;
		
		//feed = LocalIn.ar(1) + noise;
		
		//feed = DelayN.ar(feed, 2, dur / delay_div);
		
		//LocalOut.ar(feed * 1);
			
		//Out.ar(out, Pan2.ar(noise + (feed * delay), pos, env));

		Out.ar(out, Pan2.ar(LPF.ar(noise, 22000), pos, env));
		
	}).add;
	
});

//s.prepareForRecord;

)

(

//s.record;

// TWO ARRAYS CONTAINING DEGREES OF A SCALE
a = [0, 5, 0, 5, 0, 0, 5, 0, 0, 5];
b = [3, 8, 4, 8, 3, 10, 3, 3, 7, 8];

// COMBINE THE ABOVE ARRAYS SO THAT THE PATTERN BELOW PLAYS TWO NOTES AT ONCE FOR EACH ROOT
f = [a,b].flop;

Pdef(\organ).play(quant:1).fadeTime = 3.5;
Pdef(\kick).play(quant: 1).fadeTime = 2;
Pdef(\clock).play(quant: 1);
Pdef(\noise).stop(quant: 1).fadeTime = 4;
Pdef(\clap).stop(quant:1);

Pdef(\organ,
	Pmono(\trigger_tone,
		\addAction, 1,
		\trigger_in, 100,
		\done, 0,
		\scale, Scale.minor,
		\root, [-30, -22, -18, -20],
		//\root, [-32, -22, -8, -3],
		//\root, [-12, -2],
		\degree, Pseq(f, inf),
		\dur, Pseq([0.25, 0.5], inf),
		\thresh, 0.065,
		\above, 0.08,
		\gain, 3.6,
		\compressor_release, 0.25,
		\amp, 0.2,
		\release_time, 0.25,
		\out, 0
	)
);


Pdef(\clock,
	Pmono(\tick_clock, \addAction, 0, \rate, 0.3, \out, 100);
	//Pmono(\div_clock, \addAction, 0, \out, 100);
);


Pdef(\kick,
	Pmono(\kick, \addAction, 1, \decay, 0.5, \amp, 0.85)
);

Pdef(\noise,
	Pmono(\noise, \addAction, 1, \trigger_in, 10, \amp, 0.2);
);


Pdef(\clap,
	Pmono(\clap1,
		\delay, 2,
		\delay_div, 2,
		\freq, Prand([100, 110, 220], inf),
		\amp, 0.1,
		\addAction, 1,
		\dur, Pwhite(0.2, 0.5),
		\pos, Pwhite(-0.24,0.24)
	);
);



)


/*

PdefAllGui(16);

s.plotTree;
s.meter;
s.freqscope;
s.scope;

s.queryAllNodes;
s.sendMsg(\n_free, 1011);
s.stopRecording;

s.sendMsg(\s_new, \clap1, s.nextNodeID, 1, 1, \freq, 110, \amp, 0.5); 

*/