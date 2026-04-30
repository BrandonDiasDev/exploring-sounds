# Complete Test Guide: 4x3 Infinite-Grid System

## Overview
This document provides step-by-step testing procedures to validate the infinite-scrolling 4x3 grid, instrument interactions, audio, and performance.

**Total testing time:** ~30 minutes for full coverage

---

## Pre-Test Setup

### Prerequisites
- ✅ Godot 4.6+ running
- ✅ WorldExample.tscn fully set up (see SCENE_SETUP.md)
- ✅ Debug mode enabled in GridManager and CameraController
- ✅ Console open (View → Toggle Bottom Panel)

### Launch
```
Press F5 (or Play button) to start WorldExample
```

**Expected output in console:**
```
[GridManager] Ready. Cells: 12, world_seed: [number], cell_size: (512, 512)
[Instrument] Ready: id=flute, logical=(0,0)
[Instrument] Ready: id=drum, logical=(1,0)
[Instrument] Ready: id=bell, logical=(0,1)
[AudioManager] Ready. Cache size: 0
```

---

## Test Category 1: Grid Coverage & Recycling

### Test 1.1: Basic Cell Arrangement

**Objective:** Verify 12 cells are arranged in a 4×3 grid with no gaps

**Steps:**
1. Launch scene
2. Observe viewport: Should see 12 cells arranged as a 4×3 pool
3. Each cell should display debug text: `(x, y)` (logical coordinates)
4. Top-left cell: `(-1, -1)`; center cell: `(0, 0)`; bottom-right cell: `(1, 1)`

**Pass Criteria:**
- ✅ 12 cells visible
- ✅ No gaps between cells
- ✅ Debug text visible on each cell
- ✅ Logical coordinates correct

**Log to check:**
```
Cells should NOT be destroyed/created during this test
```

---

### Test 1.2: Camera Movement - Right

**Objective:** Verify grid recycles columns correctly when moving RIGHT

**Steps:**
1. Note current camera position: Should be at `(256, 256)` or `(512, 512)`
2. Press **RIGHT ARROW** and hold for 3 seconds
3. Observe cells reposition
4. Watch console for recycle logs
5. Release RIGHT ARROW

**Expected behavior:**
- Camera moves right smoothly
- When camera crosses cell boundary (~512 px), leftmost column disappears and reappears on right
- No visual gaps or jitter
- Console shows: `[GridManager] Recycled: dx=1, dy=0, offset=(...)`

**Pass Criteria:**
- ✅ Camera scrolls smoothly
- ✅ Cells recycle seamlessly
- ✅ Grid always has 4×3 coverage
- ✅ No temporary blanks

---

### Test 1.3: Camera Movement - Left, Up, Down

**Objective:** Verify recycling works in all four directions

**Steps:**
1. From centered position:
   - Press **LEFT ARROW** for 2 seconds
   - Observe column recycle
   - Release

2. From current position:
   - Press **UP ARROW** for 2 seconds
   - Observe row recycle
   - Release

3. From current position:
   - Press **DOWN ARROW** for 2 seconds
   - Observe row recycle
   - Release

**Expected behavior:**
- LEFT: Rightmost column wraps to left
- UP: Bottom row wraps to top
- DOWN: Top row wraps to bottom
- Grid always maintains 4×3 coverage

**Pass Criteria:**
- ✅ All four directions recycle correctly
- ✅ Logical coordinates update appropriately
- ✅ No gaps or overlaps

---

### Test 1.4: Fast Diagonal Movement

**Objective:** Verify robust recycling under fast movement (edge case)

**Steps:**
1. Press **RIGHT ARROW + UP ARROW** simultaneously
2. Hold for 3 seconds (fast diagonal movement)
3. Release

**Expected behavior:**
- Grid recycles both columns AND rows
- No gaps appear during or after movement
- Camera position tracked accurately

**Pass Criteria:**
- ✅ Diagonal movement works smoothly
- ✅ Multiple recycles happen sequentially without error
- ✅ Grid remains intact

**Console check:**
```
Should see multiple log entries:
[GridManager] Recycled: dx=1, dy=0, offset=(...)
[GridManager] Recycled: dx=0, dy=-1, offset=(...)
etc.
```

---

### Test 1.5: Rapid Direction Changes

**Objective:** Verify grid robustness under chaotic input

