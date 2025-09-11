const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const mainspace = @import("root.zig");

pub fn ComponentArray(comptime Type: type) type
{
  return struct
  {
    instances: std.AutoArrayHashMapUnmanaged(mainspace.Entity, Type) = .empty,
  };
}

