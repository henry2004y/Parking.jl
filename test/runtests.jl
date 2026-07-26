using Parking
using Test

@testset "Parking" begin
    # Build a vehicle and a simple open lot
    vehicle = Vehicle(4.5, 1.8, 2.7)
    bounds = Rectangle(0.0, 0.0, 20.0, 10.0, 0.0)
    spot = ParkingSpot(Pose(0.0, 0.0, 0.0), 5.0, 2.4)
    env = Environment(bounds, Rectangle[], spot)

    @testset "footprint/mapping" begin
        # Identity when heading is 0
        fp = footprint(vehicle, Pose(0.0, 0.0, 0.0))
        @test length(fp) == 4
        # Geometric-center pose -> rear-axle-center pose
        # The rear axle is offset backward from the geometric center by (Lf - Lr)/2
        p = rear_axle_pose(vehicle, 0.0, 0.0, 0.0)
        @test p.x ≈ -(vehicle.Lf - vehicle.Lr) / 2
    end

    @testset "collision" begin
        # A pose outside the bounds should be in collision
        @test is_collision(vehicle, Pose(100.0, 0.0, 0.0), env)
        # Center of the empty lot should be collision-free
        @test !is_collision(vehicle, Pose(0.0, 0.0, 0.0), env)
    end

    @testset "step_vehicle kinematics" begin
        # Straight motion
        p0 = Pose(0.0, 0.0, 0.0)
        p1 = step_vehicle(vehicle, p0, 2.0, 0.0, 0.5)
        @test p1.x ≈ 1.0
        # Turning: heading changes (bicycle model: dθ = v·tan(δ)·dt / wheelbase)
        p2 = step_vehicle(vehicle, p0, 2.0, deg2rad(20), 0.5)
        @test p2.θ ≈ (2.0 / vehicle.wheelbase) * tan(deg2rad(20)) * 0.5
    end

    @testset "plan_park in open lot" begin
        res = plan_park(vehicle, env, Pose(6.0, 0.0, 0.0); clearance = 0.0)
        @test res.status == SUCCESS
        @test path_clear(vehicle, res.path, env)
        # Start is a geometric-center pose; internally converted to rear-axle by
        # (Lf - Lr)/2, so path[1] is shifted that amount backward along +x.
        shift = (vehicle.Lf - vehicle.Lr) / 2
        @test res.path[1].x ≈ 6.0 - shift
        # The goal is the rear-axle pose corresponding to the spot's geometric center.
        @test res.path[end].x ≈ -shift atol = 0.4
    end

    @testset "plan_park with obstacles" begin
        # Parallel-parking scenario
        env2, veh2 = parallel_parking()
        start = Pose(4.0, -1.0, 0.0)  # on the lane (below the parked-car row)
        res = plan_park(veh2, env2, start; clearance = 0.15)
        @test res.status == SUCCESS
        @test path_clear(veh2, res.path, env2)
    end

    @testset "plan_leave" begin
        env3, veh3 = perpendicular_nose_out()
        # Start inside the spot (nose along +y, aligned with the spot heading)
        start = env3.spot.center
        res = plan_leave(veh3, env3, start; clearance = 0.15)
        @test res.status == SUCCESS
    end

    @testset "trajectory" begin
        env4, veh4 = build_lot()
        res = plan_park(veh4, env4, Pose(6.0, 0.0, 0.0); clearance = 0.0)
        traj = trajectory(res.path; dt = 0.5)
        @test duration(traj) ≈ 0.5 * (length(res.path) - 1)
        # Sampling at the start
        @test traj(0.0).x ≈ res.path[1].x
    end
end
