//! This is the meta data generator for parsing winmd files
const std = @import("std");
const stdO = @import("std_overrides.zig");
usingnamespace @import("../winmd.zig");

const mem = @This();
const meta = std.meta;
const trait = meta.trait;

/// DatabaseFile is the core of how TypeReader traverses the winmd file
/// It will iterate over the bytes and store meta info about table locations as well as other meta details like strings, blobs, and guids
pub const DatabaseFile = struct {
    const Self = @This();
    bytes: []const u8,
    blobs: u32 = 0,
    guids: u32 = 0,
    strings: u32 = 0,
    tables: [16]TableData = [1]TableData{TableData{}} ** 16,

    /// This is the recommended entry point of creating a DatabaseFile
    /// fromBytes will validate the bytes passed in as a valid winmd file and parse the bytes to meta data fields
    pub fn fromBytes(bytes: []const u8) !Self {
        var self = DatabaseFile{ .bytes = bytes };

        const dos = viewAs(ImageDosHeader, self.bytes, 0);
        if (dos.signature != IMAGE_DOS_SIGNATURE) return error.InvalidDosHeader;

        const pe = viewAs(ImageNtHeader, self.bytes, dos.lfanew);
        var com_virtual_address: u32 = undefined;
        var sections: []const ImageSectionHeader = undefined;
        switch (pe.optional_header.magic) {
            MAGIC_PE32 => {
                var optional_header = pe.optional_header;
                com_virtual_address = optional_header.data_directory[IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR].virtual_address;
                const file_header = pe.file_header;
                sections = viewAsSliceOf(ImageSectionHeader, self.bytes, dos.lfanew + stdO.sizeOf(ImageNtHeader), file_header.number_of_sections);
            },
            MAGIC_PE32PLUS => {
                var pe_plus = viewAs(ImageNtHeaderPlus, self.bytes, dos.lfanew);
                com_virtual_address = pe_plus.optional_header.data_directory[IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR].virtual_address;
                const file_header = pe_plus.file_header;
                sections = viewAsSliceOf(ImageSectionHeader, self.bytes, dos.lfanew + stdO.sizeOf(ImageNtHeaderPlus), file_header.number_of_sections);
            },
            else => {
                return error.InvalidMagic;
            },
        }

        const s_rva = try sectionFromRva(sections, com_virtual_address);
        const cli = viewAs(ImageCorHeader, self.bytes, offsetFromRva(s_rva, com_virtual_address));

        if (cli.cb != stdO.sizeOf(ImageCorHeader)) {
            return error.InvalidImageCorHeader;
        }

        var cli_offset = offsetFromRva(try sectionFromRva(sections, cli.meta_data.virtual_address), cli.meta_data.virtual_address);

        if (copyAs(u32, self.bytes, cli_offset) != STORAGE_MAGIC_SIG) {
            return error.InvalidStorageMagicSig;
        }

        const version_length = copyAs(u32, self.bytes, cli_offset + 12);
        var view = cli_offset + version_length + 20;
        var tables_data = [2]u32{ 0, 0 };
        var i: u16 = 0;
        while (i < copyAs(u16, self.bytes, cli_offset + version_length + 18)) : (i += 1) {
            const stream_offset = copyAs(u32, self.bytes, view);
            const stream_size = copyAs(u32, self.bytes, view + 4);
            const stream_name = viewAsStr(self.bytes, view + 8);

            if (std.mem.eql(u8, stream_name, "#Strings")) {
                self.strings = cli_offset + stream_offset;
            } else if (std.mem.eql(u8, stream_name, "#Blob")) {
                self.blobs = cli_offset + stream_offset;
            } else if (std.mem.eql(u8, stream_name, "#GUID")) {
                self.guids = cli_offset + stream_offset;
            } else if (std.mem.eql(u8, stream_name, "#~")) {
                tables_data = [2]u32{ cli_offset + stream_offset, stream_size };
            } else if (std.mem.eql(u8, stream_name, "#US")) {} else {
                return error.InvalidStreamName;
            }

            var padding = 4 - stream_name.len % 4;
            if (padding == 0) {
                padding = 4;
            }
            view += @intCast(u32, (8 + stream_name.len + padding));
        }

        const heap_sizes = self.bytes[tables_data[0] + 6];
        const string_index_size: u32 = if ((heap_sizes & 1) == 1) 4 else 2;
        const guid_index_size: u32 = if ((heap_sizes >> 1 & 1) == 1) 4 else 2;
        const blob_index_size: u32 = if ((heap_sizes >> 2 & 1) == 1) 4 else 2;
        const valid_bits = copyAs(u64, self.bytes, tables_data[0] + 8);
        view = tables_data[0] + 24;

        // some tables are not needed for our projection, but these are still needed to help determine size offsets
        var unused_empty = TableData{};
        var unused_assembly = TableData{};
        var unused_assembly_os = TableData{};
        var unused_assembly_processor = TableData{};
        var unused_assembly_ref = TableData{};
        var unused_assembly_ref_os = TableData{};
        var unused_assembly_ref_processor = TableData{};
        var unused_class_layout = TableData{};
        var unused_decl_security = TableData{};
        var unused_event = TableData{};
        var unused_event_map = TableData{};
        var unused_exported_type = TableData{};
        var unused_field_layout = TableData{};
        var unused_field_marshal = TableData{};
        var unused_field_rva = TableData{};
        var unused_file = TableData{};
        var unused_generic_param_constraint = TableData{};
        var unused_impl_map = TableData{};
        var unused_manifest_resource = TableData{};
        var unused_method_impl = TableData{};
        var unused_method_semantics = TableData{};
        var unused_method_spec = TableData{};
        var unused_module = TableData{};
        var unused_module_ref = TableData{};
        var unused_nested_class = TableData{};
        var unused_property = TableData{};
        var unused_property_map = TableData{};
        var unused_standalone_sig = TableData{};

        i = 0;
        while (i < 64) : (i += 1) {
            if ((valid_bits >> @intCast(u6, i) & 1) == 0) {
                continue;
            }

            var row_count = copyAs(u32, self.bytes, view);
            view += 4;

            switch (i) {
                0x00 => self.tables[@enumToInt(TableIndex.Module)].row_count = row_count,
                0x01 => self.tables[@enumToInt(TableIndex.TypeRef)].row_count = row_count,
                0x02 => self.tables[@enumToInt(TableIndex.TypeDef)].row_count = row_count,
                0x04 => self.tables[@enumToInt(TableIndex.Field)].row_count = row_count,
                0x06 => self.tables[@enumToInt(TableIndex.MethodDef)].row_count = row_count,
                0x08 => self.tables[@enumToInt(TableIndex.Param)].row_count = row_count,
                0x09 => self.tables[@enumToInt(TableIndex.InterfaceImpl)].row_count = row_count,
                0x0a => self.tables[@enumToInt(TableIndex.MemberRef)].row_count = row_count,
                0x0b => self.tables[@enumToInt(TableIndex.Constant)].row_count = row_count,
                0x0c => self.tables[@enumToInt(TableIndex.CustomAttribute)].row_count = row_count,
                0x0d => unused_field_marshal.row_count = row_count,
                0x0e => unused_decl_security.row_count = row_count,
                0x0f => unused_class_layout.row_count = row_count,
                0x10 => unused_field_layout.row_count = row_count,
                0x11 => unused_standalone_sig.row_count = row_count,
                0x12 => unused_event_map.row_count = row_count,
                0x14 => unused_event.row_count = row_count,
                0x15 => unused_property_map.row_count = row_count,
                0x17 => unused_property.row_count = row_count,
                0x18 => unused_method_semantics.row_count = row_count,
                0x19 => unused_method_impl.row_count = row_count,
                0x1a => self.tables[@enumToInt(TableIndex.ModuleRef)].row_count = row_count,
                0x1b => self.tables[@enumToInt(TableIndex.TypeSpec)].row_count = row_count,
                0x1c => self.tables[@enumToInt(TableIndex.ImplMap)].row_count = row_count,
                0x1d => unused_field_rva.row_count = row_count,
                0x20 => unused_assembly.row_count = row_count,
                0x21 => unused_assembly_processor.row_count = row_count,
                0x22 => unused_assembly_os.row_count = row_count,
                0x23 => self.tables[@enumToInt(TableIndex.AssemblyRef)].row_count = row_count,
                0x24 => unused_assembly_ref_processor.row_count = row_count,
                0x25 => unused_assembly_ref_os.row_count = row_count,
                0x26 => unused_file.row_count = row_count,
                0x27 => unused_exported_type.row_count = row_count,
                0x28 => unused_manifest_resource.row_count = row_count,
                0x29 => self.tables[@enumToInt(TableIndex.NestedClass)].row_count = row_count,
                0x2a => self.tables[@enumToInt(TableIndex.GenericParam)].row_count = row_count,
                0x2b => unused_method_spec.row_count = row_count,
                0x2c => unused_generic_param_constraint.row_count = row_count,
                else => unreachable,
            }
        }

        // define table layouts
        var type_def_or_ref = compositeIndexSize(&[_]TableData{
            self.tables[@enumToInt(TableIndex.TypeDef)],
            self.tables[@enumToInt(TableIndex.TypeRef)],
            self.tables[@enumToInt(TableIndex.TypeSpec)],
        });

        var has_constant = compositeIndexSize(&[_]TableData{
            self.tables[@enumToInt(TableIndex.Field)],
            self.tables[@enumToInt(TableIndex.Param)],
            unused_property,
        });

        var has_custom_attribute = compositeIndexSize(&[_]TableData{
            self.tables[@enumToInt(TableIndex.MethodDef)],
            self.tables[@enumToInt(TableIndex.Field)],
            self.tables[@enumToInt(TableIndex.TypeRef)],
            self.tables[@enumToInt(TableIndex.TypeDef)],
            self.tables[@enumToInt(TableIndex.Param)],
            self.tables[@enumToInt(TableIndex.InterfaceImpl)],
            self.tables[@enumToInt(TableIndex.MemberRef)],
            unused_module,
            unused_property,
            unused_event,
            unused_standalone_sig,
            self.tables[@enumToInt(TableIndex.ModuleRef)],
            self.tables[@enumToInt(TableIndex.TypeSpec)],
            unused_assembly,
            self.tables[@enumToInt(TableIndex.AssemblyRef)],
            unused_file,
            unused_exported_type,
            unused_manifest_resource,
            self.tables[@enumToInt(TableIndex.GenericParam)],
            unused_generic_param_constraint,
            unused_method_spec,
        });

        var has_field_marshal = compositeIndexSize(&[_]TableData{
            self.tables[@enumToInt(TableIndex.Field)],
            self.tables[@enumToInt(TableIndex.Param)],
        });

        var has_decl_security = compositeIndexSize(&[_]TableData{
            self.tables[@enumToInt(TableIndex.TypeDef)],
            self.tables[@enumToInt(TableIndex.MethodDef)],
            unused_assembly,
        });

        var member_ref_parent = compositeIndexSize(&[_]TableData{
            self.tables[@enumToInt(TableIndex.TypeDef)],
            self.tables[@enumToInt(TableIndex.TypeRef)],
            self.tables[@enumToInt(TableIndex.ModuleRef)],
            self.tables[@enumToInt(TableIndex.MethodDef)],
            self.tables[@enumToInt(TableIndex.TypeSpec)],
        });

        var has_semantics = compositeIndexSize(&[_]TableData{ unused_event, unused_property });

        var method_def_or_ref = compositeIndexSize(&[_]TableData{
            self.tables[@enumToInt(TableIndex.MethodDef)],
            self.tables[@enumToInt(TableIndex.MemberRef)],
        });

        var member_forwarded = compositeIndexSize(&[_]TableData{
            self.tables[@enumToInt(TableIndex.Field)],
            self.tables[@enumToInt(TableIndex.MethodDef)],
        });

        var implementation = compositeIndexSize(&[_]TableData{
            unused_file,
            self.tables[@enumToInt(TableIndex.AssemblyRef)],
            unused_exported_type,
        });

        var custom_attribute_type = compositeIndexSize(&[_]TableData{
            self.tables[@enumToInt(TableIndex.MethodDef)],
            self.tables[@enumToInt(TableIndex.MemberRef)],
            unused_empty,
            unused_empty,
            unused_empty,
        });

        var resolution_scope = compositeIndexSize(&[_]TableData{
            self.tables[@enumToInt(TableIndex.Module)],
            self.tables[@enumToInt(TableIndex.ModuleRef)],
            self.tables[@enumToInt(TableIndex.AssemblyRef)],
            self.tables[@enumToInt(TableIndex.TypeRef)],
        });

        var type_or_method_def = compositeIndexSize(&[_]TableData{
            self.tables[@enumToInt(TableIndex.TypeDef)],
            self.tables[@enumToInt(TableIndex.MethodDef)],
        });

        // set columns of various tables
        unused_assembly.setColumns(
            4,
            8,
            4,
            blob_index_size,
            string_index_size,
            string_index_size,
        );
        unused_assembly_os.setColumns(4, 4, 4, 0, 0, 0);
        unused_assembly_processor.setColumns(4, 0, 0, 0, 0, 0);
        self.tables[@enumToInt(TableIndex.AssemblyRef)].setColumns(
            8,
            4,
            blob_index_size,
            string_index_size,
            string_index_size,
            blob_index_size,
        );
        unused_assembly_ref_os.setColumns(
            4,
            4,
            4,
            self.tables[@enumToInt(TableIndex.AssemblyRef)].indexSize(),
            0,
            0,
        );
        unused_assembly_ref_processor.setColumns(
            4,
            self.tables[@enumToInt(TableIndex.AssemblyRef)].indexSize(),
            0,
            0,
            0,
            0,
        );

        unused_class_layout.setColumns(
            2,
            4,
            self.tables[@enumToInt(TableIndex.TypeDef)].indexSize(),
            0,
            0,
            0,
        );

        self.tables[@enumToInt(TableIndex.Constant)].setColumns(
            2,
            has_constant,
            blob_index_size,
            0,
            0,
            0,
        );
        self.tables[@enumToInt(TableIndex.CustomAttribute)].setColumns(
            has_custom_attribute,
            custom_attribute_type,
            blob_index_size,
            0,
            0,
            0,
        );
        unused_decl_security.setColumns(2, has_decl_security, blob_index_size, 0, 0, 0);
        unused_event_map.setColumns(
            self.tables[@enumToInt(TableIndex.TypeDef)].indexSize(),
            unused_event.indexSize(),
            0,
            0,
            0,
            0,
        );
        unused_event.setColumns(2, string_index_size, type_def_or_ref, 0, 0, 0);
        unused_exported_type.setColumns(
            4,
            4,
            string_index_size,
            string_index_size,
            implementation,
            0,
        );
        self.tables[@enumToInt(TableIndex.Field)].setColumns(
            2,
            string_index_size,
            blob_index_size,
            0,
            0,
            0,
        );
        unused_field_layout.setColumns(
            4,
            self.tables[@enumToInt(TableIndex.Field)].indexSize(),
            0,
            0,
            0,
            0,
        );
        unused_field_marshal.setColumns(has_field_marshal, blob_index_size, 0, 0, 0, 0);
        unused_field_rva.setColumns(
            4,
            self.tables[@enumToInt(TableIndex.Field)].indexSize(),
            0,
            0,
            0,
            0,
        );
        unused_file.setColumns(4, string_index_size, blob_index_size, 0, 0, 0);
        self.tables[@enumToInt(TableIndex.GenericParam)].setColumns(
            2,
            2,
            type_or_method_def,
            string_index_size,
            0,
            0,
        );
        unused_generic_param_constraint.setColumns(
            self.tables[@enumToInt(TableIndex.GenericParam)].indexSize(),
            type_def_or_ref,
            0,
            0,
            0,
            0,
        );
        unused_impl_map.setColumns(
            2,
            member_forwarded,
            string_index_size,
            unused_module_ref.indexSize(),
            0,
            0,
        );
        self.tables[@enumToInt(TableIndex.ImplMap)].setColumns(
            2,
            member_forwarded,
            string_index_size,
            self.tables[@enumToInt(TableIndex.ModuleRef)].indexSize(),
            0,
            0,
        );

        self.tables[@enumToInt(TableIndex.InterfaceImpl)].setColumns(
            self.tables[@enumToInt(TableIndex.TypeDef)].indexSize(),
            type_def_or_ref,
            0,
            0,
            0,
            0,
        );
        unused_manifest_resource.setColumns(4, 4, string_index_size, implementation, 0, 0);
        self.tables[@enumToInt(TableIndex.MemberRef)].setColumns(
            member_ref_parent,
            string_index_size,
            blob_index_size,
            0,
            0,
            0,
        );
        self.tables[@enumToInt(TableIndex.MethodDef)].setColumns(
            4,
            2,
            2,
            string_index_size,
            blob_index_size,
            self.tables[@enumToInt(TableIndex.Param)].indexSize(),
        );
        unused_method_impl.setColumns(
            self.tables[@enumToInt(TableIndex.TypeDef)].indexSize(),
            method_def_or_ref,
            method_def_or_ref,
            0,
            0,
            0,
        );
        unused_method_semantics.setColumns(
            2,
            self.tables[@enumToInt(TableIndex.MethodDef)].indexSize(),
            has_semantics,
            0,
            0,
            0,
        );
        unused_method_spec.setColumns(method_def_or_ref, blob_index_size, 0, 0, 0, 0);

        self.tables[@enumToInt(TableIndex.Module)].setColumns(
            2,
            string_index_size,
            guid_index_size,
            guid_index_size,
            guid_index_size,
            0,
        );
        self.tables[@enumToInt(TableIndex.ModuleRef)].setColumns(string_index_size, 0, 0, 0, 0, 0);

        self.tables[@enumToInt(TableIndex.NestedClass)].setColumns(
            self.tables[@enumToInt(TableIndex.TypeDef)].indexSize(),
            self.tables[@enumToInt(TableIndex.TypeDef)].indexSize(),
            0,
            0,
            0,
            0,
        );
        self.tables[@enumToInt(TableIndex.Param)].setColumns(2, 2, string_index_size, 0, 0, 0);
        unused_property.setColumns(2, string_index_size, blob_index_size, 0, 0, 0);
        unused_property_map.setColumns(
            self.tables[@enumToInt(TableIndex.TypeDef)].indexSize(),
            unused_property.indexSize(),
            0,
            0,
            0,
            0,
        );
        unused_standalone_sig.setColumns(blob_index_size, 0, 0, 0, 0, 0);
        self.tables[@enumToInt(TableIndex.TypeDef)].setColumns(
            4,
            string_index_size,
            string_index_size,
            type_def_or_ref,
            self.tables[@enumToInt(TableIndex.Field)].indexSize(),
            self.tables[@enumToInt(TableIndex.MethodDef)].indexSize(),
        );
        self.tables[@enumToInt(TableIndex.TypeRef)].setColumns(
            resolution_scope,
            string_index_size,
            string_index_size,
            0,
            0,
            0,
        );
        self.tables[@enumToInt(TableIndex.TypeSpec)].setColumns(blob_index_size, 0, 0, 0, 0, 0);

        // set data of tables
        self.tables[@enumToInt(TableIndex.Module)].setData(&view);
        self.tables[@enumToInt(TableIndex.TypeRef)].setData(&view);
        self.tables[@enumToInt(TableIndex.TypeDef)].setData(&view);
        self.tables[@enumToInt(TableIndex.Field)].setData(&view);
        self.tables[@enumToInt(TableIndex.MethodDef)].setData(&view);
        self.tables[@enumToInt(TableIndex.Param)].setData(&view);
        self.tables[@enumToInt(TableIndex.InterfaceImpl)].setData(&view);
        self.tables[@enumToInt(TableIndex.MemberRef)].setData(&view);
        self.tables[@enumToInt(TableIndex.Constant)].setData(&view);
        self.tables[@enumToInt(TableIndex.CustomAttribute)].setData(&view);
        unused_field_marshal.setData(&view);
        unused_decl_security.setData(&view);
        unused_class_layout.setData(&view);
        unused_field_layout.setData(&view);
        unused_standalone_sig.setData(&view);
        unused_event_map.setData(&view);
        unused_event.setData(&view);
        unused_property_map.setData(&view);
        unused_property.setData(&view);
        unused_method_semantics.setData(&view);
        unused_method_impl.setData(&view);
        self.tables[@enumToInt(TableIndex.ModuleRef)].setData(&view);
        self.tables[@enumToInt(TableIndex.TypeSpec)].setData(&view);
        self.tables[@enumToInt(TableIndex.ImplMap)].setData(&view);
        unused_field_rva.setData(&view);
        unused_assembly.setData(&view);
        unused_assembly_processor.setData(&view);
        unused_assembly_os.setData(&view);
        self.tables[@enumToInt(TableIndex.AssemblyRef)].setData(&view);
        unused_assembly_ref_processor.setData(&view);
        unused_assembly_ref_os.setData(&view);
        unused_file.setData(&view);
        unused_exported_type.setData(&view);
        unused_manifest_resource.setData(&view);
        self.tables[@enumToInt(TableIndex.NestedClass)].setData(&view);
        self.tables[@enumToInt(TableIndex.GenericParam)].setData(&view);

        return self;
    }
};

