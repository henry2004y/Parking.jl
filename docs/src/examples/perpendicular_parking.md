# Perpendicular parking (nose-in)

A perpendicular (90 degree) park-in into a spot that is flanked by parked cars on
both sides and bounded by a wall behind it. The example uses
[`perpendicular_parking`](@ref) to build a single row of identical spots with the
target in the middle, defines the start pose on the driving lane, and plans with
[`plan_park`](@ref).

Full source:

```julia
# Perpendicular-parking (nose-in) example
# Plans a 90-degree park-in into a spot flanked by parked cars and a back wall.

using Parking
using Plots

# 1. Build the scenario (nose-in)
env, vehicle = perpendicular_parking(; nose_in = true)

# 2. Set the start pose on the lane
start = Pose(-6.0, 0.5, 0.0)

# 3. Plan
res = plan_park(vehicle, env, start; clearance = 0.15)
println("Status: ", res.status)

# 4. Draw and animate
plt = plot_scene(env, vehicle)
plt = plot_path!(plt, res.path; vehicle = vehicle)
display(plt)
animate_parking(env, vehicle, res.path; fps = 10,
                filename = "perpendicular_parking.gif")
```

The generated animation of the planned maneuver:

![Perpendicular nose-in parking animation](../figures/perpendicular_park.gif)
