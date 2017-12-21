s.boot;


(

SynthDef(\feed_hit, { |out = 0, amp = 0.3, decay = 1, room_size = 8|
	var rate, trigger, mod_source, snd, feed;
	trigger = Impulse.ar(0);
	mod_source = LFNoise2.ar(TRand.ar(20, 200, trigger));
	snd = Decay.ar(trigger, TRand.ar(0.05, decay, trigger), WhiteNoise.ar);
	feed = LocalIn.ar(1) + snd;
	feed = DelayN.ar(feed, 5, LFNoise2.ar(3, 0.5, 0.1).abs);
	feed = HPF.ar(feed, mod_source.abs * (TExpRand.ar(200, 10000, trigger) + 20));

	// Mul & add were 1.5 & 0.5, but think this lead to explosions...
	LocalOut.ar(feed * LFNoise2.ar(TRand.ar(1, 11, trigger), 0.45, 0.75));

	feed = Limiter.ar(feed, 0.7, 0.01);
	DetectSilence.ar(feed, doneAction:2);
	Out.ar(out, Pan2.ar(feed, mod_source * TRand.ar(0,0.85, trigger), amp));
}).add;







SynthDef(\pulse_mod, {
	|amp = 0.45, freq = 102, mod_depth = 0.85, out = 0|
	var pulse, freq_mod;

	freq_mod =
	freq + SinOsc.kr(
		TRand.kr(0.1, 10.16, Dust.kr(1)), 0, TRand.kr(0.1, TIRand.kr(5, 130, Dust.kr(1)), Dust.kr(2)) * mod_depth);

	pulse = Pulse.ar(
		freq_mod,
		SinOsc.ar(0.05,0,0.3,0.1).abs,
		SinOsc.ar([
			TRand.ar(0.5, 3, Dust.ar(2)),
			TRand.ar(0.5, 8, Dust.ar(1))
		])
	);

	// the clip here keeps the filter frequencies beneath nyquist and avoids distortion.
	pulse = LPF.ar(pulse, LFNoise2.ar(TRand.ar(0.5, 15, Dust.ar(1)).abs, 17000, 25).abs.clip(20, 20000));

	Out.ar(out, Splay.ar(pulse * amp));
}).add;








SynthDef(\bands, { |freq = 207, mul = 0.001, amp = 1, out = 0|
	var n = 24, noise, rqs, freqs, bands, feed;
	noise = WhiteNoise.ar;

	rqs = Array.fill(n, {
		LFNoise0.kr(
			LFNoise2.kr(1, 50, 1).abs,
			LFNoise2.kr(5.rand,
				LFNoise2.kr(TRand.kr(0.1, 0.5, Dust.kr(0.2)), 0.01)
			).abs
		).abs
	});

	freqs = freq + [0, 53, 74, 93, 182, 230, 259, 456, 585, 822, 869, 871, 886, 978, 1107, 1250, 1519, 1651, 1708, 1735, 2072, 2237, 2460, 2711];


	// BASS PULSE
	Out.ar(0, Mix.new(Formlet.ar(Dust.ar(0.1), freqs[0] / [4,6], 0.01, 7, 0.8))!2);

	bands = Splay.ar(BPF.ar(noise, freqs, rqs, 6));
	feed = LocalIn.ar(2) + bands;
	feed = DelayN.ar(feed, 2, LFNoise0.kr(0.25, 1.8).abs);
	LocalOut.ar(feed*LFNoise2.kr(0.23).abs);
	Out.ar(out, bands*10 * amp);
	Out.ar(out,Splay.ar(feed), 1, 0.5*amp);
}).add;




SynthDef(\reverb, { |in = 10, out = 0, room = 22, revtime = 0.67, damp = 0.1, bw = 0.9, tail = 0.6, amp = 0.3|
	Out.ar(out, GVerb.ar(In.ar(in), room, revtime, damp, bw, taillevel: tail, mul: amp));

}).add;





SynthDef(\line, { |out = 100, end = 0, dur = 1|
	var line;
	line = Line.kr(In.kr(out), end, dur, doneAction: 2);
	Out.kr(out, line);

}).add;

)




(

~fade_bus = Bus.control(s, 1).set(0);

~reverb_group = ParGroup.new;

Pdef(\reverb).play;

Pdef(\reverb,
	Pmono(\reverb, \group, ~reverb_group, \in, 10, \out, 0, \room, 12, \revtime, 0.67, \damp, 0.1, \bw, 0.9, \tail, 1, \amp, 0.45)
);


~feed_group = ParGroup.new;

Pdef(\feed_hit,
	Pbind(\instrument, \feed_hit,
		\group, ~feed_group,
		\addAction, 0,
		//\room_size, Prand([2,4,8], inf),
		\decay, Pwhite(0.5, 3),
		//\delta, Pwhite(0.25, 0.5),
		\delta, Prand([0.5, 1, 2, 4], inf),
		\amp, Pwhite(0.25, 0.47),
		\out, 0)
);

Pdef(\bands,
	Pmono(\bands, \amp, 0.62, \freq, 52.midicps, \out, 0)
);


Pdef(\bass,
	Pmono(\pulse_mod, \freq, Pwrand([42, 48], [0.8, 0.2], inf), \mod_depth, 0,
		//\amp, 0.25,
		\amp, ~fade_bus.asMap,
		\dur, Pwhite(6.5, 9),
		\out, [0, 10]);
);

Pdef(\mid,
	Pmono(\pulse_mod, \freq, 168 * [1,2,3], \mod_depth, 0.98, \amp, 0.1, \out, [0, 10]);
);


)







(
Pdef(\feed_hit).play(quant:1);
Pdef(\bands).play(quant:1);
)







(

var mods, amps = [0.26, 0.26, 0.115] * 0.735;
mods = [0.26, 0.26, 0.16];

~high_group = ParGroup.new;

fork{
	[3919, 2919, 3099].do({ |f, i|
		Synth(\pulse_mod, [\freq, f, \amp, amps[i], \mod_depth, mods[i]], target: ~high_group);
		15.5.rrand(23).wait;
	});
	"High Tones done".postln;
}
)





(
Pdef(\bass).play(quant:1);
// fade the bass in:
Synth(\line, [\out, ~fade_bus, \end, 0.35, \dur, 35]);
)


Pdef(\mid).play;






(

Pdef(\bass).stop;
Pdef(\bands).stop;
Pdef(\mid).stop;
Pdef(\reverb).stop;

~reverb_group.free;


Pdef(\feed_hit,
	Pbind(\instrument, \feed_hit,
		\group, ~feed_group,
		\addAction, 0,
		//\room_size, Prand([2,4,8], inf),
		\decay, Pwhite(0.5, 3),
		\delta, Pwhite(0.25, 0.5),
		//\delta, Prand([0.5, 1, 2, 4], inf),
		\amp, Pwhite(0.25, 0.65),
		\out, 0)
);
)






(
~high_group.free;
Pdef(\feed_hit).stop;
)







/*
Here's a way to map long deltas to long decays

d = Pwhite(0.3, 3).asStream;

~dec = Pfunc({d.next.postln.linlin(0.3,5,0.4,0.8)}).asStream;

~dec.next;

s.meter;
s.queryAllNodes;
s.plotTree;
*/







// {Mix.new(Formlet.ar(Mix([Impulse.ar(0), Dust.ar(0.1)]), 52.midicps / [4,6], 0.01, 7, 0.8))!2}.play;