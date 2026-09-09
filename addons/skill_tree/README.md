# Skill Tree

A grid-snapped skill tree authoring tool for Godot 4. Data-driven, themeable,
and knows nothing about your project.

## Install

1. Copy `addons/skill_tree/` into your project.
2. **Project → Project Settings → Plugins → enable "Skill Tree".**
3. A **SkillTree** tab appears next to 2D / 3D / Script.

## First tree in 30 seconds

1. Open the **SkillTree** tab.
2. **New…** → pick a path → you get a grid of guide dots.
3. Press **Fill With Demo** to get a working tree to poke at, or start placing.

The toolbar dropdown lists every skill tree in the project, so you switch
between them without hunting through the FileSystem dock.

## Authoring

| Gesture | Result |
|---|---|
| Click a guide dot | Place a skill node there |
| Click a node | Select it — **it opens in Godot's Inspector** |
| Drag a node | Move it to another dot |
| **Shift**-drag node → node | Connect them (`from` becomes a prerequisite of `to`) |
| Click a connection | Select it |
| **Add Lock** (toolbar) | Gate the selected connection behind an achievement |
| `Delete` | Delete the selection |
| Wheel / middle-drag / `F` | Zoom / pan / fit |
| Toolbar dropdown | Switch trees |

Everything structural is undoable with the editor's normal Ctrl+Z.

Property editing is deliberately *not* reimplemented — selecting anything hands
it to the real Inspector, so icons, cost arrays and your own payload resources
all work at full fidelity.

**Save** writes the `.tres`. The title shows `*` while unsaved.

**Validate** reports duplicate ids, connections to missing nodes, nodes pushed
off-grid, unreachable cycles and trees with no root. Worth pressing before you
ship a tree.

## Data model

```
SkillTreeResource      the file you author
├─ grid_size / cell_size    the guide dots; nodes store CELLS, not pixels
├─ nodes:       Array[SkillNodeData]
│   ├─ id, title, description, icon, cell
│   ├─ max_rank            1 = on/off, >1 = buy repeatedly
│   ├─ costs: Array[SkillCost] → { currency: SkillCurrency, amount, per_rank_increase }
│   ├─ requirement         ALL or ANY incoming connections
│   └─ payload: Resource   YOUR type. The addon never reads it.
├─ connections: Array[SkillConnection]
│   └─ from_id, to_id, lock: SkillLock (null = open)
└─ style: SkillTreeStyle
```

Because nodes store grid cells, changing `cell_size` rescales a finished layout
instead of breaking it.

## Runtime

Add a **SkillTreeView** (Control) to a scene, assign `tree`, and it lays itself
out — including a live preview in the editor.

```gdscript
var state := SkillTreeState.new(view.tree)
state.balance_provider = func(id): return Wallet.balance(id)   # -> int
state.spender          = func(costs): return Wallet.spend(costs)  # -> bool
state.lock_provider    = func(id): return Achievements.has(id)    # -> bool
view.state = state
view.node_purchased.connect(_on_purchased)
```

Those three `Callable`s are the entire integration surface. See
`examples/example_wiring.gd`.

**Leave them unset and everything is free** — which is what you want while
prototyping. Locks default to closed; open one by hand with
`state.set_lock_open(&"my_achievement")`.

Save/load is `state.to_dict()` / `state.from_dict()`.

### Node states

`LOCKED` → `GATED` (prereqs met, lock shut) → `AVAILABLE` → `PURCHASED` → `MAXED`.
Affordability is separate, so a node can be available but dimmed.

## Making it look good

`SkillTreeStyle` holds every visual, so re-skinning is one resource swap.

- **StyleBoxes** per node state. Leave them empty for a legible grey-box.
- **`node_material`** — your `ShaderMaterial`, dropped onto every node Control.
- **`link_material`**, `link_outline_width` — for glow or energy-flow links.
- **`ui_theme`** — a `Theme` applied to the view, so labels and tooltips
  inherit your project's look.
- **`anchor_texture`**, `lock_closed_icon` / `lock_open_icon` — swap the
  placeholder circles and drawn padlock for art.

Nodes are real `Control`s (not draw calls), so hover, focus, tooltips and
per-node shaders work the way they do anywhere else in Godot.

## Exporting your game

The `editor/` scripts reference `EditorInterface` and `EditorUndoRedoManager`,
which don't exist in release builds. They carry no `class_name` and are only
reached by `preload` from `plugin.gd`, so a normal export never parses them.
If your export preset uses an explicit include list, just leave
`addons/skill_tree/editor/` out of it.

## Files

```
runtime/   shipped with your game
  skill_tree_types.gd       shared enums (SkillTree.NodeState, .Requirement)
  skill_currency.gd         a spendable resource
  skill_cost.gd             one currency's share of a price
  skill_lock.gd             an achievement gate
  skill_node_data.gd        one node
  skill_connection.gd       one prerequisite edge
  skill_tree_resource.gd    the tree + validate()
  skill_tree_style.gd       all visuals
  skill_tree_state.gd       ownership + rules (no Node, no autoload)
  skill_tree_view.gd        the runtime Control
  skill_node_control.gd     one node's Control
editor/    editor-only
  skill_tree_editor.gd      toolbar
  skill_tree_canvas.gd      authoring surface
```
