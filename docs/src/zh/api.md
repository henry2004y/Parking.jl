# API 参考

本页记录 `Parking` 的公开 API。下面列出的所有符号均由本包导出。

> 说明：本页函数签名为中文说明，但自动生成的详细文档（docstring）目前为英文，与代码中的注释保持一致。如需中文 docstring，需同步修改 `src/` 中的注释。

## 车辆与几何

```@docs
Vehicle
Pose
Rectangle
corners
footprint
rear_axle_pose
```

## 环境与车位

```@docs
ParkingSpot
spot_corners
Environment
inflate_rect
with_clearance
build_lot
```

## 碰撞检测

```@docs
is_collision
collision_reason
path_clear
```

## 规划

```@docs
PlanResult
step_vehicle
plan_park
plan_leave
```

规划结果通过 `PlanResult` 返回。其 `status` 字段为下列 `PlanStatus` 之一：
`SUCCESS`、`NO_PATH_FOUND`、`START_IN_COLLISION` 或 `GOAL_IN_COLLISION`。
`reason` 字段包含对结果的可读描述，例如
`"start pose is in collision (not in a valid free space)"`。

## 仿真与路径细化

```@docs
simulate
refine_path
Trajectory
duration
trajectory
```

## 可视化

```@docs
plot_scene
plot_pose!
plot_path!
animate_parking
```
