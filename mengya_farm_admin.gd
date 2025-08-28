extends Control

@onready var cmd_input: LineEdit = $Panel/HBox1/CmdInput#通用命令输入框
@onready var contents: RichTextLabel = $Panel/Contents#显示命令执行成功后返回输出
@onready var status_label: Label = $Panel/StatusLabel #显示连接到服务器状态


@onready var add_quick_cmd_panel = $Panel/AddQuickCmdPanel
@onready var quick_cmd_panel = $Panel/QuickCmdPanel
@onready var connect_server_panel = $Panel/ConnectServerPanel #连接服务器面板


@onready var param_input_panel = $Panel/ParamInputPanel #参数输入弹窗
@onready var param_cmd_label = $Panel/ParamInputPanel/VBox/CmdLabel
@onready var param1_container = $Panel/ParamInputPanel/VBox/Param1Container
@onready var param1_input = $Panel/ParamInputPanel/VBox/Param1Container/Param1Input
@onready var param2_container = $Panel/ParamInputPanel/VBox/Param2Container
@onready var param2_input = $Panel/ParamInputPanel/VBox/Param2Container/Param2Input

# 命令确认弹窗相关引用
@onready var cmd_confirm_panel = $Panel/CmdConfirmPanel
@onready var cmd_name_label = $Panel/CmdConfirmPanel/VBox/CmdNameLabel
@onready var cmd_content_label = $Panel/CmdConfirmPanel/VBox/CmdContentLabel

# 删除命令确认弹窗相关引用
@onready var remove_cmd_content_label = $Panel/RemoveCmdConfirmPanel/VBox/ContentLabel

@onready var remove_cmd_confirm_panel: Panel = $Panel/RemoveCmdConfirmPanel



# WebSocket相关变量
var websocket: WebSocketPeer
var is_connected: bool = false
var is_authenticated: bool = false
var server_url: String = ""
var auth_key: String = ""

# 连接超时相关
var connection_timeout_timer: Timer
var connection_start_time: float = 0.0
var connection_timeout_seconds: float = 10.0  # 10秒连接超时

# 快捷命令相关
var quick_commands: Array = []
var quick_commands_file_path: String = "user://quick_commands.json"

# 参数化命令相关变量
var current_param_command: Dictionary = {}
var current_param_command_index: int = -1

# 命令确认相关变量
var current_confirm_command: String = ""
var current_confirm_command_name: String = ""

# 删除命令确认相关变量
var current_delete_command_index: int = -1
var current_delete_command_name: String = ""

#0.5秒计时器
var maxTime :float = 0.5
var currentTime :float = 0.0


#====================功能按钮列表==========================
#打开添加快捷命令面板
func _on_add_quick_cmd_pressed() -> void:
	add_quick_cmd_panel.show()
	pass 

#打开快捷命令面板
func _on_open_quick_cmd_pressed() -> void:
	quick_cmd_panel.show()
	pass 

#打开连接服务器面板
func _on_connect_server_pressed() -> void:
	connect_server_panel.show()
	pass 
	
#获取命令输入框命令并发送
func _on_send_button_pressed() -> void:
	var command = cmd_input.text.strip_edges()
	if command.is_empty():
		add_message("❌ 请输入命令")
		return
	
	if not is_connected:
		add_message("❌ 未连接到服务器")
		return
	
	if not is_authenticated:
		add_message("❌ 未通过服务器认证")
		return
	
	# 发送命令到服务器
	send_command(command)

	cmd_input.clear()
#====================功能按钮列表==========================

func _ready() -> void:
	# 连接信号
	connect_server_panel.connection_requested.connect(_on_connection_requested)
	connect_server_panel.connection_cancelled.connect(_on_connection_cancelled)
	
	# 初始化WebSocket
	websocket = WebSocketPeer.new()
	
	# 初始化连接超时计时器
	connection_timeout_timer = Timer.new()
	connection_timeout_timer.wait_time = connection_timeout_seconds
	connection_timeout_timer.one_shot = true
	connection_timeout_timer.timeout.connect(_on_connection_timeout)
	add_child(connection_timeout_timer)
	
	
	# 连接快捷命令面板信号
	add_quick_cmd_panel.command_added.connect(_on_quick_command_added)
	quick_cmd_panel.command_executed.connect(_on_quick_command_executed)
	quick_cmd_panel.command_edited.connect(_on_quick_command_edited)
	quick_cmd_panel.command_deleted.connect(_on_quick_command_deleted)
	quick_cmd_panel.command_delete_requested.connect(_on_quick_command_delete_requested)
	
	# 加载快捷命令
	load_quick_commands()
	
	# 初始化状态
	update_status("未连接")
	add_message("🌱 萌芽农场管理员控制台已启动")
	add_message("💡 请点击'🔗 连接服务器'按钮连接到游戏服务器")
	add_message("⚡ 您可以使用快捷命令功能来提高工作效率")
	add_message("📥📤 支持配置的导入和导出功能")
	
	# 刷新快捷命令面板
	refresh_quick_commands_panel()

