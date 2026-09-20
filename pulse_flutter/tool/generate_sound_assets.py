#!/usr/bin/env python3
"""
NiosMess Material 3 Expressive Sound Synthesizer
Generates 100% pure mathematical DSP audio assets (Vorbis OGG) for all 28 semantic sound events.
Eliminates ElevenLabs AI noise, hiss, artifacts, and provides crystal-clear acoustic design.
"""

import os
import sys
import math
import struct
import hashlib
import json
import subprocess
from datetime import datetime, timezone

SAMPLE_RATE = 44100

def create_raw_buffer(num_samples):
    return [0.0] * num_samples

def apply_envelope(samples, attack_sec, decay_sec, hold_sec=0.0):
    total = len(samples)
    attack_samples = int(attack_sec * SAMPLE_RATE)
    hold_samples = int(hold_sec * SAMPLE_RATE)
    
    out = []
    for i, s in enumerate(samples):
        t = i / SAMPLE_RATE
        if i < attack_samples and attack_samples > 0:
            env = 0.5 * (1.0 - math.cos(math.pi * i / attack_samples))
        elif i < attack_samples + hold_samples:
            env = 1.0
        else:
            decay_t = (i - attack_samples - hold_samples) / SAMPLE_RATE
            if decay_sec > 0:
                env = math.exp(-decay_t / decay_sec)
            else:
                env = 1.0
        out.append(s * env)
    return out

def synth_sine_glide(f_start, f_end, duration_sec, attack_sec=0.001, decay_sec=0.01, harmonics=None):
    num_samples = int(duration_sec * SAMPLE_RATE)
    samples = []
    phase = 0.0
    harmonics = harmonics or [(1.0, 1.0)] # (harmonic_mult, amplitude)
    
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        frac = t / duration_sec
        # linear frequency glide
        inst_freq = f_start + (f_end - f_start) * frac
        phase += 2.0 * math.pi * inst_freq / SAMPLE_RATE
        
        val = 0.0
        for h_mult, h_amp in harmonics:
            val += h_amp * math.sin(phase * h_mult)
        samples.append(val)
        
    return apply_envelope(samples, attack_sec, decay_sec)

def synth_bell(freq, duration_sec, attack_sec=0.002, decay_sec=0.05, fm_index=0.2, fm_mult=2.0):
    num_samples = int(duration_sec * SAMPLE_RATE)
    samples = []
    carrier_phase = 0.0
    mod_phase = 0.0
    
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        mod_freq = freq * fm_mult
        carrier_phase += 2.0 * math.pi * freq / SAMPLE_RATE
        mod_phase += 2.0 * math.pi * mod_freq / SAMPLE_RATE
        
        mod_env = math.exp(-t / (decay_sec * 0.5))
        mod_val = fm_index * mod_env * math.sin(mod_phase)
        
        val = math.sin(carrier_phase + mod_val)
        samples.append(val)
        
    return apply_envelope(samples, attack_sec, decay_sec)

def mix_tracks(track_list):
    """
    track_list is a list of (start_sec, samples_list, volume)
    """
    max_len = 0
    for start_sec, samples, vol in track_list:
        end_idx = int(start_sec * SAMPLE_RATE) + len(samples)
        if end_idx > max_len:
            max_len = end_idx
            
    buffer = [0.0] * max_len
    for start_sec, samples, vol in track_list:
        start_idx = int(start_sec * SAMPLE_RATE)
        for i, s in enumerate(samples):
            buffer[start_idx + i] += s * vol
            
    return buffer

def normalize_and_pack(samples, peak_db=-1.5):
    max_val = max(abs(s) for s in samples) if samples else 0.0
    if max_val < 1e-6:
        max_val = 1.0
        
    target_peak = 10.0 ** (peak_db / 20.0)
    scale = target_peak / max_val
    
    int_samples = []
    for s in samples:
        val = s * scale
        # soft clip
        if val > 1.0:
            val = 1.0
        elif val < -1.0:
            val = -1.0
        int_samples.append(int(val * 32767))
        
    return struct.pack(f'<{len(int_samples)}h', *int_samples)

