const std = @import("std");
const print = std.debug.print;
const http = std.http;
const WebBackend = @This();

pub const RunMode = enum { Local, Prod };

pub const ServerOptions = struct {
    port: u16 = 3000,
    address: []const u8 = "127.0.0.1", // never use "localhost"
    allocator: std.mem.Allocator = undefined,
    run_mode: RunMode = RunMode.Local,
};

pub fn WebServer() type {
    return struct {
        var options: ServerOptions = undefined;
        var server: http.Server = undefined;
        const pageNotFoundPath = "src/util/pageNotFound.html";
        pub fn init_and_run(p_Options: ServerOptions) !void {
            options = p_Options;
            server = std.http.Server.init(options.allocator, .{});
            defer server.deinit();

            if (options.run_mode == RunMode.Local) {
                const portString = try std.fmt.allocPrint(options.allocator, "{any}", .{options.port});
                const authority = try std.mem.concat(options.allocator, u8, &.{ options.address, ":", portString });
                print("\n\nRunning development server at: {s}\n", .{authority});
            }
            const address = try std.net.Address.parseIp(options.address, options.port);

            try server.listen(address);
            try run();
        }

        fn handle_get_request(response: *std.http.Server.Response) !void {
            const target = response.request.target;
            var param_split_iterator: std.mem.SplitIterator(u8, .scalar) = std.mem.splitScalar(u8, target, '?');
            var path: []const u8 = param_split_iterator.first(); // this gets everything up until the first '?', so if no '?' exists, then its still OK
            var params: ?[]const u8 = param_split_iterator.next(); // gets param if exits
            _ = params;

            var path_split_iterator: std.mem.SplitBackwardsIterator(u8, .scalar) = std.mem.splitBackwardsScalar(u8, path, '/');
            // if .css or .ico or .js, etc... what other features should we support?
            var last_path: []const u8 = path_split_iterator.first();

            const js_dir = "scripts/";
            const css_dir = "styles/";
            var file_content: anyerror![]u8 = "";
            var content_type: []const u8 = "";
            if (std.mem.containsAtLeast(u8, last_path, 1, ".")) {
                var last_split_iterator: std.mem.SplitBackwardsIterator(u8, .scalar) = std.mem.splitBackwardsScalar(u8, path, '.');
                const extension: []const u8 = last_split_iterator.first();
                if (std.mem.eql(u8, extension, "js")) {
                    const js_path = try std.mem.concat(options.allocator, u8, &.{ js_dir, last_path });
                    file_content = std.fs.cwd().readFileAlloc(options.allocator, js_path, std.math.maxInt(usize));
                    content_type = "text/javascript";
                } else if (std.mem.eql(u8, extension, "css")) {
                    const css_path = try std.mem.concat(options.allocator, u8, &.{ css_dir, last_path });
                    file_content = std.fs.cwd().readFileAlloc(options.allocator, css_path, std.math.maxInt(usize));
                    content_type = "text/css";
                }
            } else {
                content_type = "text/html";
                const server_path_prefix = try std.mem.concat(options.allocator, u8, &.{ "pages", path });
                const requested_html = try std.mem.concat(options.allocator, u8, &.{ server_path_prefix, "/index.html" });
                file_content = std.fs.cwd().readFileAlloc(options.allocator, requested_html, std.math.maxInt(usize));
                if (file_content) |fileContent| {
                    _ = fileContent;
                } else |err| {
                    if (err == error.FileNotFound)
                        file_content = std.fs.cwd().readFileAlloc(options.allocator, "util/pageNotFound.html", std.math.maxInt(usize));
                }
            }
            try response.headers.append("Content-Type", content_type);

            if (file_content) |file| {
                const len = try std.fmt.allocPrint(options.allocator, "{any}", .{file.len});
                try response.headers.append("Content-Length", len);
            } else |err| {
                print("{any}\n", .{err});
            }

            try response.do();
            if (file_content) |file| {
                _ = try response.write(file);
            } else |err| {
                print("{any}\n", .{err});
            }
            try response.finish();
        }

        fn run() !void {
            var running: bool = true;
            while (running) {
                const server_thread = try std.Thread.spawn(.{}, (struct {
                    fn apply(s: *std.http.Server) !void {
                        var res = try s.accept(.{
                            .allocator = options.allocator,
                        });
                        defer res.deinit();
                        defer _ = res.reset();

                        try res.wait();
                        const body = res.reader().readAllAlloc(options.allocator, 8192) catch unreachable;
                        defer options.allocator.free(body);

                        try switch (res.request.method) {
                            std.http.Method.GET => handle_get_request(&res),
                            else => undefined,
                        };
                    }
                }).apply, .{&server});
                server_thread.join();
            }
        }
    };
}
