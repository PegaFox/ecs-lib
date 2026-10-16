const Self = @This();

const std = @import("std");
const log = std.log;
const Allocator = std.mem.Allocator;

const ComponentArray = @import("component_array.zig").ComponentArray;
const ComponentArrayReference = @import("component_array_reference.zig");

const ComponentTable = std.StringHashMapUnmanaged(ComponentArrayReference);

pub const Entity = @import("entity.zig");

const Archetype = struct
{
  // TODO: this
};

/// If true, functions which would add a new component type return error.Locked
locked: bool,

allocator: Allocator,
componentTable: ComponentTable,

/// Maps archetype hashes to their source archetypes
//archetypes: std.array_hash_map.Auto(u64, Archetype),
/// Contains indices into the archetypes map
//archetypeMappings: ComponentArray(usize),

nextEntity: Entity.Unmanaged,

pub const Lockable = error{Locked};

pub fn init(allocator: Allocator) Self
{
  return .{
    .locked = false,
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

/// Returns the number of component types
pub fn cTypes(self: *Self) usize
{
  return self.componentTable.count();
}

pub fn getPtr(
  self: *Self,
  entity: Entity.Unmanaged,
  comptime component: []const u8,
  comptime Type: type) ?*Type
{
  const reference = self.componentTable.get(component);
  if (reference) |ptr|
  {
    const componentArray: *ComponentArray(Type) =
      @ptrCast(@alignCast(ptr.componentArray));

    return componentArray.instances.getPtr(entity);
  } else
  {
    return null;
  }
}

pub fn get(
  self: *Self,
  entity: Entity.Unmanaged,
  comptime component: []const u8,
  comptime Type: type) ?Type
{
  const componentPtr = self.getPtr(entity, component, Type);

  if (componentPtr) |ptr|
  {
    return ptr.*;
  } else
  {
    return null;
  }
}

/// Change ownership of a component from oldOwner to newOwner
/// Returns a pointer to the component value if it exists, orelse null
pub fn moveC(
  self: *Self,
  oldOwner: Entity.Unmanaged,
  comptime component: []const u8,
  comptime Type: type,
  newOwner: Entity.Unmanaged) ?*Type
{
  const reference = self.componentTable.get(component) orelse return null;

  const componentArray: *ComponentArray(Type) =
    @ptrCast(@alignCast(reference.componentArray));

  const entry = componentArray.instances.getEntry(oldOwner) orelse return null;
  entry.key_ptr.* = newOwner;
  componentArray.instances.reIndex() catch return null;

  return entry.value_ptr;
}

pub fn getArr(
  self: *Self, component: []const u8, comptime Type: type) ?[]Type
{
  const reference = self.componentTable.get(component);
  if (reference) |ptr|
  {
    const componentArray: *ComponentArray(Type) =
      @ptrCast(@alignCast(ptr.componentArray));

    return componentArray.instances.values();
  } else
  {
    return null;
  }
}

/// Only errors if self.locked == true
pub fn addArr(
  self: *Self, component: []const u8, comptime Type: type) Lockable!void
{
  if (self.locked)
  {
    return Lockable.Locked;
  }

  self.componentTable.putNoClobber(
    self.allocator,
    component,
    ComponentArrayReference.init(Type, self.allocator) catch |e|
    {
      log.err("Failed to add component type \"{s}\" {}", .{component, e});
      return;
    }
  ) catch |e|
    log.err("Failed to add component type \"{s}\" {}", .{component, e});
}

/// Adds a new component to entity
pub fn addC(
  self: *Self,
  entity: Entity.Unmanaged,
  comptime component: []const u8,
  value: anytype) Lockable!void
{
  const reference: ComponentArrayReference =
    self.componentTable.get(component) orelse blk:
    {
      try self.addArr(component, @TypeOf(value));
      break :blk self.componentTable.get(component).?;
    };

  reference.setAtID(
    reference.componentArray, self.allocator, entity, @ptrCast(&value)
  );
}

/// components is a struct with member names for component keys and member values for component values
pub fn addEntity(self: *Self, components: anytype) Lockable!Entity.Managed
{
  return .{.id = try self.addEntityUnmanaged(components), .parent = self};
}

/// components is a struct with member names for component keys and member values for component values
fn addEntityUnmanaged(self: *Self, components: anytype)
  Lockable!Entity.Unmanaged
{
  const ComponentsType = @TypeOf(components);
  if (@typeInfo(ComponentsType) != .@"struct")
  {
    @compileError(
      "values expected tuple or struct argument, found " ++
      @typeName(ComponentsType)
    );
  }
  const entityValuesInfo = @typeInfo(ComponentsType).@"struct";

  inline for (entityValuesInfo.fields) |field|
  {
    try self.addC(self.nextEntity, field.name, @field(components, field.name));
  }

  self.nextEntity +%= 1;
  return self.nextEntity-1;
}
