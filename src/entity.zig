const ECS = @import("root.zig");

pub const Unmanaged = u16;

pub const Managed = struct
{
  const Self = @This();

  id: Unmanaged,
  parent: *ECS,

  /// Deprecated, use getPtr
  pub const getComponentPtr = getPtr; 
  /// Deprecated, use get
  pub const getComponent = get;
  /// Deprecated, use add
  pub const addComponent = add;
  
  pub fn getPtr(
    self: Self,
    comptime component: []const u8,
    comptime Type: type) ?*Type
  {
    return self.parent.getComponentPtr(self.id, component, Type);
  }
  
  pub fn get(
    self: Self,
    comptime component: []const u8,
    comptime Type: type) ?Type
  {
    return self.parent.getComponent(self.id, component, Type);
  }

  pub fn add(
    self: Self,
    comptime component: []const u8,
    value: anytype) void
  {
    self.parent.addEntityComponent(self.id, component, value);
  }
  
  pub fn give(
    self: Self,
    newOwner: Unmanaged,
    comptime component: []const u8,
    comptime Type: type) ?*Type
  {
    return self.parent.moveComponent(self.id, component, type, newOwner);
  }
};