def encode_to_ogg(raw_data, output_ogg_path):
    cmd = [
        'ffmpeg', '-y',
        '-f', 's16le',
        '-ar', str(SAMPLE_RATE),
        '-ac', '1',
        '-i', 'pipe:0',
        '-c:a', 'libvorbis',
        '-q:a', '6',
        output_ogg_path
    ]
    res = subprocess.run(cmd, input=raw_data, capture_output=True)
    if res.returncode != 0:
        raise RuntimeError(f"FFmpeg error: {res.stderr.decode('utf-8', errors='ignore')}")

# ==============================================================================
# Sound Generators
# ==============================================================================

def gen_ui_tap():
    # Ceramic micro-tap: fast glide from 1500 Hz to 520 Hz, tau=0.007s
    return synth_sine_glide(1500, 520, 0.035, attack_sec=0.0005, decay_sec=0.007,
                            harmonics=[(1.0, 0.85), (2.0, 0.15)])

def gen_ui_select():
    # Selection tick: rising 850 Hz -> 1400 Hz, tau=0.009s
    return synth_sine_glide(850, 1400, 0.040, attack_sec=0.001, decay_sec=0.009,
                            harmonics=[(1.0, 0.8), (2.0, 0.2)])

def gen_ui_toggle_on():
    # Upward 4th: D5 (587 Hz) -> G5 (784 Hz)
    n1 = synth_bell(587, 0.050, attack_sec=0.001, decay_sec=0.015, fm_index=0.1)
    n2 = synth_bell(784, 0.080, attack_sec=0.001, decay_sec=0.022, fm_index=0.1)
    return mix_tracks([(0.0, n1, 0.7), (0.022, n2, 0.9)])

def gen_ui_toggle_off():
    # Downward 4th: G5 (784 Hz) -> D5 (587 Hz)
    n1 = synth_bell(784, 0.045, attack_sec=0.001, decay_sec=0.012, fm_index=0.1)
    n2 = synth_bell(587, 0.070, attack_sec=0.001, decay_sec=0.020, fm_index=0.1)
    return mix_tracks([(0.0, n1, 0.8), (0.020, n2, 0.7)])

def gen_ui_confirm():
    # Affirmative major interval: E5 (659 Hz) -> B5 (987 Hz)
    n1 = synth_bell(659, 0.080, attack_sec=0.002, decay_sec=0.025, fm_index=0.15)
    n2 = synth_bell(987, 0.130, attack_sec=0.002, decay_sec=0.045, fm_index=0.15)
    return mix_tracks([(0.0, n1, 0.75), (0.035, n2, 0.95)])

def gen_ui_cancel():
    # Polite cancel: C#5 (554 Hz) -> A4 (440 Hz)
    n1 = synth_bell(554, 0.060, attack_sec=0.002, decay_sec=0.018, fm_index=0.1)
    n2 = synth_bell(440, 0.090, attack_sec=0.002, decay_sec=0.028, fm_index=0.1)
    return mix_tracks([(0.0, n1, 0.75), (0.028, n2, 0.7)])

def gen_ui_success():
    # Major triad cascade: F5 (698 Hz) -> A5 (880 Hz) -> C6 (1046 Hz)
    n1 = synth_bell(698, 0.12, attack_sec=0.002, decay_sec=0.04, fm_index=0.15)
    n2 = synth_bell(880, 0.15, attack_sec=0.002, decay_sec=0.05, fm_index=0.15)
    n3 = synth_bell(1046, 0.22, attack_sec=0.002, decay_sec=0.07, fm_index=0.18)
    return mix_tracks([(0.0, n1, 0.7), (0.030, n2, 0.8), (0.065, n3, 1.0)])

