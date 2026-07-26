# Plotting API (backend-agnostic)
#
# This file declares the names of the plotting / visualisation functions used by
# Parking. The actual implementations live in optional package
# extensions that are only loaded when the corresponding backend is available:
#
#   * ParkingPlots  (requires Plots.jl)
#       plot_scene, plot_pose!, plot_path!, animate_parking
#   * ParkingMakie  (requires Makie.jl + Bonito.jl + WGLMakie.jl)
#       plot_scene!, plot_pose!, plot_path!, makie_scene, designer
#
# Calling any of these without the relevant backend loaded raises a MethodError,
# which is the intended signal that you need to `using Plots` (or
# `using Makie, Bonito, WGLMakie`) first.

"""
    plot_scene(env, vehicle; kwargs...)

Render the static parking scene with Plots.jl. Provided by the
`ParkingPlots` extension (load Plots.jl first).
"""
function plot_scene end

"""
    plot_pose!(target, vehicle, pose; kwargs...)

Draw a vehicle footprint at `pose` into `target`, which is a `Plots.Plot` (Plots
backend) or a Makie `Axis` (Makie backend).
"""
function plot_pose! end

"""
    plot_path!(target, path; vehicle=nothing, kwargs...)

Draw a planned `path` (a vector of `Pose`) into `target`.
"""
function plot_path! end

"""
    animate_parking(env, vehicle, path; kwargs...)

Animate the vehicle along `path` and export a GIF. Provided by the
`ParkingPlots` extension.
"""
function animate_parking end

"""
    plot_scene!(ax, env, vehicle; kwargs...)

Render the static parking scene into an existing Makie `Axis`. Provided by the
`ParkingMakie` extension.
"""
function plot_scene! end

"""
    makie_scene(env, vehicle; kwargs...) -> Makie.Figure

Create a new `Makie.Figure` showing the static scene. Provided by the
`ParkingMakie` extension.
"""
function makie_scene end

"""
    designer(; vehicle=Vehicle(4.5, 1.8, 2.7),
               bounds=Rectangle(0.0, 0.0, 24.0, 12.0, 0.0)) -> Bonito.App

Launch the interactive Bonito + Makie parking-scenario designer (a web canvas).
Provided by the `ParkingMakie` extension.
"""
function designer end

export plot_scene, plot_pose!, plot_path!, animate_parking,
       plot_scene!, makie_scene, designer
