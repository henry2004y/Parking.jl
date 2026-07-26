module Parking

# Core module layout
include("vehicle.jl")       # Vehicle dynamics model
include("environment.jl")   # Parking-lot environment
include("collision.jl")     # Collision detection
include("planner.jl")       # Path planning
include("scenarios.jl")     # Scenario factory
include("simulation.jl")    # Trajectory simulation
include("plot_api.jl")      # Plotting API (backend implementations live in extensions)

export Vehicle, Pose, Rectangle, ParkingSpot, Environment,
       footprint, corners, spot_corners, rear_axle_pose,
       is_collision, path_clear, collision_reason,
       inflate_rect, with_clearance, build_lot,
       parallel_parking, perpendicular_parking, perpendicular_nose_out,
       three_rows_parking,
       plan_park, plan_leave, step_vehicle,
       simulate, refine_path,
       Trajectory, trajectory, duration,
       PlanResult, PlanStatus,
       SUCCESS, NO_PATH_FOUND, START_IN_COLLISION, GOAL_IN_COLLISION

end # module