def gen_ui_error():
    # Polite low double-thud: 290 Hz -> 220 Hz
    n1 = synth_sine_glide(300, 260, 0.045, attack_sec=0.002, decay_sec=0.015)
    n2 = synth_sine_glide(240, 200, 0.070, attack_sec=0.002, decay_sec=0.022)
    return mix_tracks([(0.0, n1, 0.75), (0.035, n2, 0.8)])

def gen_message_send():
    # Iconic whoosh-chirp: sweep 420 Hz -> 1250 Hz + high droplet 1480 Hz
    swoosh = synth_sine_glide(420, 1250, 0.085, attack_sec=0.005, decay_sec=0.025,
                              harmonics=[(1.0, 0.75), (2.0, 0.25)])
    droplet = synth_bell(1480, 0.090, attack_sec=0.001, decay_sec=0.030, fm_index=0.1)
    return mix_tracks([(0.0, swoosh, 0.8), (0.060, droplet, 0.75)])

def gen_message_receive():
    # NiosMess signature dual marimba droplet: G5 (784 Hz) -> D6 (1175 Hz)
    n1 = synth_bell(784, 0.060, attack_sec=0.001, decay_sec=0.020, fm_index=0.25)
    n2 = synth_bell(1175, 0.160, attack_sec=0.001, decay_sec=0.055, fm_index=0.25)
    return mix_tracks([(0.0, n1, 0.75), (0.035, n2, 0.95)])

def gen_message_mention():
    # Priority dual chime: A5 (880 Hz) + E6 (1320 Hz) -> A6 (1760 Hz)
    n1 = synth_bell(880, 0.160, attack_sec=0.002, decay_sec=0.05, fm_index=0.15)
    n2 = synth_bell(1320, 0.180, attack_sec=0.002, decay_sec=0.06, fm_index=0.15)
    n3 = synth_bell(1760, 0.200, attack_sec=0.002, decay_sec=0.065, fm_index=0.12)
    return mix_tracks([(0.0, n1, 0.75), (0.0, n2, 0.85), (0.040, n3, 0.9)])

def gen_reaction():
    # Bouncy cute micro-pop: 380 Hz -> 1050 Hz parabolic
    return synth_sine_glide(380, 1050, 0.050, attack_sec=0.0005, decay_sec=0.012,
                            harmonics=[(1.0, 0.85), (2.0, 0.15)])

def gen_sticker_send():
    # Soft rubbery pop/whoosh: 320 Hz -> 780 Hz
    swoosh = synth_sine_glide(320, 780, 0.065, attack_sec=0.003, decay_sec=0.018)
    pop = synth_bell(820, 0.050, attack_sec=0.001, decay_sec=0.014, fm_index=0.2)
    return mix_tracks([(0.0, swoosh, 0.75), (0.025, pop, 0.8)])

def gen_upload_complete():
    # Bright dual completion chime: G5 (784 Hz) -> C6 (1046 Hz)
    n1 = synth_bell(784, 0.090, attack_sec=0.002, decay_sec=0.030, fm_index=0.15)
    n2 = synth_bell(1046, 0.170, attack_sec=0.002, decay_sec=0.055, fm_index=0.2)
    return mix_tracks([(0.0, n1, 0.75), (0.035, n2, 0.95)])

def gen_upload_error():
    # Muted descending double tone: 420 Hz -> 310 Hz
    n1 = synth_bell(420, 0.055, attack_sec=0.002, decay_sec=0.018)
    n2 = synth_bell(310, 0.080, attack_sec=0.002, decay_sec=0.025)
    return mix_tracks([(0.0, n1, 0.75), (0.030, n2, 0.7)])

def gen_record_start():
    # Tactile mic open cue: rising chirp 460 Hz -> 750 Hz
    return synth_sine_glide(460, 750, 0.045, attack_sec=0.001, decay_sec=0.012)

