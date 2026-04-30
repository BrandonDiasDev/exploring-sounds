# Scene Setup Instructions: WorldExample.tscn

## Overview
This document walks you through setting up `WorldExample.tscn` in the Godot editor. The scene demonstrates a fully functional infinite-scrolling 4x3 grid with instruments.

**Estimated time:** 15–20 minutes

---

## Step 1: Create the Main Scene

1. **Create new scene** → Root node: `Node2D`, name it `WorldExample`
2. **Save scene** as `res://scenes/WorldExample.tscn`

---

## Step 2: Create GridManager and CellsContainer

1. **Add child to WorldExample:** `Node2D`, name it `GridManager`
2. **Attach script** to GridManager: `res://scripts/GridManager.gd`
3. **Add child to GridManager:** `Node2D`, name it `CellsContainer`
4. **Add child to GridManager:** `Node2D`, name it `InstrumentsContainer`

**Scene tree so far:**
```
WorldExample
├── GridManager (script: GridManager.gd)
│   ├── CellsContainer
│   └── InstrumentsContainer
```

---

## Step 3: Create GridCell Scene (Reusable)

1. **Create new scene** → Root node: `Node2D`, save as `res://scenes/GridCell.tscn`

2. **Rename root to:** `GridCell` (for clarity)

3. **Add children:**
   - `ColorRect` (named `ColorRect`)
     - Set `Custom Minimum Size: (512, 512)` (or 1024x1024 if you prefer larger cells)
     - Set `Anchor Layout: Full Rect`
     - Set `Color: WHITE` (background)
   - `Sprite2D` (named `Sprite2D`)
     - Set `Position: (256, 256)` (center of cell)
     - Assign a placeholder sprite or leave empty

4. **Attach script** to GridCell root: `res://scripts/GridCell.gd`

5. **Save scene**

**GridCell.tscn tree:**
```
GridCell (script: GridCell.gd)
├── ColorRect
└── Sprite2D
```

---

## Step 4: Populate CellsContainer with 12 GridCell Instances

1. **Open WorldExample.tscn**

2. **Select CellsContainer**

3. **Instance GridCell 12 times** (Ctrl+Shift+A → Add Node → Instance, select `res://scenes/GridCell.tscn`)
   - Name them: `GridCell_00`, `GridCell_01`, ..., `GridCell_11`

4. **Set their LOCAL positions** (not global) to arrange in 4x3 grid:
   - GridCell_00: (0, 0)
   - GridCell_01: (512, 0)
   - GridCell_02: (1024, 0)
   - GridCell_03: (0, 512)
   - GridCell_04: (512, 512)
   - GridCell_05: (1024, 512)
   - GridCell_06: (0, 1024)
   - GridCell_07: (512, 1024)
   - GridCell_08: (1024, 1024)
   - GridCell_09: (1536, 0)
   - GridCell_10: (1536, 512)
   - GridCell_11: (1536, 1024)

   *If using 1024x1024 cells, multiply all positions by 2.*

**Scene tree after step 4:**
```
GridManager
├── CellsContainer
│   ├── GridCell_00 (instance)
│   ├── GridCell_01 (instance)
│   ├── ... (12 total)
│   └── GridCell_08 (instance)
└── InstrumentsContainer
```

---

## Step 5: Create Instrument Scene (Reusable)

1. **Create new scene** → Root node: `Node2D`, save as `res://scenes/Instrument.tscn`

2. **Rename root to:** `Instrument`

3. **Add children:**
   - `Area2D` (named `Area2D`)
     - Add child: `CollisionShape2D` (set shape to `CircleShape2D`, radius ~30)
   - `Sprite2D` (named `Sprite2D`)
     - Set `Position: (0, 0)`
     - Assign a placeholder sprite (colored circle, musical note, etc.)
     - Set `Scale: (0.5, 0.5)` for visibility

4. **Attach script** to Instrument root: `res://scripts/Instrument.gd`

5. **Set properties** in Inspector:
   - `Instrument Id: "instrument_default"` (will be unique per instance)
   - `Long Press Threshold: 0.4` (seconds)
   - `Allow Dragging: true`

6. **Save scene**

**Instrument.tscn tree:**
```
Instrument (script: Instrument.gd)
├── Area2D
│   └── CollisionShape2D
└── Sprite2D
```

---

## Step 6: Add Test Instruments to InstrumentsContainer

1. **Open WorldExample.tscn**

2. **Select InstrumentsContainer**

3. **Instance Instrument 3 times** (e.g., for test):
   - Instance 1: name `Instrument_0`, position `(256, 256)`, id: `"flute"`
   - Instance 2: name `Instrument_1`, position `(768, 256)`, id: `"drum"`
   - Instance 3: name `Instrument_2`, position `(512, 768)`, id: `"bell"`

4. **Unique properties for each:**
   - `Instrument_0`: `instrument_id = "flute"`
   - `Instrument_1`: `instrument_id = "drum"`
   - `Instrument_2`: `instrument_id = "bell"`

**Scene tree after step 6:**
```
GridManager
├── CellsContainer
│   ├── GridCell_00 (instance)
│   ├── ... (12 total)
│   └── GridCell_08 (instance)
└── InstrumentsContainer
    ├── Instrument_0 (instance, id: "flute")
    ├── Instrument_1 (instance, id: "drum")
    └── Instrument_2 (instance, id: "bell")
```

