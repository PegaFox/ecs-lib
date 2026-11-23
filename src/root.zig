const Self = @This();

const std = @import("std");
const log = std.log;
const Allocator = std.mem.Allocator;

const ComponentArray = @import("component_array.zig").ComponentArray;
const ComponentArrayReference = @import("component_array_reference.zig");

const ComponentTable = std.StringHashMapUnmanaged(ComponentArrayReference);

pub const Entity = @import("entity.zig");

/// Archetypes must satisfy two requirements:
/// - An archetype must be accessible using an entity key
/// - An archetype must be accessible using an archetype key (to avoid duplicate data)
const Archetype = struct
{
  /// Archetype count is limited to entity count
  pub const Size = Entity.Unmanaged;

  startIndex: Size,
  len: Size,
};

/// If true, functions which would add a new component type return error.Locked
/// This field is intended to be accessed directly
locked: bool,

allocator: Allocator,
componentTable: ComponentTable,
/// Keys for the component table
archetypeStorage: std.ArrayList([]const u8),
/// Allows fast archetype searching
archetypes: std.array_hash_map.Custom(Archetype, void, struct
  {
    /// Backing array referred to by startIndex
    storage: []const []const u8,

    pub fn hash(self: @This(), key: Archetype) u32
    {
      const hashString = std.array_hash_map.hashString;
      const hashInts = std.array_hash_map.getAutoHashFn([2]u32, void);

      var result: u32 = 0;
      for (self.storage[key.startIndex..][0..key.len]) |str|
      {
        result = hashInts({}, .{result, hashString(str)});
      }

      return result;
    }

    pub fn eql(self: @This(), a: Archetype, b: Archetype, bIdx: usize) bool
    {
      _ = bIdx;

      if (a.len != b.len) return false;
      if (a.len == 0 or a.startIndex == b.startIndex) return true;

      for (
        self.storage[a.startIndex..][0..a.len],
        self.storage[b.startIndex..][0..b.len]
      ) |strA, strB|
      {
        if (!std.mem.eql(u8, strA, strB)) return false;
      }
      return true;
    }
  }, true
),
/// Contains indices into the archetypes map
/// Used to map entities to archetypes
/// Empty entities will not be present in the array (to preserve zero memory footprint for empty entities)
archetypeMappings: ComponentArray(Archetype.Size),

nextEntity: Entity.Unmanaged,

pub const Lockable = error{Locked};