func _process(_delta):
	if websocket:
		websocket.poll()

		var state = websocket.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			if not is_connected:
				is_connected = true
				# 停止连接超时计时器
				if connection_timeout_timer.time_left > 0:
					connection_timeout_timer.stop()
				update_status("已连接，等待认证")
				add_message("✅ 已连接到服务器，正在进行认证...")
				# 发送认证请求
				send_auth_request()
			
			# 处理接收到的消息
			while websocket.get_available_packet_count() > 0:
				var packet = websocket.get_packet()
				var message = packet.get_string_from_utf8()
				handle_server_message(message)
				
		elif state == WebSocketPeer.STATE_CLOSED:
			if is_connected:
				is_connected = false
				is_authenticated = false
				update_status("连接已断开")
				add_message("❌ 与服务器的连接已断开")



func _on_connection_requested(ip: String, port: String, auth_key_input: String):
	"""处理连接请求"""
	# 优化DNS解析：将localhost转换为127.0.0.1以避免DNS查询延迟
	var resolved_ip = ip
	if ip.to_lower() == "localhost":
		resolved_ip = "127.0.0.1"
	
	server_url = "ws://" + resolved_ip + ":" + port
	auth_key = auth_key_input
	
	add_message("正在连接到服务器: " + server_url)
	update_status("连接中...")
	
	# 连接到WebSocket服务器
	var error = websocket.connect_to_url(server_url)
	if error != OK:
		add_message("❌ 连接失败: " + str(error))
		update_status("连接失败")
		return
	
	# 启动连接超时检测
	start_connection_timeout()

func _on_connection_cancelled():
	"""处理连接取消"""
	add_message("连接已取消")

func send_auth_request():
	"""发送认证请求"""
	var auth_data = {
		"type": "auth",
		"auth_key": auth_key
	}
	send_json_message(auth_data)

func send_command(command: String):
	"""发送命令到服务器"""
	var command_data = {
		"type": "command",
		"command": command
	}
	send_json_message(command_data)
	add_message("> " + command)

func send_json_message(data: Dictionary):
	"""发送JSON消息到服务器"""
	if websocket and websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var json_string = JSON.stringify(data)
		websocket.send_text(json_string)

func handle_server_message(message: String):
	"""处理服务器消息"""
	var json = JSON.new()
	var parse_result = json.parse(message)
	
	if parse_result != OK:
		add_message("❌ 收到无效的服务器消息: " + message)
		return
	
	var data = json.data
	var message_type = data.get("type", "")
	
	match message_type:
		"welcome":
			handle_welcome_message(data)
		"auth_result":
			handle_auth_result(data)
		"command_result":
			handle_command_result(data)
		"error":
			handle_error_message(data)
		"pong":
			# 处理ping响应
			pass
		_:
			add_message("❓ 未知消息类型: " + message_type)

func handle_welcome_message(data: Dictionary):
	"""处理欢迎消息"""
	var welcome_msg = data.get("message", "欢迎")
	var server_version = data.get("server_version", "未知")
	add_message("🌱 " + welcome_msg)
	add_message("服务器版本: " + server_version)

func handle_auth_result(data: Dictionary):
	"""处理认证结果"""
	var success = data.get("success", false)
	var message = data.get("message", "")
	
	if success:
		is_authenticated = true
		update_status("已连接并认证")
		add_message("✅ " + message)
		add_message("现在可以发送命令了，输入 'help' 查看可用命令")
	else:
		is_authenticated = false
		update_status("认证失败")
		add_message("❌ " + message)
		# 断开连接
		websocket.close()

func handle_command_result(data: Dictionary):
	"""处理命令执行结果"""
	var command = data.get("command", "")
	var success = data.get("success", false)
	var output = data.get("output", "")
	
	if success:
		add_message("✅ 命令执行成功")
	else:
		add_message("❌ 命令执行失败")
	
	if not output.is_empty():
		# 分行显示输出
		var lines = output.split("\n")
		for line in lines:
			if not line.strip_edges().is_empty():
				add_message(line)