// A set of helper functions to help facilitate the parsing of winmd bytes

// winmd files are little endian based
fn copyAs(comptime T: type, bytes: []const u8, offset: u32) T {
    return std.mem.readIntSliceLittle(T, bytes[offset .. offset + stdO.sizeOf(T)]);
}

// Can't use @bitCast due to size validation with packed structs using @sizeOf
fn viewAs(comptime T: type, bytes: []const u8, offset: u32) T {
    return viewAsSliceOf(T, bytes, offset, 1)[0];
}

fn viewAsSliceOf(comptime T: type, bytes: []const u8, offset: u32, len: u32) []const T {
    const aligned_bytes align(@alignOf(T)) = bytes[offset..(offset + stdO.sizeOf(T) * len)];
    return stdO.bytesAsSlice(T, aligned_bytes);
}

fn viewAsStr(bytes: []const u8, offset: u32) []const u8 {
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

fn sectionFromRva(sections: []const ImageSectionHeader, rva: u32) !ImageSectionHeader {
    for (sections) |s| {
        if (rva >= s.virtual_address and rva < s.virtual_address + s.physical_address_or_virtual_size) {
            return s;
        }
    }

    return error.InvalidFile;
}

fn offsetFromRva(section: ImageSectionHeader, rva: u32) u32 {
    return rva - section.virtual_address + section.pointer_to_raw_data;
}

fn small(row_count: u32, bits: u6) bool {
    return (@intCast(u64, row_count) < @as(u64, 1) << (16 - bits));
}
fn bitsNeeded(bits_value: usize) u6 {
    var value = bits_value - 1;
    var bits: u6 = 0;
    while (value != 0) : (bits += 1) {
        value >>= 1;
    }
    return bits;
}
fn compositeIndexSize(tables: []TableData) u32 {
    const vbits_needed = bitsNeeded(tables.len);

    for (tables) |table| {
        if (!small(table.row_count, vbits_needed)) return 4;
    }

    return 2;
}

// A set of vadidation consts that each DatabaseFile uses to validate winmd bytes
const IMAGE_DOS_SIGNATURE: u16 = 0x5A4D;
const MAGIC_PE32: u16 = 0x10B;
const MAGIC_PE32PLUS: u16 = 0x20B;
const IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR: usize = 14;
const STORAGE_MAGIC_SIG: u32 = 0x424A_5342;

// A set of packed structs to represent how bytes are laid out in winmd bytes
const ImageDosHeader = packed struct {
    signature: u16,
    cblp: u16,
    cp: u16,
    crlc: u16,
    cparhdr: u16,
    minalloc: u16,
    maxalloc: u16,
    ss: u16,
    sp: u16,
    csum: u16,
    ip: u16,
    cs: u16,
    lfarlc: u16,
    ovno: u16,
    res: [4]u16,
    oemid: u16,
    oeminfo: u16,
    res2: [10]u16,
    lfanew: u32,
};

const ImageFileHeader = packed struct {
    machine: u16,
    number_of_sections: u16,
    time_date_stamp: u32,
    pointer_to_symbol_table: u32,
    number_of_symbols: u32,
    size_of_optional_header: u16,
    characteristics: u16,
};

const ImageDataDirectory = packed struct {
    virtual_address: u32,
    size: u32,
};

const ImageOptionalHeader = packed struct {
    magic: u16,
    major_linker_version: u8,
    minor_linker_version: u8,
    size_of_code: u32,
    size_of_initialized_data: u32,
    size_of_uninitialized_data: u32,
    address_of_entry_point: u32,
    base_of_code: u32,
    base_of_data: u32,
    image_base: u32,
    section_alignment: u32,
    file_alignment: u32,
    major_operating_system_version: u16,
    minor_operating_system_version: u16,
    major_image_version: u16,
    minor_image_version: u16,
    major_subsystem_version: u16,
    minor_subsystem_version: u16,
    win32_version_value: u32,
    size_of_image: u32,
    size_of_headers: u32,
    check_sum: u32,
    subsystem: u16,
    dll_characteristics: u16,
    size_of_stack_reserve: u32,
    size_of_stack_commit: u32,
    size_of_heap_reserve: u32,
    size_of_heap_commit: u32,
    loader_flags: u32,
    number_of_rva_and_sizes: u32,
    data_directory: [16]ImageDataDirectory,
};

const ImageNtHeader = packed struct {
    signature: u32,
    file_header: ImageFileHeader,
    optional_header: ImageOptionalHeader,
};

const ImageOptionalHeaderPlus = packed struct {
    magic: u16,
    major_linker_version: u8,
    minor_linker_version: u8,
    size_of_code: u32,
    size_of_initialized_data: u32,
    size_of_uninitialized_data: u32,
    address_of_entry_point: u32,
    base_of_code: u32,
    image_base: u64,
    section_alignment: u32,
    file_alignment: u32,
    major_operating_system_version: u16,
    minor_operating_system_version: u16,
    major_image_version: u16,
    minor_image_version: u16,
    major_subsystem_version: u16,
    minor_subsystem_version: u16,
    win32_version_value: u32,
    size_of_image: u32,
    size_of_headers: u32,
    check_sum: u32,
    subsystem: u16,
    dll_characteristics: u16,
    size_of_stack_reserve: u64,
    size_of_stack_commit: u64,
    size_of_heap_reserve: u64,
    size_of_heap_commit: u64,
    loader_flags: u32,
    number_of_rva_and_sizes: u32,
    data_directory: [16]ImageDataDirectory,
};

const ImageNtHeaderPlus = packed struct {
    signature: u32,
    file_header: ImageFileHeader,
    optional_header: ImageOptionalHeaderPlus,
};

const ImageSectionHeader = packed struct {
    name: [8]u8,
    physical_address_or_virtual_size: u32,
    virtual_address: u32,
    size_of_raw_data: u32,
    pointer_to_raw_data: u32,
    pointer_to_relocations: u32,
    pointer_to_line_numbers: u32,
    number_of_relocations: u16,
    number_of_line_numbers: u16,
    characteristics: u32,
};

const ImageCorHeader = packed struct {
    cb: u32,
    major_runtime_version: u16,
    minor_runtime_version: u16,
    meta_data: ImageDataDirectory,
    flags: u32,
    entry_point_token_or_entry_point_rva: u32,
    resources: ImageDataDirectory,
    strong_name_signature: ImageDataDirectory,
    code_manager_table: ImageDataDirectory,
    vtable_fixups: ImageDataDirectory,
    export_address_table_jumps: ImageDataDirectory,
    managed_native_header: ImageDataDirectory,
};
