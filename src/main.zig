const std = @import("std");
const gl = @import("gl.zig");
const Shader = @import("shader.zig").Shader;
const glLog = std.log.scoped(.OpenGL);
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("stb_image.h");
});

const Allocator = std.mem.Allocator;

pub fn debugCallback(_: gl.GLenum, _: gl.GLenum, _: gl.GLuint, severity: gl.GLenum, length: gl.GLsizei, message: [*:0]const u8, _: ?*anyopaque) callconv(.C) void {
    const tty = std.io.tty;
    const color: tty.Color = switch (severity) {
        gl.DEBUG_SEVERITY_HIGH => .red,
        gl.DEBUG_SEVERITY_LOW, gl.DEBUG_SEVERITY_NOTIFICATION => .blue,
        gl.DEBUG_SEVERITY_MEDIUM => .yellow,
        else => std.debug.panic("severity didnt match enums: {}\n", .{severity})
    };
    const stdout = std.io.getStdOut();
    const config = tty.detectConfig(stdout);
    config.setColor(stdout, color) catch std.debug.panic("failed to set color\n", .{});
    glLog.debug("{s}", .{message[0..@intCast(usize, length)]});
}

pub fn SDLDie(result: anytype) !void {
    if (result < 0) {
        std.log.debug("{s}", .{c.SDL_GetError()});
        return error.SDLBad;
    }
    return;
}

pub fn getProcAddress(_: void, name: [:0]const u8) ?*const anyopaque {
    return c.SDL_GL_GetProcAddress(name);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        if (status == .leak) @panic("memory leaked :(");
    }
    const allocator = gpa.allocator();
    try SDLDie(c.SDL_SetHint("SDL_VIDEODRIVER", "wayland,x11,kmsdrm"));
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) return error.SDlFailedInit;
    defer c.SDL_Quit();
    try SDLDie(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, c.SDL_GL_CONTEXT_PROFILE_CORE));
    try SDLDie(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 4));
    try SDLDie(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 6));
    try SDLDie(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_FLAGS, c.SDL_GL_CONTEXT_DEBUG_FLAG));
    const window = c.SDL_CreateWindow(
        "uwu",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        640,
        480,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_ALLOW_HIGHDPI | c.SDL_WINDOW_RESIZABLE
    );
    defer c.SDL_DestroyWindow(window);


    const glContext = c.SDL_GL_CreateContext(window);
    defer c.SDL_GL_DeleteContext(glContext);
    try SDLDie(c.SDL_GL_MakeCurrent(window, glContext));
    try SDLDie(c.SDL_GL_SetSwapInterval(1));
    try gl.load({}, getProcAddress);
    gl.enable(gl.DEBUG_OUTPUT);
    gl.debugMessageCallback(debugCallback, undefined);
    gl.debugMessageControl(gl.DONT_CARE, gl.DONT_CARE, gl.DONT_CARE, 0, null, gl.TRUE);
    glLog.info("{s}", .{gl.getString(gl.VERSION).?});
    {
        var w: i32 = undefined;
        var h: i32 = undefined;
        c.SDL_GL_GetDrawableSize(window, &w, &h);
        gl.viewport(0, 0, w, h);
    }

    const triangle = [_]f32 {
        0.5,  0.5, 0.0,  1.0, 0.0, 0.0,   1.0, 1.0,   
        0.5, -0.5, 0.0,  0.0, 1.0, 0.0,   1.0, 0.0,  
       -0.5, -0.5, 0.0,  0.0, 0.0, 1.0,   0.0, 0.0,
       -0.5,  0.5, 0.0,  1.0, 1.0, 0.0,   0.0, 1.0   
    };

    const indices = [_]f32 {
        0, 1, 3,
        1, 2, 3
    };


    const shader = try Shader.initFromFiles(allocator, "shaders/vert.glsl", "shaders/frag.glsl");

    var ebo: u32 = undefined;
    var vbo: u32 = undefined;
    var vao: u32 = undefined;

    gl.genBuffers(1, &ebo);
    defer gl.deleteBuffers(1, &ebo);
    gl.genBuffers(1, &vbo);
    defer gl.deleteVertexArrays(1, &vbo);
    gl.genVertexArrays(1, &vao);
    defer gl.deleteBuffers(1, &vao);

    gl.bindVertexArray(vao);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(triangle)), &triangle, gl.STATIC_DRAW);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.STATIC_DRAW);

    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);

    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*void, 3 * @sizeOf(f32)));
    gl.enableVertexAttribArray(1);

    gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*void, 6 * @sizeOf(f32)));
    gl.enableVertexAttribArray(2);

    var texture: u32 = undefined;
    gl.genTextures(1, &texture);
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    {
        var w: i32 = undefined;
        var h: i32 = undefined;
        var nch: i32 = undefined;
        const data = c.stbi_load("container.jpg", &w, &h, &nch, 0)
            orelse return error.FailedToLoadImage;
        defer c.stbi_image_free(data);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB,
            w,
            h,
            0,
            gl.RGB,
            gl.UNSIGNED_BYTE,
            data
        );
    }
    gl.generateMipmap(gl.TEXTURE_2D);

    var event: c.SDL_Event = undefined;
    var running = true;
    while (running) {
        while (c.SDL_PollEvent(&event) > 0) {
            switch (event.@"type") {
                c.SDL_QUIT => running = false,
                c.SDL_WINDOWEVENT_RESIZED => gl.viewport(0, 0, event.window.data1, event.window.data2),
                else => {}
            }
        }


        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, texture);
        shader.use();
        try shader.set(i32, "texture1", 0);
        gl.bindVertexArray(vao);
        gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);
        c.SDL_GL_SwapWindow(window);
    }
}
