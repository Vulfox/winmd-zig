//! Integration Test Suite

const std = @import("std");
const testing = std.testing;

const winmd = @import("winmd.zig");

test "TypeReader with no files" {
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

test "TypeReader with specified file" {
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

    // verify type layout, mostly mimicing what is laid out here:
    // https://github.com/microsoft/winmd-rs/blob/master/tests/stringable.rs
    const def = reader.findTypeDef("Windows.Foundation", "IStringable");
    testing.expect(def != null);
    testing.expect(std.mem.eql(u8, def.?.namespace(), "Windows.Foundation"));
    testing.expect(std.mem.eql(u8, def.?.name(), "IStringable"));
}

test "read DatabaseFile fromBytes" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked) testing.expect(false);
    }
    var allocator = &gpa.allocator;

    const foundation_winmd = "test/data/Windows.Foundation.FoundationContract.winmd";
    const foundation_file = try std.fs.cwd().readFileAlloc(allocator, foundation_winmd, std.math.maxInt(usize));
    defer allocator.free(foundation_file);

    const foundation_database_file = try winmd.DatabaseFile.fromBytes(foundation_file);
    testing.expect(foundation_database_file.blobs == 19360);
    testing.expect(foundation_database_file.strings == 14148);

    // expected table layout
    const tables = [_]winmd.TableData{
        winmd.TableData{
            .data = 11152,
            .row_count = 83,
            .row_size = 6,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 2 },
                winmd.TableColumn{ .offset = 2, .size = 2 },
                winmd.TableColumn{ .offset = 4, .size = 2 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
            },
        },
        winmd.TableData{
            .data = 11650,
            .row_count = 235,
            .row_size = 6,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 2 },
                winmd.TableColumn{ .offset = 2, .size = 2 },
                winmd.TableColumn{ .offset = 4, .size = 2 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
            },
        },
        winmd.TableData{
            .data = 2864,
            .row_count = 109,
            .row_size = 6,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 2 },
                winmd.TableColumn{ .offset = 2, .size = 2 },
                winmd.TableColumn{ .offset = 4, .size = 2 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
            },
        },
        winmd.TableData{
            .data = 13880,
            .row_count = 33,
            .row_size = 8,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 2 },
                winmd.TableColumn{ .offset = 2, .size = 2 },
                winmd.TableColumn{ .offset = 4, .size = 2 },
                winmd.TableColumn{ .offset = 6, .size = 2 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
            },
        },
        winmd.TableData{
            .data = 10784,
            .row_count = 29,
            .row_size = 4,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 2 },
                winmd.TableColumn{ .offset = 2, .size = 2 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
            },
        },
        winmd.TableData{
            .data = 10900,
            .row_count = 42,
            .row_size = 6,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 2 },
                winmd.TableColumn{ .offset = 2, .size = 2 },
                winmd.TableColumn{ .offset = 4, .size = 2 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
            },
        },
        winmd.TableData{
            .data = 3518,
            .row_count = 318,
            .row_size = 14,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 4 },
                winmd.TableColumn{ .offset = 4, .size = 2 },
                winmd.TableColumn{ .offset = 6, .size = 2 },
                winmd.TableColumn{ .offset = 8, .size = 2 },
                winmd.TableColumn{ .offset = 10, .size = 2 },
                winmd.TableColumn{ .offset = 12, .size = 2 },
            },
        },
        winmd.TableData{
            .data = 7970,
            .row_count = 469,
            .row_size = 6,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 2 },
                winmd.TableColumn{ .offset = 2, .size = 2 },
                winmd.TableColumn{ .offset = 4, .size = 2 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
            },
        },
        winmd.TableData{
            .data = 1464,
            .row_count = 100,
            .row_size = 14,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 4 },
                winmd.TableColumn{ .offset = 4, .size = 2 },
                winmd.TableColumn{ .offset = 6, .size = 2 },
                winmd.TableColumn{ .offset = 8, .size = 2 },
                winmd.TableColumn{ .offset = 10, .size = 2 },
                winmd.TableColumn{ .offset = 12, .size = 2 },
            },
        },
        winmd.TableData{
            .data = 822,
            .row_count = 107,
            .row_size = 6,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 2 },
                winmd.TableColumn{ .offset = 2, .size = 2 },
                winmd.TableColumn{ .offset = 4, .size = 2 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
            },
        },
        winmd.TableData{
            .data = 13810,
            .row_count = 14,
            .row_size = 2,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 2 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
            },
        },
        winmd.TableData{
            .data = 0,
            .row_count = 0,
            .row_size = 8,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 2 },
                winmd.TableColumn{ .offset = 2, .size = 2 },
                winmd.TableColumn{ .offset = 4, .size = 2 },
                winmd.TableColumn{ .offset = 6, .size = 2 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
            },
        },
        winmd.TableData{
            .data = 0,
            .row_count = 0,
            .row_size = 2,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 2 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
            },
        },
        winmd.TableData{
            .data = 0,
            .row_count = 0,
            .row_size = 4,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 2 },
                winmd.TableColumn{ .offset = 2, .size = 2 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
            },
        },
        winmd.TableData{
            .data = 812,
            .row_count = 1,
            .row_size = 10,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 2 },
                winmd.TableColumn{ .offset = 2, .size = 2 },
                winmd.TableColumn{ .offset = 4, .size = 2 },
                winmd.TableColumn{ .offset = 6, .size = 2 },
                winmd.TableColumn{ .offset = 8, .size = 2 },
                winmd.TableColumn{ .offset = 0, .size = 0 },
            },
        },
        winmd.TableData{
            .data = 13860,
            .row_count = 1,
            .row_size = 20,
            .columns = [6]winmd.TableColumn{
                winmd.TableColumn{ .offset = 0, .size = 8 },
                winmd.TableColumn{ .offset = 8, .size = 4 },
                winmd.TableColumn{ .offset = 12, .size = 2 },
                winmd.TableColumn{ .offset = 14, .size = 2 },
                winmd.TableColumn{ .offset = 16, .size = 2 },
                winmd.TableColumn{ .offset = 18, .size = 2 },
            },
        },
    };

    testing.expect(std.mem.eql(u8, std.mem.sliceAsBytes(foundation_database_file.tables[0..]), std.mem.sliceAsBytes(tables[0..])));
}
