usingnamespace @import("../winmd.zig");

pub const MethodDef = struct {
    const Self = @This();
    reader: *TypeReader,
    row: Row,

    pub fn flags(self: *const Self) MethodFlags {
        return MethodFlags{ .value = self.reader.parseU32(&self.row, 2) };
    }

    pub fn name(self: *const Self) []const u8 {
        return self.reader.parseStr(&self.row, 3);
    }
};
