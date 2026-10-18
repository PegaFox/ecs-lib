const ECS = @import("root.zig");

pub const Unmanaged = u16;

pub const Managed = struct
{
  const Self = @This();

  id: Unmanaged,
  parent: *ECS,

  pub fn getPtr(
    self: Self,
    component: []const u8,
    comptime Type: type) ?*Type
  {
    return self.parent.getPtr(self.id, component, Type);
  }
  
  pub fn get(
    self: Self,
    component: []const u8,
    comptime Type: type) ?Type
  {
    return self.parent.get(self.id, component, Type);
  }

  pub fn getCList(self: Self) []const []const u8
  {
    return self.parent.getCList(self.id);
  }

  pub fn add(
    self: Self,
    components: anytype) ECS.AddError!void
  {
    try self.parent.addC(self.id, components);
  }
  
  pub fn give(
    self: Self,
    newOwner: Unmanaged,
    component: []const u8,
    comptime Type: type) ?*Type
  {
    return self.parent.moveC(self.id, component, type, newOwner);
  }
};