func handle_error_message(data: Dictionary):
	"""处理错误消息"""
	var error_msg = data.get("message", "未知错误")
	add_message("❌ " + error_msg)
	
	

func add_message(message: String):
	"""添加消息到输出区域"""
	var timestamp = Time.get_datetime_string_from_system().split("T")[1].substr(0, 8)
	
	# 使用BBCode格式化不同类型的消息
	var formatted_message = ""
	
	# 根据消息内容添加不同的颜色和样式
	if message.begins_with("✅"):
		# 成功消息 - 绿色
		formatted_message = "[color=#00FF88][b][" + timestamp + "][/b][/color] [color=#00DD66]" + message + "[/color]"
	elif message.begins_with("❌"):
		# 错误消息 - 红色
		formatted_message = "[color=#FF6B6B][b][" + timestamp + "][/b][/color] [color=#FF4444]" + message + "[/color]"
	elif message.begins_with("⏱️") or message.begins_with("💡"):
		# 提示消息 - 黄色
		formatted_message = "[color=#FFD93D][b][" + timestamp + "][/b][/color] [color=#FFC107]" + message + "[/color]"
	elif message.begins_with("🌱"):
		# 欢迎消息 - 青色
		formatted_message = "[color=#4ECDC4][b][" + timestamp + "][/b][/color] [color=#26C6DA]" + message + "[/color]"
	elif message.begins_with("❓"):
		# 未知消息 - 紫色
		formatted_message = "[color=#BB86FC][b][" + timestamp + "][/b][/color] [color=#9C27B0]" + message + "[/color]"
	elif message.begins_with(">"):
		# 用户输入命令 - 蓝色
		formatted_message = "[color=#64B5F6][b][" + timestamp + "][/b][/color] [color=#2196F3][b]" + message + "[/b][/color]"
	else:
		# 普通消息 - 浅灰色
		formatted_message = "[color=#B0BEC5][b][" + timestamp + "][/b][/color] [color=#ECEFF1]" + message + "[/color]"
	
	contents.append_text(formatted_message + "\n")
	


func update_status(status: String):
	"""更新状态标签"""
	# 根据状态添加不同的图标和颜色
	var status_text = ""
	var status_color = Color.WHITE
	
	if status.contains("未连接"):
		status_text = "📡 状态: ❌ " + status
		status_color = Color(1, 0.4, 0.4, 1)  # 红色
	elif status.contains("连接中"):
		status_text = "📡 状态: 🔄 " + status
		status_color = Color(1, 0.8, 0.2, 1)  # 黄色
	elif status.contains("已连接"):
		status_text = "📡 状态: ✅ " + status
		status_color = Color(0.2, 0.8, 0.4, 1)  # 绿色
	elif status.contains("认证失败") or status.contains("连接失败") or status.contains("连接超时"):
		status_text = "📡 状态: ❌ " + status
		status_color = Color(1, 0.3, 0.3, 1)  # 深红色
	elif status.contains("断开"):
		status_text = "📡 状态: ⚠️ " + status
		status_color = Color(1, 0.6, 0.2, 1)  # 橙色
	else:
		status_text = "📡 状态: " + status
		status_color = Color(0.96, 0.87, 0.26, 1)  # 默认黄色
	
	status_label.text = status_text
	status_label.modulate = status_color

func start_connection_timeout():
	"""启动连接超时检测"""
	connection_start_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	connection_timeout_timer.start()
	add_message("⏱️ 连接超时检测已启动（" + str(connection_timeout_seconds) + "秒）")

func _on_connection_timeout():
	"""处理连接超时"""
	if not is_connected:
		add_message("❌ 连接超时，请检查网络连接和服务器状态")
		update_status("连接超时")
		# 关闭WebSocket连接
		if websocket:
			websocket.close()
		add_message("💡 提示：如果使用localhost连接本地服务器，请尝试使用127.0.0.1")

# ==================== 快捷命令系统 ====================


# 显示命令确认对话框
func show_command_confirmation(command: String, command_name: String):
	# 存储当前要确认的命令信息
	current_confirm_command = command
	current_confirm_command_name = command_name
	
	# 设置弹窗内容
	if command_name != "":
		cmd_name_label.text = "命令名称: " + command_name
	else:
		cmd_name_label.text = "命令名称: 未命名命令"
	
	cmd_content_label.text = "命令内容: " + command
	
	# 显示确认弹窗
	cmd_confirm_panel.visible = true


