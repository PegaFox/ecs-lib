const Self = @This();

const std = @import("std");
const log = std.log;
const Allocator = std.mem.Allocator;

const ComponentArray = @import("component_array.zig").ComponentArray;
const ComponentArrayReference = @import("component_array_reference.zig");

pub const Entity = u16;

const ComponentTable = std.StringHashMapUnmanaged(ComponentArrayReference);

allocator: Allocator,
componentTable: ComponentTable,
nextEntity: Entity,

pub fn init(allocator: Allocator) Self
{
  return .{
    .allocator = allocator,
    .componentTable = ComponentTable.empty,
    .nextEntity = 0,
  };
}

pub fn deinit(self: *Self) void
{
  var iter = self.componentTable.valueIterator();
  while (iter.next()) |entry|
  {
    entry.deinit(entry.componentArray, self.allocator);
  }

  self.componentTable.deinit(self.allocator);
}

pub fn componentCount(self: *Self) usize
{
  return self.componentTable.count();
}

pub fn getComponentPtr(self: *Self, entity: Entity, comptime component: []const u8, comptime Type: type) ?*Type
{
  const reference = self.componentTable.get(component);
  if (reference) |ptr|
  {
    const componentArray: *ComponentArray(Type) = @ptrCast(@alignCast(ptr.componentArray));

    return componentArray.instances.getPtr(entity);
  } else
  {
    return null;
  }
}

pub fn getComponent(self: *Self, entity: Entity, comptime component: []const u8, comptime Type: type) ?Type
{
  const componentPtr = self.getComponentPtr(entity, component, Type);

  if (componentPtr) |ptr|
  {
    return ptr.*;
  } else
  {
    return null;
  }
}

pub fn getComponentArray(self: *Self, component: []const u8, comptime Type: type) ?[]Type
{
  const reference = self.componentTable.get(component);
  if (reference) |ptr|
  {
    const componentArray: *ComponentArray(Type) = @ptrCast(@alignCast(ptr.componentArray));

    return componentArray.instances.values();
  } else
  {
    return null;
  }
}

pub fn addComponentArray(self: *Self, component: []const u8, comptime Type: type) void
{
  self.componentTable.putNoClobber(self.allocator, component, ComponentArrayReference.init(Type, self.allocator) catch |e| {
  log.err("Failed to add component type \"{s}\" {}", .{component, e}); return;}) catch |e|
  log.err("Failed to add component type \"{s}\" {}", .{component, e});
}

pub fn addEntityComponent(self: *Self, entity: Entity, comptime component: []const u8, value: anytype) void
{
  const reference: ComponentArrayReference = self.componentTable.get(component) orelse blk: {
    self.addComponentArray(component, @TypeOf(value));
    break :blk self.componentTable.get(component).?;
  };

  reference.setAtID(reference.componentArray, self.allocator, entity, @ptrCast(&value));
}

/// components is a struct with member names for component keys and member values for component values
pub fn addEntity(self: *Self, components: anytype) Entity
{
  const ComponentsType = @TypeOf(components);
  if (@typeInfo(ComponentsType) != .@"struct") {
    @compileError("values expected tuple or struct argument, found " ++ @typeName(ComponentsType));
  }
  const entityValuesInfo = @typeInfo(ComponentsType).@"struct";

  inline for (entityValuesInfo.fields) |field|
  {
    self.addEntityComponent(self.nextEntity, field.name, field.defaultValue().?);
  }

  self.nextEntity +%= 1;
  return self.nextEntity-1;
}
