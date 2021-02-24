//! These overrides are here until this issue is addressed: https://github.com/ziglang/zig/issues/2627
const std = @import("std");
const mem = std.mem;
const meta = std.meta;
const trait = meta.trait;
const builtin = std.builtin;

pub fn sizeOf(comptime T: type) u32 {
    return @bitSizeOf(T) / 8;
}

fn CopyPtrAttrs(comptime source: type, comptime size: builtin.TypeInfo.Pointer.Size, comptime child: type) type {
    const info = @typeInfo(source).Pointer;
    return @Type(.{
        .Pointer = .{
            .size = size,
            .is_const = info.is_const,
            .is_volatile = info.is_volatile,
            .is_allowzero = info.is_allowzero,
            .alignment = info.alignment,
            .child = child,
            .sentinel = null,
        },
    });
}

fn BytesAsSliceReturnType(comptime T: type, comptime bytesType: type) type {
    if (!(trait.isSlice(bytesType) or trait.isPtrTo(.Array)(bytesType)) or meta.Elem(bytesType) != u8) {
        @compileError("expected []u8 or *[_]u8, passed " ++ @typeName(bytesType));
    }

    if (trait.isPtrTo(.Array)(bytesType) and @typeInfo(meta.Child(bytesType)).Array.len % sizeOf(T) != 0) {
        @compileError("number of bytes in " ++ @typeName(bytesType) ++ " is not divisible by size of " ++ @typeName(T));
    }

    return CopyPtrAttrs(bytesType, .Slice, T);
}

pub fn bytesAsSlice(comptime T: type, bytes: anytype) BytesAsSliceReturnType(T, @TypeOf(bytes)) {
    // let's not give an undefined pointer to @ptrCast
    // it may be equal to zero and fail a null check
    if (bytes.len == 0) {
        return &[0]T{};
    }

    const cast_target = CopyPtrAttrs(@TypeOf(bytes), .Many, T);

    return @ptrCast(cast_target, bytes)[0..@divExact(bytes.len, sizeOf(T))];
}
