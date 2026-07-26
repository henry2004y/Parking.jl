# API Reference

This page documents the public API of `Parking`. All symbols listed here
are exported from the package.

## Vehicle and geometry

```@docs
Vehicle
Pose
Rectangle
corners
footprint
rear_axle_pose
```

## Environment and parking spots

```@docs
ParkingSpot
spot_corners
Environment
inflate_rect
with_clearance
build_lot
```

## Collision checking

```@docs
is_collision
collision_reason
path_clear
```

## Planning

```@docs
PlanResult
step_vehicle
plan_park
plan_leave
```

The planner reports its outcome through `PlanResult`. The `status` field is one of
the `PlanStatus` values: `SUCCESS`, `NO_PATH_FOUND`, `START_IN_COLLISION`, or
`GOAL_IN_COLLISION`. The `reason` field carries a human readable description of
the outcome, e.g. `"start pose is in collision (not in a valid free space)"`.

## Simulation and refinement

```@docs
simulate
refine_path
Trajectory
duration
trajectory
```

## Visualization

Drawing and animation are provided by optional package extensions, so the core
package stays lightweight:

- `ParkingPlots` - loaded automatically when `Plots` is in scope.
  Provides `plot_scene`, `plot_pose!`, `plot_path!`, and `animate_parking`.
- `ParkingMakie` - loaded automatically when `Makie`, `Bonito`, and
  `WGLMakie` are in scope. Provides `plot_scene!`, `makie_scene`, the interactive
  `designer`, and also implements `plot_pose!` / `plot_path!` for a Makie `Axis`.

`plot_pose!` and `plot_path!` are backend-agnostic: their `target` is a
`Plots.Plot` (Plots backend) or a Makie `Axis` (Makie backend). Load the matching
backend before calling any of these, e.g. `using Parking, Plots` or
`using Parking, Makie, Bonito, WGLMakie`.

```@docs
plot_scene
plot_scene!
plot_pose!
plot_path!
makie_scene
animate_parking
designer
```
