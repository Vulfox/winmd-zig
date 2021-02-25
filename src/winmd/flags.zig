pub const MethodFlags = struct {
    value: u32,

    pub fn special(self: *const MethodFlags) bool {
        return (self.value & 0b1000_0000_0000 != 0);
    }
};

pub const TypeFlags = struct {
    value: u64,

    pub fn windowsRuntime(self: *const TypeFlags) bool {
        return (self.value & 0b100_0000_0000_0000 != 0);
    }
    pub fn interface(self: *const TypeFlags) bool {
        return (self.value & 0b10_0000 != 0);
    }
    pub fn explicit(self: *const TypeFlags) bool {
        return (self.value & 0b1_0000 != 0);
    }
};

pub const ParamFlags = struct {
    value: u32 = 0,

    pub fn input(self: *const MethodFlags) bool {
        return (self.value & 0x0001 != 0);
    }
    pub fn putput(self: *const MethodFlags) bool {
        return (self.value & 0x0002 != 0);
    }
    pub fn pptional(self: *const MethodFlags) bool {
        return (self.value & 0x0010 != 0);
    }
};

pub const FieldFlags = struct {
    value: u32 = 0,

    pub fn literal(self: *const FieldFlags) bool {
        return (self.value & 0b100_0000 != 0);
    }

    pub fn static(self: *const FieldFlags) bool {
        return (self.value & 0b1_0000 != 0);
    }
};

pub const TypeCategory = enum {
    Interface,
    Class,
    Enum,
    Struct,
    Delegate,
    Attribute,
    Contract,
};

pub const ParamCategory = enum {
    Array,
    Enum,
    Generic,
    Object,
    Primitive,
    String,
    Struct,
};

pub const MethodCategory = enum {
    Normal,
    Get,
    Set,
    Add,
    Remove,
};
