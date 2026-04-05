const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const Entity = @import("entity.zig");

pub fn ComponentArray(comptime Type: type) type
{
  return struct
  {
    instances: std.AutoArrayHashMapUnmanaged(Entity.Unmanaged, Type) = .empty,
  };
}

