/*
=====================================================================
COMPLEX NESTED PROBABILITY STRUCTURES
(as discussed in thesis section "Workflow & Creative Implementation" of Case Study 3)
 =====================================================================
*/





// =====================================================================
// GLITCH GRANULAR WITH DYNAMIC GLISSANDO
// (central implementation discussed in "Workflow & Creative Implementation" of Case Study 3)
// =====================================================================

// Setup buffers

~sample1 = Buffer.readChannel(s, "/path_to_your_sound", channels: [0]);
~sample2 = Buffer.readChannel(s, "/path_to_your_sound", channels: [0]);

Ndef(\glitchGranularDynamicGliss).fadeTime = 10;

(
Ndef(\glitchGranularDynamicGliss, { |trig = 1, gliss = 0.5, windowSize = 0.005, pitchDisp = 0.005, dencityKick = 0.09|
	var numGrains = 10;
	var trigger, pos, dur, rate, amp, grainEnv;
	var kickTrigger, kickEnv, kickSynth, kickLow, kickGlitch;
	var buffers = [~sample1, ~sample2];
	var grainSound, processedGrainSound;
	var stutterTrig, glissandoTrig, glissandoEnv, glissandoAmpEnv, glissandoSpeedEnv;
	var bassDropTrig, bassDropEnv, bassDropSynth;

	trigger = Dust.kr(trig);
	grainEnv = EnvGen.ar(Env.perc(0.001, 10), trigger);
	grainSound = Mix.fill(numGrains, {
		var buf = Select.kr(TIRand.kr(0, buffers.size - 1, trigger), buffers);
		pos = TRand.kr(0, BufDur.kr(buf), trigger);
		dur = TExpRand.kr(0.001, 0.1, trigger);
		rate = TExpRand.kr(0.5, 2, trigger);
		amp = TRand.kr(0.1, 1, trigger);
		GrainBuf.ar(1, trigger, dur, buf, rate, pos, 2) * amp * grainEnv;
	});

	stutterTrig = Dust.kr(1);
	grainSound = SelectX.ar(
		ToggleFF.kr(stutterTrig),
		[
			grainSound,
			CombC.ar(grainSound, 0.5, LFNoise2.kr(4).range(0.01, 0.1), LFNoise2.kr(0.5).range(0.1, 0.5))
		]
	);

	glissandoTrig = Dust.kr(1);
	glissandoEnv = EnvGen.kr(
		Env(
			[1, LFNoise2.kr(0.1).range(0.5, 2), 1],
			[LFNoise2.kr(0.1).range(5, 20), LFNoise2.kr(0.1).range(5, 20)],
			[\sine, \welch]
		),
		glissandoTrig
	);
	glissandoSpeedEnv = EnvGen.kr(
		Env(
			[1, LFNoise2.kr(0.1).range(0.5, 2), LFNoise2.kr(0.1).range(0.5, 2), 1],
			[LFNoise2.kr(0.1).range(2, 7), gliss, LFNoise2.kr(0.1).range(2, 7)],
			[\sine, \welch, \sine]
		),
		glissandoTrig
	);
	glissandoAmpEnv = EnvGen.kr(
		Env(
			[1, LFNoise2.kr(0.1).range(0.3, 1.5), LFNoise2.kr(0.1).range(0.3, 1.5), 1],
			[LFNoise2.kr(0.1).range(2, 7), LFNoise2.kr(0.1).range(2, 7), LFNoise2.kr(0.1).range(2, 7)],
			[\sine, \welch, \sine]
		),
		glissandoTrig
	);
	processedGrainSound = PitchShift.ar(
		grainSound,
		windowSize,
		glissandoEnv * glissandoSpeedEnv,  // * 3  * 100
		pitchDisp,    //  1000
		0.1  //  1000
	) * glissandoAmpEnv;
	grainSound = XFade2.ar(grainSound, processedGrainSound, EnvGen.kr(Env([0, 1, 1, 0], [0.1, 20, 0.1], \sine), glissandoTrig) * 2 - 1);

	kickTrigger = Dust.kr(dencityKick);
	kickEnv = EnvGen.ar(Env.new([0, 1, 0.5, 0], [0.005, 0.1, 0.3], [2, -4, -4]), kickTrigger);
	kickLow = SinOsc.ar(XLine.kr(80, 40, 0.1)) * EnvGen.ar(Env.perc(0.005, 0.4), kickTrigger);
	kickSynth = kickLow * kickEnv * 2;
	kickGlitch = kickSynth * LFPulse.ar(LFNoise1.kr(4).exprange(4, 100), 0, LFNoise1.kr(200).range(0.9, 2));
	kickGlitch = CombC.ar(kickGlitch, 0.5, LFNoise2.kr(0.2).range(0.05, 0.1), LFNoise2.kr(0.2).range(0, 1));

	bassDropTrig = Dust.kr(0.4);
	bassDropEnv = EnvGen.ar(
		Env([0, 1, 0.7, 0], [0.05, 0.7, 0.65], [2, \sine, -6]),
		bassDropTrig
	);
	bassDropSynth = SinOsc.ar(
		EnvGen.kr(
			Env([40, 10], [1], \exp),
			bassDropTrig
		)
	) * bassDropEnv * 2;

	Mix([
		grainSound * 2,
		kickGlitch * 0.7,
		bassDropSynth * 0.7
	])
});
);


