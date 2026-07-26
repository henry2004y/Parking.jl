# Interactive parking-scenario designer (Bonito + Makie / WGLMakie)
#
# Run this with the plotting backends loaded:
#
#   using Parking, Makie, Bonito, WGLMakie
#   include("examples/designer.jl")   # or just call Parking.designer()
#   app = Parking.designer()
#
# In VSCode / Jupyter the App renders inline. To serve it as a standalone web
# page, use:
#
#   Bonito.Server(app, "0.0.0.0", 8080)
#
# Usage in the canvas:
#   * Spot    : click-drag to set the parking-spot center, heading and length
#   * Start   : click-drag to set the start pose (rear-axle) and heading
#   * Rect    : click-drag to drop an axis-aligned rectangular obstacle
#   * Wall    : click-drag to drop a thin wall (oriented rectangle)
#   * Polygon : click to add vertices, then "Finish polygon"
#   * Generate: build the Environment and plan; the path animates on the canvas
#   * Presets : load a parallel / perpendicular scenario instantly

using Parking, Makie, Bonito, WGLMakie

app = Parking.designer()
app
