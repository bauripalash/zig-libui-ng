//! A simple example of a CRUD (Create Read Update Delete) application using libui.
//! Makes use of ui-extras to reduce boilerplate when creating the table.
const std = @import("std");
const ui = @import("ui");
const extras = @import("ui-extras");

pub fn on_closing(_: *ui.Window, _: ?*void) !ui.Window.ClosingAction {
    ui.Quit();
    return .should_close;
}

const OnClickError = std.mem.Allocator.Error || ui.Error || error{
    Other,
};
pub fn on_click(_: *ui.Button, app_opt: ?*App) OnClickError!void {
    const app = app_opt orelse return error.LibUIPassedNullPointer;
    const name = try app.allocator.dupeZ(u8, "");
    const surname = try app.allocator.dupeZ(u8, "");
    const button_text = try app.allocator.dupeZ(u8, "Delete");
    try app.table.data.array_list.append(.{ .name = name, .surname = surname, .button_text = button_text });
    app.table.model.RowInserted(@intCast(app.table.data.array_list.items.len - 1));
}

pub fn on_table_button_clicked(table: *extras.Table(ViewData), value: *ViewData, column: usize, row: usize) void {
    std.log.debug("Button for column {}, row {}, clicked. Value is: {}", .{ column, row, value });
    std.debug.assert(column == 1);

    const allocator = table.allocator orelse @panic("");

    allocator.free(table.data.array_list.items[row].name);
    allocator.free(table.data.array_list.items[row].surname);
    allocator.free(table.data.array_list.items[row].button_text);

    _ = table.data.array_list.orderedRemove(row);
    table.model.RowDeleted(@intCast(row));
}

const PrefixError = ui.Error;
fn on_prefix_changed(entry: *ui.Entry, table_opt: ?*App) PrefixError!void {
    const table = table_opt orelse return error.LibUIPassedNullPointer;
    _ = table;
    const new_prefix = entry.Text();
    std.log.debug("Prefix changed: {s}", .{new_prefix});
}

pub fn main() !void {
    // Initialize libui
    var init_data = ui.InitData{
        .options = .{ .Size = 0 },
    };
    ui.Init(&init_data) catch {
        std.debug.print("Error initializing LibUI: {s}\n", .{init_data.get_error()});
        init_data.free_error();
        return;
    };
    defer ui.Uninit();

    // Create a ui.Window
    const main_window = try ui.Window.New("CRUD", 480, 240, .hide_menubar);

    main_window.as_control().Show();
    main_window.OnClosing(void, ui.Error, on_closing, null);

    const vbox = try ui.Box.New(.Vertical);
    main_window.SetChild(vbox.as_control());

    vbox.SetPadded(true);
    main_window.SetMargined(true);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const string_allocator = gpa.allocator();

    // Our context struct
    var app = App.init(gpa.allocator());
    defer app.deinit();

    try app.model.appendSlice(&.{
        .{ .id = 0, .name = "Hans", .surname = "Emil", .age = 20, .height = 5.5 },
        .{ .id = 1, .name = "Max", .surname = "Mustermann", .age = 21, .height = 5.75 },
        .{ .id = 2, .name = "Roman", .surname = "Tisch", .age = 22, .height = 6.0 },
    });
    app.current_id = 3;

    // Create an entry for searching our data
    const hbox = try ui.Box.New(.Horizontal);
    const filter_label = try ui.Label.New("Filter prefix:");
    const filter_prefix = try ui.Entry.New(.Search);

    filter_prefix.OnChanged(App, PrefixError, on_prefix_changed, &app);

    hbox.Append(filter_label.as_control(), .dont_stretch);
    hbox.Append(filter_prefix.as_control(), .stretch);
    hbox.SetPadded(true);

    vbox.Append(hbox.as_control(), .dont_stretch);

    // Initialize the `extras.Table(TestStruct)` and pass it an ArrayList
    try app.table.init(.{ .array_list = &app.view }, string_allocator);
    defer app.table.deinit(); // Defer deinitalization of `extras.Table(TestStruct)` to end of scope
    app.table.button_callback = on_table_button_clicked;

    // Create a table view without using the default column generator
    const Editable = ui.Table.ColumnParameters.Editable;
    const custom_table_view = try app.table.NewView(.{});
    custom_table_view.AppendColumn("Editable", .{ .Checkbox = .{
        .editable = .Always,
        .checkbox_column = 0,
    } });
    custom_table_view.AppendColumn("Name", .{ .Text = .{
        .editable = Editable.column(0),
        .text_column = 2,
    } });
    custom_table_view.AppendColumn("Surname", .{ .Text = .{
        .editable = Editable.column(0),
        .text_column = 3,
    } });
    custom_table_view.AppendColumn("Age", .{ .Text = .{
        .editable = Editable.column(0),
        .text_column = 4,
    } });
    custom_table_view.AppendColumn("Height", .{ .Text = .{
        .editable = Editable.column(0),
        .text_column = 5,
    } });
    custom_table_view.AppendColumn("", .{ .Button = .{
        .button_column = 1,
        .button_clickable = .Always,
    } });
    vbox.Append(custom_table_view.as_control(), .stretch);

    const button = try ui.Button.New("Add Row");
    button.OnClicked(App, OnClickError, on_click, &app);
    vbox.Append(button.as_control(), .dont_stretch);

    ui.Main();
}

