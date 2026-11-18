const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log;

const ComponentArray = @import("component_array.zig").ComponentArray;

const Entity = @import("entity.zig");

componentArray: *anyopaque,
typeID: []const u8,
deinit: *const fn (ptr: *anyopaque, allocator: Allocator) void,
typeSize: *const fn () usize,
count: *const fn (ptr: *anyopaque) usize,
/// Returns if a new element was added
setAtID: *const fn (
  ptr: *anyopaque,
  allocator: Allocator,
  id: Entity.Unmanaged,
  value: *const anyopaque) Allocator.Error!bool,
/// Swap removes element with id
/// Invalideates pointers to last array element
/// Returns if an element was removed
removeAtID: *const fn (ptr: *anyopaque, id: Entity.Unmanaged) bool,

pub fn init(comptime Type: type, allocator: Allocator) !Self
{
  const componentPos = try allocator.create(ComponentArray(Type));

  componentPos.* = ComponentArray(Type){};

  return
  .{
    .componentArray = componentPos,

    .typeID = @typeName(Type),
    .deinit = struct
    {
      fn deinit(ptr: *anyopaque, gpa: Allocator) void
      {
        const componentArray: *ComponentArray(Type) = @ptrCast(@alignCast(ptr));

        componentArray.instances.clearAndFree(gpa);
        componentArray.instances.deinit(gpa);
        gpa.destroy(componentArray);
      }
    }.deinit,
    .typeSize = struct
    {
      fn typeSize() usize
      {
        return @sizeOf(Type);
      }
    }.typeSize,
    .count = struct
    {
      fn count(ptr: *anyopaque) usize
      {
        const componentArray: *ComponentArray(Type) = @ptrCast(@alignCast(ptr));
        return componentArray.instances.count();
      }
    }.count,
    .setAtID = struct
    {
      fn setAtID(
        ptr: *anyopaque,
        gpa: Allocator,
        id: Entity.Unmanaged,
        value: *const anyopaque) Allocator.Error!bool
      {
        const componentArray: *ComponentArray(Type) = @ptrCast(@alignCast(ptr));

        const trueValue: *const Type = @ptrCast(@alignCast(value));

        if (try componentArray.instances.fetchPut(gpa, id, trueValue.*)) |_|
        {
          return false;
        }

        return true;
      }
    }.setAtID,
    .removeAtID = struct
    {
      fn removeAtID(ptr: *anyopaque, id: Entity.Unmanaged) bool
      {
        const componentArray: *ComponentArray(Type) = @ptrCast(@alignCast(ptr));

        return componentArray.instances.swapRemove(id);
      }
    }.removeAtID,
  };
}

