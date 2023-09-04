const std = @import("std");
const http = std.http;
const print = std.debug.print;
const uri_path = std.Uri;

const WebBackend = @import("BPWB.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    var allocator = gpa.allocator();
    const options: WebBackend.ServerOptions = .{ .allocator = allocator };
    const webserver: type = WebBackend.WebServer();
    try webserver.init_and_run(options);
}
