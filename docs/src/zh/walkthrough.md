# 端到端流程

本页跟随一次泊车动作，从一个空脚本走到仿真、动画的结果，覆盖流水线的每个环节：
构建场景、规划、路径细化、可视化与验证。

我们将把一辆车泊入一个垂直车位，先用 Plots 后端绘图，再用 Makie 后端重复可视化。

## 1. 加载包并构建场景

```julia
using Parking
using Plots                       # Plots 后端（绘图前先加载）

env, vehicle = perpendicular_parking()
start = Pose(-6.0, 0.5, 0.0)     # 车道上的几何中心起始位形
```

`perpendicular_parking()` 返回一个 [`Environment`](@ref)（可行驶边界、两侧邻车、
后方路缘，以及空闲的目标车位）以及一个默认的 [`Vehicle`](@ref)。`start` 以几何
中心坐标给出；`plan_park` 会在内部把它换算为后轴中心参考。

## 2. 规划动作

```julia
res = plan_park(vehicle, env, start; clearance = 0.15)

res.status == SUCCESS || error("规划失败：", res.reason)
path = res.path                  # Vector{Pose}，后轴中心位形序列
```

这里发生了什么：

- 安全 `clearance` 会膨胀每个障碍（并收缩边界），使规划路径与周围保留余量。
- 若规划失败，`res.reason` 会说明原因（`START_IN_COLLISION`、
  `GOAL_IN_COLLISION` 或 `NO_PATH_FOUND`）。
- 成功时，`path` 是从起始位形到车位中心、无碰撞的位形序列。

## 3. 细化路径

A* 搜索运行在离散网格上，因此原始路径可能切角。[`refine_path`](@ref) 把它平滑为
分辨率更高、仍无碰撞的轨迹：

```julia
refined = refine_path(vehicle, env, path)
```

## 4. 可视化

使用 Plots 后端：

```julia
plt = plot_scene(env, vehicle)                # 静态场景
plot_path!(plt, refined; vehicle = vehicle)   # 路径 + 起始/终点轮廓
savefig(plt, "scene.png")
```

使用 Makie 后端（`using Parking, Makie, Bonito, WGLMakie`）：

```julia
fig = Figure()
ax  = Axis(fig[1, 1]; aspect = DataAspect())
plot_scene!(ax, env, vehicle)
plot_path!(ax, refined; vehicle = vehicle)
fig
```

要把车辆沿路径行驶的动画导出为 GIF，可使用 [`animate_parking`](@ref)
（Plots 后端）：

```julia
animate_parking(env, vehicle, refined; fps = 10, filename = "perpendicular_park.gif")
```

## 5. 通过仿真验证

把路径包成 [`Trajectory`](@ref)，并用自行车模型重新仿真，以检查规划与真实动力学
之间的跟踪误差：

```julia
traj = trajectory(refined; dt = 0.5)
println("时长：", duration(traj), " s")

reached = simulate(vehicle, traj)   # 动力学实际到达的位形
```

`traj(t)` 可在任意时刻 `t` 采样轨迹（零阶保持），便于逐帧驱动动画。

## 6. （可选）交互式规划

若想要探索式、鼠标驱动的工作流，可启动 [`designer`](@ref) Web 工具（详见
[场景规划器](scene_planner.md)）。它会根据你绘制的图形构建 `Environment`，
并在画布上动画演示规划出的路径。

## 结果

本场景规划并细化后的轨迹如下图所示：

![垂直泊车](../figures/perpendicular_park.gif)
