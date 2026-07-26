# Collision detection
#
# The vehicle footprint and obstacles are both convex quadrilaterals, so we use
# the Separating Axis Theorem (SAT) to test convex-polygon intersection. We also
# check whether the vehicle leaves the drivable bounds. When there are many
# obstacles, an axis-aligned bounding box (AABB) is used for broad-phase pruning.

"""
    project_poly(poly, axis)

Project the polygon vertices onto an axis, returning (min, max).
"""
function project_poly(poly, axis)
    dots = [v[1] * axis[1] + v[2] * axis[2] for v in poly]
    return minimum(dots), maximum(dots)
end

"""
    sat_collision(polyA, polyB) -> Bool

Separating Axis Theorem: if the two convex polygons have a separating axis, they
do not intersect. We test every edge normal of both polygons as a candidate
separating axis.
"""
function sat_collision(polyA, polyB)
    for poly in (polyA, polyB)
        n = length(poly)
        for i in 1:n
            a = poly[i]
            b = poly[mod1(i + 1, n)]
            axis = (a[2] - b[2], b[1] - a[1])   # edge normal
            minA, maxA = project_poly(polyA, axis)
            minB, maxB = project_poly(polyB, axis)
            if maxA < minB || maxB < minA
                return false  # found a separating axis
            end
        end
    end
    return true
end

"""
    _aabb(r::Rectangle) -> (xmin, xmax, ymin, ymax)

Return the rectangle's world-coordinate axis-aligned bounding box, used for
collision broad-phase pruning.
"""
function _aabb(r::Rectangle)
    cs = corners(r)
    xs = first.(cs); ys = last.(cs)
    return minimum(xs), maximum(xs), minimum(ys), maximum(ys)
end

"""
    _aabb_overlap(ax1, ax2, ay1, ay2, bx1, bx2, by1, by2) -> Bool

Test whether two axis-aligned bounding boxes overlap.
"""
function _aabb_overlap(ax1, ax2, ay1, ay2, bx1, bx2, by1, by2)
    return ax1 <= bx2 && ax2 >= bx1 && ay1 <= by2 && ay2 >= by1
end

"""
    is_collision(vehicle, pose, env) -> Bool

Test whether the vehicle at the given pose collides with the bounds or any
obstacle. A broad-phase prune is done first using the footprint's bounding box,
and SAT narrow-phase checks are performed only on obstacles whose boxes overlap,
which significantly speeds things up when there are many obstacles.
"""
function is_collision(vehicle::Vehicle, pose::Pose, env::Environment)
    fp = footprint(vehicle, pose)
    b = env.bounds
    xmin, xmax = b.cx - b.L / 2, b.cx + b.L / 2
    ymin, ymax = b.cy - b.W / 2, b.cy + b.W / 2
    # Out-of-bounds check
    for (x, y) in fp
        if x < xmin || x > xmax || y < ymin || y > ymax
            return true
        end
    end
    # Broad phase: footprint AABB
    fp_xs = first.(fp); fp_ys = last.(fp)
    fx1, fx2 = minimum(fp_xs), maximum(fp_xs)
    fy1, fy2 = minimum(fp_ys), maximum(fp_ys)
    # SAT check against obstacles (only those whose boxes overlap)
    for o in env.obstacles
        ox1, ox2, oy1, oy2 = _aabb(o)
        _aabb_overlap(fx1, fx2, fy1, fy2, ox1, ox2, oy1, oy2) || continue
        if sat_collision(fp, corners(o))
            return true
        end
    end
    return false
end

"""
    collision_reason(vehicle, pose, env) -> Union{String, Nothing}

If the pose is in collision, return a reason string (out of bounds / overlaps
obstacle i); otherwise return `nothing`. Used by the planner to give readable
diagnostics when the start/goal is in collision.
"""
function collision_reason(vehicle::Vehicle, pose::Pose, env::Environment)
    fp = footprint(vehicle, pose)
    b = env.bounds
    xmin, xmax = b.cx - b.L / 2, b.cx + b.L / 2
    ymin, ymax = b.cy - b.W / 2, b.cy + b.W / 2
    for (x, y) in fp
        if x < xmin || x > xmax || y < ymin || y > ymax
            return "outside the drivable bounds"
        end
    end
    fp_xs = first.(fp); fp_ys = last.(fp)
    fx1, fx2 = minimum(fp_xs), maximum(fp_xs)
    fy1, fy2 = minimum(fp_ys), maximum(fp_ys)
    for (i, o) in enumerate(env.obstacles)
        ox1, ox2, oy1, oy2 = _aabb(o)
        _aabb_overlap(fx1, fx2, fy1, fy2, ox1, ox2, oy1, oy2) || continue
        if sat_collision(fp, corners(o))
            return "overlaps obstacle $i"
        end
    end
    return nothing
end

"""
    path_clear(vehicle, path, env) -> Bool

Check that every pose along the entire path is collision-free (used to verify results).
"""
function path_clear(vehicle::Vehicle, path, env::Environment)
    for p in path
        if is_collision(vehicle, p, env)
            return false
        end
    end
    return true
end
