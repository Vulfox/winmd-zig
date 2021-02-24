//! Integration Test Suite

const std = @import("std");
const testing = std.testing;

const winmd = @import("winmd.zig");

test "init TypeReader with no files" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked) testing.expect(false); //fail test
    }

    var allocator = &gpa.allocator;
    var reader = try winmd.TypeReader.init(allocator, null);
    defer reader.deinit();

    testing.expect(reader.files.items.len == 2);
}

test "init TypeReader with specified file" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked) testing.expect(false);
    }
    var allocator = &gpa.allocator;

    const foundation_winmd = "test/data/Windows.Foundation.FoundationContract.winmd";
    const foundation_file = try std.fs.cwd().readFileAlloc(allocator, foundation_winmd, std.math.maxInt(usize));
    defer allocator.free(foundation_file);

    const files = &[_][]const u8{foundation_file};
    var reader = try winmd.TypeReader.init(allocator, files);
    defer reader.deinit();

    testing.expect(reader.files.items.len == 1);
}
