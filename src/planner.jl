# Path planning
#
# Planning is done with a lattice / hybrid-A* style search. The action set comes
# from sampled forward/reverse steering commands combined with the bicycle-kinematics
# model; the vehicle moves along circular arcs. The search space is an explicit
# (x, y, θ) grid; collision-free nodes are expanded with a binary-heap priority
# queue, and the path is reconstructed via a parent dictionary. Because the
# discrete grid is used, the resulting path may cut corners, so a continuous
# refinement step is run afterward.

using .Parking: Pose, Vehicle, Environment, is_collision, rear_axle_pose

# ---------------------------------------------------------------------------
# Planning status codes and result type
# ---------------------------------------------------------------------------

const SUCCESS          = :success
const NO_PATH_FOUND    = :no_path_found
const START_IN_COLLISION = :start_in_collision
const GOAL_IN_COLLISION  = :goal_in_collision

"""
    PlanStatus

Status code for a planning result (see the constants above).
"""
const PlanStatus = Symbol

"""
    PlanResult

Planning result.
- `status`: one of SUCCESS / NO_PATH_FOUND / START_IN_COLLISION / GOAL_IN_COLLISION
- `path`: list of poses from start to goal (empty if failed)
- `reason`: reason string for failure (empty if successful)
- `env_used`: the (clearance-inflated) environment actually used for planning
- `expanded`: number of nodes expanded (for diagnostics)
"""
struct PlanResult
    status::PlanStatus
    path::Vector{Pose}
    reason::String
    env_used::Environment
    expanded::Int
end

# ---------------------------------------------------------------------------
# A minimal binary-heap priority queue (min-heap on f = g + h)
# ---------------------------------------------------------------------------

mutable struct MinHeap
    keys::Vector{Float64}
    vals::Vector{Any}
end
MinHeap() = MinHeap(Float64[], Any[])

function _heap_swap!(h::MinHeap, i, j)
    h.keys[i], h.keys[j] = h.keys[j], h.keys[i]
    h.vals[i], h.vals[j] = h.vals[j], h.vals[i]
end

function _heap_up!(h::MinHeap, i)
    while i > 1
        p = i ÷ 2
        if h.keys[i] < h.keys[p]
            _heap_swap!(h, i, p)
            i = p
        else
            break
        end
    end
end

function _heap_down!(h::MinHeap, i)
    n = length(h.keys)
    while true
        l = 2i
        r = 2i + 1
        smallest = i
        if l <= n && h.keys[l] < h.keys[smallest]
            smallest = l
        end
        if r <= n && h.keys[r] < h.keys[smallest]
            smallest = r
        end
        if smallest != i
            _heap_swap!(h, i, smallest)
            i = smallest
        else
            break
        end
    end
end

function heappush!(h::MinHeap, key, val)
    push!(h.keys, key)
    push!(h.vals, val)
    _heap_up!(h, length(h.keys))
end

function heappop!(h::MinHeap)
    n = length(h.keys)
    n == 0 && error("pop from empty heap")
    top_key = h.keys[1]
    top_val = h.vals[1]
    h.keys[1] = h.keys[n]
    h.vals[1] = h.vals[n]
    pop!(h.keys); pop!(h.vals)
    if n > 1
        _heap_down!(h, 1)
    end
    return top_key, top_val
end

# ---------------------------------------------------------------------------
# Discrete grid over (x, y, θ)
# ---------------------------------------------------------------------------

"""
    grid_key(pose, dx, dy, dθ) -> Tuple{Int,Int,Int}

Quantize a continuous pose into grid indices.
"""
function grid_key(pose::Pose, dx, dy, dθ)
    ix = round(Int, pose.x / dx)
    iy = round(Int, pose.y / dy)
    # Quantize θ into [0, 2π)
    ith = round(Int, mod2pi(pose.θ) / dθ)
    return (ix, iy, ith)
end

"""
    GridSpec(dx, dy, dθ; xmin, xmax, ymin, ymax, θmax)

Define the discrete search grid range.
"""
struct GridSpec
    dx::Float64
    dy::Float64
    dθ::Float64
    xmin::Float64; xmax::Float64
    ymin::Float64; ymax::Float64
    θmax::Int
end

function GridSpec(dx, dy, dθ;
                  xmin, xmax, ymin, ymax)
    θmax = round(Int, 2π / dθ)
    return GridSpec(dx, dy, dθ, xmin, xmax, ymin, ymax, θmax)
