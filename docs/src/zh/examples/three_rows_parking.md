# 三排停车场

本示例通过 [`three_rows_parking`](@ref) 构建一个包含多排垂直车位的停车场
（含邻位与后墙），并规划一条垂直泊入某排中间唯一空车位的路径。为安全起见使用 0.15 m 的 clearance。

完整源码：

```julia
# 三排停车场示例
# 规划泊入一排车位中、被多辆邻车包围的中央空车位。

using Parking
using Plots

# 1. 构建场景（一排包含邻车的垂直车位）
env, vehicle = three_rows_parking()

# 2. 设置车道上的起始位形
start = Pose(-8.0, 0.5, 0.0)

# 3. 规划
res = plan_park(vehicle, env, start; clearance = 0.15)
println("状态：", res.status)

# 4. 绘制与动画
plt = plot_scene(env, vehicle)
plt = plot_path!(plt, res.path; vehicle = vehicle)
display(plt)
animate_parking(env, vehicle, res.path; fps = 10,
                filename = "three_rows_parking.gif")
```

规划动作的预生成动画如下：

![三排停车场动画](../figures/three_rows_park.gif)
