extends Panel

@onready var ip_input: LineEdit = $IP/IPInput #输入要连接到服务器IP
@onready var port_input: LineEdit = $Port/PortInput #输入要连接到服务器端口
@onready var key_input: LineEdit = $Key/KeyInput #输入要连接到服务端的秘钥 进行验证

# 信号定义
signal connection_requested(ip: String, port: String, auth_key: String)
signal connection_cancelled

# 服务器配置相关
var server_config: Dictionary = {}
var server_config_file_path: String = "user://server_config.json"

func _ready() -> void:
	self.hide()
	# 加载服务器配置
	load_server_config()
	# 如果没有配置，设置默认值（使用127.0.0.1避免DNS解析延迟）
	if server_config.is_empty():
		ip_input.text = "127.0.0.1"
		port_input.text = "7071"
		key_input.text = "mengya2024"
	else:
		apply_config_to_ui()
		
	

		
func _on_quit_button_pressed() -> void:
	self.hide()
	connection_cancelled.emit()

func _on_connect_server_pressed() -> void:
	# 获取输入的连接信息
	var ip = ip_input.text.strip_edges()
	var port = port_input.text.strip_edges()
	var auth_key = key_input.text.strip_edges()
	
	# 验证输入
	if ip.is_empty():
		print("❌ 请输入服务器IP地址")
		return
	
	if port.is_empty():
		print("❌ 请输入服务器端口")
		return
	
	if auth_key.is_empty():
		print("❌ 请输入认证密钥")
		return
	
	# 保存服务器配置
	server_config["ip"] = ip
	server_config["port"] = port.to_int()
	server_config["key"] = auth_key
	save_server_config()
	
	# 发送连接请求信号
	connection_requested.emit(ip, port, auth_key)
	self.hide()

# 保存服务器配置到JSON文件
func save_server_config():
	var file = FileAccess.open(server_config_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(server_config))
		file.close()
		print("服务器配置已保存到: ", server_config_file_path)
	else:
		print("无法创建服务器配置文件")

# 从JSON文件加载服务器配置
func load_server_config():
	if FileAccess.file_exists(server_config_file_path):
		var file = FileAccess.open(server_config_file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				server_config = json.data
				# 确保端口号为整数类型
				if server_config.has("port") and typeof(server_config["port"]) == TYPE_FLOAT:
					server_config["port"] = int(server_config["port"])
				print("服务器配置已加载，共 ", server_config.size(), " 个配置项")
			else:
				print("解析服务器配置JSON失败")
				server_config = {}
		else:
			print("无法读取服务器配置文件")
			server_config = {}
	else:
		print("服务器配置文件不存在，使用默认配置")
		server_config = {}

# 将服务器配置应用到UI
func apply_config_to_ui():
	if server_config.has("ip"):
		ip_input.text = server_config["ip"]
	if server_config.has("port"):
		# 确保端口号为整数类型
		var port_value = server_config["port"]
		if typeof(port_value) == TYPE_FLOAT:
			port_value = int(port_value)
		port_input.text = str(port_value)
	if server_config.has("key"):
		key_input.text = server_config["key"]