def gen_record_lock():
    # Digital latch click: 1200 Hz + 1600 Hz micro-clicks
    c1 = synth_sine_glide(1200, 700, 0.020, attack_sec=0.0005, decay_sec=0.005)
    c2 = synth_sine_glide(1600, 900, 0.025, attack_sec=0.0005, decay_sec=0.006)
    return mix_tracks([(0.0, c1, 0.75), (0.015, c2, 0.85)])

def gen_record_cancel():
    # Soft swoop down: 700 Hz -> 350 Hz
    return synth_sine_glide(700, 350, 0.055, attack_sec=0.002, decay_sec=0.015)

def gen_record_send():
    # Confident rising whoosh: 520 Hz -> 1150 Hz
    return synth_sine_glide(520, 1150, 0.075, attack_sec=0.003, decay_sec=0.022)

def gen_ai_start():
    # Crystalline glass pulse: A5 (880 Hz) + E6 (1320 Hz)
    n1 = synth_bell(880, 0.130, attack_sec=0.004, decay_sec=0.040, fm_index=0.15)
    n2 = synth_bell(1320, 0.140, attack_sec=0.004, decay_sec=0.045, fm_index=0.15)
    return mix_tracks([(0.0, n1, 0.8), (0.015, n2, 0.85)])

def gen_ai_complete():
    # Intelligent ascending triad: E5 (659 Hz) -> G#5 (830 Hz) -> B5 (987 Hz) -> E6 (1318 Hz)
    n1 = synth_bell(659, 0.100, attack_sec=0.002, decay_sec=0.035, fm_index=0.12)
    n2 = synth_bell(830, 0.120, attack_sec=0.002, decay_sec=0.040, fm_index=0.12)
    n3 = synth_bell(987, 0.150, attack_sec=0.002, decay_sec=0.050, fm_index=0.15)
    n4 = synth_bell(1318, 0.240, attack_sec=0.002, decay_sec=0.080, fm_index=0.18)
    return mix_tracks([(0.0, n1, 0.65), (0.025, n2, 0.7), (0.055, n3, 0.8), (0.090, n4, 0.95)])

def gen_ai_error():
    # Soft descending minor tone: 622 Hz -> 554 Hz
    n1 = synth_bell(622, 0.065, attack_sec=0.002, decay_sec=0.020)
    n2 = synth_bell(554, 0.095, attack_sec=0.002, decay_sec=0.030)
    return mix_tracks([(0.0, n1, 0.75), (0.030, n2, 0.7)])

def gen_security_connecting():
    # Gentle radar ping: 950 Hz pure bell
    return synth_bell(950, 0.140, attack_sec=0.002, decay_sec=0.045, fm_index=0.1)

def gen_security_verified():
    # Pure octave resolution: C5 (523 Hz) -> C6 (1046 Hz)
    n1 = synth_bell(523, 0.110, attack_sec=0.002, decay_sec=0.035, fm_index=0.15)
    n2 = synth_bell(1046, 0.180, attack_sec=0.002, decay_sec=0.060, fm_index=0.2)
    return mix_tracks([(0.0, n1, 0.75), (0.030, n2, 0.95)])

def gen_security_warning():
    # Discreet double alert pulse: 550 Hz
    p1 = synth_bell(550, 0.060, attack_sec=0.002, decay_sec=0.018, fm_index=0.2)
    p2 = synth_bell(550, 0.075, attack_sec=0.002, decay_sec=0.022, fm_index=0.2)
    return mix_tracks([(0.0, p1, 0.8), (0.040, p2, 0.85)])

def gen_call_incoming():
    # Soothing marimba ringtone loop (2.4 seconds total, gentle pentatonic melody)
    # C5 (523), G5 (784), A5 (880), E5 (659), G5 (784), C6 (1046), A5 (880), G5 (784)
    notes = [
        (0.00, 523, 0.20),
        (0.24, 784, 0.20),
        (0.48, 880, 0.20),
        (0.72, 659, 0.20),
        (0.96, 784, 0.20),
        (1.20, 1046, 0.25),
        (1.44, 880, 0.20),
        (1.68, 784, 0.30),
    ]
    track = []
    for start_t, f, dur in notes:
        b = synth_bell(f, dur, attack_sec=0.003, decay_sec=0.06, fm_index=0.25, fm_mult=1.414)
        track.append((start_t, b, 0.85))
    mixed = mix_tracks(track)
    # Pad to 2.4s to create rhythmic breathing gap before repeat
    target_samples = int(2.4 * SAMPLE_RATE)
    if len(mixed) < target_samples:
        mixed.extend([0.0] * (target_samples - len(mixed)))
    return mixed

