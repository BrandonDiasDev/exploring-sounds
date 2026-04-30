# QUICK START GUIDE

## Files Created

| File | Purpose |
|------|---------|
| `scripts/GridManager.gd` | Main orchestrator for 4x3 grid, cell recycling, instrument tracking |
| `scripts/GridCell.gd` | Individual cell: content management, input forwarding |
| `scripts/Instrument.gd` | Base class: touch input, drag, haptic, audio signals |
| `scripts/AudioManager.gd` | Autoload: audio playback, spatial audio |
| `scripts/CameraController.gd` | Smart camera: scroll when NOT dragging, freeze when dragging |
| `SCENE_SETUP.md` | Step-by-step scene construction guide |
| `TEST_GUIDE.md` | Comprehensive testing procedures (all edge cases) |

---

## One-Minute Setup

1. **Create scenes** (using SCENE_SETUP.md):
   - `GridCell.tscn` (reusable template)
   - `Instrument.tscn` (reusable template)
   - `WorldExample.tscn` (main scene)

2. **Attach scripts** to nodes as specified in SCENE_SETUP.md

3. **Set AudioManager as Autoload**:
   - Project → Project Settings → Autoload
   - Add `res://scenes/AudioManager.tscn` as "AudioManager"

4. **Press Play (F5)** and test

---

## Key Architecture

### Coordinate Systems
```
LOGICAL (integer, infinite):  World coordinates like (-5, 3)
PHYSICAL (fixed 4x3 pool):    12 GridCell nodes, recycled
VISUAL (pixels):              cell.global_position = logical * cell_size
```

### Grid Recycling Logic
```
Camera moves → Detect logical cell change
		↓
If camera moved by ±1 cell → Recycle one row/column
		↓
Move physical cell to new logical position
		↓
Update all instruments in that cell (preserve global_position)
		↓
Update world_offset
		↓
Next frame: repeat
```

### Instrument Lifecycle
```
Create Instrument node in InstrumentsContainer
		↓
Call GridManager.add_instrument(id, logical_x, logical_y)
		↓
Instrument reparented to correct GridCell
		↓
User interaction:
  - Tap (<0.4s): short_press_requested → AudioManager plays short sound
  - Hold (>0.4s): long_press_requested → AudioManager plays looped sound
  - Drag: instrument moves between cells, GridManager updates tracking
		↓
On cell recycle: Instrument reparented smoothly (global_position preserved)
```

---

## Testing Quick Checklist

**Before deployment, verify:**

- [ ] Arrow keys scroll camera smoothly
- [ ] Cells recycle without gaps (scroll 10+ cells in one direction)
- [ ] Instruments don't duplicate or disappear
- [ ] Tap on instrument plays short sound
- [ ] Hold on instrument plays sustained sound (release stops it)
- [ ] Drag instrument moves it to adjacent cells smoothly
- [ ] Camera freezes while dragging, resumes after
- [ ] Memory stable (no growth over 60 seconds)
- [ ] FPS stable at ≥58 FPS
- [ ] HTML5 export works in browser
- [ ] Android/mobile export responds to touch

---

## Key Configuration Values

```gdscript
# In GridManager inspector:
cell_size = Vector2(512, 512)  # or (1024, 1024)
debug_mode = true              # Set to false for release

# In Instrument properties:
long_press_threshold = 0.4     # seconds
haptic_duration_short = 50     # milliseconds
haptic_duration_long = 100     # milliseconds
allow_dragging = true          # enable/disable drag

# In CameraController:
pan_speed = 300                # pixels/second
smoothing = 0.1                # 0-1 (higher = smoother)
debug_mode = false             # press F1 to toggle

# In AudioManager:
fade_out_duration = 0.2        # seconds
```

---

## Common Issues & Fixes

### Cells aren't visible
→ Check `ColorRect.custom_minimum_size` matches `cell_size`

### Instruments don't respond to input
→ Verify `Area2D` has `CollisionShape2D` child; check `input_event` signal

### Camera won't scroll
→ Ensure `ui_up/down/left/right` actions exist in Input Map

### Audio doesn't play
→ Create `res://assets/audio/instruments/` folder; add `.ogg` files

### Grid shows gaps during fast movement
→ Check `int(floor(...))` is used for all logical calculations; verify reparenting preserves `global_position`

---

## Performance Targets

| Metric | Target | How to Check |
|--------|--------|---|
| Frame Rate | ≥60 FPS | Debug → Monitor → FPS |
| Memory | Constant | Debug → Monitor → Memory over 60s |
| Cell Count | Always 12 | Scene tree: GridManager → CellsContainer |
| Scroll Latency | <1 frame | Smooth visual feedback on input |

---

## Next Steps After Setup

1. **Add audio files** to `res://assets/audio/instruments/`:
   - `flute.ogg`, `drum.ogg`, `bell.ogg` (or your instruments)

2. **Customize sprites**:
   - Replace placeholder sprites in `Instrument.tscn` and `GridCell.tscn`
   - Update colors, sizes, animations

3. **Expand features**:
   - Add more instruments
   - Add procedural decorations beyond simple flora
   - Integrate with game logic (inventory, effects, etc.)

4. **Optimize for mobile**:
   - Test on actual device
   - Adjust `cell_size` if needed (larger cells = better performance)
   - Reduce flora density if FPS drops

5. **Export & distribute**:
   - HTML5: `File → Export Project → HTML5`
   - Android: Install SDK/NDK, then `File → Export Project → Android`
   - iOS: Requires Mac; follow Godot iOS export docs

---

## Helpful Console Commands

```gdscript
# Print active instruments
print(AudioManager.get_active_instruments())

# Force recycle (simulate camera movement)
GridManager._update_grid_position()

# Get cell at logical position
var cell = GridManager.get_cell_at_logical(5, 3)

# Get instruments in a cell
var instruments = GridManager._get_instruments_in_cell(cell)
```

---

## Glossary

| Term | Definition |
|------|---|
| **Logical Coordinates** | Integer grid position (e.g., 0,0); infinite, unbounded |
| **Physical Pool** | Fixed 4x3 array of GridCell nodes |
| **World Offset** | Current logical position of top-left physical cell |
| **Recycling** | Moving a physical cell to represent a new logical position |
| **Reparenting** | Moving an Instrument from one GridCell parent to another |
| **Drift** | Numeric error from floating-point accumulation (prevented by always using `int(floor(...))`) |

---

## Support & Debugging

**If something breaks:**

1. Enable debug mode in all managers:
   ```
   GridManager.debug_mode = true
   CameraController.debug_mode = true
   GridCell.debug_text = "show"
   ```

2. Check console logs for:
   - `[GridManager]` messages
   - `[Instrument]` messages
   - `[AudioManager]` messages
   - Errors or warnings

3. Use Godot Profiler (Debug → Monitor) to check FPS, memory, and draw calls

4. Inspect Scene tree to verify node counts and hierarchy

5. Run TEST_GUIDE.md tests to isolate the issue

---

## You're Ready!

✅ All GDScript files created with full comments  
✅ Scene structure documented  
✅ Recycling algorithm explained with edge cases  
✅ Test procedures provided  
✅ Performance optimized  

**Next: Follow SCENE_SETUP.md to build your WorldExample.tscn, then run TEST_GUIDE.md to validate.**

Good luck! 🎵🎮
