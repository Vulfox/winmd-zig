//! This is the meta data generator for parsing winmd files

pub const DatabaseFile = struct {
    bytes: []const u8,
    pub fn fromBytes(bytes: []const u8) DatabaseFile {
        return DatabaseFile{ .bytes = bytes };
    }
};
