class_name NoteBlockTones
extends RefCounted

# Original deterministic additive/percussive synthesis. No audio samples copied.
const RATE = 22050
const INSTRUMENTS = ["piano","bass_guitar","bass_drum","snare","hit","bell","flute","chime","guitar","xylophone_wood","xylophone_metal","cowbell","didgeridoo","squarewave","banjo","piano_digital"]
const FREQUENCIES = {"piano":523.2511306,"bass_guitar":110.0,"bass_drum":65.0,"snare":180.0,"hit":800.0,"bell":587.33,"flute":440.0,"chime":1896.0,"guitar":209.3,"xylophone_wood":1275.0,"xylophone_metal":940.0,"cowbell":738.0,"didgeridoo":75.6,"squarewave":200.0,"banjo":350.0,"piano_digital":505.0}
const DURATIONS = {"piano":1.65,"bass_guitar":0.95,"bass_drum":0.4,"snare":0.22,"hit":0.13,"bell":1.1,"flute":0.35,"chime":1.45,"guitar":0.9,"xylophone_wood":0.32,"xylophone_metal":0.95,"cowbell":0.42,"didgeridoo":0.95,"squarewave":0.22,"banjo":0.45,"piano_digital":1.05}
static var streams: Dictionary = {}

static func sample(instrument: String) -> AudioStreamWAV:
	if not INSTRUMENTS.has(instrument): instrument = "piano"
	if streams.has(instrument): return streams[instrument]
	var path: String = "res://assets/audio/noteblocks/"+instrument+".wav"
	if ResourceLoader.exists(path):
		var stored: AudioStreamWAV = load(path)
		if stored != null: streams[instrument] = stored; return stored
	return synthesize(instrument)

# Offline asset generator uses this directly; normal play loads the original
# rendered WAVs above, avoiding first-use synthesis pauses in a live circuit.
static func synthesize(instrument: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = RATE
	var duration: float = DURATIONS[instrument]; var frequency: float = FREQUENCIES[instrument]
	var count: int = int(RATE*duration); var data := PackedByteArray(); data.resize(count*2)
	var rng := RandomNumberGenerator.new(); rng.seed = 6700+INSTRUMENTS.find(instrument)
	var filtered: float = 0
	for index in count:
		var time: float = float(index)/RATE; var progress: float = time/duration
		var phase: float = TAU*frequency*time
		var noise: float = rng.randf_range(-1,1); filtered = filtered*0.7+noise*0.3
		var value: float = 0; var envelope: float = minf(time*250,1)*pow(1-progress,2)
		match instrument:
			"piano":
				value = sin(phase)*0.7+sin(phase*2.001)*0.22*exp(-time*4)+sin(phase*3.003)*0.08*exp(-time*8)
				envelope = minf(time*350,1)*exp(-time*2.6)*minf((duration-time)*25,1)
			"bass_guitar": value = sin(phase)*0.65+sin(phase*2)*0.23+sin(phase*3)*0.09+noise*0.035*exp(-time*80)
			"bass_drum":
				value = sin(TAU*(frequency*time+40.0/25.0*(1-exp(-25*time))))*0.92+noise*0.08*exp(-time*40)
				envelope = minf(time*1000,1)*exp(-time*12)*minf((duration-time)*40,1)
			"snare": value = (noise-filtered)*0.62+sin(phase)*0.25+sin(phase*1.47)*0.13; envelope = minf(time*1000,1)*pow(1-progress,3)
			"hit": value = (noise-filtered)*0.65+sin(phase)*0.22+sin(phase*2.73)*0.13; envelope = exp(-time*40)*minf((duration-time)*50,1)
			"bell": value = sin(phase)*0.6+sin(phase*2.76)*0.23*exp(-time*3)+sin(phase*5.4)*0.13*exp(-time*6); envelope = minf(time*500,1)*exp(-time*3)*minf((duration-time)*20,1)
			"flute": value = sin(phase+sin(TAU*5*time)*0.035)*0.83+sin(phase*3)*0.1+filtered*0.07; envelope = minf(time*45,1)*minf((duration-time)*18,1)*0.8
			"chime": value = sin(phase)*0.58+sin(phase*1.007)*0.18+sin(phase*2.4)*0.13+sin(phase*3.97)*0.08; envelope = minf(time*500,1)*exp(-time*2)*minf((duration-time)*15,1)
			"guitar": value = sin(phase)*0.5+sin(phase*2)*0.23+sin(phase*3)*0.13+sin(phase*4)*0.07+noise*0.025*exp(-time*60)
			"xylophone_wood": value = sin(phase)*0.73+sin(phase*3.96)*0.24*exp(-time*28); envelope = minf(time*900,1)*exp(-time*13)*minf((duration-time)*40,1)
			"xylophone_metal": value = sin(phase)*0.7+sin(phase*2.75)*0.19*exp(-time*6)+sin(phase*5.4)*0.08*exp(-time*10); envelope = minf(time*700,1)*exp(-time*4)*minf((duration-time)*30,1)
			"cowbell": value = sin(phase)*0.5+sin(phase*1.48)*0.31+sin(phase*2)*0.11+sin(phase*2.96)*0.06; envelope = minf(time*1000,1)*exp(-time*10)*minf((duration-time)*30,1)
			"didgeridoo": value = sin(phase)*0.45+sin(phase*2)*0.28+sin(phase*3)*0.12+sin(phase*5+sin(TAU*3*time))*0.1; envelope = minf(time*22,1)*minf((duration-time)*8,1)*(0.8+sin(TAU*6*time)*0.1)
			"squarewave": value = (sin(phase)+sin(phase*3)/3+sin(phase*5)/5+sin(phase*7)/7)*0.75; envelope = minf(time*500,1)*minf((duration-time)*35,1)*0.75
			"banjo": value = sin(phase)*0.48+sin(phase*1.5)*0.18+sin(phase*2)*0.18+sin(phase*3)*0.09+noise*0.05*exp(-time*100); envelope = minf(time*1000,1)*pow(1-progress,3)
			"piano_digital": value = sin(phase+sin(phase*5)*exp(-time*7)*0.9)*0.74+sin(phase*2)*0.2; envelope = minf(time*500,1)*exp(-time*3)*minf((duration-time)*25,1)
		data.encode_s16(index*2,int(clampf(value*envelope,-1,1)*26000))
	stream.data = data; streams[instrument] = stream
	return stream
