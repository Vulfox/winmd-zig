usingnamespace @import("../winmd.zig");

pub const Row = struct {
    const Self = @This();
    index: u32,
    table_index: TableIndex,
    file_index: u16,

    pub fn next(self: *const Self) Self {
        return Self{
            .index = self.index + 1,
            .table_index = self.table_index,
            .file_index = self.file_index,
        };
    }
};

pub const RowIterator = struct {
    file_index: u16,
    table: TableIndex,
    first: u32,
    last: u32,
    index: u32 = 0,
    pub fn next(self: *RowIterator) ?Row {
        const index = self.index + self.first;

        if (index >= self.last) return null;
        self.index += 1;
        return Row{
            .index = index,
            .table_index = self.table,
            .file_index = self.file_index,
        };
    }
};
