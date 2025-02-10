const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

const Args = std.mem.SplitIterator(u8, .any);

const Command = enum { exit, echo, type, env, pwd, cd };
pub fn parse_command(command: []const u8) ?Command {
    inline for (std.meta.fields(Command)) |c| {
        if (std.mem.eql(u8, command, c.name)) {
            return @enumFromInt(c.value);
        }
    }

    return null;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    while (true) {
        try stdout.print("$ ", .{});
        const user_input = try stdin.readUntilDelimiterAlloc(allocator, '\n', 1024);

        var args = std.mem.splitAny(u8, user_input, " ");

        const command = args.next() orelse "";
        if (parse_command(command)) |cmd| {
            try switch (cmd) {
                .exit => exit(&args),
                .echo => echo(&args),
                .type => type_cmd(allocator, &args),
                .env => env(allocator),
                .pwd => pwd(allocator),
                .cd => cd(allocator, &args),
            };
        } else {
            if (try is_in_path(allocator, command)) {
                var argv_list = std.ArrayList([]const u8).init(allocator);
                defer argv_list.deinit();

                args.reset();
                while (args.next()) |arg| try argv_list.append(arg);

                var cmd = std.process.Child.init(try argv_list.toOwnedSlice(), allocator);
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
        if (args.peek() != null) try w.print(" ", .{});
    }
    try w.print("\n", .{});
    try buf.flush();
}

fn pwd(allocator: std.mem.Allocator) !void {
    const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
    try stdout.print("{s}\n", .{cwd});
}

fn cd(allocator: std.mem.Allocator, args: *Args) !void {
    const path = args.next() orelse "~";

    var dir: std.fs.Dir = undefined;
    if (std.mem.eql(u8, path, "~")) {
        var env_map = try std.process.getEnvMap(allocator);
        defer env_map.deinit();

        const home = env_map.get("HOME").?;

        dir = try std.fs.cwd().openDir(home, .{});
    } else {
        dir = std.fs.cwd().openDir(path, .{}) catch {
            try stdout.print("cd: {s}: No such file or directory\n", .{path});
            return;
        };
    }

    try dir.setAsCwd();
}

fn env(allocator: std.mem.Allocator) !void {
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    var iter = env_map.iterator();
    while (iter.next()) |entry| {
        try stdout.print("{s}={s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }
}

fn type_cmd(allocator: std.mem.Allocator, args: *Args) !void {
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

fn is_in_path(allocator: std.mem.Allocator, cmd: []const u8) !bool {
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
