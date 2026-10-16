const std = @import("std");

const ECS = @import("root.zig");

test "tmp"
{
  const str = comptime blk:{
    var buffer: [1024]u8 = undefined;

    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    break:blk try fba.allocator().dupe(u8, "Hi, Grace!");
  };

  _ = str;
}

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
  _ = entity;

  try std.testing.expectEqual(ecs.componentTable.size, 2);

  try std.testing.expectEqualSlices(
    @Vector(2, f32),
    ecs.getArr("position", @Vector(2, f32)) orelse
      return error.TestExpectedNonNull,
    &.{.{0.5, 0.5}}
  );
}

test "initialize blank entity"
{
  const gpa = std.testing.allocator;

  var ecs = ECS.init(gpa);
  defer ecs.deinit();
  
  const entity = try ecs.addEntity(.{});
  try entity.add("position", @Vector(2, f32){0.5, 0.5});
  try entity.add("velocity", @Vector(2, f32){0, 0});

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
    entity.add("velocity", @Vector(2, f32){0, 0})
  );
}
