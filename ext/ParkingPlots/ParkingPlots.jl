# ParkingPlots
#
# Plots.jl backend for Parking. This extension is loaded automatically
# when Plots.jl is imported alongside Parking. It implements the
# plotting functions declared in `src/plot_api.jl`.

module ParkingPlots

using Parking
using Plots

import Parking: plot_scene, plot_pose!, plot_path!, animate_parking

"""
    plot_scene(env, vehicle; title="Parking Scene", show_spot=true, show_neighbors=true)

Draw the static scene: the lot bounds, obstacles, the target spot, and the
neighbor spots (for drawing only). Returns a `Plots.Plot`.
"""
function plot_scene(env::Environment, vehicle::Vehicle;
                    title::String = "Parking Scene",
                    show_spot::Bool = true,
                    show_neighbors::Bool = true)
    plt = plot(aspect_ratio = :equal, legend = :topright,
               xlabel = "x (m)", ylabel = "y (m)", title = title,
               grid = true, size = (720, 480))

    # Drivable bounds
    _plot_rect!(plt, env.bounds; fillcolor = :white, linecolor = :black,
                lw = 2, label = "Drivable area")

    # Obstacles (parked cars, curb, etc.)
    for o in env.obstacles
        _plot_rect!(plt, o; fillcolor = :gray, linecolor = :black,
                    lw = 1, label = "")
    end

    # Neighbor spots (for drawing only)
    if show_neighbors
        for ns in env.neighbor_spots
            cs = spot_corners(ns)
            _plot_poly!(plt, cs; fillcolor = :lightgray, linecolor = :gray,
                        lw = 1, label = "")
        end
    end

    # Target spot
    if show_spot
        cs = spot_corners(env.spot)
        _plot_poly!(plt, cs; fillcolor = :lightgreen, linecolor = :green,
                    lw = 1.5, label = "Target spot")
    end

    return plt
end

"""
    plot_pose!(plt, vehicle, pose; color=:red, label="")

Draw the vehicle footprint at a given pose into an existing plot.
"""
function plot_pose!(plt::Plots.Plot, vehicle::Vehicle, pose::Pose;
                    color = :red, label::String = "")
    fp = footprint(vehicle, pose)
    _plot_poly!(plt, fp; fillcolor = color, linecolor = color, lw = 1, label = label)
    return plt
end

"""
    plot_path!(plt, path; vehicle = nothing, color=:blue, lw=1.5, label="Planned path")

Draw a planned path (list of poses) into an existing plot: the trajectory of the
rear-axle center is drawn as a polyline, and the vehicle outline is drawn at the
start and goal poses.
"""
function plot_path!(plt::Plots.Plot, path::Vector{Pose}; vehicle = nothing,
                    color = :blue, lw::Float64 = 1.5, label::String = "Planned path")
    if !isempty(path)
        xs = [p.x for p in path]
        ys = [p.y for p in path]
        plot!(plt, xs, ys; color = color, lw = lw, label = label,
              linestyle = :dash)
    end
    if vehicle !== nothing && !isempty(path)
        plot_pose!(plt, vehicle, path[1]; color = :green, label = "Start")
        plot_pose!(plt, vehicle, path[end]; color = :red, label = "Goal")
    end
    return plt
end

"""
    animate_parking(env, vehicle, path; fps=10, filename="parking.gif", show=true)

Animate the vehicle driving along the planned path and export a GIF. The vehicle
footprint is drawn at each frame; the static scene is the background.
"""
function animate_parking(env::Environment, vehicle::Vehicle, path::Vector{Pose};
                         fps::Int = 10, filename::String = "parking.gif", show::Bool = true)
    plt = plot_scene(env, vehicle; title = "Parking Animation")
    plt = plot_path!(plt, path; vehicle = vehicle)
    anim = @animate for p in path
        plot_pose!(plt, vehicle, p; color = :orange, label = "")
    end
    gif(anim, filename; fps = fps, show = show)
    return filename
end

# ---------------------------------------------------------------------------
# Internal drawing helpers
# ---------------------------------------------------------------------------

function _plot_rect!(plt, r::Rectangle; kwargs...)
    cs = corners(r)
    _plot_poly!(plt, cs; kwargs...)
end

function _plot_poly!(plt, poly; fillcolor = :white, linecolor = :black,
                     lw = 1, label::String = "")
    n = length(poly)
    xs = [poly[i][1] for i in 1:n]
    ys = [poly[i][2] for i in 1:n]
    push!(xs, xs[1]); push!(ys, ys[1])
    plot!(plt, xs, ys; seriestype = :shape, fillcolor = fillcolor,
          linecolor = linecolor, lw = lw, label = label, fillalpha = 0.4)
    return plt
end

export plot_scene, plot_pose!, plot_path!, animate_parking

end # module
