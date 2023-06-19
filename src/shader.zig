const std = @import("std");
const gl = @import("gl.zig");

const Allocator = std.mem.Allocator;
pub fn readFile(allocator: Allocator, path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stats = try file.stat();
    var buff: []u8 = try allocator.alloc(u8, stats.size);
    std.debug.assert(try file.readAll(buff) == buff.len);
    return buff;
}


pub const Shader = struct {
    id: u32,
    const Self = @This();
    pub fn initFromFiles(allocator: Allocator, vertexPath: []const u8, fragmentPath: []const u8) !Self {
        const vertexSource = try readFile(allocator, vertexPath);
        defer allocator.free(vertexSource);
        const fragmentSource = try readFile(allocator, fragmentPath);
        defer allocator.free(fragmentSource);

        return Self.init(vertexSource, fragmentSource);
    }
    pub fn init(vertexSource: []const u8, fragmentSource: []const u8) Self {
        const vertexShader = gl.createShader(gl.VERTEX_SHADER);
        defer gl.deleteShader(vertexShader);
        gl.shaderSource(vertexShader, 1, &vertexSource.ptr, &@intCast(c_int, vertexSource.len));
        gl.compileShader(vertexShader);

        const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
        defer gl.deleteShader(fragmentShader);
        gl.shaderSource(fragmentShader, 1, &fragmentSource.ptr, &@intCast(c_int, fragmentSource.len));
        gl.compileShader(fragmentShader);

        const program = gl.createProgram();
        gl.attachShader(program, vertexShader);
        gl.attachShader(program, fragmentShader);
        gl.linkProgram(program);
        return .{ .id = program };
    }
    pub fn use(self: Self) void {
        gl.useProgram(self.id);
    }
    pub fn set(self: Self, comptime T: type, name: []const u8, value: T) !void {
        const location = gl.getUniformLocation(self.id, name.ptr);
            switch (T) {
                bool => gl.uniform1i(location, @boolToInt(value)),
                c_int, comptime_int, i32 => gl.uniform1i(location, value),
                comptime_float, f32 => gl.uniform1f(location, value),
                else => return error.InvalidType
            }
    }
    pub fn setVector(self: Self, name: []const u8, value: anytype) void {
        const location = gl.getUniformLocation(self.id, name.ptr);
        const info = @typeInfo(@TypeOf(value)).Vector;
        switch (info.len) {
            2 => switch (info.child) {
                bool => gl.uniform2i(location, @boolToInt(value)),
                c_int, comptime_int, i32 => gl.uniform2i(location, value),
                comptime_float, f32 => gl.uniform2f(location, value),
                else => return error.InvalidType
            },
            3 => switch (info.child) {
                bool => gl.uniform3i(location, @boolToInt(value[0]), @boolToInt(value[1]), @boolToInt(value[2]), @boolToInt(value[3])),
                c_int, comptime_int, i32 => gl.uniform3i(location, value[0], value[1], value[2], value[3]),
                comptime_float, f32 => gl.uniform3f(location, value),
                else => return error.InvalidType
            },
            4 => switch (info.child) {
                bool => gl.uniform4i(location, @boolToInt(value)),
                c_int, comptime_int, i32 => gl.uniform4i(location, value[0], value[1], value[2], value[3]),
                comptime_float, f32 => gl.uniform4f(location, value[0], value[1], value[2], value[3]),
                else => return error.InvalidType
            },
            else => return error.InvalidType
        }
    }
};