def gen_call_connected():
    # Warm welcome chord: C5 (523) -> E5 (659) -> G5 (784) -> C6 (1046)
    c5 = synth_bell(523, 0.120, attack_sec=0.002, decay_sec=0.04)
    e5 = synth_bell(659, 0.140, attack_sec=0.002, decay_sec=0.045)
    g5 = synth_bell(784, 0.170, attack_sec=0.002, decay_sec=0.055)
    c6 = synth_bell(1046, 0.240, attack_sec=0.002, decay_sec=0.075)
    return mix_tracks([(0.0, c5, 0.7), (0.030, e5, 0.75), (0.065, g5, 0.85), (0.100, c6, 0.95)])

def gen_call_ended():
    # Gentle farewell chord: C6 (1046) -> G5 (784) -> E5 (659) -> C5 (523)
    c6 = synth_bell(1046, 0.120, attack_sec=0.002, decay_sec=0.035)
    g5 = synth_bell(784, 0.140, attack_sec=0.002, decay_sec=0.040)
    e5 = synth_bell(659, 0.170, attack_sec=0.002, decay_sec=0.050)
    c5 = synth_bell(523, 0.240, attack_sec=0.002, decay_sec=0.070)
    return mix_tracks([(0.0, c6, 0.85), (0.030, g5, 0.8), (0.065, e5, 0.75), (0.100, c5, 0.7)])


SOUND_GENERATORS = {
    'ui_tap': (gen_ui_tap, -4.0, "Ceramic glass micro-tap with rapid exponential decay"),
    'ui_select': (gen_ui_select, -4.0, "Crisp upward selection tick"),
    'ui_toggle_on': (gen_ui_toggle_on, -3.0, "Ascending warm fourth arpeggio for switch activation"),
    'ui_toggle_off': (gen_ui_toggle_off, -3.5, "Descending warm fourth arpeggio for switch deactivation"),
    'ui_confirm': (gen_ui_confirm, -2.5, "Affirmative dual chime (E5 -> B5)"),
    'ui_cancel': (gen_ui_cancel, -3.5, "Polite soft descending dismiss cue"),
    'ui_success': (gen_ui_success, -2.0, "Uplifting major triad cascade (F5 -> A5 -> C6)"),
    'ui_error': (gen_ui_error, -3.0, "Discreet, polite low double-thud"),
    'message_send': (gen_message_send, -2.0, "Iconic messenger rising whoosh-chirp"),
    'message_receive': (gen_message_receive, -1.5, "Signature NiosMess marimba droplet (G5 -> D6)"),
    'message_mention': (gen_message_mention, -1.0, "Radiant dual chime for direct mentions"),
    'reaction': (gen_reaction, -3.0, "Bouncy tactile micro-pop"),
    'sticker_send': (gen_sticker_send, -2.5, "Soft rubbery pop-whoosh"),
    'upload_complete': (gen_upload_complete, -2.0, "Bright completion chime (G5 -> C6)"),
    'upload_error': (gen_upload_error, -3.0, "Muted descending double tone"),
    'record_start': (gen_record_start, -3.0, "Tactile rising chirp indicating mic active"),
    'record_lock': (gen_record_lock, -3.0, "Mechanical-digital latch click"),
    'record_cancel': (gen_record_cancel, -3.5, "Descending soft swoop"),
    'record_send': (gen_record_send, -2.5, "Confident release whoosh"),
    'ai_start': (gen_ai_start, -2.5, "Crystalline futuristic glass pulse"),
    'ai_complete': (gen_ai_complete, -1.5, "Intelligent ascending arpeggiated triad"),
    'ai_error': (gen_ai_error, -3.0, "Soft descending minor tone"),
    'security_connecting': (gen_security_connecting, -3.0, "Gentle sonar ping for E2EE handshake"),
    'security_verified': (gen_security_verified, -2.0, "Octave resolution chime (C5 -> C6)"),
    'security_warning': (gen_security_warning, -2.0, "Discreet double alert pulse"),
    'call_incoming': (gen_call_incoming, -1.5, "Calming marimba pentatonic loop"),
    'call_connected': (gen_call_connected, -2.0, "Warm ascending welcome chord"),
    'call_ended': (gen_call_ended, -2.5, "Gentle descending farewell chord"),
}

