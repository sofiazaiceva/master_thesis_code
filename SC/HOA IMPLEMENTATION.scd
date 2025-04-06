// BASIC HOA IMPLEMENTATION

// 1. Basic Setup
// A 3rd order Ambisonic system is being initialized with 16 channels
// and a decoder matrix for a 12-speaker dome configuration is being defined
(
~order = 3;  // 3rd order ambisonics
~numHOAChannels = (~order + 1).squared;  // 16 channels for 3rd order

// Decoder matrix for 12-speaker dome setup
// Note: These values are provided as examples only
// Actual implementation requires replacing with values specific to the speaker setup being used
~decoderMatrix = [
	[ 0.1356943398714066, 0.07435062527656555, -0.1065663769841194, 0.08597026020288467,
	0.09826100617647171, -0.03230631723999977, 0.00867766048759222, -0.03853815793991089,
	0.014493010006845, 0.06527309119701385, -0.04025755077600479, -0.01787852123379707,
	0.005838004406541586, -0.02020644955337048, -0.007306730374693871, -0.03895625472068787],
	[ 0.1294411867856979, 2.082179207718582e-6, -0.08082421123981476, 0.1071060970425606,
	7.714151593063434e-7, -1.401489953423152e-6, 0.01105216704308987, -0.008323891088366508,
	0.09873675554990768, -1.256651330550085e-6, -2.91543074126821e-7, 5.972789949737489e-6,
	-0.02022106014192104, -0.02232324331998825, -0.006370376795530319, 0.08421877026557922],
	// ... additional matrix rows would be included here
];
);

// 2. Sound Source Loading
// A buffer is being loaded with audio content for processing
~sourceBuffer = Buffer.read(s, "path/to/your/sound.wav");

// 3. Granular Source Player
// A NodeProxy is being created that reads from the buffer using granular techniques
(
Ndef(\grainSource, {
	|amp = 1, grainRate = 0.09, grainOffset = 0|
	var sig, grainPos;

	// Creating varying playback position for granular effect
	grainPos = LFNoise1.ar(grainRate).range(0.0, (~sourceBuffer.numFrames-1) + grainOffset);

	// Read from buffer with interpolation
	sig = BufRd.ar(1, ~sourceBuffer, grainPos, 1, 2);
	sig = sig * amp;

	// Basic stereo spread and limiting
	sig = Limiter.ar(sig, 0.9); // limiting
	Mix.ar(sig);
});

// Crossfade time is being set for smooth transitions
Ndef(\grainSource).fadeTime = 4;
);

Ndef(\grainSource).stop(4)

// 4. HOA Spatial Processor
// A NodeProxy for spatial encoding, rotation, and decoding is being created
(
Ndef(\hoaSpatial, {
	|
	// Motion rates
	azimuthRate = 0.1,
	elevationRate = 0.08,
	distanceRate = 0.05,
	rotationRate = 0.15,

	// Spatial ranges
	minDistance = 1,
	maxDistance = 3
	|

	var source = Ndef(\grainSource).ar; // source material

	// Spatial motion generation
	var azimuth = LFNoise2.kr(azimuthRate).range(0, 2pi);      // Horizontal plane
	var elevation = LFNoise2.kr(elevationRate).range(-0.5pi, 0.5pi); // Vertical plane
	var distance = LFNoise2.kr(distanceRate).range(minDistance, maxDistance);
	var rotation = LFNoise2.kr(rotationRate).range(0, 2pi);     // Global rotation

	// Encoding to HOA
	var hoaSignal = HoaEncodeDirection.ar(source, azimuth, elevation, distance, ~order);

	// Applying rotation
	var rotatedSignal = HoaRotate.ar(hoaSignal, rotation, ~order);

	// Decoding to speaker signals
	Mix.ar(rotatedSignal * ~decoderMatrix.flop);
});
);

// 5. Starting the system
// The spatial processor is being played to a 12-channel speaker array
(
// Playing to 12-channel speaker array
Ndef(\hoaSpatial).play(0, 12, fadeTime: 5);
)

// Stopping with fadeout
Ndef(\hoaSpatial).stop(10);

// Optional: Parameter control examples
(
Ndef(\hoaSpatial).set(
	\azimuthRate, 0.15,
	\elevationRate, 0.1,
	\distanceRate, 0.07
);
);

// Audio Analysis System
// Spectral characteristics of the input signal are being analyzed
(
Ndef(\audioAnalyzer, {
	var input = Ndef(\grainSource).ar;
	var fft = FFT(LocalBuf(2048), input);

	// Three analysis parameters
	var centroid = SpecCentroid.kr(fft);
	var flatness = SpecFlatness.kr(fft);
	var power = FFTPower.kr(fft);

	// Converting linear power to dB for better scaling (adding small value to avoid log(0))
	var powerDB = 10 * log10(power + 1e-10);

	// Limiting to prevent extreme values
	input = Limiter.ar(input, 0.9);

	// Normalized analysis data with appropriate ranges
	[
		centroid.clip(100, 12000).linlin(100, 12000, 0, 1),  // centroid frequency range
		flatness,                                           // Flatness
		powerDB.clip(-60, -10).linlin(-60, -10, 0, 1)       // Proper dB range
	];
});
);

