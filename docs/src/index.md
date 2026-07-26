# Parking.jl

Parking is a Julia package that simulates and plans parking maneuvers for
a kinematic bicycle-model vehicle. It provides a small, self-contained toolkit for:

- describing a vehicle, its pose and its footprint,
- building a parking-lot environment with spots and obstacles,
- checking collisions and clearances,
- planning perpendicular and parallel parking (and leaving) maneuvers with an
  A* search over motion primitives, and
- simulating and animating the resulting trajectory.

The planner searches a discrete set of motion primitives with A* over an (x, y, θ)
grid, then refines the path so the vehicle can follow it smoothly.

## Installation

Add the package from the repository:

```julia
using Pkg
Pkg.add(url = "https://github.com/henry/Parking.jl")
```

## Getting started

```julia
using Parking

# Build a simple open lot (returns the environment and a default vehicle)
env, vehicle = build_lot()

# Define the start pose at the geometric center; plan_park converts it to the
# internally used rear-axle-center pose.
start = Pose(6.0, 0.0, 0.0)

# Plan a park-in into the lot's free spot.
res = plan_park(vehicle, env, start; clearance = 0.15)
if res.status == SUCCESS
    path = res.path                       # list of rear-axle-center poses
    println("Found a path with $(length(path)) poses.")
end
```

## Contents

- **[Home](index.md)** - this page.
- **[Scene planner](scene_planner.md)** - plan by writing code or with the interactive tool.
- **[Walkthrough](walkthrough.md)** - an end-to-end example with code.
- **[Examples](examples/index.md)** - runnable examples.
- **[API Reference](api.md)** - the full public API.

Also available in [中文](zh/index.md).
