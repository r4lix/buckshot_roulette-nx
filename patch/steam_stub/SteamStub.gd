extends Node
## Offline stand-in for the GodotSteam singleton ("Steam") used by Buckshot Roulette.
## Registered as the autoload "Steam" so the game's scripts compile and run without Steam.
## Everything reports "offline": no lobbies, no leaderboards, achievements are no-ops.

signal avatar_loaded(avatar_id, size, data)
signal join_requested(lobby_id, steam_id)
signal leaderboard_find_result(handle, found)
signal leaderboard_score_uploaded(success, handle, score_details)
signal leaderboard_scores_downloaded(message, handle, result)
signal lobby_chat_update(lobby_id, changed_id, making_change_id, chat_state)
signal lobby_created(connect, lobby_id)
signal lobby_joined(lobby_id, permissions, locked, response)
signal lobby_match_list(lobbies)
signal p2p_session_connect_fail(steam_id, session_error)
signal p2p_session_request(remote_id)
signal persona_state_change(steam_id, flags)

const CHAT_MEMBER_STATE_CHANGE_ENTERED = 1
const CHAT_MEMBER_STATE_CHANGE_LEFT = 2
const CHAT_MEMBER_STATE_CHANGE_DISCONNECTED = 4
const CHAT_MEMBER_STATE_CHANGE_KICKED = 8
const CHAT_MEMBER_STATE_CHANGE_BANNED = 16

const CHAT_ROOM_ENTER_RESPONSE_SUCCESS = 1
const CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST = 2
const CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED = 3
const CHAT_ROOM_ENTER_RESPONSE_FULL = 4
const CHAT_ROOM_ENTER_RESPONSE_ERROR = 5
const CHAT_ROOM_ENTER_RESPONSE_BANNED = 6
const CHAT_ROOM_ENTER_RESPONSE_LIMITED = 7
const CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED = 8
const CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN = 9
const CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU = 10
const CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER = 11

const LEADERBOARD_DATA_REQUEST_GLOBAL = 0
const LEADERBOARD_DATA_REQUEST_GLOBAL_AROUND_USER = 1
const LEADERBOARD_DATA_REQUEST_FRIENDS = 2

const LOBBY_TYPE_PRIVATE = 0
const LOBBY_TYPE_FRIENDS_ONLY = 1
const LOBBY_TYPE_PUBLIC = 2

const P2P_SEND_UNRELIABLE = 0
const P2P_SEND_RELIABLE = 2

func steamInit(_retrieve_stats := true, _app_id := 0, _embed_callbacks := false) -> Dictionary:
	return {"status": 20, "verbal": "Steam not available (offline stub)"}

func run_callbacks() -> void: pass
func loggedOn() -> bool: return false
func getSteamID() -> int: return 0
func getPersonaName() -> String: return "Player"
func getFriendPersonaName(_id = 0) -> String: return "Player"
func getPlayerAvatar(_size = 2, _id = 0) -> void: pass
func isSteamRunningOnSteamDeck() -> bool: return false
func activateGameOverlayInviteDialog(_lobby = 0) -> void: pass

func setAchievement(_name) -> bool: return false
func clearAchievement(_name) -> bool: return false
func storeStats() -> bool: return false

func findLeaderboard(_name) -> void: pass
func setLeaderboardDetailsMax(_m = 0) -> int: return 0
func uploadLeaderboardScore(_score = 0, _keep_best = true, _details = PackedInt32Array(), _handle = 0) -> void: pass
func downloadLeaderboardEntries(_start = 0, _end = 0, _type = 0, _handle = 0) -> void: pass
func getLeaderboardEntryCount(_handle = 0) -> int: return 0

func createLobby(_type = 0, _max = 2) -> void: pass
func joinLobby(_id = 0) -> void: pass
func leaveLobby(_id = 0) -> void: pass
func requestLobbyList() -> void: call_deferred("emit_signal", "lobby_match_list", [])
func addRequestLobbyListDistanceFilter(_f = 0) -> void: pass
func addRequestLobbyListResultCountFilter(_c = 0) -> void: pass
func getLobbyData(_id = 0, _key = "") -> String: return ""
func setLobbyData(_id = 0, _key = "", _value = "") -> bool: return false
func setLobbyJoinable(_id = 0, _j = true) -> bool: return false
func setLobbyType(_id = 0, _t = 0) -> bool: return false
func setLobbyMemberLimit(_id = 0, _l = 0) -> bool: return false
func getLobbyOwner(_id = 0) -> int: return 0
func getNumLobbyMembers(_id = 0) -> int: return 0
func getLobbyMemberByIndex(_id = 0, _i = 0) -> int: return 0

func acceptP2PSessionWithUser(_id = 0) -> bool: return false
func allowP2PPacketRelay(_a = true) -> bool: return false
func closeP2PSessionWithUser(_id = 0) -> bool: return true
func getAvailableP2PPacketSize(_ch = 0) -> int: return 0
func readP2PPacket(_size = 0, _ch = 0) -> Dictionary: return {}
func sendP2PPacket(_id = 0, _data = PackedByteArray(), _type = 0, _ch = 0) -> bool: return false