// =====================================================================
// AMBISONIC SPATIAL PROCESSING
// (as discussed in "Ambisonics within SuperCollider" section)
// =====================================================================

// HOA Processing for glitchGranularDynamicGliss

(
// Ndef for ambisonic processing
Ndef(\ambisonicSystem6, {
	var source = Ndef(\glitchGranularDynamicGliss).ar;
	var theta = LFNoise2.kr(0.1).range(0, 2pi);
	var phi = LFNoise2.kr(0.08).range(-0.5pi, 0.5pi);
	var radius = LFNoise2.kr(0.05).range(1, 3);
	var rotAngle = LFNoise2.kr(0.15).range(0, 2pi);
	var hoaSignal = HoaEncodeDirection.ar(source, theta, phi, radius, ~order);
	var rotatedSignal = HoaRotate.ar(hoaSignal, rotAngle, ~order);
	var decodedSignal = Mix.ar(rotatedSignal * ~decoderMatrix.flop);
	decodedSignal
});
)

// Playing the spatialized sound
Ndef(\ambisonicSystem6).play(fadeTime: 10);
Ndef(\ambisonicSystem6).stop(fadeTime: 6);


// =====================================================================
// EFFECT CHAINS WITH UNCONVENTIONAL APPROACH
// (described in "Workflow & Creative Implementation" of Case Study 3)
// =====================================================================

// Effect processing with randomized parameter control

