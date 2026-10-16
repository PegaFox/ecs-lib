const ECS = @import("root.zig");

pub const Unmanaged = u16;

pub const Managed = struct
{
  const Self = @This();

  id: Unmanaged,
  parent: *ECS,

  pub fn getPtr(
    self: Self,
    comptime component: []const u8,
    comptime Type: type) ?*Type
  {
    return self.parent.getPtr(self.id, component, Type);
  }
  
  pub fn get(
    self: Self,
    comptime component: []const u8,
    comptime Type: type) ?Type
  {
    return self.parent.get(self.id, component, Type);
  }

  pub fn add(
    self: Self,
    comptime component: []const u8,
    value: anytype) ECS.Lockable!void
  {
    try self.parent.addC(self.id, component, value);
  }
  
  pub fn give(
    self: Self,
    newOwner: Unmanaged,
    comptime component: []const u8,
    comptime Type: type) ?*Type
  {
    return self.parent.moveC(self.id, component, type, newOwner);
  }
};
