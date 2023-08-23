const std = @import("std");
const http = std.http;
const print = std.debug.print;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    const allocator = gpa.allocator();
    var server: http.Server = http.Server.init(allocator, .{});
    const primAddr = std.net.Ip4Address.init([4]u8{ 192, 168, 0, 20 }, 3000);
    const addr = std.net.Address{ .in = primAddr };
    _ = try server.listen(addr);
    while (true) {
        var response: http.Server.Response = try server.accept(.{ .allocator = allocator });
        _ = response;

        print("\nListening on port {any}...", .{addr.in});
    }
}
