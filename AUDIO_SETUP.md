# Exploring Sounds - Audio Configuration

## Audio Setup Instructions

### Step 1: Create Audio Directory

```bash
mkdir -p res://assets/audio/instruments/
```

### Step 2: Add Audio Files

Copy or create `.ogg` files for each instrument:

```
res://assets/audio/instruments/
├── flute.ogg       (short, bright tone)
├── drum.ogg        (percussive, impact sound)
└── bell.ogg        (sustained, resonant tone)
```

### Step 3: Audio File Specifications

**Recommended specs for mobile:**
- Format: `.ogg` (Vorbis codec, good compression)
- Sample rate: 22050 Hz (mono) or 44100 Hz (stereo)
- Bit rate: 128 kbps
- Duration:
  - Short-press samples: 0.1–0.5 seconds (one-shot)
  - Long-press samples: 2–5 seconds (looped)

### Step 4: Test Audio Playback

1. Add audio files to `res://assets/audio/instruments/`
2. In Godot editor, press F5 to play
3. Tap instruments to verify audio plays
4. Hold to verify looping works
5. Release to verify fade-out

---

## AudioManager API

### Play Sound
```gdscript
AudioManager.play_instrument("flute", {"type": "short"})
AudioManager.play_instrument("drum", {"type": "long", "volume_db": -6})
```

### Stop Sound
```gdscript
AudioManager.stop_instrument("flute", fade_duration=0.2)
```

### Preload Audio
```gdscript
AudioManager.preload_audio([
    "res://assets/audio/instruments/flute.ogg",
    "res://assets/audio/instruments/drum.ogg",
    "res://assets/audio/instruments/bell.ogg"
])
```

---

## Audio Sources

### Free/Open-Source Audio Libraries

- **Freesound.org** - Creative Commons samples
- **OpenGameArt.org** - Royalty-free game audio
- **Zapsplat** - Free sound effects
- **Storyblocks Audio** - Subscription service

### Tools to Create/Edit Audio

- **Audacity** (free, open-source)
- **REAPER** (affordable, powerful)
- **Ableton Live** (professional)
- **GarageBand** (Mac, free)

### Tools to Convert to OGG

```bash
# Using ffmpeg (free)
ffmpeg -i input.wav -c:a libvorbis -q:a 5 output.ogg
```

---

## Spatial Audio Notes

The system includes basic spatial audio (panning) based on instrument position:
- **Left side:** Audio pans left
- **Center:** Audio is center
- **Right side:** Audio pans right

This enhances immersion on stereo headphones or speaker setups.

---

## Performance Tips

1. **Use OGG format** - Best compression for Godot
2. **Keep samples short** - Reduces memory footprint
3. **Preload on startup** - `AudioManager.preload_audio(...)` in GridManager._ready()
4. **Limit simultaneous playback** - 3+ instruments OK, test on your target device
5. **Use appropriate bit rates** - 128 kbps is good balance

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Audio doesn't play | Check file paths; verify `.ogg` format |
| Audio is too quiet | Increase `volume_db` in play_instrument() |
| Audio loops incorrectly | Ensure loop points set properly in audio editor |
| Memory usage high | Reduce sample quality or use compression |
| No spatial audio effect | Use headphones or stereo speakers |

---

## Example: Adding Audio from Audacity

1. **Record or import audio** in Audacity
2. **Edit length:**
   - Short sample: trim to 0.2–0.3 seconds
   - Long sample: keep 2–4 seconds, set loop point
3. **Export as OGG:**
   - File → Export → Export as OGG Vorbis
   - Quality: 5–6 (128 kbps)
4. **Save to:** `res://assets/audio/instruments/[instrument_id].ogg`
5. **Test in Godot** (press F5)

---

Done! Your audio system is ready to use. 🎵
