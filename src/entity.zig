const ECS = @import("root.zig");

pub const Unmanaged = u16;

pub const Managed = struct
{
  const Self = @This();

  id: Unmanaged,
  parent: *ECS,

  pub fn getComponentPtr(
    self: Self,
    comptime component: []const u8,
    comptime Type: type) ?*Type
  {
    return self.parent.getComponentPtr(self.id, component, Type);
  }
  
  pub fn getComponent(
    self: Self,
    comptime component: []const u8,
    comptime Type: type) ?Type
  {
    return self.parent.getComponent(self.id, component, Type);
  }

  pub fn addComponent(
    self: Self,
    comptime component: []const u8,
    value: anytype) void
  {
    self.parent.addEntityComponent(self.id, component, value);
  }
};