(
// Create control buses for each effect
~effectControls = Array.fill(7, { Bus.control(s, 1) });

Ndef(\LivePlayer, {
	var input, processedSig, trigger, ampAnalysis, peakPos;
	var crossfade, fadeTime = 0.1;
	var silenceDetector, silenceTrigger;
	var effectCount = 7;
	var effectTriggers, effectSignals, effectEnvelopes;
	var reverseBuf, recordBuf, stretchBuf;
	var effectOnOff;
	var beatSource, beatTrigger, beatDuration, beatEnv, beatGate;

	// Live input (mono)
	input = SoundIn.ar(0);

	// Buffers for effects (mono)
	reverseBuf = LocalBuf(10 * SampleRate.ir, 1).clear;
	stretchBuf = LocalBuf(10 * SampleRate.ir, 1).clear;

	// Continuously record into buffers
	recordBuf = RecordBuf.ar(input, reverseBuf, loop: 1);
	RecordBuf.ar(input, stretchBuf, loop: 1);

	// Trigger for choosing new effect timings
	trigger = Impulse.kr(1/2);

	// Silence detector
	silenceDetector = DetectSilence.kr(A2K.kr(LocalIn.ar(1)), amp: 0.01, time: 3);
	silenceTrigger = Changed.kr(silenceDetector);

	// Combine regular trigger with silence trigger
	trigger = trigger + silenceTrigger;

	// Random triggers for effects
	effectTriggers = Array.fill(effectCount, {
		Dust.kr(TExpRand.kr(0.05, 8, trigger))
	});

	// Read control values for each effect
	effectOnOff = ~effectControls.collect { |bus| In.kr(bus) };

	// Effect signals (now mono)
	effectSignals = [
		// 1. Radical Glitch/Stutter effect
		Latch.ar(input, Impulse.ar(TRand.kr(1, 70, effectTriggers[0]))) * effectOnOff[0],

		// 2. Extreme Grain Freeze effect
		{
			var grainDur = TRand.kr(0.01, 0.3, effectTriggers[1]);
			var grainTrig = Impulse.ar(1/grainDur);
			GrainIn.ar(1, grainTrig, grainDur, input, envbufnum: -1) * 2 * effectOnOff[1]
		}.(),

		// 3. Radical Reverse effect
		PlayBuf.ar(1, reverseBuf, rate: TChoose.kr(effectTriggers[2], [-1, -2, -0.5, -10]), trigger: effectTriggers[2], startPos: TRand.kr(0, BufFrames.ir(reverseBuf), effectTriggers[2])) * effectOnOff[2],

		// 4. Extreme Pitch Shift effect
		PitchShift.ar(input, windowSize: 0.1, pitchRatio: TChoose.kr(effectTriggers[3], [0.25, 0.5, 2, 9, -7])) * effectOnOff[3],

		// 5. New Grain Freeze effect
		{
			var grainDur = TRand.kr(5, 30, effectTriggers[4]);
			var grainTrig = Delay2.kr(Impulse.ar(1 / grainDur));
			var freeze = LFNoise1.kr(0.04).range(10, 50);
			GrainIn.ar(1, grainTrig, grainDur, input, envbufnum: -1, maxGrains: 512) * EnvFollow.ar(input, 0.2).max(freeze) * effectOnOff[4]
		}.(),

		// 6. New Time Stretching effect
		{
			var stretchRatio = TExpRand.kr(0.15, 0.6, effectTriggers[5]);
			var grainSize = TExpRand.kr(0.01, 10, effectTriggers[5]);
			var pos = Phasor.ar(0, stretchRatio * BufRateScale.kr(stretchBuf), 0, BufFrames.kr(stretchBuf));
			var grainTrig = Impulse.ar(1 / grainSize);
			GrainBuf.ar(1, grainTrig, grainSize, stretchBuf, 1, pos / BufFrames.kr(stretchBuf), 2, -1, 512) * effectOnOff[5]
		}.(),

		// 7. Greyhole effect with random parameters
		{
			var greyHoleTrig = effectTriggers[6];
			var greyHoleDur = TRand.kr(10, 60, greyHoleTrig);
			var greyHoleEnv = EnvGen.kr(Env([0, 1, 1, 0], [0.1, greyHoleDur - 0.2, 0.1], curve: \sine), greyHoleTrig);

			var delayTime = TExpRand.kr(0.1, 2, greyHoleTrig);
			var damping = TRand.kr(0, 5, greyHoleTrig);
			var size = TRand.kr(0.5, 5, greyHoleTrig);
			var diff = TRand.kr(0, 1, greyHoleTrig);
			var feedback = TRand.kr(0.4, 0.96, greyHoleTrig);
			var modDepth = TRand.kr(0, 1, greyHoleTrig);
			var modFreq = TExpRand.kr(0.01, 10, greyHoleTrig);

			Greyhole.ar(input, delayTime, damping, size, diff, feedback, modDepth, modFreq)[0] * greyHoleEnv * effectOnOff[6]
		}.()
	];

	// Effect envelopes
	effectEnvelopes = effectTriggers.collect { |trig|
		EnvGen.kr(Env.perc(0.005, TExpRand.kr(0.1, 2, trig)), gate: trig)
	};

	// Mixing only the effects (no dry signal)
	processedSig = Mix.ar(effectSignals * effectEnvelopes);

	// distortion for more grit
	processedSig = (processedSig * 5).tanh * 0.4;

	// High-pass filter to remove rumble
	processedSig = HPF.ar(processedSig, 20);

	// Amplitude analysis
	ampAnalysis = Amplitude.kr(processedSig);
	peakPos = Timer.kr(ampAnalysis > 0.09).clip(0, 1);

	// Beat generation (original version)
	beatSource = {
		var a = LFTri.ar(1/3);
		9.do {
			a = BAllPass.ar(a, PinkNoise.kr(0.2, 41), 1);
			a = BAllPass.ar(a, LFNoise0.kr(7/8, 2400, 2200), 2);
			a = (a * LFNoise0.kr(3/4, 7, 2)).tanh;
			a = LeakDC.ar(a);
		};
		a/3
	}.();

	// Beat triggering and envelope
	beatTrigger = Dust.kr(1/15);  // Trigger on average every 15 seconds
	beatDuration = TRand.kr(2, 10, beatTrigger);  // Random duration between 2 and 10 seconds
	beatGate = Trig.kr(beatTrigger, beatDuration);
	beatEnv = EnvGen.kr(Env([0, 1, 1, 0], [0.1, beatDuration - 0.2, 0.1], curve: \sine), beatGate);

	// Mixing beat with processed signal
	processedSig = processedSig + (beatSource * beatEnv * 0.5);

	// Crossfade between old and new signal
	crossfade = EnvGen.kr(Env([0, 1], [fadeTime], \sine), trigger);
	processedSig = XFade2.ar(LocalIn.ar(1), processedSig, crossfade * 2 - 1);
	LocalOut.ar(processedSig);

	// Overall envelope
	processedSig = processedSig * EnvGen.kr(Env.asr(0.01, 1, 0.01), gate: 1);

	// Output (mono)
	Limiter.ar(processedSig * 0.9, 0.95, 0.01)  // Limit to prevent clipping
});

// Initially turn on all effects
~effectControls.do { |bus| bus.set(1) };
)

