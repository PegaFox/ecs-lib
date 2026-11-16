const std = @import("std");

const ECS = @import("root.zig");

test "initialize entity"
{
  const gpa = std.testing.allocator;

  var ecs = ECS.init(gpa);
  defer ecs.deinit();
  
  const entity = try ecs.addEntity(.{
    .position = @Vector(2, f32){0.5, 0.5},
    .velocity = @Vector(2, f32){0, 0}
  });

  try std.testing.expectEqual(
    entity.get("position", @Vector(2, f32)),
    @Vector(2, f32){0.5, 0.5}
  );
  try std.testing.expectEqual(
    entity.get("velocity", @Vector(2, f32)),
    @Vector(2, f32){0, 0}
  );
}

test "add component arrays"
{
  const gpa = std.testing.allocator;

  var ecs = ECS.init(gpa);
  defer ecs.deinit();
  
  try ecs.addArr("position", @Vector(2, f32));
  try ecs.addArr("velocity", @Vector(2, f32));

  const entity = try ecs.addEntity(.{
    .position = @Vector(2, f32){0.5, 0.5},
    .velocity = @Vector(2, f32){0, 0}
  });

  try std.testing.expectEqual(ecs.componentTable.size, 2);

  const positions = 
    ecs.getArr("position", @Vector(2, f32)) orelse
      return error.TestExpectedNonNull;

  try std.testing.expectEqualSlices(
    ECS.Entity.Unmanaged,
    positions.entities,
    &.{entity.id}
  );
  try std.testing.expectEqualSlices(
    @Vector(2, f32),
    positions.components,
    &.{.{0.5, 0.5}}
  );
}

test "initialize blank entity"
{
  const gpa = std.testing.allocator;

  var ecs = ECS.init(gpa);
  defer ecs.deinit();
  
  const entity = try ecs.addEntity(.{});
  try entity.add(.{.position = @Vector(2, f32){0.5, 0.5}});
  try entity.add(.{.velocity = @Vector(2, f32){0, 0}});

  try std.testing.expectEqual(
    entity.get("position", @Vector(2, f32)),
    @Vector(2, f32){0.5, 0.5}
  );
  try std.testing.expectEqual(
    entity.get("velocity", @Vector(2, f32)),
    @Vector(2, f32){0, 0}
  );
}

test "error when locked"
{
  const gpa = std.testing.allocator;

  var ecs = ECS.init(gpa);
  defer ecs.deinit();

  try ecs.addArr("position", @Vector(2, f32));
  
  // Disallow new component types from being added to the ecs
  ecs.locked = true;

  const entity = try ecs.addEntity(.{
    .position = @Vector(2, f32){0.5, 0.5},
  });

  try std.testing.expectEqual(
    entity.get("position", @Vector(2, f32)),
    @Vector(2, f32){0.5, 0.5}
  );
  try std.testing.expectError(
    ECS.Lockable.Locked,
    entity.add(.{.velocity = @Vector(2, f32){0, 0}})
  );
}

test "check entity archetype"
{
  const gpa = std.testing.allocator;

  var ecs = ECS.init(gpa);
  defer ecs.deinit();
  
  const entity = try ecs.addEntity(.{
    .position = @Vector(2, f32){0.5, 0.5},
    .velocity = @Vector(2, f32){0, 0}
  });

  try std.testing.expectEqualDeep(
    &[_][]const u8{"position", "velocity"}, entity.getCList()
  );
}

