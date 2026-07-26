# ParkingMakie
#
# Makie (and Bonito) backend for Parking. This extension is loaded
# automatically when WGLMakie.jl is loaded alongside Parking
# (WGLMakie pulls in Makie and Bonito). It provides:
#   * static plotting helpers (plot_scene!, plot_pose!, plot_path!, makie_scene)
#   * the interactive Bonito + WGLMakie parking-scenario designer (designer)

module ParkingMakie

# ParkingMakie: Bonito + WGLMakie backend (interactive designer).
# Trigger package is WGLMakie (single-dep extension). WGLMakie brings in Makie
# and Bonito, which we alias here so the extension does not need to `using` them
# directly (a multi-dep extension trigger fails to load in Julia 1.12).
using Parking
using WGLMakie
const Makie = WGLMakie.Makie
const Bonito = WGLMakie.Bonito

import Parking: plot_scene!, plot_pose!, plot_path!, makie_scene, designer

# ===========================================================================
# Static plotting helpers (Makie)
# ===========================================================================

_rect_poly(r::Rectangle) = Point2f.(corners(r))
_spot_poly(s::ParkingSpot) = Point2f.(spot_corners(s))

function _rect_polys(os::Vector{Rectangle})
    return [_rect_poly(o) for o in os]
end

"""
    plot_scene!(ax::Axis, env::Environment, vehicle::Vehicle;
                show_spot=true, show_neighbors=true)

Draw the static scene (drivable bounds, obstacles, neighbor & target spots)
into an existing Makie `Axis`.
"""
function plot_scene!(ax::Axis, env::Environment, vehicle::Vehicle;
                     show_spot::Bool = true, show_neighbors::Bool = true)
    poly!(ax, _rect_poly(env.bounds); color = (:white, 0.0),
          strokecolor = :black, strokewidth = 2, label = "Drivable area")
    for o in env.obstacles
        poly!(ax, _rect_poly(o); color = (:gray, 0.5),
              strokecolor = :black, strokewidth = 1)
    end
    if show_neighbors
        for ns in env.neighbor_spots
            poly!(ax, _spot_poly(ns); color = (:lightgray, 0.4),
                  strokecolor = :gray, strokewidth = 1)
        end
    end
    if show_spot
        poly!(ax, _spot_poly(env.spot); color = (:green, 0.25),
              strokecolor = :green, strokewidth = 1.5, label = "Target spot")
    end
    return ax
end

"""
    plot_pose!(ax::Axis, vehicle::Vehicle, pose::Pose; color=:red, label="")

Draw the vehicle footprint at `pose` (rear-axle-center reference) into `ax`.
"""
function plot_pose!(ax::Axis, vehicle::Vehicle, pose::Pose;
                    color = :red, label::String = "")
    poly!(ax, Point2f.(footprint(vehicle, pose));
          color = (color, 0.5), strokecolor = color, strokewidth = 1,
          label = label)
    return ax
end

"""
    plot_path!(ax::Axis, path::Vector{Pose}; vehicle=nothing,
               color=:blue, lw=1.5, label="Planned path")

Draw a planned path (rear-axle-center poses) and the vehicle outline at the
start and goal poses.
"""
function plot_path!(ax::Axis, path::Vector{Pose}; vehicle = nothing,
                    color = :blue, lw::Float64 = 1.5,
                    label::String = "Planned path")
    if !isempty(path)
        xs = Float32[p.x for p in path]
        ys = Float32[p.y for p in path]
        lines!(ax, xs, ys; color = color, linewidth = lw,
               linestyle = :dash, label = label)
    end
    if vehicle !== nothing && !isempty(path)
        plot_pose!(ax, vehicle, path[1]; color = :green, label = "Start")
        plot_pose!(ax, vehicle, path[end]; color = :red, label = "Goal")
    end
    return ax
end

"""
    makie_scene(env::Environment, vehicle::Vehicle; kwargs...) -> Figure

Create a new `Makie.Figure` showing the static scene.
"""
function makie_scene(env::Environment, vehicle::Vehicle; kwargs...)
    fig = Figure()
    ax = Axis(fig[1, 1]; aspect = DataAspect(), xlabel = "x (m)",
              ylabel = "y (m)", title = "Parking Scene")
    plot_scene!(ax, env, vehicle; kwargs...)
    return fig
