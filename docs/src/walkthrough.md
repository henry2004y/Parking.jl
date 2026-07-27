# End-to-end walkthrough

This page follows one maneuver from an empty script to a simulated, animated
result, touching every stage of the pipeline: scene building, planning,
refinement, visualization, and verification.

We will park a vehicle into a perpendicular spot using the Plots backend for
drawing, then repeat the visualization with the Makie backend.

## 1. Load the package and build a scene

```julia
using Parking
using Plots                       # Plots backend (load it before drawing)

env, vehicle = perpendicular_parking()
start = Pose(-6.0, 0.5, 0.0)     # geometric-center start pose on the lane
```

`perpendicular_parking()` returns an [`Environment`](@ref) (drivable bounds, the
two neighbor cars, a rear curb, and the free target spot) together with a default
[`Vehicle`](@ref). `start` is expressed in geometric-center coordinates;
`plan_park` converts it to the rear-axle-center reference internally.

## 2. Plan the maneuver

```julia
res = plan_park(vehicle, env, start; clearance = 0.15)

res.status == SUCCESS || error("planning failed: ", res.reason)
path = res.path                  # Vector{Pose}, rear-axle-center poses
```

What is happening here:

- A safety `clearance` inflates every obstacle (and shrinks the bounds) so the
  planned path keeps a margin from everything around it.
- If planning fails, `res.reason` tells you why (`START_IN_COLLISION`,
  `GOAL_IN_COLLISION`, or `NO_PATH_FOUND`).
- On success, `path` is the collision-free sequence of poses from the start to the
  spot center.

## 3. Refine the path

The A* search runs on a discrete grid, so the raw path can cut corners.
[`refine_path`](@ref) smooths it into a finer, still collision-free trajectory:

```julia
refined = refine_path(vehicle, env, path)
```

## 4. Visualize

With the Plots backend:

```julia
plt = plot_scene(env, vehicle)               # static scene
plot_path!(plt, refined; vehicle = vehicle)  # path + start/goal footprints
savefig(plt, "scene.png")
```

With the Makie backend (`using Parking, Makie, Bonito, WGLMakie`):

```julia
fig = Figure()
ax  = Axis(fig[1, 1]; aspect = DataAspect())
plot_scene!(ax, env, vehicle)
plot_path!(ax, refined; vehicle = vehicle)
fig
```

To export an animated GIF of the vehicle following the path, use
[`animate_parking`](@ref) (Plots backend):

```julia
animate_parking(env, vehicle, refined; fps = 10, filename = "perpendicular_park.gif")
```

## 5. Verify by simulation

Wrap the path in a [`Trajectory`](@ref) and re-simulate it with the bicycle model
to check the tracking error between the plan and the real dynamics:

```julia
traj = trajectory(refined; dt = 0.5)
println("Duration: ", duration(traj), " s")

reached = simulate(vehicle, traj)   # poses actually reached by the dynamics
```

`traj(t)` samples the trajectory at any time `t` (zero-order hold), which is
handy for stepping an animation frame by frame.

## 6. (Optional) Interactive planning

For an exploratory, mouse-driven workflow, launch the [`designer`](@ref) web tool
(see [The scene planner](scene_planner.md) for details). It builds the
`Environment` for you from the drawing and animates the planned path on the
canvas.

## Result

The planned, refined trajectory for this scenario looks like this:

![Perpendicular parking](figures/perpendicular_park.gif)
