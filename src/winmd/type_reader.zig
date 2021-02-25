const std = @import("std");
usingnamespace @import("parse_helpers.zig");
usingnamespace @import("../winmd.zig");

const win32: []const u8 = @embedFile("../default/Windows.Win32.winmd");
const winRT: []const u8 = @embedFile("../default/Windows.WinRT.winmd");

const Allocator = std.mem.Allocator;

/// TypeRow contains the necessary info to dig into a type's particular row
/// TypeReader's primary function is to provide these rows from winmd files
const TypeRow = struct {
    type_def: TypeDef,
    method_def: ?MethodDef = null,
    field: ?Field = null,
};

/// Provided a list of winmd file bytes, the TypeReader will parse these files and attempt to provide a StringHashMap of namespaces and types
/// If a set of file bytes are not provided, TypeReader will attempt to parse the default winmd files ["Windows.Win32.winmd", "Windows.WinRT.winmd"]
///   The default files are embedded as part of this lib
pub const TypeReader = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,
    files: std.ArrayList(DatabaseFile),
    types: std.StringArrayHashMap(std.StringArrayHashMap(TypeRow)),

    /// The defacto initialization method of TypeReader.
    pub fn init(allocator: *Allocator, winmd_files_bytes: ?[][]const u8) !*Self {
        const reader = try allocator.create(Self);
        reader.* = Self{
            .allocator = allocator,
            .files = std.ArrayList(DatabaseFile).init(allocator),
            .types = std.StringArrayHashMap(std.StringArrayHashMap(TypeRow)).init(allocator),
        };
        errdefer allocator.destroy(reader);

        if (winmd_files_bytes == null) {
            try reader.files.append(try DatabaseFile.fromBytes(win32));
            try reader.files.append(try DatabaseFile.fromBytes(winRT));
        } else {
            for (winmd_files_bytes.?) |file_bytes| {
                try reader.files.append(try DatabaseFile.fromBytes(file_bytes));
            }
        }

        try reader.parseDatabases();

        return reader;
    }
    pub fn deinit(self: *Self) void {
        var namespaces = self.types.iterator();
        while (namespaces.next()) |namespace| {
            namespace.value.deinit();
        }
        self.types.deinit();
        self.files.deinit();
        self.allocator.destroy(self);
    }

    fn parseDatabases(self: *Self) !void {
        for (self.files.items) |database, index| {
            const row_count = database.tables[@enumToInt(TableIndex.TypeDef)].row_count;

            var row: u32 = 0;
            while (row < row_count) : (row += 1) {
                const def = Row{
                    .index = row,
                    .table_index = TableIndex.TypeDef,
                    .file_index = @intCast(u16, index),
                };

                const type_def = TypeDef{
                    .row = def,
                    .reader = self,
                };

                var namespace_hash = try self.types.getOrPutValue(type_def.namespace(), std.StringArrayHashMap(TypeRow).init(self.allocator));
                _ = try namespace_hash.value.getOrPutValue(type_def.name(), TypeRow{ .type_def = type_def });

                const flags = type_def.flags();
                if (flags.interface() or flags.windowsRuntime()) {
                    continue;
                }

                const extends_index = self.parseU32(&def, 3);
                if (extends_index == 0) continue;
                const extends = Row{
                    .index = (extends_index >> 2) - 1,
                    .table_index = TableIndex.TypeRef,
                    .file_index = @intCast(u16, index),
                };

                if (!std.mem.eql(u8, self.parseStr(&extends, 2), "System") or !std.mem.eql(u8, self.parseStr(&extends, 1), "Object")) {
                    continue;
                }

                // begin gathering field info
                var field_iter = self.getRowIterator(&def, TableIndex.Field, 4);
                while (field_iter.next()) |field_row| {
                    const field = Field{
                        .row = field_row,
                        .reader = self,
                    };

                    var field_name_hash = try namespace_hash.value.getOrPutValue(field.name(), TypeRow{ .type_def = type_def });
                    field_name_hash.value.field = field;
                }

                //begin gathering method info
                var method_iter = self.getRowIterator(&def, TableIndex.MethodDef, 5);
                while (method_iter.next()) |method_row| {
                    const method_def = MethodDef{
                        .row = method_row,
                        .reader = self,
                    };
                    var method_name_hash = try namespace_hash.value.getOrPutValue(method_def.name(), TypeRow{ .type_def = type_def });
                    method_name_hash.value.method_def = method_def;
                }
            }
        }
    }

    /// Read a [`u32`] value from a specific row and column
    pub fn parseU32(self: *const TypeReader, row: *const Row, column: u32) u32 {
        var file_obj = self.files.items[row.file_index];
        var table = file_obj.tables[@enumToInt(row.table_index)];
        var offset = table.data + row.index * table.row_size + table.columns[column].offset;
        return switch (table.columns[column].size) {
            1 => @intCast(u32, copyAs(u8, file_obj.bytes, offset)),
            2 => @intCast(u32, copyAs(u16, file_obj.bytes, offset)),
            4 => @intCast(u32, copyAs(u32, file_obj.bytes, offset)),
            else => {
                // Saw this in the windows-rs code. Seems weird
                return @truncate(u32, copyAs(u64, file_obj.bytes, offset));
            },
        };
    }

    /// Read a []const u8 value from a specific row and column
    pub fn parseStr(self: *const TypeReader, row: *const Row, column: u32) []const u8 {
        var file_obj = self.files.items[row.file_index];
        var offset = file_obj.strings + self.parseU32(row, column);

        return viewAsStr(file_obj.bytes, offset);
    }

    /// Returns the start of a RowIterator for a given starting row and column
    pub fn getRowIterator(self: *const TypeReader, row: *const Row, table: TableIndex, column: u32) RowIterator {
        var file_obj = self.files.items[row.file_index];
        var first = self.parseU32(row, column) - 1;

        var last: u32 = 0;
        if (row.index + 1 < file_obj.tables[@enumToInt(row.table_index)].row_count) {
            var nrow = row.next();
            last = self.parseU32(&nrow, column) - 1;
        } else {
            last = file_obj.tables[@enumToInt(table)].row_count;
        }

        return RowIterator{
            .file_index = row.file_index,
            .table = table,
            .first = first,
            .last = last,
        };
    }

    /// Tries to find a TypeDef within the known set of databases
    /// null is returned if it can't be found
    pub fn findTypeDef(self: *const TypeReader, namespace: []const u8, name: []const u8) ?TypeDef {
        var namespace_entry = self.types.getEntry(namespace);
        if (namespace_entry == null) return null;
        var name_entry = namespace_entry.?.value.getEntry(name);
        if (name_entry == null) return null;

        return name_entry.?.value.type_def;
    }
};
