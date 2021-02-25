//! A set of helper functions to help facilitate the parsing of winmd bytes
const std = @import("std");
pub const stdO = @import("std_overrides.zig");

// winmd files are little endian based
pub fn copyAs(comptime T: type, bytes: []const u8, offset: u32) T {
    return std.mem.readIntSliceLittle(T, bytes[offset .. offset + stdO.sizeOf(T)]);
}

// Can't use @bitCast due to size validation with packed structs using @sizeOf
pub fn viewAs(comptime T: type, bytes: []const u8, offset: u32) T {
    return viewAsSliceOf(T, bytes, offset, 1)[0];
}

pub fn viewAsSliceOf(comptime T: type, bytes: []const u8, offset: u32, len: u32) []const T {
    const aligned_bytes align(@alignOf(T)) = bytes[offset..(offset + stdO.sizeOf(T) * len)];
    return stdO.bytesAsSlice(T, aligned_bytes);
}

pub fn viewAsStr(bytes: []const u8, offset: u32) []const u8 {
    var buf = bytes[offset..];
    var index: usize = 0;
    for (buf) |c, i| {
        if (c == 0) {
            index = i;
            break;
        }
    }

    return bytes[offset .. offset + index];
}
