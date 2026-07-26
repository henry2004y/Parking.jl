# Trajectory simulation
#
# Wrap a planned path into a `Trajectory` that can be evaluated at any time, and
# provide stepwise simulation (forward integration with the bicycle model) for
# animation / control.

"""
    Trajectory(poses, dt)

A trajectory sampled at a fixed time step.
- `poses`: list of rear-axle-center poses (the path)
- `dt`: time step between adjacent poses (s)

The total duration is `dt * (length(poses) - 1)`.
"""
struct Trajectory
    poses::Vector{Pose}
    dt::Float64
end

"""
    trajectory(path; dt=0.5) -> Trajectory

Build a `Trajectory` from a planned path, with a default time step of 0.5 s.
"""
function trajectory(path::Vector{Pose}; dt::Float64 = 0.5)
    return Trajectory(path, dt)
end

"""
    duration(traj) -> Float64

Total duration of the trajectory (s).
"""
function duration(traj::Trajectory)
    return traj.dt * (length(traj.poses) - 1)
end

"""
    (traj::Trajectory)(t)

Sample the trajectory at time `t` (seconds). Uses zero-order hold (returns the
nearest sample pose); clamps `t` into [0, duration].
"""
function (traj::Trajectory)(t::Real)
    n = length(traj.poses)
    idx = clamp(round(Int, t / traj.dt) + 1, 1, n)
    return traj.poses[idx]
end

"""
    simulate(vehicle, traj; dt=traj.dt) -> Vector{Pose}

Re-simulate the trajectory with the bicycle model, returning the actually reached
poses. `dt` can differ from the trajectory's sampling step (sub-sampling), and the
result can be used to verify tracking error between the plan and the dynamics.
"""
function simulate(vehicle::Vehicle, traj::Trajectory; dt::Float64 = traj.dt)
    out = Vector{Pose}()
    push!(out, traj.poses[1])
    t = 0.0
    while t < duration(traj) - 1e-9
        i = min(round(Int, t / traj.dt) + 1, length(traj.poses))
        cur = out[end]
        nxt = traj.poses[min(i + 1, length(traj.poses))]
        # Use the arc motion primitive (matching step_vehicle) for forward simulation
        dθ = mod2pi(nxt.θ - cur.θ + π) - π   # shortest heading change
        # Estimate velocity / steering from the displacement
        v_guess = 2.0
        δ = atan(vehicle.wheelbase * dθ, max(abs(v_guess) * dt, 1e-6)) * sign(v_guess)
        next_pose = step_vehicle(vehicle, cur, v_guess, δ, dt)
        push!(out, next_pose)
        t += dt
    end
    return out
end
