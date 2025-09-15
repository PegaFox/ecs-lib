const std = @import("std");

const ECS = @import("root.zig");

test "initialize entity"
{
  var gpa = std.heap.DebugAllocator(.{}).init;

  var ecs = ECS.init(gpa.allocator());
  defer ecs.deinit();
  
  const entity = ecs.addEntity(.{.position = @Vector(2, f32){0.5, 0.5}, .velocity = @Vector(2, f32){0, 0}});

  _ = ecs.getComponent(entity, "position", @Vector(2, f32)) orelse return error.TestFailure;
  _ = ecs.getComponentPtr(entity, "velocity", @Vector(2, f32)) orelse return error.TestFailure;
}

test "add component arrays"
{
  var gpa = std.heap.DebugAllocator(.{}).init;

  var ecs = ECS.init(gpa.allocator());
  defer ecs.deinit();
  
  ecs.addComponentArray("position", @Vector(2, f32));
  ecs.addComponentArray("velocity", @Vector(2, f32));

  const entity = ecs.addEntity(.{.position = @Vector(2, f32){0.5, 0.5}, .velocity = @Vector(2, f32){0, 0}});
  _ = entity;

  try std.testing.expect(ecs.componentTable.size == 2);

  _ = ecs.getComponentArray("position", @Vector(2, f32)) orelse return error.TestFailure;
}

test "initialize blank entity"
{
  var gpa = std.heap.DebugAllocator(.{}).init;

  var ecs = ECS.init(gpa.allocator());
  defer ecs.deinit();
  
  const entity = ecs.addEntity(.{});
  ecs.addEntityComponent(entity, "position", @Vector(2, f32){0.5, 0.5});
  ecs.addEntityComponent(entity, "velocity", @Vector(2, f32){0, 0});

  _ = ecs.getComponent(entity, "position", @Vector(2, f32)) orelse return error.TestFailure;
  _ = ecs.getComponentPtr(entity, "velocity", @Vector(2, f32)) orelse return error.TestFailure;
}
