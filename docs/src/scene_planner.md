# The scene planner

Parking gives you two ways to turn a scene into a planned parking
maneuver:

1. **Write code** against the planning API (`plan_park` / `plan_leave`). This is
   the right choice for batch runs, tests, and embedding planning inside a larger
   program.
2. **Use the interactive designer** ([`designer`](@ref)), a web canvas backed by
   Makie + Bonito + WGLMakie, where you draw the scene with the mouse and press
   *Generate* to plan and animate.

Both paths ultimately build an [`Environment`](@ref), call the planner, and return
a [`PlanResult`](@ref).

## Planning by writing code

A planning call needs three things: a [`Vehicle`](@ref), an
[`Environment`](@ref) (bounds, obstacles, target spot), and a `start` pose. The
scenario factories in this package build all three for you.

```julia
using Parking

# 1. Build a scene: a single perpendicular spot flanked by parked cars and a wall.
env, vehicle = perpendicular_parking()

# 2. Start pose on the driving lane, in geometric-center coordinates.
#    plan_park converts it to the internally used rear-axle-center pose.
start = Pose(-6.0, 0.5, 0.0)

# 3. Plan a park-in. A safety clearance inflates every obstacle so the path
#    keeps a margin.
res = plan_park(vehicle, env, start; clearance = 0.15)

# 4. Inspect the outcome.
if res.status == SUCCESS
    println("Found a path with $(length(res.path)) poses.")
else
    println("Planning failed: ", res.reason)
end
```

`res.status` is one of the `PlanStatus` values `SUCCESS`, `NO_PATH_FOUND`,
`START_IN_COLLISION`, or `GOAL_IN_COLLISION`. On failure, `res.reason` carries a
human readable explanation. The planned path is a `Vector{Pose}` of rear-axle
center poses (`res.path`); it is empty when planning fails.

### Leaving a spot

[`plan_leave`](@ref) reverses the problem: it plans a path that drives the
vehicle *out* of `env.spot` to a pulled-out pose on the lane. The `start` pose is
the spot's center (geometric coordinates).

```julia
env, vehicle = perpendicular_nose_out()
start = env.spot.center          # vehicle begins inside the spot
res = plan_leave(vehicle, env, start; clearance = 0.15)
```

### Optional knobs

- `clearance` (default `0.15` m): safety margin added to obstacles and subtracted
  from the bounds.
- `sample_goals = true`: sample a few candidate final poses inside the spot and
  keep the shortest successful path, improving robustness in tight spaces.
- `dx`, `dy`, `dθ`: search-grid resolution. Finer grids find more paths but expand
  more nodes.
- `refine_path(vehicle, env, res.path)`: smooth the discrete grid path into a
  higher-resolution, still collision-free trajectory you can feed to a controller.

## Planning with the interactive tool

The [`designer`](@ref) launches a Bonito web app. It is provided by the
`ParkingMakie` extension, so you must load the Makie stack first:

```julia
using Parking, Makie, Bonito, WGLMakie

app = designer()                 # renders inline in VSCode / Jupyter
# Bonito.Server(app, "0.0.0.0", 8080)   # or serve as a standalone web page
```

In the canvas you:

- pick a **tool** - *Spot*, *Start*, *Rect obstacle*, *Wall*, or *Polygon*;
- **draw with the mouse** - click-drag for Spot / Start / Rect / Wall; click to
  add polygon vertices, then press *Finish polygon*;
- adjust the **sliders** for spot length, width, angle, and planning clearance;
- press **Generate** to build the `Environment`, run `plan_park`, and animate the
  resulting path on the canvas;
- use the **presets** to load a parallel / perpendicular scenario instantly.

A full, runnable version of this is shipped as `examples/designer.jl`.

The figure below shows the kind of planned trajectory the tool (and the code API)
produce: the rear-axle-center path drawn as a dashed polyline with the vehicle
outline at the start (green) and goal (red) poses.

![Planned trajectory](../figures/three_rows_park.gif)
