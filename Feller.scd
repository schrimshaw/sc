o = Server.local.options;
o.numBuffers = 6000;
o.numWireBufs = 128*2;

s.boot;

s.doWhenBooted({

/*
// Additive with internal envelopes.

SynthDef(\adder, {
	| fund = 40.34, gate=1 |
	var parts = 7, freqs, phase, mod, amps;
	freqs = Array.fill(parts, {|i| fund * (i**1.rrand(1.34))});
	phase = Array.rand(parts, -2pi, 2pi);
	mod = SinOsc.kr(TRand.kr(0.1, 20, Dust.kr(2)));


	amps = Array.fill(parts, {	EnvGen.kr(Env.circle(Array.rand(parts, 0, parts.reciprocal*2), Array.rand(parts-1, 0.5, 2)), gate)});
	Out.ar(0, DynKlang.ar(`[freqs, amps, phase]) 	* mod);
	// envelopes for right channel:
	amps = Array.fill(parts, {	EnvGen.kr(Env.circle(Array.rand(parts, 0, parts.reciprocal*2), Array.rand(parts-1, 0.5, 2)), gate, doneAction:2)});
	Out.ar(1, DynKlang.ar(`[freqs+2.2, amps, phase]) 	* mod);
}).play;

s.sendMsg(\n_free, 1002);
*/


~feller = Group.new(s, 0);

	
	SynthDef(\additive, { |out = 0, cut=22000, q=1, amp = 0.6|
		var freqs, phase, amps, parts = 80, stack, mod, feed;
		freqs = Control.names([\freqs]).kr(Array.fill(80, {|i| 40 * (i ** 0.984)}));
		phase = Control.names([\phase]).kr(Array.rand(parts, -8.0pi, 8.0pi));
		amps = Control.names([\amps]).kr(Array.fill(parts, {|i| 1/(i+(parts/10))}));
		stack = DynKlang.ar(`[freqs, amps, phase]);
		mod = SinOsc.kr(TRand.kr(0.5, 15, Dust.kr(4)), 0, SinOsc.kr(0.1).abs, 1).abs;
		feed = RLPF.ar(stack, cut * mod, q);
		Out.ar(out, (feed * 0.5) * amp);
	}).add;

	SynthDef(\verb_decay, { |amp = 1|
		var synth =
		GVerb.ar(
			Decay.ar(
				Impulse.ar(TRand.kr(0.2, 15, Dust.kr(2))),
				LFNoise1.kr(6, 0.5).abs, LPF.ar(In.ar(10), 22000)
			), 14, 0.5, 0, LFNoise2.kr(1, 0.85).abs,
			drylevel:1, taillevel:LFNoise2.kr(0.3, 0.6)
		);

		Out.ar(0, synth * amp);
	}).add;

	SynthDef(\env, {
		|in = 10, attack = 0.01, decay = 0.1, sustain = 0.8, release = 1.2, out = 0, selector = 1, gate = 1, amp = 1|
		var sig = In.ar(in), env;
		env = Env.adsr(attack, decay, sustain, release);
		sig = sig * EnvGen.kr(env, gate, doneAction: 2);
		sig = GVerb.ar(sig, 13, 3, 1, 1, 5, 0.8, 0.2, 0.8);
		Out.ar(out, Pan2.ar(sig, sig, 0.6 * amp));
	}).add;

	s.sync;




	
	s.sendMsg(\s_new, \additive, b = s.nextNodeID, 0, ~feller.nodeID, \out, 10);


	/*

	Pbind(\instrument, \additive,
		\amp, Ptuple(Array.fill(80, {|i| 1/(i+(8))}).rotate(-10.rrand(10)), inf),
		\freqs, Ptuple(Array.fill(80, {|i| f.value * (i ** p)}), inf),
		\dur, Pwhite(0.01, 0.5)
	).play;

	*/

	
	t = Task.new({
		loop({
			~freq = [17, 20, 30, 40, 4000, 12000].choose; ~power = 0.984;

			s.sendMsg(\n_setn, b, \amps, 80,
				*Array.fill(80, {|i| 1/(i+(8))}).rotate(-10.rrand(10)));

			s.sendMsg(\n_setn, b, \freqs, (20..80).choose,
				*Array.fill(80, {|i| ~freq.value * (i ** ~power)}));

			s.sendMsg(\n_set, b, \cut, 22000, \q, 0.1);

			s.sendMsg(\s_new, \env, e = s.nextNodeID, 1, ~feller.nodeID,
				\in, 10, \gate, 1, \attack, 0.05, \release, 1.7);
			
			1.5.rand.wait;
			
			p = 3.2.rand; s.sendMsg(\n_setn, b, \freqs, 80,
				*Array.fill(80, {|i| ~freq.value * (i ** ~power)}));

			s.sendMsg(\n_set, e, \gate, 0);

			0.01.rrand(0.5).wait;
			//0.005.rrand(5).wait; // better when using with other synths, leaves some space
		})
	});

	r = Task.new({
		loop({
			~freq = [30, 40, 4000, 7000, 8000, 9000, 12000].choose; ~power = 0.984.rand;
			s.sendMsg(\n_setn, b, \freqs, 20, *Array.fill(20, {|i| ~freq.value * (i ** ~power)}));
			//s.sendMsg(\n_setn, b, \amp, 20, *Array.fill(20, {|i| 1/(i+(8))}).rotate(-10.rrand(10)));
			0.2.rrand(3).wait;
		})
	});

	// MIDI Things

	MIDIClient.init;

	MIDIIn.connectAll;

	// Make sure that everything is clear:
	MIDIdef.freeAll;
	
	MIDIdef.cc(\tone_toggle, {|val| if(val==127, {t.play}, {t.pause})}, 0, 1);

	MIDIdef.cc(\pulse_toggle, {|val| if(val==127, {
		s.sendMsg(\n_free, e);
		s.sendMsg(\s_new, \verb_decay, d = s.nextNodeID,1, ~feller.nodeID); r.play;},
		{r.pause; s.sendMsg(\n_free, d);}
	)}, 1, 1);

});



/*
s.meter;
*/


/*

~feller.set(\amp, 1);

~feller.free;

s.meter;
MIDIdef.freeAll;

t.play;
t.pause;
t.resume;

t.stop;
s.sendMsg(\s_new, \verb_decay, d = s.nextNodeID,1,0);

s.sendMsg(\n_free, e);

r.play;
r.stop;
s.sendMsg(\n_free, d);

MIDIdef(\mf).free;

*/