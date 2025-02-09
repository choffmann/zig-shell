const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

const Args = std.mem.SplitIterator(u8, .any);

const Command = enum { exit, echo, type, env };
pub fn parse_command(command: []const u8) ?Command {
    inline for (std.meta.fields(Command)) |c| {
        if (std.mem.eql(u8, command, c.name)) {
            return @enumFromInt(c.value);
        }
    }

    return null;
}

pub fn main() !void {
    while (true) {
        var buffer: [1024]u8 = undefined;
        try stdout.print("$ ", .{});
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        var args = std.mem.splitAny(u8, user_input, " ");

        const command = args.next() orelse "";
        if (parse_command(command)) |cmd| {
            try switch (cmd) {
                .exit => exit(&args),
                .echo => echo(&args),
                .type => type_cmd(&args),
                .env => env(&args),
            };
        } else {
            const allocator = std.heap.page_allocator; // Allocate a whole page of memory each time we ask for some memory. Very simple, very dumb, very wasteful.
            if (try is_in_path(command)) {
                const argv_buf = [_][]const u8{args.next() orelse ""};
                var cmd = std.process.Child.init(&argv_buf, allocator);
                try cmd.spawn();
                _ = try cmd.wait();
            } else {
                try stdout.print("{s}: command not found\n", .{user_input});
            }
        }
    }
}

fn exit(args: *Args) !void {
    const code = try std.fmt.parseInt(u8, args.next() orelse "0", 10);
    std.process.exit(code);
}

fn echo(args: *Args) !void {
    var buf = std.io.bufferedWriter(stdout);
    var w = buf.writer();
    while (args.next()) |arg| {
        try w.print("{s}", .{arg});

        if (args.peek() != null) {
            try w.print(" ", .{});
        }
    }
    try w.print("\n", .{});
    try buf.flush();
}

fn env(_: *Args) !void {
    const allocator = std.heap.page_allocator; // Allocate a whole page of memory each time we ask for some memory. Very simple, very dumb, very wasteful.

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    var iter = env_map.iterator();
    while (iter.next()) |entry| {
        std.debug.print("{s}={s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }
}

fn type_cmd(args: *Args) !void {
    const allocator = std.heap.page_allocator; // Allocate a whole page of memory each time we ask for some memory. Very simple, very dumb, very wasteful.
    const command = args.next() orelse "";

    if (parse_command(command) != null) {
        try stdout.print("{s} is a shell builtin\n", .{command});
        return;
    }

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    const path = env_map.get("PATH") orelse "";
    var path_iter = std.mem.splitAny(u8, path, ":");

    while (path_iter.next()) |e| {
        var dir = std.fs.openDirAbsolute(e, .{ .iterate = true }) catch {
            continue;
        };

        var dir_iter = dir.iterate();
        while (try dir_iter.next()) |d| {
            if (std.mem.eql(u8, d.name, command)) {
                try stdout.print("{s} is {s}/{s}\n", .{ command, e, d.name });
                return;
            }
        }
    }

    try stdout.print("{s}: not found\n", .{command});
}

fn is_in_path(cmd: []const u8) !bool {
    const allocator = std.heap.page_allocator; // Allocate a whole page of memory each time we ask for some memory. Very simple, very dumb, very wasteful.
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    const path = env_map.get("PATH") orelse "";
    var path_iter = std.mem.splitAny(u8, path, ":");

    while (path_iter.next()) |e| {
        var dir = std.fs.openDirAbsolute(e, .{ .iterate = true }) catch {
            continue;
        };

        var dir_iter = dir.iterate();
        while (try dir_iter.next()) |d| {
            if (std.mem.eql(u8, d.name, cmd)) {
                return true;
            }
        }
    }

    return false;
}
