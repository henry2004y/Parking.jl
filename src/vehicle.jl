# Vehicle dynamics model
#
# Convention: the reference point is the rear-axle center. The vehicle's local
# frame has its x-axis pointing forward and its y-axis pointing to the left.
# With this choice the rear-axle center follows circular arcs under the bicycle
# model, which makes kinematic integration and footprint/collision computation easy.

"""
    Pose(x, y, θ)

The vehicle configuration (pose) in the environment.
- `x`, `y`: rear-axle center coordinates
- `θ`: heading angle (radians, 0 means aligned with the +x direction)
"""
struct Pose
    x::Float64
    y::Float64
    θ::Float64
end

"""
    Vehicle(Lf, Lr, width, wheelbase, max_steer)

Vehicle geometry and constraints.
- `Lf`: distance from rear axle to front bumper
- `Lr`: distance from rear axle to rear bumper
- `width`: vehicle width
- `wheelbase`: distance between front and rear axles
- `max_steer`: maximum front-wheel steering angle (radians)
"""
struct Vehicle
    Lf::Float64
    Lr::Float64
    width::Float64
    wheelbase::Float64
    max_steer::Float64
end

"""
    Vehicle(length, width, wheelbase; max_steer=deg2rad(40))

Construct a vehicle from overall length, width, and wheelbase. The rear axle is
placed at the midpoint between the axles by default (the geometric center is
offset rearward by wheelbase/2).
"""
function Vehicle(length::Float64, width::Float64, wheelbase::Float64;
                max_steer::Float64 = deg2rad(40))
    front_axle = (length - wheelbase) / 2        # front axle to front bumper
    Lf = front_axle + wheelbase                  # rear axle to front bumper
    Lr = length - Lf                             # rear axle to rear bumper
    return Vehicle(Lf, Lr, width, wheelbase, max_steer)
end

"""
    rear_axle_pose(vehicle, x, y, θ) -> Pose

Convert a "geometric-center pose" into the internally used "rear-axle-center pose".
The reference point is the rear axle; the geometric center is offset forward along
the heading by (Lf - Lr)/2 relative to the rear axle.
"""
function rear_axle_pose(vehicle::Vehicle, x::Real, y::Real, θ::Real)
    shift = (vehicle.Lf - vehicle.Lr) / 2
    return Pose(x - shift * cos(θ), y - shift * sin(θ), θ)
end

"""
    footprint(vehicle, pose)

Return the world coordinates of the vehicle's four corners (a convex quadrilateral),
in the order: front-left, front-right, rear-right, rear-left. Used for collision
detection and drawing.
"""
function footprint(vehicle::Vehicle, pose::Pose)
    w = vehicle.width / 2
    local_pts = [(vehicle.Lf, w), (vehicle.Lf, -w),
                 (-vehicle.Lr, -w), (-vehicle.Lr, w)]
    out = Vector{Tuple{Float64,Float64}}(undef, 4)
    c = cos(pose.θ)
    s = sin(pose.θ)
    for (i, (lx, ly)) in enumerate(local_pts)
        out[i] = (pose.x + lx * c - ly * s, pose.y + lx * s + ly * c)
    end
    return out
end
