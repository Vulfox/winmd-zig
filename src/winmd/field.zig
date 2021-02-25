usingnamespace @import("../winmd.zig");

pub const Field = struct {
    const Self = @This();
    reader: *TypeReader,
    row: Row,

    pub fn flags(self: *Self) FieldFlags {
        return FieldFlags{ .value = self.reader.parseU32(&self.row, 0) };
    }

    pub fn name(self: *const Self) []const u8 {
        return self.reader.parseStr(&self.row, 1);
    }
};
