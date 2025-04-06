// DEPENDENCIES
// Below code requires:
Quarks.install("PitchShiftPA"); // Only needs to be done once on the system

// ==========================================================
// STEP 1: Setting up the speaker configuration | should be changed according to the actual setup
// This defines the positions of speakers in 3D space
// Each pair of numbers is [azimuth, elevation] in degrees:
// - Azimuth: horizontal angle (0 = front, 90 = right, 180 = back, -90 = left)
// - Elevation: vertical angle (0 = ear level, 45 = above, -45 = below)
// ==========================================================
(
~speakerSetup = VBAPSpeakerArray(3, [
	[-45, 0],
	[0, 0],
	[45, 0],
	[90, 0],
	[135, 0],
	[180, 0],
	[-135, 0],
	[-90, 0],
	[-45, 45],
	[45, 45],
	[135, 45],
	[-135, 45]
]);
)

// For only stereo speakers; simplified setup:
// ~speakerSetup = VBAPSpeakerArray(2, [[-30, 0], [30, 0]]);

// The number of speakers can be checked with this command
~speakerSetup.numSpeakers;

// Second step: loading the setup into a buffer
// The VBAP matrices are stored in a buffer for efficient processing
~vbapBuffer = Buffer.loadCollection(s, ~speakerSetup.getSetsAndMatrices);

// Basic implementation with manual control parameters
(
Ndef(\texturesfxgrainIN, {
	// Parameters that can be adjusted while the sound is playing
	|amp = 4, freq = 400, pitchRatio = 1, formantRatio = 1, minFreq = 10, maxFormantRatio = 10,
	grainsPeriod = 2, timeDispersion = 1, spr = 1, speedUp = 0.1, speedSide = 20, gate = 1|

	var in, sig, output;
	var jSource1, jAmnt1;

	// Jitter source for frequency modulation
	jSource1 = LFDNoise0.ar(1).range(1, 100);
	jAmnt1 = 0.6; // The amount of jitter/modulation

	// Audio input processing
	in = SoundIn.ar(0); // Getting audio from the first input (microphone)
	sig = PitchShiftPA.ar(in,
		freq + (jSource1 * jAmnt1),
		pitchRatio,
		formantRatio,
		minFreq,
		maxFormantRatio,
		grainsPeriod,
		timeDispersion
	);

	// Optional reverb and delay for coloring the sound
	// sig = FreeVerb.ar(DelayC.ar(sig, 1, 0.5, 1), 0.4, 3);

	// Optional way to perform the same sounds but in other multichannel setup.
	// This should be uncommented and everything else that comes below should be commented.
	// sig = SplayAz.ar(2, sig * amp, LFNoise2.ar(0.7), 1, 2);

	// Mixing down to mono for VBAP spatialization
	sig = Mix.new(sig);

	// VBAP spatialization - positions the sound in 3D space using the speaker array
	output = VBAP.ar(~speakerSetup.numSpeakers,
		sig,
		~vbapBuffer.bufnum,
		LFNoise2.kr(speedSide, 1).range(-180, 180) * -1,
		SinOsc.kr(speedUp, 0).range(0, 90),
		spr
	);

	// Amplitude control and envelope to prevent clicks
	output = output * amp * EnvGen.ar(Env.asr(4, 1, 1), gate, doneAction: 2);
});
)


// play the Ndef
Ndef(\texturesfxgrainIN).play

// stop the Ndef
Ndef(\texturesfxgrainIN).stop

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////// NDEF WITH PATTERN CONTROLS /////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Pattern-based control definitions for spatialization
(
// Azimuth pattern using Demand UGens
// Cycles through speaker positions horizontally
Ndef(\azimuthPattern, {
	var trig, seq;
	trig = Impulse.kr(0.5); // Trigger rate - controls the speed of azimuth changes
	seq = Dseq([0, 45, 90, 135, 180, -135, -90, -45], inf);
	Demand.kr(trig, 0, seq);
});

// Elevation pattern using Demand UGens
// Creates vertical movement patterns
Ndef(\elevationPattern, {
	var trig, seq;
	trig = Impulse.kr(0.8); // Different trigger rate for variation
	seq = Dseq([0, 15, 30, 45, 30, 15], inf);
	Demand.kr(trig, 0, seq);
});
)