// Functions to turn effects on and off
(
~turnEffectOn = { |index|
	~effectControls[index].set(1);
	("Effect " ++ (index + 1) ++ " turned on").postln;
};

~turnEffectOff = { |index|
	~effectControls[index].set(0);
	("Effect " ++ (index + 1) ++ " turned off").postln;
};
)

// Turn off the effects
(
~turnEffectOff.(0);
~turnEffectOff.(1);
~turnEffectOff.(2);
~turnEffectOff.(3);
~turnEffectOff.(4);
~turnEffectOff.(5);
~effectControls[6].set(0);  // Turn off GreyHole
)

// Turn on the effects
(
~turnEffectOn.(0);   // Turn on the first effect
~turnEffectOn.(1);
~turnEffectOn.(2);
~turnEffectOn.(3);
~turnEffectOn.(4);
~effectControls[6].set(1);  // Turn on GreyHole
)

// GreyHole controls
~effectControls[6].set(1);  // Turn on GreyHole
~effectControls[6].set(0);  // Turn off GreyHole


// =====================================================================
// SPECTRAL CENTROID-BASED CONTROL
// (Advanced HOA Implementation and Machine Collaboration)
// =====================================================================

(
// Ndef for spectral centroid analysis
Ndef(\specCentroidControl, {
	var input = (Ndef(\LivePlayer).ar) * 1.4;
	var centroid = SpecCentroid.kr(FFT(LocalBuf(2048), input));
	var mappedSpeed = centroid.linexp(20, 20000, 1, 0.01);  // Map centroid frequency to LFO speed
	mappedSpeed
});

// Ndef for ambisonic processing
Ndef(\ambiLivePlayer, {
	var source = Ndef(\LivePlayer).ar;
	var thetaSpeed = Ndef(\specCentroidControl).kr;
	var theta = LFNoise2.kr(thetaSpeed).range(0, 2pi);
	var phi = LFNoise2.kr(0.08).range(-0.5pi, 0.5pi);
	var radius = LFNoise2.kr(0.05).range(1, 3);
	var rotAngle = LFNoise2.kr(0.15).range(0, 2pi);
	var hoaSignal = HoaEncodeDirection.ar(source, theta, phi, radius, ~order);
	var rotatedSignal = HoaRotate.ar(hoaSignal, rotAngle, ~order);
	var decodedSignal = Mix.ar(rotatedSignal * ~decoderMatrix.flop);
	decodedSignal
});
)

// =====================================================================
// PLAY COMMANDS AND FADEOUTS
// =====================================================================

// Playing and stopping the spatialized sound
Ndef(\ambiLivePlayer).play(fadeTime: 20);
Ndef(\ambiLivePlayer).stop(fadeTime: 20);
Ndef(\ambiLivePlayer).free;

// Clearing Ndefs
(
Ndef(\specCentroidControl).clear;
Ndef(\ambiLivePlayer).clear;
Ndef(\LivePlayer).clear;
)

// Additional Play/Stop Commands (commented for reference)
/*
// Complex and ambisonic complex
Ndef(\complex).play;
Ndef(\ambisoniccomplex).play(fadeTime: 20);
Ndef(\ambisoniccomplex).stop(fadeTime: 10);

// Glitch granular
Ndef(\glitchGranularDynamicGliss).play(0, 1);  // Play mono output
Ndef(\ambisonicSystem6).play(fadeTime: 80);
Ndef(\ambisonicSystem6).stop(fadeTime: 50);

// Live player with ambisonics
Ndef(\ambiLivePlayer).play(fadeTime: 20);
Ndef(\ambiLivePlayer).stop(fadeTime: 20);

// Clear commands
Ndef(\complex).clear;
Ndef(\ambisoniccomplex).clear;
Ndef(\glitchGranularDynamicGliss).clear;
Ndef(\ambisonicSystem6).clear;
Ndef(\specCentroidControl).clear;
Ndef(\ambiLivePlayer).clear;
Ndef(\LivePlayer).clear;
*/