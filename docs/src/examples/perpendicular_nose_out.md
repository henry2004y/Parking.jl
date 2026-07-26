# Perpendicular parking (nose-out / reverse-in)

Similar to the [nose-in example](perpendicular_parking.md), but the target final
heading is `θ = -π/2`, i.e. the vehicle backs into the spot with its nose pointing
out toward the driving lane. The same constrained spot (parked neighbors + back
wall) is used, and the path is planned with [`plan_leave`](@ref).

Full source:

```julia
# Perpendicular parking, nose-out (reverse-in) example
# Plans a path for the vehicle to back into the spot with its nose pointing out.

using Parking
using Plots

# 1. Build the scenario (the target spot is the start position)
env, vehicle = perpendicular_nose_out()

# 2. Start inside the spot, aligned with the spot heading (+y)
start = env.spot.center

# 3. Plan the pull-out / reverse-in path
res = plan_leave(vehicle, env, start; clearance = 0.15)
println("Status: ", res.status)

# 4. Draw and animate
plt = plot_scene(env, vehicle)
plt = plot_path!(plt, res.path; vehicle = vehicle)
display(plt)
animate_parking(env, vehicle, res.path; fps = 10,
                filename = "perpendicular_nose_out.gif")
```

The generated animation of the planned maneuver:

![Perpendicular nose-out parking animation](../figures/perpendicular_nose_out.gif)