end

function in_grid(g::GridSpec, pose::Pose)
    return g.xmin <= pose.x <= g.xmax &&
           g.ymin <= pose.y <= g.ymax
end

# ---------------------------------------------------------------------------
# Kinematic integration (bicycle model, rear-axle reference point)
# ---------------------------------------------------------------------------

"""
    step_vehicle(vehicle, pose, v, δ, dt) -> Pose

Integrate the bicycle model for a single step.
- `v`: velocity (m/s, signed: positive = forward, negative = reverse)
- `δ`: front-wheel steering angle (radians, positive = left turn)
- `dt`: time step (s)

Returns the new rear-axle-center pose. When the steering angle is nearly zero,
we fall back to straight-line motion to avoid division by zero.
"""
function step_vehicle(vehicle::Vehicle, pose::Pose, v, δ, dt)
    if abs(δ) < 1e-6
        return Pose(pose.x + v * cos(pose.θ) * dt,
                    pose.y + v * sin(pose.θ) * dt,
                    pose.θ)
    end
    L = vehicle.wheelbase
    R = L / tan(δ)                       # turning radius
    dθ = v * dt / R                      # heading change
    cx = pose.x - R * sin(pose.θ)        # center of the turning circle
    cy = pose.y + R * cos(pose.θ)
    θn = pose.θ + dθ
    xn = cx + R * sin(θn)
    yn = cy - R * cos(θn)
    return Pose(xn, yn, θn)
end

# ---------------------------------------------------------------------------
# Action set (forward/reverse + sampled steering angles)
# ---------------------------------------------------------------------------

"""
    action_set(max_steer; v=2.0, dt=0.5, n_steer=5)

Build the discrete action set. Each action is a tuple (v, δ, dt) representing a
fixed-duration arc. We sample `n_steer` steering angles in [0, max_steer] and
their negatives, combined with both forward and reverse (signed) velocities.
`dt` is the duration of one motion primitive; the arc length thus equals |v|*dt.
"""
function action_set(max_steer; v=2.0, dt=0.5, n_steer=5)
    steers = LinRange(0.0, max_steer, n_steer + 1)[2:end]  # exclude 0
    actions = Vector{Tuple{Float64,Float64,Float64}}()
    for s in steers
        for dir in (1.0, -1.0)
            push!(actions, (dir * v,  s, dt))  # forward/reverse + left turn
            push!(actions, (dir * v, -s, dt))  # forward/reverse + right turn
        end
    end
    return actions
end

# ---------------------------------------------------------------------------
# Heuristic (Euclidean distance to the goal, admissible lower bound)
# ---------------------------------------------------------------------------

function _dist(a::Pose, b::Pose)
    return sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end

function heuristic(pose::Pose, goal::Pose)
    # Lower bound on time = straight-line distance / max speed
    return _dist(pose, goal) / 2.0
end

# ---------------------------------------------------------------------------
# Core search
# ---------------------------------------------------------------------------

"""
    search!(vehicle, env, start, goal, grid, actions; max_expand=200000)

Search for a collision-free path from `start` to `goal`. Uses A* in the (x, y, θ)
discrete grid with a binary-heap open set and a parent map. Returns one of:
- `(false, :start_in_collision)` / `(false, :goal_in_collision)`
- `(true, path::Vector{Pose})` when a path is found
- `(false, :no_path_found)`
"""
function search!(vehicle::Vehicle, env::Environment, start::Pose, goal::Pose,
                 grid::GridSpec, actions;
                 max_expand::Int = 200000)
    # Check start / goal collision first
    if is_collision(vehicle, start, env)
        return (false, :start_in_collision)
    end
    if is_collision(vehicle, goal, env)
        return (false, :goal_in_collision)
    end

    start_key = grid_key(start, grid.dx, grid.dy, grid.dθ)
    goal_key  = grid_key(goal,  grid.dx, grid.dy, grid.dθ)

    open = MinHeap()
    g_score = Dict{Any,Float64}()
    f_score = Dict{Any,Float64}()
    parent  = Dict{Any,Any}()
    pose_of = Dict{Any,Pose}()

    g_score[start_key] = 0.0
    f_score[start_key] = heuristic(start, goal)
    pose_of[start_key] = start
    heappush!(open, f_score[start_key], start_key)

    expanded = 0
    while length(open.keys) > 0
        _, current = heappop!(open)
        expanded += 1
        if expanded > max_expand
            return (false, :no_path_found)
        end
        if current == goal_key
            # Reconstruct path
            path = Vector{Pose}()
            node = current
            while haskey(parent, node)
                pushfirst!(path, pose_of[node])
                node = parent[node]
            end
            pushfirst!(path, start)
            return (true, path)
        end
        g_curr = g_score[current]
        curr_pose = pose_of[current]
        for (v, δ, dt) in actions
            next = step_vehicle(vehicle, curr_pose, v, δ, dt)
            if !in_grid(grid, next)
                continue
            end
            if is_collision(vehicle, next, env)
                continue
            end
            nk = grid_key(next, grid.dx, grid.dy, grid.dθ)
            tentative = g_curr + abs(v) * dt
            if !haskey(g_score, nk) || tentative < g_score[nk]
                parent[nk] = current
                pose_of[nk] = next
                g_score[nk] = tentative
                f_score[nk] = tentative + heuristic(next, goal)
                heappush!(open, f_score[nk], nk)
            end
        end
    end
    return (false, :no_path_found)