**Steps:**
1. Rapidly change camera direction (right → up → left → down, repeat)
2. Hold for 5 seconds
3. Observe grid behavior

**Expected behavior:**
- Grid responds immediately to direction changes
- No lag, stutter, or visual artifacts
- Logical coordinates remain consistent

**Pass Criteria:**
- ✅ No crashes or errors
- ✅ Grid state remains valid
- ✅ Instruments don't disappear

---

## Test Category 2: Instrument Identity & Positioning

### Test 2.1: Instrument Persistence

**Objective:** Verify instruments maintain unique identity across cell recycling

**Setup:**
- Note instrument positions:
  - Instrument_0 (flute) at logical ~(0, 0)
  - Instrument_1 (drum) at logical ~(1, 0)
  - Instrument_2 (bell) at logical ~(0, 1)

**Steps:**
1. Scroll right (hold RIGHT ARROW for 3 sec)
2. Instrument_0 should move from left-center to right edge (still visible)
3. Note that when grid recycles, Instrument_0 should still exist and be trackable
4. Scroll right again; Instrument_0 moves off-screen but still exists logically
5. Scroll left back to center
6. Instrument_0 should reappear at its logical position

**Expected behavior:**
- Instruments don't duplicate
- Instruments don't disappear permanently
- Each maintains unique ID throughout

**Pass Criteria:**
- ✅ 3 instruments always exist (check scene tree)
- ✅ Logical coordinates updated correctly
- ✅ No duplication in registry

---

### Test 2.2: Instrument Positioning After Recycle

**Objective:** Verify instruments maintain correct global position when cell recycles

**Steps:**
1. Scroll to center grid view
2. Take note of Instrument_0's visual position on screen
3. Scroll right until a recycle happens
4. Verify Instrument_0 is still at same visual position (or moved off-screen smoothly)
5. No jitter or sudden jumps

**Expected behavior:**
- Instrument visual position changes smoothly with camera movement
- When reparented to recycled cell, no visual "pop" or jump
- Global position preserved through recycling

**Pass Criteria:**
- ✅ No jitter at cell boundaries
- ✅ Instruments move smoothly with camera
- ✅ Position updates are continuous

---

### Test 2.3: Multi-Instrument in Same Cell

**Objective:** Verify multiple instruments can occupy same logical cell

**Setup:**
- Drag two instruments to same cell position

**Steps:**
1. Drag Instrument_0 directly on top of Instrument_1
2. Note: Both should occupy same cell
3. Scroll and verify both track correctly
4. No collision or overlap issues

**Pass Criteria:**
- ✅ Multiple instruments per cell supported
- ✅ Both maintain independent identity
- ✅ Registry tracks both correctly

---

## Test Category 3: Touch Interaction (Short/Long Press)

### Test 3.1: Short Press Detection

**Objective:** Verify taps <0.4s fire short-press event

**Steps:**
1. **Tap** (quick click) on Instrument_0
2. Hold for <0.2 seconds and release
3. Observe:
   - Instrument glows briefly
   - Console may show: `[AudioManager] Playing: flute (short)`
   - Haptic feedback if on mobile (brief pulse)

**Expected behavior:**
- Short press detected immediately on release
- Audio plays (if configured)
- Visual feedback (glow) appears

**Pass Criteria:**
- ✅ Short press fires
- ✅ Instrument glow appears
- ✅ Audio plays

---

### Test 3.2: Long Press Detection

**Objective:** Verify holds >0.4s fire long-press event (once only)

