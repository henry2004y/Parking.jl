# 场景规划器

Parking 提供两种把场景变成一条规划泊车动作的方式：

1. **编写代码** 调用规划 API（`plan_park` / `plan_leave`）。适合批量运行、测试，
   以及把规划嵌入更大的程序中。
2. **使用交互式设计器**（`designer`），一个由 Makie + Bonito + WGLMakie 驱动的
   Web 画布，你可以用鼠标绘制场景，然后按下 *Generate* 来规划并动画演示。

两条路径最终都会构建一个 [`Environment`](@ref)，调用规划器，并返回一个
[`PlanResult`](@ref)。

## 用代码规划

一次规划调用需要三样东西：一个 [`Vehicle`](@ref)、一个
[`Environment`](@ref)（边界、障碍、目标车位），以及一个 `start` 位形。本包中的
场景工厂会一次性帮你把三者都建好。

```julia
using Parking

# 1. 构建一个场景：一个垂直车位，两侧有停着的车、后方有墙。
env, vehicle = perpendicular_parking()

# 2. 车道上的起始位形，使用几何中心坐标。
#    plan_park 会把它换算为内部使用的后轴中心位形。
start = Pose(-6.0, 0.5, 0.0)

# 3. 规划一次泊入。安全 clearance 会膨胀所有障碍，使路径保留余量。
res = plan_park(vehicle, env, start; clearance = 0.15)

# 4. 检查规划结果。
if res.status == SUCCESS
    println("找到一条包含 $(length(res.path)) 个位形的路径。")
else
    println("规划失败：", res.reason)
end
```

`res.status` 是 `PlanStatus` 之一：`SUCCESS`、`NO_PATH_FOUND`、
`START_IN_COLLISION` 或 `GOAL_IN_COLLISION`。失败时，`res.reason` 给出可读的原因。
规划出的路径是一串后轴中心位形（`res.path`），失败时为空。

### 驶离车位

[`plan_leave`](@ref) 把问题反过来：它规划一条把车辆 *开出* `env.spot`、
到达车道上“驶出”位形的路径。`start` 位形是车位的中心（几何坐标）。

```julia
env, vehicle = perpendicular_nose_out()
start = env.spot.center          # 车辆从车位内起步
res = plan_leave(vehicle, env, start; clearance = 0.15)
```

### 可选参数

- `clearance`（默认 `0.15` m）：添加到障碍、并从边界中减去的安全余量。
- `sample_goals = true`：在车位内采样若干候选终态位形，保留最短的成功路径，
  提升狭窄空间的鲁棒性。
- `dx`、`dy`、`dθ`：搜索网格分辨率。更细的网格能找到更多路径，但会展开更多节点。
- `refine_path(vehicle, env, res.path)`：把离散网格路径细化为分辨率更高、
  仍无碰撞的轨迹，可供控制器使用。

## 用交互式工具规划

[`designer`](@ref) 启动一个 Bonito Web 应用，由 `ParkingMakie` 扩展
提供，因此必须先加载 Makie 技术栈：

```julia
using Parking, Makie, Bonito, WGLMakie

app = designer()                 # 在 VSCode / Jupyter 中内联渲染
# Bonito.Server(app, "0.0.0.0", 8080)   # 或作为独立 Web 页面提供服务
```

在画布中你可以：

- 选择 **工具** —— *Spot*、*Start*、*Rect obstacle*、*Wall* 或 *Polygon*；
- **用鼠标绘制** —— Spot / Start / Rect / Wall 用点击-拖拽；Polygon 点击添加
  顶点，然后按 *Finish polygon*；
- 用 **滑块** 调整车位长度、宽度、角度与规划 clearance；
- 按 **Generate** 构建 `Environment`、运行 `plan_park`，并在画布上动画演示
  规划出的路径；
- 使用 **预设** 一键加载平行 / 垂直泊车场景。

一个完整、可运行的版本已随包提供：`examples/designer.jl`。

下图展示了该工具（以及代码 API）产出的规划轨迹：后轴中心路径以虚线折线绘制，
并在起始（绿色）与终点（红色）位形处画出车辆轮廓。

![规划轨迹](../figures/three_rows_park.gif)
