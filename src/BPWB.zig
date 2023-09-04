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
                const authority = std.mem.concat(options.allocator, u8, &.{ options.address, portString });
                print("\n\nRunning development server at: {s}\n", .{authority});
            }
            const address = try std.net.Address.parseIp(options.address, options.port);

            try server.listen(address);
            try run();
        }

        fn handle_get_request(response: *std.http.Server.Response) !void {

            // match to explicit specification
            // if no match, then return generic page not found

            const target = response.request.target;
            var param_split_iterator: std.mem.SplitIterator(u8, .scalar) = std.mem.splitScalar(u8, target, '?');
            var path: []const u8 = param_split_iterator.first(); // this gets everything up until the first '?', so if no '?' exists, then its still OK
            var params: ?[]const u8 = param_split_iterator.next(); // gets param if exits
            _ = params;

            // do server logic conditionally based on the params

            var path_split_iterator: std.mem.SplitBackwardsIterator(u8, .scalar) = std.mem.splitBackwardsScalar(u8, path, '/');
            // if .css or .ico or .js, etc... what other features should we support?
            var last_path: []const u8 = path_split_iterator.first();
            const last_path_len = last_path.len;
            const supported_feature = std.mem.eql(u8, last_path[last_path_len - 3 .. last_path_len], "css") or std.mem.eql(u8, last_path[last_path_len - 2 .. last_path_len], "js");
            const is_valid_dir_path = !std.mem.containsAtLeast(u8, last_path, 1, ".");

            const adjusted_path = try std.mem.concat(options.allocator, u8, &.{ "src", path });
            var file_content: anyerror![]u8 = "";
            if (supported_feature) {
                const css_path = try std.mem.concat(options.allocator, u8, &.{ "src/styles/", last_path });
                if (std.mem.eql(u8, last_path[last_path_len - 3 .. last_path_len], "css")) {
                    //css
                    file_content = try std.fs.cwd().readFileAlloc(options.allocator, css_path, std.math.maxInt(usize));
                    try response.headers.append("Content-Type", "text/css");
                } else {
                    // js
                    try response.headers.append("Content-Type", "text/javascript");
                }
            } else if (is_valid_dir_path) {
                const html_path = try std.mem.concat(options.allocator, u8, &.{ adjusted_path, "/index.html" });
                const currentDir = std.fs.cwd();
                file_content = currentDir.readFileAlloc(options.allocator, html_path, std.math.maxInt(usize));
                if (file_content) |fileContent| {
                    _ = fileContent;
                } else |err| {
                    if (err == error.FileNotFound)
                        file_content = try std.fs.cwd().readFileAlloc(options.allocator, "src/util/pageNotFound.html", std.math.maxInt(usize));
                }
                try response.headers.append("Content-Type", "text/html");
            } else {
                //handle bad request scenario
                file_content = try std.fs.cwd().readFileAlloc(options.allocator, "src/util/pageNotFound.html", std.math.maxInt(usize));
                try response.headers.append("Content-Type", "text/html");
            }

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
