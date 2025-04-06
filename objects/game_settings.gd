class_name GameSettings extends Object

const LOBBY_TYPES: Dictionary = {
	Steam.LobbyType.LOBBY_TYPE_PUBLIC: "Public",
	Steam.LobbyType.LOBBY_TYPE_FRIENDS_ONLY: "Friends Only",
	Steam.LobbyType.LOBBY_TYPE_PRIVATE: "Invite Only"
}

const MIN_PLAYERS = 2
const MAX_PLAYERS = 4

var lobby_name: String
var lobby_type: Steam.LobbyType
var max_players: int:
	set(value):
		max_players = value
		if max_players < MIN_PLAYERS:
			max_players = MIN_PLAYERS
		elif max_players > MAX_PLAYERS:
			max_players = MAX_PLAYERS
