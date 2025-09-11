const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log;

const ComponentArray = @import("component_array.zig").ComponentArray;

const mainspace = @import("main.zig");

componentArray: *anyopaque,
deinit: *const fn (ptr: *anyopaque, allocator: Allocator) void,
//getType: *fn () type,
setAtID: *const fn (ptr: *anyopaque, allocator: Allocator, id: mainspace.Entity, value: *const anyopaque) void,

pub fn init(comptime Type: type, allocator: Allocator) !Self
{
  const componentPos = try allocator.create(ComponentArray(Type));

  componentPos.* = ComponentArray(Type){};

  return
  .{
    .componentArray = componentPos,

    .deinit = struct
    {
      fn deinit(ptr: *anyopaque, gpa: Allocator) void
      {
        const componentArray: *ComponentArray(Type) = @ptrCast(@alignCast(ptr));

        componentArray.instances.clearAndFree(gpa);
        componentArray.instances.deinit(gpa);
      }
    }.deinit,
    //.getType = struct
    //{
    //  fn getType() type
    //  {
    //    return Type;
    //  }
    //}.getType,
    .setAtID = struct
    {
      fn setAtID(ptr: *anyopaque, gpa: Allocator, id: mainspace.Entity, value: *const anyopaque) void
      {
        const componentArray: *ComponentArray(Type) = @ptrCast(@alignCast(ptr));

        const trueValue: *const Type = @ptrCast(@alignCast(value));

        componentArray.instances.put(gpa, id, trueValue.*) catch |e|
        log.err("Failed to add component to entity {} {}", .{id, e});
      }
    }.setAtID,
  };
}


