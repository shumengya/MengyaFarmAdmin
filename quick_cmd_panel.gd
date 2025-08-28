extends Panel

# 信号定义
signal command_executed(command_index: int)
signal command_edited(command_index: int, command_name: String, command_content: String, command_color: Color)
signal command_deleted(command_index: int)
signal command_delete_requested(command_index: int, command_name: String)

@onready var grid: GridContainer = $Scroll/Grid
@onready var cmd_v_box_1: VBoxContainer = $Scroll/Grid/CmdVBox1 #命令模板
@onready var cmd: Button = $Scroll/Grid/CmdVBox1/Cmd #命令按钮，点击执行
@onready var h_box: HBoxContainer = $Scroll/Grid/CmdVBox1/HBox 
@onready var edit: Button = $Scroll/Grid/CmdVBox1/HBox/Edit #编辑命令按钮，打开addquickcmdpanel
@onready var delate: Button = $Scroll/Grid/CmdVBox1/HBox/Delate #删除该命令 

# 存储命令数据和UI元素
var commands_data: Array = []
var command_containers: Array = []

func _ready() -> void:
	self.hide()
	# 隐藏模板
	cmd_v_box_1.visible = false

func _on_quit_button_pressed() -> void:
	self.hide()

# 更新命令列表
func update_commands(commands: Array):
	commands_data = commands
	# 清除现有的命令容器（除了模板）
	clear_command_containers()
	
	# 为每个命令创建UI
	for i in range(commands.size()):
		create_command_ui(commands[i], i)

# 清除命令容器
func clear_command_containers():
	for container in command_containers:
		if container and is_instance_valid(container):
			container.queue_free()
	command_containers.clear()

# 创建命令UI
func create_command_ui(command_data: Dictionary, index: int):
	# 复制模板
	var cmd_container = cmd_v_box_1.duplicate()
	cmd_container.visible = true
	grid.add_child(cmd_container)
	command_containers.append(cmd_container)
	
	# 获取子节点
	var cmd_button = cmd_container.get_node("Cmd")
	var edit_button = cmd_container.get_node("HBox/Edit")
	var delete_button = cmd_container.get_node("HBox/Delate")
	
	# 检查是否为参数化命令
	var arg1_enabled = command_data.get("arg1_enabled", false)
	var arg2_enabled = command_data.get("arg2_enabled", false)
	var is_parameterized = arg1_enabled or arg2_enabled
	
	# 设置命令按钮文本，为参数化命令添加指示器
	var button_text = command_data.name
	if is_parameterized:
		var param_indicators = []
		if arg1_enabled:
			param_indicators.append("①")
		if arg2_enabled:
			param_indicators.append("②")
		button_text += " " + " ".join(param_indicators)
	
	cmd_button.text = button_text
	cmd_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cmd_button.clip_contents = false
	if command_data.has("color"):
		cmd_button.modulate = Color.html(command_data.color)
	
	# 连接信号
	cmd_button.pressed.connect(_on_command_button_pressed.bind(index))
	edit_button.pressed.connect(_on_edit_button_pressed.bind(index))
	delete_button.pressed.connect(_on_delete_button_pressed.bind(index))

# 命令按钮被点击
func _on_command_button_pressed(index: int):
	command_executed.emit(index)

# 编辑按钮被点击
func _on_edit_button_pressed(index: int):
	if index >= 0 and index < commands_data.size():
		var command = commands_data[index]
		var color = Color.WHITE
		if command.has("color"):
			color = Color.html(command.color)
		command_edited.emit(index, command.name, command.content, color)

# 删除按钮被点击
func _on_delete_button_pressed(index: int):
	# 显示自定义确认弹窗
	if index >= 0 and index < commands_data.size():
		var command_name = commands_data[index].name
		# 发送信号给主界面显示删除确认弹窗
		command_delete_requested.emit(index, command_name)
