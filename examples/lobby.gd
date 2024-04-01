extends Node


@onready var create_lobby_btn: Button = $CreateLobbyBtn
@onready var invite_friend_btn: Button = $InviteFriendBtn
@onready var member_list: ItemList = $ItemList
@onready var connected_gui: Control = $ConnectedGUI

@onready var start_btn: Button = $ConnectedGUI/StartBtn

@onready var rpc_on_server_btn: Button = $ConnectedGUI/RPCOnServerBtn
@onready var rpc_on_server_label: Label = $ConnectedGUI/RPCOnServerBtn/Label

@onready var rset_slider: HSlider = $ConnectedGUI/RSetSlider
@onready var rset_label: Label = $ConnectedGUI/RSetSlider/Label

@onready var change_owner_btn: Button = $ConnectedGUI/ChangeHostBtn

@onready var chat_line_edit: LineEdit = $ConnectedGUI/ChatLineEdit
@onready var chat_send_btn: Button = $ConnectedGUI/ChatSendBtn
@onready var chat_window: ItemList = $ConnectedGUI/ChatWindow

var invite_intent: bool = false

func _ready() -> void:
	connected_gui.visible = false
	rpc_on_server_label.text = ""
	
	SteamLobby.lobby_created.connect(on_lobby_created)
	SteamLobby.lobby_joined.connect(on_lobby_joined)
	SteamLobby.lobby_owner_changed.connect(on_lobby_owner_changed)
	SteamLobby.player_joined_lobby.connect(on_player_joined)
	SteamLobby.player_left_lobby.connect(on_player_left)
	SteamLobby.chat_message_received.connect(on_chat_message_received)
	
	SteamNetwork.register_rpcs(self,
		[
			["_server_button_pressed", SteamNetwork.PERMISSION.CLIENT_ALL],
			["_client_button_pressed", SteamNetwork.PERMISSION.SERVER],
		]
	)
	
	SteamNetwork.peer_status_updated.connect(on_peer_status_changed)
	SteamNetwork.all_peers_connected.connect(on_all_peers_connected)
	
	create_lobby_btn.pressed.connect(on_create_lobby_pressed)
	invite_friend_btn.pressed.connect(on_invite_friend_pressed)
	
	chat_line_edit.text_submitted.connect(on_chat_text_entered)
	chat_send_btn.pressed.connect(on_chat_send_pressed)

	rpc_on_server_btn.pressed.connect(on_rpc_server_pressed)
	
	change_owner_btn.pressed.connect(on_change_owner_pressed)

###########################################
# Steam Lobby/Network connect functions

func on_lobby_created(_lobby_id: int) -> void:
	render_lobby_members()
	if invite_intent:
		invite_intent = false
		on_invite_friend_pressed()

func on_lobby_joined(_lobby_id: int) -> void:
	render_lobby_members()
	connected_gui.visible = true
	create_lobby_btn.text = "Leave Lobby"
	
func on_lobby_owner_changed(old_owner: int, new_owner: int) -> void:
	render_lobby_members()
	print("Lobby Ownership Changed: %s => %s" % [old_owner, new_owner])

func on_player_joined(_steam_id: int) -> void:
	render_lobby_members()

func on_player_left(steam_id: int) -> void:
	if steam_id == Steam.getSteamID():
		connected_gui.visible = false
	render_lobby_members()

func on_chat_message_received(_sender_steam_id: int, steam_name: String, message: String) -> void:
	var display_msg: String = steam_name + ": " + message
	chat_window.add_item(display_msg)

func on_peer_status_changed(_steam_id: int) -> void:
	# This means we have confirmed a P2P connection going back and forth
	# between us and this steam user.
	render_lobby_members()

func on_all_peers_connected() -> void:
	start_btn.disabled = false

################################################
# SteamNetwork Examples:

func on_rpc_server_pressed() -> void:
	SteamNetwork.rpc_on_server(self, "_server_button_pressed", ["Hello World"])

func _server_button_pressed(sender_id: int, message: String) -> void:
	# Server could validate incoming data here, perform state change etc.
	message = Steam.getFriendPersonaName(sender_id) + " says: " + message
	var number: int = randi() % 100
	SteamNetwork.rpc_all_clients(self, "_client_button_pressed", [message, number])

func _client_button_pressed(_sender_id: int, message: String, number: int) -> void:
	rpc_on_server_label.text = "%s (%s)" % [message, number]

################################################
# Basic lobby connections/setup

func on_change_owner_pressed() -> void:
	var user_index: int = member_list.get_selected_items()[0]
	var user: int = SteamLobby.get_lobby_members().keys()[user_index]
	var me: int = Steam.getSteamID()
	if user != me and SteamLobby.is_owner():
		Steam.setLobbyOwner(SteamLobby.get_lobby_id(), user)

func on_create_lobby_pressed() -> void:
	if SteamLobby.in_lobby():
		SteamLobby.leave_lobby()
		create_lobby_btn.text = "Create Lobby"
	else:
		SteamLobby.create_lobby(Steam.LOBBY_TYPE_PUBLIC, 3)

func on_invite_friend_pressed() -> void:
	if SteamLobby.in_lobby():
		#pop up invite
		Steam.activateGameOverlayInviteDialog(SteamLobby.get_lobby_id())
	else:
		invite_intent = true
		on_create_lobby_pressed()

func on_chat_text_entered(message: String) -> void:
	SteamLobby.send_chat_message(message)
	chat_line_edit.clear()
	
func on_chat_send_pressed() -> void:
	var message: String = chat_line_edit.text
	on_chat_text_entered(message)

func render_lobby_members() -> void:
	member_list.clear()
	
	change_owner_btn.visible = SteamLobby.is_owner()

	var lobby_members: Dictionary = SteamLobby.get_lobby_members()
	for member_id: int in lobby_members:
		var member: String = lobby_members[member_id]
		if not SteamNetwork.is_peer_connected(member_id):
			start_btn.disabled = true
		var owner_str: String = "[Host] " if SteamLobby.is_owner(member_id) else ""
		var connected_str: String = "Connecting ..." if not SteamNetwork.is_peer_connected(member_id) else "Connected"
		var display_str: String = "%s%s (%s)" % [owner_str, member, connected_str]
		member_list.add_item(display_str)