# 保存快捷命令到JSON文件
func save_quick_commands():
	var file = FileAccess.open(quick_commands_file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(quick_commands)
		file.store_string(json_string)
		file.close()
		print("快捷命令已保存到: ", quick_commands_file_path)
	else:
		print("无法保存快捷命令文件")

# 从JSON文件加载快捷命令
func load_quick_commands():
	if FileAccess.file_exists(quick_commands_file_path):
		var file = FileAccess.open(quick_commands_file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				quick_commands = json.data
				print("已加载 ", quick_commands.size(), " 个快捷命令")
			else:
				print("解析快捷命令JSON失败")
				quick_commands = []
		else:
			print("无法读取快捷命令文件")
			quick_commands = []
	else:
		print("快捷命令文件不存在，将创建新文件")
		quick_commands = []

# 添加快捷命令
func _on_quick_command_added(command_name: String, command_content: String, command_color: Color, arg1_enabled: bool, arg2_enabled: bool):
	var new_command = {
		"name": command_name,
		"content": command_content,
		"color": command_color.to_html(),
		"arg1_enabled": arg1_enabled,
		"arg2_enabled": arg2_enabled
	}
	quick_commands.append(new_command)
	save_quick_commands()
	refresh_quick_commands_panel()
	add_message("已添加快捷命令: " + command_name)

# 执行快捷命令
func _on_quick_command_executed(command_index: int):
	if command_index >= 0 and command_index < quick_commands.size():
		var command = quick_commands[command_index]
		var arg1_enabled = command.get("arg1_enabled", false)
		var arg2_enabled = command.get("arg2_enabled", false)
		
		# 检查是否需要参数输入
		if arg1_enabled or arg2_enabled:
			show_param_input_dialog(command, command_index)
		else:
			show_command_confirmation(command.content, command.name)

# 编辑快捷命令（从快捷命令面板触发）
func _on_quick_command_edited(command_index: int, command_name: String, command_content: String, command_color: Color):
	if command_index >= 0 and command_index < quick_commands.size():
		var command = quick_commands[command_index]
		var arg1_enabled = command.get("arg1_enabled", false)
		var arg2_enabled = command.get("arg2_enabled", false)
		# 打开编辑面板
		add_quick_cmd_panel.set_edit_mode(command_name, command_content, command_color, command_index, arg1_enabled, arg2_enabled)

# 实际更新快捷命令（从添加面板触发）
func update_quick_command(command_index: int, command_name: String, command_content: String, command_color: Color, arg1_enabled: bool, arg2_enabled: bool):
	if command_index >= 0 and command_index < quick_commands.size():
		quick_commands[command_index] = {
			"name": command_name,
			"content": command_content,
			"color": command_color.to_html(),
			"arg1_enabled": arg1_enabled,
			"arg2_enabled": arg2_enabled
		}
		save_quick_commands()
		refresh_quick_commands_panel()
		add_message("已更新快捷命令: " + command_name)

# 删除快捷命令
func _on_quick_command_deleted(command_index: int):
	if command_index >= 0 and command_index < quick_commands.size():
		var command_name = quick_commands[command_index].name
		quick_commands.remove_at(command_index)
		save_quick_commands()
		refresh_quick_commands_panel()
		add_message("已删除快捷命令: " + command_name)

# 显示参数输入弹窗
func show_param_input_dialog(command: Dictionary, command_index: int):
	current_param_command = command
	current_param_command_index = command_index
	
	# 设置命令标签
	param_cmd_label.text = "命令: " + command.content
	
	# 显示/隐藏参数输入框
	var arg1_enabled = command.get("arg1_enabled", false)
	var arg2_enabled = command.get("arg2_enabled", false)
	
	param1_container.visible = arg1_enabled
	param2_container.visible = arg2_enabled
	
	# 清空输入框
	param1_input.text = ""
	param2_input.text = ""
	
	# 显示弹窗
	param_input_panel.show()
	
	# 聚焦到第一个可见的输入框
	if arg1_enabled:
		param1_input.grab_focus()
	elif arg2_enabled:
		param2_input.grab_focus()

# 参数输入弹窗 - 退出按钮
func _on_param_input_quit_pressed():
	param_input_panel.hide()
	current_param_command = {}
	current_param_command_index = -1

# 参数输入弹窗 - 取消按钮
func _on_param_input_cancel_pressed():
	param_input_panel.hide()
	current_param_command = {}
	current_param_command_index = -1

# 命令确认弹窗 - 退出按钮
func _on_cmd_confirm_quit_pressed():
	cmd_confirm_panel.visible = false

# 命令确认弹窗 - 确认按钮
func _on_cmd_confirm_confirm_pressed():
	cmd_confirm_panel.visible = false
	send_command(current_confirm_command)

# 命令确认弹窗 - 取消按钮
func _on_cmd_confirm_cancel_pressed():
	cmd_confirm_panel.visible = false

# 参数输入弹窗 - 执行按钮
func _on_param_input_execute_pressed():
	if current_param_command.is_empty():
		return
	
	var command_content = current_param_command.content
	var arg1_enabled = current_param_command.get("arg1_enabled", false)
	var arg2_enabled = current_param_command.get("arg2_enabled", false)
	
	# 构建最终命令
	var final_command = command_content
	
	if arg1_enabled:
		var param1 = param1_input.text.strip_edges()
		if param1.is_empty():
			add_message("❌ 请输入参数1")
			return
		final_command += " " + param1
	
	if arg2_enabled:
		var param2 = param2_input.text.strip_edges()
		if param2.is_empty():
			add_message("❌ 请输入参数2")
			return
		final_command += " " + param2
	
	# 隐藏弹窗
	param_input_panel.hide()
	
	# 直接执行命令，不需要二次确认
	send_command(final_command)
	
	# 清理状态
	current_param_command = {}
	current_param_command_index = -1

# 刷新快捷命令面板显示
func refresh_quick_commands_panel():
	quick_cmd_panel.update_commands(quick_commands)


#导入配置
func _on_import_config_pressed() -> void:
	# 从剪切板导入配置
	var clipboard_text = DisplayServer.clipboard_get()
	if clipboard_text.is_empty():
		add_message("❌ 剪切板为空，无法导入配置")
		return
	
	var json = JSON.new()
	var parse_result = json.parse(clipboard_text)
	if parse_result != OK:
		add_message("❌ 剪切板内容不是有效的JSON格式")
		return
	
	var config_data = json.data
	if not config_data.has("quick_commands"):
		add_message("❌ 配置格式错误，缺少quick_commands字段")
		return
	
	# 覆盖现有配置
	quick_commands = config_data["quick_commands"]
	save_quick_commands()
	refresh_quick_commands_panel()
	add_message("✅ 配置导入成功，共导入 " + str(quick_commands.size()) + " 个快捷命令")
	print("配置导入成功，共导入 ", quick_commands.size(), " 个快捷命令") 

#导出配置
func _on_export_config_pressed() -> void:
	# 将快捷命令配置导出到剪切板
	var config_data = {
		"quick_commands": quick_commands
	}
	var json_string = JSON.stringify(config_data)
	DisplayServer.clipboard_set(json_string)
	add_message("✅ 配置已导出到剪切板")
	print("配置已导出到剪切板，共 ", quick_commands.size(), " 个快捷命令")


# 移除命令确认弹窗 - 退出按钮
func _on_remove_cmd_confirm_quit_button_pressed() -> void:
	remove_cmd_confirm_panel.visible = false
	current_delete_command_index = -1
	current_delete_command_name = "" 

# 移除命令确认弹窗 - 确认按钮
func _on_remove_cmd_confirm_confirm_button_pressed() -> void:
	remove_cmd_confirm_panel.visible = false
	# 执行删除操作
	if current_delete_command_index >= 0:
		quick_commands.remove_at(current_delete_command_index)
		save_quick_commands()
		quick_cmd_panel.update_commands(quick_commands)
		current_delete_command_index = -1
		current_delete_command_name = "" 

# 移除命令确认弹窗 - 取消按钮
func _on_remove_cmd_confirm_cancel_button_pressed() -> void:
	remove_cmd_confirm_panel.visible = false
	current_delete_command_index = -1
	current_delete_command_name = ""

# 处理快捷命令删除请求
func _on_quick_command_delete_requested(command_index: int, command_name: String):
	# 存储要删除的命令信息
	current_delete_command_index = command_index
	current_delete_command_name = command_name
	
	# 设置弹窗内容
	remove_cmd_content_label.text = "确定要删除快捷命令 '%s' 吗？" % command_name
	
	# 显示删除确认弹窗
	remove_cmd_confirm_panel.visible = true
