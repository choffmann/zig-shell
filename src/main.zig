const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

const Command = enum { exit, echo };

pub fn parse_command(command: []const u8) ?Command {
    if (std.mem.eql(u8, command, "exit")) {
        return Command.exit;
    }

    if (std.mem.eql(u8, command, "echo")) {
        return Command.echo;
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
                Command.exit => exit(&args),
                Command.echo => echo(&args),
            };
        } else {
            try stdout.print("{s}: command not found\n", .{user_input});
        }
    }
}

fn exit(args: *std.mem.SplitIterator(u8, .any)) !void {
    const code = try std.fmt.parseInt(u8, args.next() orelse "0", 10);
    std.process.exit(code);
}

fn echo(args: *std.mem.SplitIterator(u8, .any)) !void {
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
