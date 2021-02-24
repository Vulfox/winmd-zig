const std = @import("std");
usingnamespace @import("../winmd.zig");
const win32: []const u8 = @embedFile("../default/Windows.Win32.winmd");
const winRT: []const u8 = @embedFile("../default/Windows.WinRT.winmd");

const Allocator = std.mem.Allocator;

/// TypeRow contains the necessary info to dig into a type's particular row
/// TypeReader's primary function is to provide these rows from winmd files
const TypeRow = struct {};

/// Provided a list of winmd file bytes, the TypeReader will parse these files and attempt to provide a StringHashMap of namespaces and types
/// If a set of file bytes are not provided, TypeReader will attempt to parse the default winmd files ["Windows.Win32.winmd", "Windows.WinRT.winmd"]
///   The default files are embedded as part of this lib
pub const TypeReader = struct {
    files: std.ArrayList(DatabaseFile),
    types: std.StringArrayHashMap(std.StringArrayHashMap(TypeRow)),

    pub fn init(allocator: *Allocator, winmd_files_bytes: ?[][]const u8) !TypeReader {
        var reader = TypeReader{
            .files = std.ArrayList(DatabaseFile).init(allocator),
            .types = std.StringArrayHashMap(std.StringArrayHashMap(TypeRow)).init(allocator),
        };

        if (winmd_files_bytes == null) {
            //std.debug.print("alignment: {}", .{@alignOf(@TypeOf(win32))});
            try reader.files.append(DatabaseFile.fromBytes(win32));
            try reader.files.append(DatabaseFile.fromBytes(winRT));
        } else {
            for (winmd_files_bytes.?) |file_bytes| {
                try reader.files.append(DatabaseFile.fromBytes(file_bytes));
            }
        }

        reader.parseFiles();

        return reader;
    }

    fn parseFiles(self: *TypeReader) void {}

    pub fn deinit(self: *TypeReader) void {
        var namespaces = self.types.iterator();
        while (namespaces.next()) |namespace| {
            namespace.value.deinit();
        }
        self.types.deinit();
        self.files.deinit();
    }
};