---

## Step 7: Add Camera2D

1. **Add child to WorldExample:** `Camera2D`, name it `Camera2D`

2. **Set properties:**
   - `Global Position: (512, 512)` (or 1024, 1024 if 1024x1024 cells)
   - `Enabled: true`
   - `Zoom: (1.0, 1.0)` (no zoom for now)

3. **Attach script** to Camera2D: `res://scripts/CameraController.gd`

4. **Set properties:**
   - `Pan Speed: 300` (pixels/second)
   - `Smoothing: 0.1`
   - `Debug Mode: false` (set to `true` for testing)

**Scene tree after step 7:**
```
WorldExample
├── GridManager (...)
├── Camera2D (script: CameraController.gd)
```

---

## Step 8: Add AudioManager (Autoload)

1. **In Godot editor:** Project → Project Settings → Autoload

2. **Create a new Node scene** with root `Node`, name it `AudioManager`

3. **Attach script:** `res://scripts/AudioManager.gd`

4. **Save as:** `res://scenes/AudioManager.tscn`

5. **In Autoload tab:**
   - Click "Add" and select `res://scenes/AudioManager.tscn`
   - Verify it appears as `AudioManager` in the Autoload list

**This makes AudioManager a singleton accessible globally.**

---

## Step 9: Add UI Node (Optional Debug)

1. **Add child to WorldExample:** `CanvasLayer`, name it `UI`

2. **Add child to UI:** `Label`, name it `DebugLabel`

3. **Set properties:**
   - `Text: "Grid System Ready"`
   - `Anchor Layout: Top Left`
   - `Position: (10, 10)`

This is optional but useful for displaying debug info later.

---

## Step 10: Configure GridManager in Inspector

1. **Select GridManager node**

2. **In Inspector, set:**
   - `Cell Size: (512, 512)` (or 1024x1024)
   - `Debug Mode: true` (for now)

3. **Verify in console** that all systems initialize:
   ```
   [GridManager] Ready. Cells: 12, world_seed: [random_int], cell_size: (512, 512)
   [Instrument] Ready: id=flute, logical=(0,0)
   [Instrument] Ready: id=drum, logical=(1,0)
   [Instrument] Ready: id=bell, logical=(0,1)
   [AudioManager] Ready. Cache size: 0
   ```

---

## Step 11: Test Basic Functionality

1. **Press Play (F5)**

2. **Expected behavior:**
   - Camera is at center; you see 12 cells arranged in a 4x3 pool
   - 3 instruments are visible on cells
   - Debug text shows `(logical_x, logical_y)` on each cell

3. **Try inputs:**
   - **Arrow keys** → Camera moves; cells recycle as needed
   - **Mouse over instrument** → Cell highlights; instrument glows
   - **Short tap on instrument** → Instrument plays short sound (if audio setup)
   - **Hold tap (>0.4s)** → Instrument plays sustained sound
   - **Drag instrument** → Move it to adjacent cells

4. **If cells show DARK colors** → Cell content is generating; this is normal

---

## Full Scene Tree (Final)

```
WorldExample (Node2D)
├── GridManager (Node2D, script: GridManager.gd)
│   ├── CellsContainer (Node2D)
│   │   ├── GridCell_00 (instance)
│   │   ├── GridCell_01 (instance)
│   │   ├── GridCell_02 (instance)
│   │   ├── GridCell_03 (instance)
│   │   ├── GridCell_04 (instance)
│   │   ├── GridCell_05 (instance)
│   │   ├── GridCell_06 (instance)
│   │   ├── GridCell_07 (instance)
│   │   └── GridCell_08 (instance)
│   └── InstrumentsContainer (Node2D)
│       ├── Instrument_0 (instance, id: "flute")
│       ├── Instrument_1 (instance, id: "drum")
│       └── Instrument_2 (instance, id: "bell")
├── Camera2D (script: CameraController.gd)
└── UI (CanvasLayer, optional)
    └── DebugLabel (Label, optional)

(Autoload)
AudioManager (Autoload, script: AudioManager.gd)
```

---

## Configuration Summary

| Setting | Value |
|---------|-------|
| **Cell Size** | 512×512 or 1024×1024 (choose one; be consistent) |
| **Grid Dimensions** | 4×3 (12 cells, fixed) |
| **Pan Speed** | 300 px/s (camera scroll speed) |
| **Long Press Threshold** | 0.4 s (tap duration) |
| **Haptic Duration (short)** | 50 ms |
| **Haptic Duration (long)** | 100 ms |
| **Fade Out Duration** | 0.2 s (audio fade) |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Cells aren't visible | Check ColorRect size matches cell_size; enable Debug Mode |
| Instruments don't move | Verify `Allow Dragging: true` in Instrument properties |
| Camera doesn't scroll | Verify Camera2D has CameraController.gd script |
| Audio doesn't play | Set up AudioManager as Autoload; check audio file paths |
| Instruments disappear at cell edges | Check reparenting logic; inspect GridManager console logs |

---

## Next Steps

1. **Add audio files**: Create `res://assets/audio/instruments/` directory with `.ogg` files
2. **Customize sprites**: Replace placeholder sprites with your own graphics
3. **Tune parameters**: Adjust pan speed, long-press threshold, cell size as needed
4. **Export to HTML/Mobile**: Test performance; adjust cell_size if needed for FPS