def main():
    sounds_dir = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
    sounds_dir = os.path.abspath(sounds_dir)
    os.makedirs(sounds_dir, exist_ok=True)
    
    print(f"Synthesizing {len(SOUND_GENERATORS)} sound assets into {sounds_dir}...")
    
    manifest_assets = {}
    
    for name, (gen_fn, peak_db, description) in SOUND_GENERATORS.items():
        samples = gen_fn()
        raw_data = normalize_and_pack(samples, peak_db=peak_db)
        
        ogg_filename = f"{name}.ogg"
        ogg_path = os.path.join(sounds_dir, ogg_filename)
        
        encode_to_ogg(raw_data, ogg_path)
        
        # Calculate SHA-256 and metadata
        with open(ogg_path, 'rb') as f:
            file_bytes = f.read()
            sha = hashlib.sha256(file_bytes).hexdigest()
            
        dur_ms = round(len(samples) / SAMPLE_RATE * 1000.0, 1)
        
        manifest_assets[name] = {
            "name": ogg_filename,
            "description": description,
            "duration_ms": dur_ms,
            "format": "ogg/vorbis",
            "sample_rate": SAMPLE_RATE,
            "target_peak_db": f"{peak_db} dB",
            "loop": (name == "call_incoming"),
            "generator": "NiosMess Material 3 Expressive Mathematical DSP Synthesizer",
            "sha256": sha
        }
        print(f"  [OK] {ogg_filename} ({dur_ms} ms, {len(file_bytes)} bytes, SHA: {sha[:8]}...)")
        
    # Copy legacy files for backward compatibility
    import shutil
    shutil.copyfile(os.path.join(sounds_dir, 'message_receive.ogg'), os.path.join(sounds_dir, 'message.ogg'))
    shutil.copyfile(os.path.join(sounds_dir, 'ui_tap.ogg'), os.path.join(sounds_dir, 'nav1.ogg'))
    print("  [OK] Legacy message.ogg and nav1.ogg updated.")
    
    # Write manifest.json
    manifest = {
        "sound_pack_name": "NiosMess Material 3 Expressive Pure DSP Sound System",
        "version": "2.0.0",
        "acoustic_identity": {
            "style": "Material 3 Expressive, pristine mathematical synthesis",
            "transients": "warm ceramic and physical glass transients",
            "synthesis": "pure sine, FM bells, and organic arpeggios (zero noise floor, zero AI artifacts)",
            "signature": "two-note ascending pulse (NiosMess zig-zag motif)"
        },
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_assets": len(manifest_assets),
        "assets": manifest_assets
    }
    
    manifest_path = os.path.join(sounds_dir, 'manifest.json')
    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(f"  [OK] manifest.json saved ({len(manifest_assets)} assets).")
    
    # Remove obsolete master directory with old ElevenLabs files if present
    master_dir = os.path.join(sounds_dir, 'master')
    if os.path.exists(master_dir):
        shutil.rmtree(master_dir)
        print(f"  [OK] Removed obsolete ElevenLabs master/ directory (saved ~1.4 MB).")

if __name__ == '__main__':
    main()