// Advanced HOA Processor with Audio Analysis Integration
// Analysis data is being integrated to modulate spatial parameters
(
Ndef(\hoaSpatial, {
	|
	// Base parameters
	baseAzimuth = 0.5,     // 0-1 normalized base azimuth position
	baseElevation = 0.5,   // 0-1 normalized base elevation position
	baseDistance = 2.0,    // Direct base distance value
	baseRotation = 0.5,    // 0-1 normalized base rotation position

	// Modulation amounts
	azimuthMod = 0.5,      // How much noisiness affects azimuth
	elevationMod = 0.7,    // How much energy affects elevation
	distanceMod1 = 0.3,    // How much energy affects distance
	distanceMod2 = 0.3,    // How much brightness affects distance
	rotationMod = -0.5,    // How much brightness affects rotation

	// Balance between base and modulation (0-1, higher = more modulation). If the value is 0, then only static base value will be used.
	modBalance = 0.7,

	// Spatial ranges
	minDistance = 1,
	maxDistance = 3
	|

	var source, analysis;
	var brightness, noisiness, energy;
	var azimuthBase, elevationBase, distanceBase, rotationBase;
	var azimuthInfluence, elevationInfluence, distanceInfluence, rotationInfluence;
	var azimuth, elevation, distance, rotation;
	var hoaSignal, rotatedSignal;

	// Getting source and analysis signals
	source = Ndef(\grainSource).ar;
	analysis = Ndef(\audioAnalyzer).kr;

	// Extracting analysis values
	brightness = analysis[0];
	noisiness = analysis[1];
	energy = analysis[2];

	// Calculating base values
	azimuthBase = baseAzimuth * 2pi;             // 0-2π
	elevationBase = (baseElevation * 2 - 1) * 0.5pi; // -π/2 to π/2
	distanceBase = baseDistance.clip(minDistance, maxDistance);
	rotationBase = baseRotation * 2pi;           // 0-2π

	// Calculating modulation influences (centered at 0)
	azimuthInfluence = (noisiness - 0.5) * 2pi * azimuthMod;
	elevationInfluence = (energy - 0.5) * pi * elevationMod;
	distanceInfluence = (energy * distanceMod1 + brightness * distanceMod2) * (maxDistance - minDistance);
	rotationInfluence = (brightness - 0.5) * 2pi * rotationMod;

	// Applying modulation with balance control
	azimuth = (azimuthBase + (azimuthInfluence * modBalance)).wrap(0, 2pi);
	elevation = (elevationBase + (elevationInfluence * modBalance)).clip(-0.5pi, 0.5pi);
	distance = (distanceBase + (distanceInfluence * modBalance)).clip(minDistance, maxDistance);
	rotation = (rotationBase + (rotationInfluence * modBalance)).wrap(0, 2pi);

	// Optional monitoring - can be uncommented if needed
	/*
	Poll.kr(Impulse.kr(0.5), azimuth / 2pi, "Azimuth (normalized)");
	Poll.kr(Impulse.kr(0.5), elevation / pi + 0.5, "Elevation (normalized)");
	Poll.kr(Impulse.kr(0.5), distance, "Distance");
	*/

	// HOA encoding and decoding
	hoaSignal = HoaEncodeDirection.ar(source, azimuth, elevation, distance, ~order);
	rotatedSignal = HoaRotate.ar(hoaSignal, rotation, ~order);

	Mix.ar(rotatedSignal * ~decoderMatrix.flop);
});
);

// Parameter control examples
(
// Set the modulation balance
Ndef(\hoaSpatial).set(\modBalance, 0.7);  // 0 = only base values, 1 = full modulation

// Adjusting base positions
Ndef(\hoaSpatial).set(
	\baseAzimuth, 0.25,    // Position at 1/4 around the circle
	\baseDistance, 1.5     // Middle distance
);

// Modifying modulation amounts
Ndef(\hoaSpatial).set(
	\azimuthMod, 0.8,      // Stronger noisiness influence on azimuth
	\rotationMod, -0.7     // Stronger negative brightness influence on rotation
);
);

// Analysis monitor that shows both raw and processed values
(
Ndef(\analysisMonitor, {
	var analysis = Ndef(\audioAnalyzer).kr;
	var input = Ndef(\grainSource).ar;
	var fft = FFT(LocalBuf(2048), input);

	var rawCentroid = SpecCentroid.kr(fft);
	var rawPower = FFTPower.kr(fft);
	var powerDB = 10 * log10(rawPower + 1e-10); // Convert to dB for monitoring

	// Monitor raw and processed values
	Poll.kr(Impulse.kr(1), rawCentroid, "Raw Centroid (Hz)");
	Poll.kr(Impulse.kr(1), rawPower, "Raw Power (linear)");
	Poll.kr(Impulse.kr(1), powerDB, "Power (dB)");

	// Monitor normalized values
	Poll.kr(Impulse.kr(1), analysis[0], "Brightness (normalized)");
	Poll.kr(Impulse.kr(1), analysis[1], "Noisiness (normalized)");
	Poll.kr(Impulse.kr(1), analysis[2], "Energy (normalized)");

	Silent.ar;
}).play;
);