**Steps:**
1. **Click and hold** on Instrument_0 for 0.5+ seconds
2. Keep holding (don't release yet)
3. Observe: After ~0.4s, instrument should provide longer haptic pulse
4. Continue holding for another 1 second
5. Release

**Expected behavior:**
- Long press fires once after 0.4s
- Haptic feedback (longer pulse)
- Audio sustains/loops if configured
- No repeat of long-press event while holding

**Pass Criteria:**
- ✅ Long press fires exactly once
- ✅ Timing is ~0.4s
- ✅ Haptic is distinct from short press

---

### Test 3.3: Press Release Event

**Objective:** Verify release triggers stop

**Steps:**
1. Hold on Instrument_0 for 0.5s (triggers long-press)
2. Release
3. Audio should fade out (if configured)

**Expected behavior:**
- Release event fires
- Audio stops cleanly
- No error messages

**Pass Criteria:**
- ✅ Release detected
- ✅ Audio stops appropriately

---

## Test Category 4: Instrument Dragging

### Test 4.1: Basic Drag

**Objective:** Verify instruments can be dragged to adjacent cells

**Steps:**
1. **Click and drag** Instrument_0 slightly to the right (within same cell)
2. Release; instrument should stay where dragged
3. **Click and drag** Instrument_0 to clearly different cell (e.g., to Instrument_1's cell)
4. Release; instrument should remain in new cell

**Expected behavior:**
- Instrument follows mouse/touch while dragging
- Drag offset >10px initiates drag mode
- Instrument reparents to new cell if crossed boundary
- Logical position updates

**Pass Criteria:**
- ✅ Drag detection works
- ✅ Instrument follows cursor
- ✅ Cell change detected
- ✅ No jitter

---

### Test 4.2: Drag with Camera Lock

**Objective:** Verify camera freezes while dragging

**Steps:**
1. **Click and drag** Instrument_0 to new cell (hold for 2 seconds)
2. While dragging, press RIGHT ARROW
3. Camera should NOT move (frozen due to drag)
4. Release instrument
5. Press RIGHT ARROW again
6. Camera should NOW move (drag ended)

**Expected behavior:**
- While dragging: camera locked
- After release: camera responsive
- Drag freezes camera movement

**Pass Criteria:**
- ✅ Camera freezes during drag
- ✅ Camera resumes after release
- ✅ GridManager correctly tracks `is_dragging` state

---

### Test 4.3: Drag Across Multiple Cells

**Objective:** Verify robust reparenting across multiple cell boundaries

**Steps:**
1. Click on Instrument_0
2. Drag it far across multiple cells (e.g., 2-3 cells away)
3. Release

**Expected behavior:**
- Instrument smoothly transitions across cells
- No gaps or jitter
- Final position is correct logical cell

**Pass Criteria:**
- ✅ Multi-cell drag works
- ✅ No jitter or visual artifacts
- ✅ Logical position accurate

---

### Test 4.4: Drag During Recycle

**Objective:** Verify drag doesn't break if cell recycles during drag (edge case)

**Steps:**
1. Click and start dragging Instrument_0 downward
2. While dragging, scroll camera to trigger recycle (hit UP/DOWN arrow)
3. Continue dragging
4. Release

**Expected behavior:**
- Drag continues smoothly even if cell recycles
- Instrument maintains position and logical tracking
- No error or corruption

**Pass Criteria:**
- ✅ No crash
- ✅ Instrument position consistent
- ✅ Logical coordinates correct

---

## Test Category 5: Audio Playback

### Test 5.1: Short Press Audio

**Objective:** Verify short-press plays one-shot sample

**Prerequisites:**
- Audio files configured in `res://assets/audio/instruments/`
- Files named: `flute.ogg`, `drum.ogg`, `bell.ogg`

**Steps:**
1. Tap Instrument_0 (flute) quickly
2. Listen for one-shot audio sample
3. Audio should play and complete

**Expected behavior:**
- Short-press triggers one-shot playback
- Audio duration ~0.1–0.5 seconds
- No loop

**Pass Criteria:**
- ✅ Audio plays
- ✅ Audio is one-shot (doesn't repeat)
- ✅ Volume is reasonable

---

### Test 5.2: Long Press Audio (Sustain)

**Objective:** Verify long-press plays sustained/looped audio

**Prerequisites:**
- Same audio files as Test 5.1

**Steps:**
1. Hold on Instrument_0 for >0.4s
2. After 0.4s, audio should start playing (looped)
3. Hold for 2 seconds; audio sustains
4. Release; audio fades out

**Expected behavior:**
- Long-press triggers looped audio
- Audio plays continuously while held
- Release stops audio smoothly

**Pass Criteria:**
- ✅ Audio starts after 0.4s
- ✅ Audio loops
- ✅ Audio stops on release

---

### Test 5.3: Multiple Instruments Audio

**Objective:** Verify simultaneous audio playback

**Steps:**
1. Tap Instrument_0 (flute)
2. While audio plays, tap Instrument_1 (drum)
3. Both audios should play simultaneously
4. Different pitches/instruments

**Expected behavior:**
- Multiple instruments can play at once
- No audio conflicts
- Each maintains independent playback

**Pass Criteria:**
- ✅ Multiple instruments play
- ✅ No audio corruption
- ✅ Volumes appropriate

---

### Test 5.4: Spatial Audio (Panning)

**Objective:** Verify audio panning based on instrument position

**Prerequisites:**
- Headphones recommended for stereo effect

**Steps:**
1. Position Instrument_0 on left edge of screen
2. Play long-press audio
3. Audio should pan to left ear
4. Drag Instrument_0 to right
5. Audio panning should update to right ear

**Expected behavior:**
- Audio pans based on instrument X position relative to camera
- Smooth panning transitions
- Spatial effect is noticeable with headphones

**Pass Criteria:**
- ✅ Panning works
- ✅ Smooth updates during drag
- ✅ Effect is noticeable

---

## Test Category 6: Visual & Procedural Content

### Test 6.1: Cell Content Generation

**Objective:** Verify procedural flora is generated consistently

**Steps:**
1. Note flora placement in visible cells
2. Scroll away (recycle cells)
3. Scroll back to original position
4. Flora should be in same positions (deterministic)

**Expected behavior:**
- Flora generates based on logical coordinates
- Same seed → same content placement
- Different cells → potentially different flora

**Pass Criteria:**
- ✅ Content is deterministic
- ✅ Consistent between visits
- ✅ Visual variety across cells

---

### Test 6.2: Debug Text Overlay

**Objective:** Verify debug coordinates are displayed

**Steps:**
1. Enable Debug Mode in GridManager
2. Observe each cell shows `(x, y)` text
3. As grid recycles, numbers update
4. Center cell should always show `(0, 0)` or similar

**Expected behavior:**
- Debug text visible on all cells
- Updates on recycle
- Helps validate logical positioning

**Pass Criteria:**
- ✅ Debug text visible
- ✅ Updates correctly
- ✅ Matches expected coordinates

---

## Test Category 7: Performance & Memory

### Test 7.1: Frame Rate Stability

**Objective:** Verify 60 FPS maintained during normal play

**Steps:**
1. Open Godot profiler (Debug → Monitor)
2. Note FPS counter
3. Scroll camera continuously for 10 seconds
4. Observe FPS graph

**Expected behavior:**
- FPS stays ≥58 FPS (60 target)
- No significant drops during recycle
- Smooth frame pacing

**Pass Criteria:**
- ✅ FPS ≥58 consistently
- ✅ No stuttering on recycle
- ✅ Smooth gameplay

---

### Test 7.2: Memory Stability

**Objective:** Verify no memory leaks (size constant over time)

**Steps:**
1. Open Godot profiler (Debug → Monitor)
2. Note Memory usage
3. Scroll and interact for 60 seconds
4. Observe memory graph

**Expected behavior:**
- Memory usage remains constant
- No growth over time
- No unexpected spikes

**Pass Criteria:**
- ✅ Memory stable
- ✅ No leaks detected
- ✅ <100 MB base usage (typical for mobile)

---

### Test 7.3: Cell Count Constant

**Objective:** Verify exactly 12 cells always exist

**Steps:**
1. In Godot Scene tree, expand GridManager → CellsContainer
2. Count cells: should be 9
3. Scroll for 30 seconds
4. Re-count; still 9

**Expected behavior:**
- Exactly 12 cells at all times
- No cells created or destroyed

**Pass Criteria:**
- ✅ Cell count = 12 (never changes)
- ✅ Scene tree doesn't grow

---

## Test Category 8: Export & Mobile Testing

### Test 8.1: HTML5 Export

**Objective:** Verify grid works in web browser

**Steps:**
1. **File → Export Project → HTML5**
2. Select export path (e.g., `export/html5/`)
3. Export
4. Open `export/html5/index.html` in browser
5. Test:
   - Camera movement (arrow keys)
   - Tap/click on instruments
   - Drag instruments
   - Verify grid recycling

**Expected behavior:**
- Game runs in browser
- Touch input detected
- Camera scrolls responsively
- No console errors

**Pass Criteria:**
- ✅ Export succeeds
- ✅ Runs in browser
- ✅ No JavaScript errors
- ✅ Playable

**Browser testing tips:**
- Test on desktop (Firefox, Chrome)
- Test on mobile (iOS Safari, Android Chrome)
- Open DevTools → Console to check errors

---

### Test 8.2: Android Export (if available)

**Objective:** Verify touch input and performance on Android

**Setup:**
1. Install Android SDK/NDK (if not already done)
2. Connect Android device via USB
3. **File → Export Project → Android**
4. Configure debug/release settings
5. Deploy to device

**Steps on device:**
1. Launch app
2. Test touch:
   - Swipe to scroll camera
   - Tap instruments (short press)
   - Hold on instruments (long press)
   - Drag instruments
3. Monitor performance
4. Test haptic feedback (should vibrate on press)

**Expected behavior:**
- Smooth touch input response
- 60 FPS on modern devices
- Haptic feedback works
- No lag or jitter

**Pass Criteria:**
- ✅ Touch works smoothly
- ✅ FPS stable (≥50 on phones)
- ✅ Haptic feedback vibrates
- ✅ Playable

---

## Test Checklist (Summary)

| Category | Test | Status |
|----------|------|--------|
| **Grid Recycling** | Basic arrangement | ☐ |
| | Movement right | ☐ |
| | Movement left/up/down | ☐ |
| | Fast diagonal | ☐ |
| | Rapid direction changes | ☐ |
| **Instruments** | Identity persistence | ☐ |
| | Positioning after recycle | ☐ |
| | Multi-instrument per cell | ☐ |
| **Touch (Short/Long)** | Short press | ☐ |
| | Long press | ☐ |
| | Release event | ☐ |
| **Dragging** | Basic drag | ☐ |
| | Camera lock during drag | ☐ |
| | Multi-cell drag | ☐ |
| | Drag during recycle | ☐ |
| **Audio** | Short-press audio | ☐ |
| | Long-press audio | ☐ |
| | Multiple instruments | ☐ |
| | Spatial panning | ☐ |
| **Content** | Flora generation | ☐ |
| | Debug text | ☐ |
| **Performance** | Frame rate | ☐ |
| | Memory stability | ☐ |
| | Cell count constant | ☐ |
| **Export** | HTML5 export | ☐ |
| | Android export (if available) | ☐ |

---

## Known Limitations & Future Work

| Issue | Workaround | Priority |
|-------|-----------|----------|
| Audio files not auto-detected | Add files manually to `res://assets/audio/instruments/` | Medium |
| No gesture support (pinch zoom) | Keyboard zoom via config | Low |
| No visual indicators for cell boundaries | Enable debug mode (shows coordinates) | Low |
| No persistence (save/load world) | Can be added in future iteration | Low |

---

## Troubleshooting

### Cells disappear or show blanks

**Cause:** Recycling logic error or missing update_content() call

**Fix:**
1. Enable debug mode
2. Check console for error logs
3. Verify CellsContainer has exactly 9 children
4. Check GridCell.update_content() is called

### Instruments not moving on drag

**Cause:** `Allow Dragging` not set, or Area2D collision not configured

**Fix:**
1. Check `Allow Dragging: true` in Instrument properties
2. Verify Area2D has CollisionShape2D child
3. Check Area2D is configured as `input_event` source

### Audio not playing

**Cause:** Missing audio files or AudioManager not set up

**Fix:**
1. Create `res://assets/audio/instruments/` directory
2. Add `.ogg` files: `flute.ogg`, `drum.ogg`, `bell.ogg`
3. Verify AudioManager is in Autoload list
4. Check console for audio load errors

### Camera doesn't scroll

**Cause:** CameraController not attached or input actions not configured

**Fix:**
1. Verify Camera2D has CameraController.gd script
2. Check Project → Input Map has `ui_up`, `ui_down`, `ui_left`, `ui_right` actions
3. Enable debug mode in CameraController to verify input

### Jitter at cell boundaries

**Cause:** Floating-point accumulation or improper reparenting

**Fix:**
1. Verify GridManager uses `int(floor(...))` for logical calculations
2. Check instrument global_position is preserved during reparent
3. Disable camera zoom (keep at 1.0, 1.0)

---

## Conclusion

Once all tests in the checklist pass, your infinite-scrolling 4x3 grid system is **production-ready**. You can:

- ✅ Deploy to mobile/web
- ✅ Add more instruments
- ✅ Expand world features (NPCs, events, etc.)
- ✅ Integrate with larger game systems