// Main processing with pattern-controlled spatialization
(
Ndef(\texturesfxgrainIN, {
	|amp = 4, freq = 400, pitchRatio = 1, formantRatio = 1,
	minFreq = 10, maxFormantRatio = 10, grainsPeriod = 2,
	timeDispersion = 1, spr = 60, gate = 1|

	var in, sig, output;
	var jSource1, jAmnt1;
	var azimuth, elevation;

	// Pitch modulation amount
	jSource1 = LFDNoise0.ar(1).range(1, 100);
	jAmnt1 = 0.6;

	// Get position values from pattern controls
	azimuth = Ndef(\azimuthPattern).kr;
	elevation = Ndef(\elevationPattern).kr;

	// Audio signal processing chain
	in = SoundIn.ar(0);
	sig = PitchShiftPA.ar(in,
		freq + (jSource1 * jAmnt1),
		pitchRatio,
		formantRatio,
		minFreq,
		maxFormantRatio,
		grainsPeriod,
		timeDispersion
	);

	// Optional reverb and/or delay for coloring the sound
	// sig = FreeVerb.ar(DelayC.ar(sig, 1, 0.5, 1), 0.4, 3);

	// Optional way to perform the same sounds but in other multichannel setup.
	// This should be uncommented and everything else that comes below should be commented out.
	// sig = Mix.new(SplayAz.ar(2, sig * amp, LFNoise2.ar(0.7), 1, 2));

	// Mixing to mono before spatialization
	sig = Mix.new(sig);

	// VBAP spatialization with pattern-controlled positions
	output = VBAP.ar(~speakerSetup.numSpeakers,
		sig,
		~vbapBuffer.bufnum,
		azimuth,
		elevation,
		spr
	);

	// Output level control with envelope
	output = output * amp * EnvGen.ar(Env.asr(4, 1, 1), gate, doneAction: 2);
	output.flatten;
});
)

// play the Ndef
Ndef(\texturesfxgrainIN).play

// stop the Ndef
Ndef(\texturesfxgrainIN).stop

// Clear all node definitions when finished
Ndef.clear;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*
Using Ndef with Pbind might not give the smooth continuous movement desired for VBAP since it's event-based.
This would create more discrete "jumps" between positions rather than smooth transitions.
For smoother spatial movement, continuous control like LFTri or SinOsc is preferred.
*/

// Continuous movement example using oscillators
// These variables can be used in place of the discrete patterns
// azimuth = LFSaw.kr(azimuthSpeed).range(-180, 180);  // Full rotation
// elevation = SinOsc.kr(elevationSpeed).range(0, 45);  // Smooth up/down

// The movement speed can be controlled by setting:
//Ndef(\texturesfxgrainIN).set(\azimuthSpeed, 0.2);  // slower/faster rotation
// Ndef(\texturesfxgrainIN).set(\elevationSpeed, 0.1); // slower/faster elevation changes

////////////////////////////////////////////  ADDITIONAL PATTERNS FOR ELEVATION  /////////////////////////////////////

// Wave-like movement pattern
// Creates a smooth wave pattern for elevation
Ndef(\elevationPattern, {
	var trig, seq;
	trig = Impulse.kr(0.8);
	seq = Dseq([0, 15, 30, 45, 30, 15, 0], inf);
	Demand.kr(trig, 0, seq);
});

// Random jumps pattern
// Creates unpredictable vertical movements
Ndef(\elevationPattern, {
	var trig, seq;
	trig = Impulse.kr(0.8);
	seq = Drand([0, 15, 30, 45, 60], inf);
	Demand.kr(trig, 0, seq);
});

// Gradually rising and folding pattern
// Creates a sawtooth-like pattern but with discrete steps
Ndef(\elevationPattern, {
	var trig, seq;
	trig = Impulse.kr(0.8);
	seq = Dser((0, 5..55).fold(0, 45), inf);  // Creates series 0,5,10,15...45,40,35...
	Demand.kr(trig, 0, seq);
});

// Dramatic height changes pattern
// Creates stark contrasts in elevation
Ndef(\elevationPattern, {
	var trig, seq;
	trig = Impulse.kr(0.8);
	seq = Dseq([0, 45, 0, 30, 0, 45], inf);
	Demand.kr(trig, 0, seq);
});

//////////////////////////////////////////// CLEANUP ////////////////////////////////////////////

// Clearing all node definitions when finished
Ndef.clear;