pub fn init(allocator: Allocator) Self
{
  return .{
    .locked = false,
    .allocator = allocator,
    .componentTable = ComponentTable.empty,
    .archetypeStorage = .empty,
    .archetypes = .empty,
    .archetypeMappings = .{.instances = .empty},
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

  self.archetypeStorage.deinit(self.allocator);
  self.archetypes.deinit(self.allocator);
  self.archetypeMappings.instances.deinit(self.allocator);
}

/// Returns the number of component types
pub fn cTypes(self: *Self) usize
{
  return self.componentTable.count();
}

pub fn getPtr(
  self: *Self,
  entity: Entity.Unmanaged,
  component: []const u8,
  comptime Type: type) ?*Type
{
  const componentArray = self.getArr(component, Type) orelse return null;

  return componentArray.getPtr(entity);
}

pub fn get(
  self: *Self,
  entity: Entity.Unmanaged,
  component: []const u8,
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

/// Slice may be invalidated after adding/removing an entity's component(s)
pub fn getCList(self: Self, entity: Entity.Unmanaged) []const []const u8
{
  const archetype = self.getArchetype(entity);

  return self.archetypeStorage.items[archetype.startIndex..][0..archetype.len];
}

/// Change ownership of a component from oldOwner to newOwner
/// Returns a pointer to the component value if it exists, orelse null
pub fn moveC(
  self: *Self,
  oldOwner: Entity.Unmanaged,
  component: []const u8,
  comptime Type: type,
  newOwner: Entity.Unmanaged) ?*Type
{
  const componentArray = self.getArr(component, Type) orelse return null;

  const entry = componentArray.getEntry(oldOwner) orelse return null;
  entry.key_ptr.* = newOwner;
  componentArray.reIndex(self.allocator) catch return null;

  return entry.value_ptr;
}

/// Access the underlying storage for a component
pub fn getArr(self: *Self, component: []const u8, comptime Type: type)
  ?*std.AutoArrayHashMapUnmanaged(Entity.Unmanaged, Type)
{
  const reference = self.componentTable.get(component);
  if (reference) |ptr|
  {
    const componentArray: *ComponentArray(Type) =
      @ptrCast(@alignCast(ptr.componentArray));

    return &componentArray.instances;
  } else
  {
    return null;
  }
}

/// Only errors if self.locked == true
pub fn addArr(
  self: *Self,
  component: []const u8,
  comptime Type: type) Lockable!void
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

pub const AddError = Lockable || Allocator.Error;
/// Adds new components to entity
/// Recalculates entity's archetype
/// Components is a struct with string or integer field names
/// If a field name is a string, that name is used as the component name and the value as the component value
/// If a field name is an integer, the field value must be a tuple with the name and value of the component
pub fn addC(
  self: *Self,
  entity: Entity.Unmanaged,
  components: anytype) AddError!void
{
  const ComponentsType = @TypeOf(components);
  if (@typeInfo(ComponentsType) != .@"struct")
  {
    @compileError(
      "components expected tuple or struct type, found " ++
      @typeName(ComponentsType)
    );
  }
  const entityValuesInfo = @typeInfo(ComponentsType).@"struct";

  var newArchetype = Archetype{
    .startIndex = @intCast(self.archetypeStorage.items.len), .len = 0
  };
  inline for (entityValuesInfo.fields) |fieldInfo|
  {
    const name: []const u8, const value =
      if (comptime std.mem.findNone(u8, fieldInfo.name, "0123456789") != null)
        .{fieldInfo.name, @field(components, fieldInfo.name)}
      else .{
        @field(components, fieldInfo.name)[0],
        @field(components, fieldInfo.name)[1]
      };

    const reference: ComponentArrayReference =
      self.componentTable.get(name) orelse blk:
      {
        try self.addArr(name, @TypeOf(value));
        break :blk self.componentTable.get(name).?;
      };

    if (try reference.setAtID(
      reference.componentArray,
      self.allocator,
      entity,
      @ptrCast(&value)))
    {
      try self.archetypeStorage.append(self.allocator, name);
      newArchetype.len += 1;
    }
  }

  const oldArchetype = self.getArchetype(entity);

  // Due to how the hashing context works, we need to append to archetype storage before we copy the archetype
  // Reallocate first since we use a slice into the arraylist itself
  try self.archetypeStorage.ensureUnusedCapacity(
    self.allocator, oldArchetype.len
  );
  self.archetypeStorage.appendSliceAssumeCapacity(
    self.archetypeStorage.items[oldArchetype.startIndex..][0..oldArchetype.len]
  );
  newArchetype.len += oldArchetype.len;

  const entityArchetypeRef =
    try self.archetypeMappings.instances.getOrPut(self.allocator, entity);
  if (self.archetypes.getIndexContext(
    newArchetype,
    .{.storage = self.archetypeStorage.items})) |archetypeIndex|
  {
    self.archetypeStorage.items.len -= newArchetype.len;

    entityArchetypeRef.value_ptr.* = @intCast(archetypeIndex);
  } else
  {
    try self.archetypes.putNoClobberContext(
      self.allocator,
      newArchetype,
      {},
      .{.storage = self.archetypeStorage.items}
    );

    entityArchetypeRef.value_ptr.* = @intCast(self.archetypes.count()-1);
  }
}

/// See addC for info on components
pub fn addEntity(self: *Self, components: anytype) AddError!Entity.Managed
{
  return .{.id = try self.addEntityUnmanaged(components), .parent = self};
}

pub fn removeEntity(self: *Self, entity: Entity.Unmanaged) void
{
  const components = self.getCList(entity);

  for (components) |component|
  {
    _ = self.remove(entity, component);
  }
}

pub fn remove(self: *Self, entity: Entity.Unmanaged, component: []const u8) bool
{
  const reference = self.componentTable.get(component);
  if (reference) |ptr|
  {
    return ptr.removeAtID(ptr.componentArray, entity);
  } else
  {
    return false;
  }
}

fn getArchetype(self: Self, entity: Entity.Unmanaged) Archetype
{
  const index = self.archetypeMappings.instances.get(entity) orelse
    return Archetype{.startIndex = 0, .len = 0};

  return self.archetypes.entries.items(.key)[index];
}

/// See addC for info on components
fn addEntityUnmanaged(self: *Self, components: anytype)
  AddError!Entity.Unmanaged
{
  try self.addC(self.nextEntity, components);

  self.nextEntity +%= 1;
  return self.nextEntity-1;
}