const App = struct {
    allocator: std.mem.Allocator,
    model: std.ArrayList(ModelData),
    view: std.ArrayList(ViewData),
    table: extras.Table(ViewData),
    current_id: usize = 0,

    fn init(allocator: std.mem.Allocator) App {
        return .{
            .allocator = allocator,
            .model = std.ArrayList(ModelData).init(allocator),
            .view = std.ArrayList(ViewData).init(allocator),
            .table = undefined,
        };
    }

    fn deinit(app: *App) void {
        app.model.deinit();
        app.view.deinit();
    }
};

const ModelData = struct {
    name: [:0]const u8,
    surname: [:0]const u8,
    age: f64,
    height: f64,
    id: usize,
};

const ViewData = struct {
    editable: extras.TableType.Checkbox = .{ .data = 1 },
    button_text: [:0]const u8,
    name: [:0]const u8,
    surname: [:0]const u8,
    age: u64 = 0,
    height: f64 = 0,
    id: usize = 0,

    pub fn setCell(edit: *ViewData, value: *const ui.Table.Value, column: usize) bool {
        switch (column) {
            5 => {
                const string = std.mem.span(value.String());
                const feet_i = std.mem.indexOfScalar(u8, string, '\'');
                const inch_i = std.mem.indexOfScalar(u8, string, '"');
                if (feet_i) |i| {
                    const feet_str = std.mem.trim(u8, string[0..i], " \t");
                    var feet = std.fmt.parseFloat(f64, feet_str) catch {
                        std.debug.print("feet_i: {}\n", .{i});
                        return true;
                    };
                    if (inch_i) |a| inches: {
                        if (a < i) return true;
                        const inch_str = std.mem.trim(u8, string[i + 1 ..][0 .. a - i - 1], " \t");
                        const inches = std.fmt.parseFloat(f64, inch_str) catch {
                            std.debug.print("inch_i: {}\tinch_str: {s}\n", .{ a, inch_str });
                            break :inches;
                        };
                        feet += inches / 12;
                    }
                    edit.height = feet;
                } else {
                    edit.height = std.fmt.parseFloat(f64, string) catch return true;
                }
            },
            else => return false,
        }
        return true;
    }

    pub fn cellValue(edit: *const ViewData, column: usize) ?*ui.Table.Value {
        switch (column) {
            5 => {
                const modf = std.math.modf(edit.height);
                const min_size = std.fmt.format_float.min_buffer_size;
                var buf: [min_size]u8 = undefined;
                const string = std.fmt.bufPrintZ(&buf, "{d}' {d}\"", .{ modf.ipart, @round(modf.fpart * 12) }) catch return null;
                return ui.Table.Value.New(.{ .String = string }) catch null;
            },
            else => return null,
        }
    }
};