end

# ===========================================================================
# Interactive designer (Bonito + Makie / WGLMakie)
# ===========================================================================

"""
    designer(; vehicle=Vehicle(4.5, 1.8, 2.7),
               bounds=Rectangle(0.0, 0.0, 24.0, 12.0, 0.0)) -> Bonito.App

Build an interactive parking-scenario designer:

  * pick a tool (Spot / Start / Rect obstacle / Wall / Polygon)
  * draw on the canvas with the mouse (click-drag for Spot/Start/Rect/Wall,
    click to add polygon vertices, then "Finish polygon")
  * adjust spot dimensions and planning clearance with the sliders
  * press **Generate** to build the `Environment`, run `plan_park`, and
    animate the resulting path on the canvas
  * use the **Preset scenes** dropdown (right panel) to load a ready-made
    scenario (parallel / perpendicular / angled / empty) instantly

Requires the WGLMakie backend (imported by this extension), so the returned
`App` renders as an interactive web canvas in VSCode, Jupyter, or via
`Bonito.Server`.
"""
function designer(; vehicle::Vehicle = Vehicle(4.5, 1.8, 2.7),
                   bounds::Rectangle = Rectangle(0.0, 0.0, 24.0, 12.0, 0.0))
    # ----- state -----
    tool        = Observable("spot")
    spot        = Observable{Union{ParkingSpot,Nothing}}(nothing)
    start_pose  = Observable{Union{Pose,Nothing}}(nothing)
    obstacles   = Observable(Vector{Rectangle}())
    neighbor_spots = Observable(Vector{ParkingSpot}())
    bounds      = Observable(bounds)
    polys       = Observable(Vector{Vector{Point2f}}())
    path        = Observable(Vector{Pose}())
    anim_pose   = Observable{Union{Pose,Nothing}}(nothing)
    draft       = Observable(Vector{Point2f}())
    preview     = Observable(Point2f(NaN, NaN))
    drag_start  = Observable{Union{Point2f,Nothing}}(nothing)
    rect_prev   = Observable(Point2f[])
    wall_prev   = Observable(Point2f[])

    spot_len  = Observable(5.0)
    spot_wid  = Observable(2.4)
    spot_ang  = Observable(0.0)
    clearance = Observable(0.15)

    msg = Observable("Pick a tool, draw the scene, then press Generate.")

    fig = Figure(; backgroundcolor = :white)
    ax = Axis(fig[1, 1]; aspect = DataAspect(), xlabel = "x (m)",
              ylabel = "y (m)", title = "Parking Designer",
              backgroundcolor = :white)
    _set_limits!(b) = limits!(ax, b.cx - b.L/2, b.cx + b.L/2,
                                   b.cy - b.W/2, b.cy + b.W/2)
    _set_limits!(bounds[])
    on(bounds) do b; _set_limits!(b); end

    # remember the initial view so "Reset view" can restore it
    _reset_view!() = _set_limits!(bounds[])

    # ----- static scene (bounds, drivable area) -----
    poly!(ax, lift(_rect_poly, bounds); color = (:white, 0.0),
          strokecolor = :black, strokewidth = 2)

    # ----- observable-driven scene elements -----
    poly!(ax, lift(_rect_polys, obstacles); color = (:gray, 0.5),
          strokecolor = :black, strokewidth = 1)
    poly!(ax, lift(polys) do ps
              isempty(ps) ? Point2f[] : ps
          end; color = (:gray, 0.5), strokecolor = :black, strokewidth = 1)
    poly!(ax, lift(s -> s === nothing ? Point2f[] : _spot_poly(s), spot);
          color = (:green, 0.25), strokecolor = :green, strokewidth = 1.5)
    poly!(ax, lift(p -> p === nothing ? Point2f[]
              : Point2f.(footprint(vehicle,
                  rear_axle_pose(vehicle, p.x, p.y, p.θ))), start_pose);
          color = (:orange, 0.5), strokecolor = :orange, strokewidth = 1)

    # ----- neighbor spots (drawing only, shown for context scenes) -----
    _ns_polys(ns) = isempty(ns) ? Vector{Point2f}[] : [_spot_poly(s) for s in ns]
    poly!(ax, lift(_ns_polys, neighbor_spots);
          color = (:lightgray, 0.4), strokecolor = :gray, strokewidth = 1)

    # ----- planned path -----
    lines!(ax, lift(path) do p
               isempty(p) ? Point2f[] :
               Point2f.(Float32[pp.x for pp in p], Float32[pp.y for pp in p])
           end; color = :blue, linewidth = 1.5, linestyle = :dash)
    poly!(ax, lift(path) do p
               isempty(p) ? Point2f[] :
               Point2f.(footprint(vehicle, p[1]))
           end; color = (:green, 0.4), strokecolor = :green)
    poly!(ax, lift(path) do p
               isempty(p) ? Point2f[] :
               Point2f.(footprint(vehicle, p[end]))
           end; color = (:red, 0.4), strokecolor = :red)

    # ----- draft polygon preview -----
    lines!(ax, lift(draft, preview) do d, p
               isempty(d) && return Point2f[]
               isnan(p[1]) && return collect(d)
               return vcat(collect(d), [p])
           end; color = :black, linestyle = :dot, linewidth = 1.5)
    # ----- drag previews -----
    poly!(ax, lift(d -> isempty(d) ? Point2f[] : d, rect_prev);
          color = (:blue, 0.15), strokecolor = :blue, strokewidth = 1)
    lines!(ax, wall_prev; color = :blue, linestyle = :dash, linewidth = 1.5)

    # ----- animated vehicle marker -----
    poly!(ax, lift(p -> p === nothing ? Point2f[]
              : Point2f.(footprint(vehicle, p)), anim_pose);
          color = (:red, 0.7), strokecolor = :red, strokewidth = 1.5)

    # ----- interaction helpers -----
    _commit_rect(p1, p2) = begin
        dx = abs(p2[1] - p1[1]); dy = abs(p2[2] - p1[2])
        (dx < 0.2 && dy < 0.2) && return
        obstacles[] = vcat(obstacles[],
            [Rectangle((p1[1]+p2[1])/2, (p1[2]+p2[2])/2, dx, dy, 0.0)])
    end
    _commit_wall(p1, p2) = begin
        dx = p2[1]-p1[1]; dy = p2[2]-p1[2]; d = sqrt(dx^2 + dy^2)
        d < 0.2 && return
        ang = atan(dy, dx)
        obstacles[] = vcat(obstacles[],
            [Rectangle((p1[1]+p2[1])/2, (p1[2]+p2[2])/2, d, 0.3, ang)])
    end
    _commit_spot(p1, p2) = begin
        dx = p2[1]-p1[1]; dy = p2[2]-p1[2]; d = sqrt(dx^2 + dy^2)
        ang = d > 0.3 ? atan(dy, dx) : spot_ang[]
        L   = d > 0.3 ? d : spot_len[]
        spot[] = ParkingSpot(Pose(p1[1], p1[2], ang), L, spot_wid[])
    end
    _commit_start(p1, p2) = begin
        dx = p2[1]-p1[1]; dy = p2[2]-p1[2]; d = sqrt(dx^2 + dy^2)
        ang = d > 0.3 ? atan(dy, dx) : 0.0
        start_pose[] = Pose(p1[1], p1[2], ang)   # geometric-center pose
    end

    _finish_poly! = () -> begin
        if length(draft[]) >= 3
            polys[] = vcat(polys[], [copy(draft[])])
            draft[] = Point2f[]
            preview[] = Point2f(NaN, NaN)
            msg[] = "Polygon added ($(length(polys[])) total)."
        else
            msg[] = "Need at least 3 vertices to finish a polygon."
        end
    end

    on(events(ax).mousebutton) do event
        pos = mouseposition(ax)
        isnan(pos[1]) && return nothing
        if event.button == Mouse.left
            if event.action == Mouse.press
                if tool[] == "poly"
                    # click near the first vertex (>=3 pts) closes the polygon
                    if length(draft[]) >= 3
                        d0 = draft[][1]
                        if hypot(pos[1] - d0[1], pos[2] - d0[2]) < 0.5
                            _finish_poly!()
                            return nothing
                        end
                    end
                    draft[] = vcat(draft[], [pos])
                else
                    drag_start[] = pos
                end
            else
                ds = drag_start[]
                drag_start[] = nothing
                rect_prev[] = Point2f[]
                wall_prev[] = Point2f[]
                ds === nothing && return nothing
                if tool[] == "rect"
                    _commit_rect(ds, pos)
                elseif tool[] == "wall"
                    _commit_wall(ds, pos)
                elseif tool[] == "spot"
                    _commit_spot(ds, pos)
                elseif tool[] == "start"
                    _commit_start(ds, pos)
                end
            end
        end
        return nothing
    end

    on(events(ax).mouseposition) do pos
        isnan(pos[1]) && return nothing
        ds = drag_start[]
        if ds !== nothing
            if tool[] == "rect"
                rect_prev[] = Point2f.([(ds[1],ds[2]),(pos[1],ds[2]),
                                         (pos[1],pos[2]),(ds[1],pos[2])])
            elseif tool[] in ("wall","spot","start")
                wall_prev[] = Point2f.([ds, pos])
            end
        elseif tool[] == "poly"
            preview[] = pos
        end
        return nothing
    end

    # ----- generate -----
    function _generate!()
        if spot[] === nothing
            msg[] = "Place a parking spot first (tool: Spot)."
            return
        end
        if start_pose[] === nothing
            msg[] = "Place a start pose first (tool: Start)."
            return
        end
        env = Environment(bounds[], obstacles[], spot[])
        res = plan_park(vehicle, env, start_pose[]; clearance = clearance[])
        if res.status == SUCCESS
            path[] = res.path
            msg[] = "Plan found: $(length(res.path)) poses."
            @async begin
                for p in res.path
                    anim_pose[] = p
                    sleep(1/15)
                end
                anim_pose[] = res.path[end]
            end
        else
            path[] = Pose[]
            anim_pose[] = nothing
            msg[] = "Planning failed: $(res.reason)"
        end
    end

    # ----- preset scenes -----
    # Each entry is a (name => thunk) returning
    #   (bounds, spot, obstacles, neighbor_spots, start_pose)
    # Every scene is validated to be solvable by plan_park and uses the
    # designer's default bounds Rectangle(0, 0, 24, 12).
    _DEFAULT_BOUNDS = Rectangle(0.0, 0.0, 24.0, 12.0, 0.0)
    _NONE_NS = ParkingSpot[]
    _preset_specs = [
        "Parallel parking" => () -> (
            _DEFAULT_BOUNDS,
            ParkingSpot(Pose(0.0, 2.0, 0.0), 5.0, 2.0),
            [Rectangle(0.0, 3.4, 24.0, 0.4, 0.0),
             Rectangle( 6.0, 2.0, 4.5, 1.8, 0.0),
             Rectangle(-6.0, 2.0, 4.5, 1.8, 0.0)],
            _NONE_NS,
            Pose(-6.0, -2.0, 0.0)),
        "Perpendicular parking" => () -> (
            _DEFAULT_BOUNDS,
            ParkingSpot(Pose(0.0, 3.0, π/2), 5.0, 2.4),
            [Rectangle(-3.5, 3.0, 4.5, 1.8, π/2),
             Rectangle( 3.5, 3.0, 4.5, 1.8, π/2),
             Rectangle(0.0, 5.8, 24.0, 0.4, 0.0)],
            _NONE_NS,
            Pose(0.0, -3.0, π/2)),
        "Angled parking (45°)" => () -> (
            _DEFAULT_BOUNDS,
            ParkingSpot(Pose(0.0, 2.5, π/4), 5.0, 2.4),
            [Rectangle(-1.838, 4.338, 4.5, 1.8, π/4),
             Rectangle( 1.838, 0.662, 4.5, 1.8, π/4),
             Rectangle(0.0, 5.8, 24.0, 0.4, 0.0)],
            _NONE_NS,
            Pose(-6.0, -3.0, 0.0)),
        "Empty lot" => () -> (
            _DEFAULT_BOUNDS,
            ParkingSpot(Pose(0.0, 0.0, 0.0), 5.0, 2.0),
            Rectangle[],
            _NONE_NS,
            Pose(-8.0, 0.0, 0.0)),
    ]
    _preset_dict  = Dict(k => v for (k, v) in _preset_specs)
    _preset_names = [k for (k, _) in _preset_specs]

    _apply_preset!(name::AbstractString) = begin
        spec = _preset_dict[name]
        b, s, o, ns, st = spec()
        bounds[]        = b
        neighbor_spots[]= ns
        spot[]          = s
        obstacles[]     = o
        start_pose[]    = st
        polys[]         = Vector{Point2f}[]
        draft[]         = Point2f[]
        preview[]       = Point2f(NaN, NaN)
        path[]          = Pose[]
        anim_pose[]     = nothing
        rect_prev[]     = Point2f[]
        wall_prev[]     = Point2f[]
        drag_start[]    = nothing
        msg[]           = "Preset loaded: $name"
    end

    # ----- Bonito UI -----
    # small helpers for section headers and captions (light colors for dark mode)
    _hdr(t) = Bonito.DOM.div(t; style = Bonito.Styles(
        "font-weight" => "bold", "margin" => "0.7rem 0 0.25rem",
        "color" => "#e5e7eb", "font-size" => "0.95rem"))
    _cap(t) = Bonito.DOM.div(t; style = Bonito.Styles(
        "font-size" => "0.72rem", "color" => "#9ca3af",
        "line-height" => "1.15", "margin-bottom" => "0.15rem"))

    # a tool = a labelled button with an always-visible description
    _tool_item(label, name, desc) = begin
        b = Bonito.Button(label)
        on(b.value) do _; tool[] = name; msg[] = "Tool: $label — $desc"; end
        return Bonito.DOM.div(b, _cap(desc);
            style = Bonito.Styles("display" => "flex",
                                  "flex-direction" => "column",
                                  "gap" => "0.12rem"))
    end

    ui_spot  = _tool_item("Target spot", "spot",
        "Drag on the canvas to place the parking spot.")
    ui_start = _tool_item("Start pose", "start",
        "Drag to place the vehicle's starting position.")
    ui_rect  = _tool_item("Box obstacle", "rect",
        "Drag to draw a rectangular obstacle.")
    ui_wall  = _tool_item("Wall", "wall",
        "Drag to draw a thin wall segment.")
    ui_poly  = _tool_item("Polygon", "poly",
        "Click to drop vertices; click the first point again (or Finish) to close.")

    ui_finish = Bonito.Button("Finish polygon")
    on(ui_finish.value) do _; _finish_poly!(); end

    ui_reset_view = Bonito.Button("Reset view")
    on(ui_reset_view.value) do _; _reset_view!(); msg[] = "View reset."; end

    sl_len = Bonito.StylableSlider(3.0:0.5:8.0; value = spot_len[])
    on(sl_len.value) do v; spot_len[] = v; end
    sl_wid = Bonito.StylableSlider(1.5:0.1:3.5; value = spot_wid[])
    on(sl_wid.value) do v; spot_wid[] = v; end
    sl_ang = Bonito.StylableSlider(-180:5:180; value = 0)
    on(sl_ang.value) do v; spot_ang[] = deg2rad(v); end
    sl_clr = Bonito.StylableSlider(0.0:0.05:0.5; value = clearance[])
    on(sl_clr.value) do v; clearance[] = v; end

    # ----- preset scenes: a dropdown (distinct indigo accent) -----
    _PRESET_ACCENT = "#6366f1"
    preset_dd = Bonito.Dropdown(_preset_names; index = 1,
        style = Bonito.Styles(
            "background-color" => _PRESET_ACCENT,
            "color" => "white",
            "font-weight" => "bold",
            "width" => "100%",
            "padding" => "0.45rem",
            "border" => "none",
            "border-radius" => "6px",
            "cursor" => "pointer",
            "font-size" => "0.9rem"))
    on(preset_dd.value) do name; _apply_preset!(name); end

    ui_load = Bonito.Button("Load scene";
        style = Bonito.Styles(
            "background-color" => _PRESET_ACCENT,
            "color" => "white",
            "font-weight" => "bold",
            "width" => "100%",
            "padding" => "0.55rem",
            "border" => "none",
            "border-radius" => "6px",
            "cursor" => "pointer",
            "font-size" => "0.95rem",
            "margin-top" => "0.25rem"))
    on(ui_load.value) do _; _apply_preset!(preset_dd.value[]); end

    ui_reset = Bonito.Button("Clear scene")
    on(ui_reset.value) do _
        spot[] = nothing; start_pose[] = nothing
        obstacles[] = Rectangle[]; polys[] = Vector{Point2f}[]
        draft[] = Point2f[]; preview[] = Point2f(NaN, NaN)
        path[] = Pose[]; anim_pose[] = nothing
        rect_prev[] = Point2f[]; wall_prev[] = Point2f[]
        drag_start[] = nothing
        msg[] = "Scene cleared."
    end

    # prominent Generate button (placed below the preset panel on the right)
    ui_gen = Bonito.Button("Generate plan";
        style = Bonito.Styles(
            "background-color" => "#16a34a",
            "color" => "white",
            "font-weight" => "bold",
            "width" => "100%",
            "padding" => "0.7rem",
            "border" => "none",
            "border-radius" => "6px",
            "cursor" => "pointer",
            "font-size" => "1rem",
            "margin-top" => "0.4rem"))
    on(ui_gen.value) do _; _generate!(); end

    # start with the first preset loaded so the canvas isn't empty
    _apply_preset!(_preset_names[1])

    # ----- layout: [tools / parameters] [canvas centered] [preset scenes] -----
    left = Bonito.DOM.div(
        _hdr("Draw tools"),
        _cap("Select a tool, then draw on the canvas. " *
             "Spot / Start / Box / Wall use click-drag; " *
             "Polygon uses click-to-add-points."),
        ui_spot, ui_start, ui_rect, ui_wall, ui_poly,
        Bonito.DOM.div(ui_finish;
            style = Bonito.Styles("margin-top" => "0.3rem")),
        _hdr("View"),
        ui_reset_view,
        _hdr("Parameters"),
        Bonito.Labeled(sl_len, "Spot length (m)"),
        Bonito.Labeled(sl_wid, "Spot width (m)"),
        Bonito.Labeled(sl_ang, "Spot angle (deg)"),
        Bonito.Labeled(sl_clr, "Clearance (m)"),
        Bonito.DOM.div(Bonito.Label(msg);
            style = Bonito.Styles("color" => "#e5e7eb",
                                  "margin-top" => "0.4rem",
                                  "font-size" => "0.85rem",
                                  "min-height" => "2.4rem"));
        style = "display:flex; flex-direction:column; gap:0.3rem; " *
                "padding:0.6rem; color:#e5e7eb;")
    left_col = Bonito.DOM.div(left;
        style = "display:flex; flex-direction:column; gap:0.5rem;")

    center = Bonito.DOM.div(fig;
        style = "display:flex; align-items:center; justify-content:center; " *
                "min-width:600px; min-height:420px;")

    right = Bonito.DOM.div(
        _hdr("Preset scenes"),
        _cap("Pick a scene from the list, then press Load."),
        preset_dd,
        ui_load,
        _hdr("Scene"),
        ui_reset,
        ui_gen;
        style = "display:flex; flex-direction:column; gap:0.3rem; " *
                "padding:0.6rem; width:215px; color:#e5e7eb;")

    # ----- page title + grid -----
    title = Bonito.DOM.div("Parking Simulator";
        style = Bonito.Styles(
            "font-size" => "1.6rem",
            "font-weight" => "bold",
            "color" => "#f9fafb",
            "margin" => "0.6rem 0 0 0.6rem"))

    layout = Bonito.DOM.div(title,
        Bonito.DOM.div(left_col, center, right;
            style = "display:grid; grid-template-columns:270px 1fr 220px; " *
                    "gap:1rem; align-items:flex-start;");
        style = "display:flex; flex-direction:column; color:#e5e7eb;")

    return Bonito.App() do; return layout; end
end

export plot_scene!, makie_scene, designer, plot_pose!, plot_path!

end # module
