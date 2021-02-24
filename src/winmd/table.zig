//! Holds all table related structs/enums that are used by winmd
usingnamespace @import("../winmd.zig");

/// Contains the offset and size of a table's column
pub const TableColumn = struct {
    offset: u32 = 0,
    size: u32 = 0,
};

/// Holds info of a table's set of columns, row count, and size
pub const TableData = struct {
    const Self = @This();

    columns: [6]TableColumn = undefined,
    data: u32 = 0,
    row_count: u32 = 0,
    row_size: u32 = 0,

    pub fn indexSize(self: *Self) u32 {
        if (self.row_count < (1 << 16)) return 2;
        return 4;
    }

    pub fn setColumns(self: *Self, a: u32, b: u32, c: u32, d: u32, e: u32, f: u32) void {
        self.row_size = a + b + c + d + e + f;
        self.columns[0] = TableColumn{ .offset = 0, .size = a };
        if (b != 0) {
            self.columns[1] = TableColumn{ .offset = a, .size = b };
        }
        if (c != 0) {
            self.columns[2] = TableColumn{ .offset = (a + b), .size = c };
        }
        if (d != 0) {
            self.columns[3] = TableColumn{ .offset = (a + b + c), .size = d };
        }
        if (e != 0) {
            self.columns[4] = TableColumn{ .offset = (a + b + c + d), .size = e };
        }
        if (f != 0) {
            self.columns[5] = TableColumn{ .offset = (a + b + c + d + e), .size = f };
        }
    }

    pub fn setData(self: *Self, data: *u32) void {
        if (self.row_count != 0) {
            var next = data.* + self.row_count * self.row_size;
            self.data = data.*;
            data.* = next;
        }
    }
};

/// TableIndex holds a set of table types that are expected to be gathered from reading winmd bytes within DatabaseFile
pub const TableIndex = enum(usize) {
    Constant,
    CustomAttribute,
    Field,
    GenericParam,
    InterfaceImpl,
    MemberRef,
    MethodDef,
    Param,
    TypeDef,
    TypeRef,
    TypeSpec,
    ImplMap,
    ModuleRef,
    NestedClass,
    Module,
    AssemblyRef,
};
