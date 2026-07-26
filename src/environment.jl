# Parking-lot environment
#
# The environment consists of three parts: a drivable boundary, obstacles
# (rotatable rectangles), and a parking spot. The parking spot itself is treated
# as free space; the parked cars/curbs around it are represented as obstacles.

"""
    Rectangle(cx, cy, L, W, θ)

An oriented rectangle (used for obstacles and bounds).
- `cx`, `cy`: center
- `L`: full length along the local x-axis (direction θ)
- `W`: full width along the local y-axis
- `θ`: orientation (radians)
"""
struct Rectangle
    cx::Float64
    cy::Float64
    L::Float64
    W::Float64
    θ::Float64
end

"""
    corners(r::Rectangle)

Return the world coordinates of the rectangle's four corners
(front-left, front-right, rear-right, rear-left).
"""
function corners(r::Rectangle)
    hl = r.L / 2
    hw = r.W / 2
    local_pts = [(hl, hw), (hl, -hw), (-hl, -hw), (-hl, hw)]
    out = Vector{Tuple{Float64,Float64}}(undef, 4)
    c = cos(r.θ)
    s = sin(r.θ)
    for (i, (lx, ly)) in enumerate(local_pts)
        out[i] = (r.cx + lx * c - ly * s, r.cy + lx * s + ly * c)
    end
    return out
end

"""
    ParkingSpot(center, length, width)

The target parking spot. `center` is the spot's center pose (which determines the
final position and orientation after parking); `length`/`width` are the spot's full
length and width.
"""
struct ParkingSpot
    center::Pose
    length::Float64
    width::Float64
end

"""
    spot_corners(spot::ParkingSpot)

Return the world coordinates of the parking spot's four corners.
"""
function spot_corners(spot::ParkingSpot)
    c = spot.center
    hl = spot.length / 2
    hw = spot.width / 2
    local_pts = [(hl, hw), (hl, -hw), (-hl, -hw), (-hl, hw)]
    out = Vector{Tuple{Float64,Float64}}(undef, 4)
    cc = cos(c.θ)
    s = sin(c.θ)
    for (i, (lx, ly)) in enumerate(local_pts)
        out[i] = (c.x + lx * cc - ly * s, c.y + lx * s + ly * cc)
    end
    return out
end

"""
    Environment(bounds, obstacles, spot)

The full simulation environment.
- `bounds`: axis-aligned drivable rectangle (vehicle footprint must not exceed it)
- `obstacles`: list of obstacle rectangles (parked cars, curb walls, etc.)
- `spot`: the target parking spot
"""
struct Environment
    bounds::Rectangle
    obstacles::Vector{Rectangle}
    spot::ParkingSpot
    neighbor_spots::Vector{ParkingSpot}
end

"""
    Environment(bounds, obstacles, spot, neighbor_spots=ParkingSpot[])

The full simulation environment.
- `bounds`: axis-aligned drivable rectangle (vehicle footprint must not exceed it)
- `obstacles`: list of obstacle rectangles (parked cars, curb walls, etc.)
- `spot`: the target parking spot
- `neighbor_spots`: the surrounding spots (used only for drawing, to render a
  realistic row of equally sized spots; they do not take part in collision or
  planning, and default to an empty list)

When `neighbor_spots` is omitted (the three-argument form) it is treated as an
empty list.
"""
function Environment(bounds::Rectangle, obstacles::Vector{Rectangle},
                     spot::ParkingSpot)
    return Environment(bounds, obstacles, spot, ParkingSpot[])
end

"""
    inflate_rect(r::Rectangle, d) -> Rectangle

Expand the rectangle outward by `d` meters on every side (length and width each
increase by `2d`). Used to add a collision safety margin.
"""
function inflate_rect(r::Rectangle, d::Real)
    return Rectangle(r.cx, r.cy, r.L + 2d, r.W + 2d, r.θ)
end

"""
    with_clearance(env, clearance) -> Environment

Return a "planning" environment in which all obstacles are inflated by `clearance`
and the drivable bounds are shrunk by `clearance`. Planning in this environment
keeps the vehicle away from edges and prevents scraping; drawing still uses the
original `env`.
"""
function with_clearance(env::Environment, clearance::Real)
    b = env.bounds
    shrunk = Rectangle(b.cx, b.cy,
                       max(b.L - 2clearance, 0.0),
                       max(b.W - 2clearance, 0.0),
                       b.θ)
    obstacles = [inflate_rect(o, clearance) for o in env.obstacles]
    return Environment(shrunk, obstacles, env.spot, env.neighbor_spots)
end
