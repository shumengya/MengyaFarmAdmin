extends Panel

# 信号定义
signal command_added(command_name: String, command_content: String, command_color: Color, arg1_enabled: bool, arg2_enabled: bool)

@onready var cmd_name_input: LineEdit = $VBox/HBox/CmdNameInput #设置命令别名
@onready var cmd_content_input: LineEdit = $VBox/HBox2/CmdContentInput#设置命令内容
@onready var cmd_name_color_input: ColorPickerButton = $VBox/HBox3/CmdNameColorInput#设置命令别名颜色

@onready var arg_1: Button = $VBox/HBox4/Arg1 #启用参数1
@onready var arg_2: Button = $VBox/HBox5/Arg2 #启用参数2



# 编辑模式相关
var is_editing: bool = false
var editing_index: int = -1

func _ready() -> void:
	self.hide()
	# 设置默认颜色
	cmd_name_color_input.color = Color.WHITE

func _on_quit_button_pressed() -> void:
	self.hide()
	clear_inputs()

func _on_add_cmd_pressed() -> void:
	var command_name = cmd_name_input.text.strip_edges()
	var command_content = cmd_content_input.text.strip_edges()
	var command_color = cmd_name_color_input.color
	var arg1_enabled = arg_1.button_pressed
	var arg2_enabled = arg_2.button_pressed
	
	# 验证输入
	if command_name.is_empty():
		show_error("请输入命令名称")
		return
	
	if command_content.is_empty():
		show_error("请输入命令内容")
		return
	
	# 根据模式发送不同信号
	if is_editing:
		# 编辑模式：通知主控制台更新命令
		get_parent().get_parent().update_quick_command(editing_index, command_name, command_content, command_color, arg1_enabled, arg2_enabled)
	else:
		# 添加模式：发送添加信号
		command_added.emit(command_name, command_content, command_color, arg1_enabled, arg2_enabled)
	
	# 清空输入并隐藏面板
	clear_inputs()
	self.hide()

# 清空输入框
func clear_inputs():
	cmd_name_input.text = ""
	cmd_content_input.text = ""
	cmd_name_color_input.color = Color.WHITE
	arg_1.button_pressed = false
	arg_2.button_pressed = false
	is_editing = false
	editing_index = -1

# 显示错误消息
func show_error(message: String):
	print("错误: ", message)
	# 这里可以添加更好的错误显示方式，比如弹窗

# 设置编辑模式
func set_edit_mode(command_name: String, command_content: String, command_color: Color, index: int, arg1_enabled: bool = false, arg2_enabled: bool = false):
	cmd_name_input.text = command_name
	cmd_content_input.text = command_content
	cmd_name_color_input.color = command_color
	arg_1.button_pressed = arg1_enabled
	arg_2.button_pressed = arg2_enabled
	is_editing = true
	editing_index = index
	self.show()
