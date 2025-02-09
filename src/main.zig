const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    while (true) {
        var buffer: [1024]u8 = undefined;
        try stdout.print("$ ", .{});
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        var args = std.mem.splitAny(u8, user_input, " ");
        const command = args.next().?;

        if (std.mem.startsWith(u8, command, "exit")) {
            const code = try std.fmt.parseInt(u8, args.next() orelse "0", 10);
            std.process.exit(code);
        } else {
            try stdout.print("{s}: command not found\n", .{user_input});
        }
    }
}