end

# ---------------------------------------------------------------------------
# Top-level planners
# ---------------------------------------------------------------------------

"""
    plan_park(vehicle, env, start; clearance=0.15,
              dx=0.3, dy=0.3, dθ=deg2rad(15),
              v=2.0, dt=0.5, n_steer=5, max_expand=200000) -> PlanResult

Plan a path for parking the vehicle into `env.spot`, starting from `start`.
`start` is given in geometric-center coordinates and is converted to the
rear-axle-center reference internally. The goal is the center pose of the
parking spot. A safety clearance is added to all obstacles (and the bounds are
shrunk) so the planned path keeps a margin from everything around it.

Returns `PlanResult`. On success, `path` is a list of rear-axle-center poses.
On failure it reports the reason (start/goal in collision, or no path found).
"""
function plan_park(vehicle::Vehicle, env::Environment, start::Pose;
                   clearance::Float64 = 0.15,
                   dx::Float64 = 0.3, dy::Float64 = 0.3, dθ::Float64 = deg2rad(15),
                   v::Float64 = 2.0, dt::Float64 = 0.5, n_steer::Int = 5,
                   max_expand::Int = 200000)
    env_p = with_clearance(env, clearance)
    b = env_p.bounds
    grid = GridSpec(dx, dy, dθ;
                    xmin = b.cx - b.L/2, xmax = b.cx + b.L/2,
                    ymin = b.cy - b.W/2, ymax = b.cy + b.W/2)
    actions = action_set(vehicle.max_steer; v=v, dt=dt, n_steer=n_steer)

    start_r = rear_axle_pose(vehicle, start.x, start.y, start.θ)
    # spot.center is the spot's GEOMETRIC center; convert it to the rear-axle
    # reference used internally (the vehicle is asymmetric, so these differ).
    c = env_p.spot.center
    goal = rear_axle_pose(vehicle, c.x, c.y, c.θ)

    ok, res = search!(vehicle, env_p, start_r, goal, grid, actions;
                      max_expand = max_expand)
    if ok
        return PlanResult(SUCCESS, res, "", env_p, 0)
    elseif res == :start_in_collision
        return PlanResult(START_IN_COLLISION, Pose[],
                          "start pose is in collision (not in a valid free space)",
                          env_p, 0)
    elseif res == :goal_in_collision
        return PlanResult(GOAL_IN_COLLISION, Pose[],
                          "parking spot goal is in collision (spot may be blocked)",
                          env_p, 0)
    else
        return PlanResult(NO_PATH_FOUND, Pose[],
                          "no path found within the expansion limit (try loosening grid/action resolution or raising max_expand)",
                          env_p, 0)
    end
end

