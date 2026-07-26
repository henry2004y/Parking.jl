# Scenario factory
#
# Pre-built scenarios for quick testing: parallel parking, perpendicular parking,
# perpendicular parking (nose-in / nose-out), and three-row parking.

"""
    build_lot(; length=20.0, width=10.0) -> (Environment, Vehicle)

Build a simple open-lot scenario. The lot is an axis-aligned rectangle with no
obstacles; the vehicle is a typical sedan (length 4.5m, width 1.8m, wheelbase
2.7m). Mainly for verifying basic functionality.
"""
function build_lot(; length::Float64 = 20.0, width::Float64 = 10.0)
    # Lot center at origin, axis-aligned
    bounds = Rectangle(0.0, 0.0, length, width, 0.0)
    obstacles = Rectangle[]
    # Place the spot in the middle of the lot
    spot = ParkingSpot(Pose(0.0, 0.0, 0.0), 5.0, 2.4)
    env = Environment(bounds, obstacles, spot)
    vehicle = Vehicle(4.5, 1.8, 2.7)
    return env, vehicle
end

"""
    parallel_parking() -> (Environment, Vehicle)

Parallel-parking scenario. The vehicle approaches along the road (the +x
direction); the parking spot is parallel to the road. Obstacles: the curb behind
the spot and the two already-parked cars in front of and behind the spot.
"""
function parallel_parking()
    # Road along +x; the spot sits above the road (y positive)
    lane_y = 0.0
    spot_center = Pose(0.0, 1.6, 0.0)       # spot parallel to the road (heading along x)
    spot = ParkingSpot(spot_center, 5.0, 2.0)

    bounds = Rectangle(0.0, 0.5, 24.0, 8.0, 0.0)
    # Curb behind the spot (along the top)
    curb = Rectangle(0.0, 3.4, 24.0, 0.4, 0.0)
    # Parked cars in front of and behind the spot
    front_car = Rectangle(spot_center.x + 6.0, 1.6, 4.5, 1.8, 0.0)
    rear_car  = Rectangle(spot_center.x - 6.0, 1.6, 4.5, 1.8, 0.0)
    obstacles = [curb, front_car, rear_car]

    env = Environment(bounds, obstacles, spot)
    vehicle = Vehicle(4.5, 1.8, 2.7)
    return env, vehicle
end

"""
    perpendicular_parking(; nose_in=true) -> (Environment, Vehicle)

Perpendicular-parking scenario. The parking spot is perpendicular to the lane
(the spot's heading is along +y). `nose_in` controls whether the vehicle is
expected to park nose-in (front first, heading +y) or back-in (heading -y is
also acceptable; here the spot heading is fixed to +y). Obstacles: the two
neighboring cars on either side of the spot and the rear curb.
"""
function perpendicular_parking(; nose_in::Bool = true)
    # Lane along +x; the spot along the top, perpendicular to the lane (heading +y)
    spot_center = Pose(0.0, 2.0, π/2)      # spot heading along +y (perpendicular)
    spot = ParkingSpot(spot_center, 5.0, 2.4)

    bounds = Rectangle(0.0, 0.0, 24.0, 10.0, 0.0)
    # Left/right neighbor cars (perpendicular to the lane, heading +y)
    left_car  = Rectangle(-3.5, 2.0, 1.8, 4.5, π/2)
    right_car = Rectangle( 3.5, 2.0, 1.8, 4.5, π/2)
    # Rear curb
    curb = Rectangle(0.0, 4.8, 24.0, 0.4, 0.0)
    obstacles = [left_car, right_car, curb]

    env = Environment(bounds, obstacles, spot)
    vehicle = Vehicle(4.5, 1.8, 2.7)
    return env, vehicle
end

"""
    perpendicular_nose_out() -> (Environment, Vehicle)

Variant of perpendicular parking: the target spot originally holds a parked car,
and the vehicle must pull out (nose-out) then leave. Used to test the `plan_leave`
path. The spot itself is free (the originally-parked car is removed); obstacles
are the two neighbor cars and the rear curb.
"""
function perpendicular_nose_out()
    # Same geometry as perpendicular, but the spot is occupied at the start.
    # The bounds are made tall enough that plan_leave can pull the vehicle
    # forward (2.5 * Lf) out of the spot into open space without leaving the lot.
    # The spot faces -y (nose-out, toward the open aisle below), so the forward
    # pull-out moves away from the curb at +y.
    spot_center = Pose(0.0, 2.0, -π/2)
    spot = ParkingSpot(spot_center, 5.0, 2.4)

    bounds = Rectangle(0.0, 0.0, 24.0, 28.0, 0.0)
    left_car  = Rectangle(-3.5, 2.0, 1.8, 4.5, π/2)
    right_car = Rectangle( 3.5, 2.0, 1.8, 4.5, π/2)
    curb = Rectangle(0.0, 4.8, 24.0, 0.4, 0.0)
    obstacles = [left_car, right_car, curb]

    env = Environment(bounds, obstacles, spot)
    vehicle = Vehicle(4.5, 1.8, 2.7)
    return env, vehicle
end

"""
    three_rows_parking() -> (Environment, Vehicle)

Three-row parking-lot scenario. There are multiple rows of spots; here we model
one row with several parallel perpendicular spots, and add the neighbor spots
(next to and across the lane) for drawing only. The vehicle starts on the lane
and must park into the middle spot.
"""
function three_rows_parking()
    # A row of perpendicular spots along the top; spot heading along +y
    rows_y = 2.0
    spot = ParkingSpot(Pose(0.0, rows_y, π/2), 5.0, 2.4)

    # Surrounding spots (for drawing only; they do not affect collision/planning)
    neighbor_spots = ParkingSpot[
        ParkingSpot(Pose(-3.5, rows_y, π/2), 5.0, 2.4),
        ParkingSpot(Pose( 3.5, rows_y, π/2), 5.0, 2.4),
        ParkingSpot(Pose(-7.0, rows_y, π/2), 5.0, 2.4),
        ParkingSpot(Pose( 7.0, rows_y, π/2), 5.0, 2.4),
    ]

    bounds = Rectangle(0.0, 0.0, 28.0, 12.0, 0.0)
    # Neighbor cars (real obstacles). Cars are 1.8 m wide (world-x after the
    # pi/2 rotation), so L (along world-y) = 4.5 and W (along world-x) = 1.8.
    left1  = Rectangle(-3.5, rows_y, 4.5, 1.8, π/2)
    right1 = Rectangle( 3.5, rows_y, 4.5, 1.8, π/2)
    left2  = Rectangle(-7.0, rows_y, 4.5, 1.8, π/2)
    right2 = Rectangle( 7.0, rows_y, 4.5, 1.8, π/2)
    curb   = Rectangle(0.0, 4.8, 28.0, 0.4, 0.0)
    obstacles = [left1, right1, left2, right2, curb]

    env = Environment(bounds, obstacles, spot, neighbor_spots)
    vehicle = Vehicle(4.5, 1.8, 2.7)
    return env, vehicle
end