"""
    plan_leave(vehicle, env, start; clearance=0.15,
               dx=0.3, dy=0.3, dθ=deg2rad(15),
               v=2.0, dt=0.5, n_steer=5, max_expand=200000) -> PlanResult

Plan a path for the vehicle to leave the parking spot. `start` is the spot's
center pose (rear-axle reference) and the goal is set to a "pulled-out" free pose
in front of the spot. The rest is the same as `plan_park`.

The pull-out goal is placed `2.5 * vehicle.length` ahead along the spot's
heading, so the vehicle exits to a spot on the drive lane.
"""
function plan_leave(vehicle::Vehicle, env::Environment, start::Pose;
                    clearance::Float64 = 0.15,
                    dx::Float64 = 0.3, dy::Float64 = 0.3, dθ::Float64 = deg2rad(15),
                    v::Float64 = 2.0, dt::Float64 = 0.5, n_steer::Int = 5,
                    max_expand::Int = 200000)
    env_p = with_clearance(env, clearance)
    b = env_p.bounds
    grid = GridSpec(dx, dy, dθ;
                    xmin = b.cx - b.L/2, xmax = b.cx + b.L/2,
                    ymin = b.cy - b.W/2, ymax = b.cy + b.W/2)
    actions = action_set(vehicle.max_steer; v=v, dt=dt, n_steer=n_steer)

    start_r = rear_axle_pose(vehicle, start.x, start.y, start.θ)
    goal = Pose(start_r.x + 2.5 * vehicle.Lf * cos(start_r.θ),
                start_r.y + 2.5 * vehicle.Lf * sin(start_r.θ),
                start_r.θ)

    ok, res = search!(vehicle, env_p, start_r, goal, grid, actions;
                      max_expand = max_expand)
    if ok
        return PlanResult(SUCCESS, res, "", env_p, 0)
    elseif res == :start_in_collision
        return PlanResult(START_IN_COLLISION, Pose[],
                          "start pose is in collision", env_p, 0)
    elseif res == :goal_in_collision
        return PlanResult(GOAL_IN_COLLISION, Pose[],
                          "pull-out goal is in collision", env_p, 0)
    else
        return PlanResult(NO_PATH_FOUND, Pose[],
                          "no path found within the expansion limit", env_p, 0)
    end
end

# ---------------------------------------------------------------------------
# Path refinement (continuous optimization along the grid path)
# ---------------------------------------------------------------------------

"""
    refine_path(vehicle, env, path; n_interp=4, v=2.0, dt=0.5, n_steer=5,
                n_inner=2, n_tries=8)

Refine the discrete grid path into a smooth, collision-free, continuous path.
We walk along the path, replacing each "coarse" arc between adjacent poses with a
finer local search (finer steering/velocity/time samples), and stitch the results
into a higher-resolution trajectory. The refined path still satisfies collision
constraints (checked against the original `env`, i.e. without extra clearance).

Approach:
1. Interpolate `n_interp` intermediate poses between adjacent grid poses.
2. For each interpolated segment, search locally for a feasible finer arc
   (smaller dt and denser steering/velocity samples) and concatenate.

Returns the refined `Vector{Pose}`.
"""
function refine_path(vehicle::Vehicle, env::Environment, path::Vector{Pose};
                     n_interp::Int = 4, v::Float64 = 2.0, dt::Float64 = 0.5,
                     n_steer::Int = 5, n_inner::Int = 2, n_tries::Int = 8)
    isempty(path) && return path
    refine_actions = action_set(vehicle.max_steer;
                                v = v, dt = dt / n_inner, n_steer = n_steer * 2)

    out = Vector{Pose}()
    push!(out, path[1])

    for i in 1:length(path) - 1
        a = path[i]
        b = path[i + 1]
        # Linear interpolation between the two poses (position + heading angle)
        for k in 1:n_interp
            t = k / n_interp
            xi = a.x + (b.x - a.x) * t
            yi = a.y + (b.y - a.y) * t
            θi = a.θ + mod2pi(b.θ - a.θ + π) - π  # shortest-angle interpolation
            θi = a.θ + (mod2pi(b.θ - a.θ + π) - π) * t
            push!(out, Pose(xi, yi, θi))
        end
        # Try to locally replace the segment with a finer arc (a few attempts)
        improved = false
        best_local = Vector{Pose}()
        for _ in 1:n_tries
            # Sample a finer arc from `a` toward `b`
            local_path = Vector{Pose}()
            cur = a
            steps = n_inner * 2
            for _ in 1:steps
                act = refine_actions[rand(1:length(refine_actions))]
                nxt = step_vehicle(vehicle, cur, act[1], act[2], act[3])
                if is_collision(vehicle, nxt, env)
                    break
                end
                push!(local_path, nxt)
                cur = nxt
            end
            if !isempty(local_path) &&
               _dist(cur, b) < _dist(out[end], b) &&
               path_clear(vehicle, local_path, env)
                best_local = local_path
                improved = true
                break
            end
        end
        if improved
            append!(out, best_local)
        end
    end
    push!(out, path[end])
    return out
end
