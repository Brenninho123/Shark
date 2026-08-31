package shark.online;

import haxe.Json;
import haxe.Timer;
import shark.mobile.backend.HapticStyle;
import shark.mobile.backend.Vibration;
import shark.online.Network;
import shark.online.NetworkResponse;
import shark.online.User;
import shark.server.Servers;
import shark.ui.debug.CrasherLog;

enum abstract MultiplayerStatus(Int)
{
	var DISCONNECTED = 0;
	var CONNECTING = 1;
	var IN_ROOM = 2;
	var FAILED = 3;
}

typedef MultiplayerPlayer = {
	id:String,
	name:String,
	isHost:Bool,
	?score:Int,
	?lastSeen:Float
}

typedef MultiplayerRoom = {
	code:String,
	gameId:String,
	hostId:String,
	players:Array<MultiplayerPlayer>,
	state:Dynamic,
	?createdAt:Float
}

class MultiPlayer
{
	static inline var MAX_POLL_FAILURES:Int = 5;

	public static var status(default, null):MultiplayerStatus = DISCONNECTED;
	public static var currentRoom(default, null):MultiplayerRoom;
	public static var localPlayerId(default, null):String;
	public static var pollIntervalSeconds:Float = 2;
	public static var maxPlayers:Int = 8;
	public static var maxRetries:Int = 2;

	public static var onRoomUpdated:MultiplayerRoom->Void;
	public static var onPlayerJoined:MultiplayerPlayer->Void;
	public static var onPlayerLeft:MultiplayerPlayer->Void;
	public static var onError:String->Void;
	public static var onDisconnected:Void->Void;

	static var pollTimer:Timer;
	static var knownPlayerIds:Array<String> = [];
	static var isPolling:Bool = false;
	static var pollFailureCount:Int = 0;
	static var totalRoomsJoined:Int = 0;

	public static function isAvailable():Bool
	{
		return getEndpoint() != null;
	}

	public static function createRoom(gameId:String, playerName:String, onComplete:MultiplayerRoom->Void):Void
	{
		if (status == CONNECTING || status == IN_ROOM)
		{
			reportError("Already connecting or already in a room");
			return;
		}

		status = CONNECTING;
		localPlayerId = resolveLocalPlayerId();

		var payload:Dynamic = {
			type: "create_room",
			gameId: gameId,
			playerId: localPlayerId,
			playerName: playerName
		};

		sendRequest(payload, function(response:Dynamic):Void
		{
			var room:MultiplayerRoom = parseRoom(response);

			if (room == null)
			{
				failConnection("Invalid response creating room");
				return;
			}

			enterRoom(room);
			onComplete(room);
		});
	}

	public static function joinRoom(code:String, playerName:String, onComplete:MultiplayerRoom->Void):Void
	{
		if (status == CONNECTING || status == IN_ROOM)
		{
			reportError("Already connecting or already in a room");
			return;
		}

		var trimmedCode:String = StringTools.trim(code).toUpperCase();

		if (trimmedCode.length == 0)
		{
			reportError("Room code is empty");
			return;
		}

		status = CONNECTING;
		localPlayerId = resolveLocalPlayerId();

		var payload:Dynamic = {
			type: "join_room",
			code: trimmedCode,
			playerId: localPlayerId,
			playerName: playerName
		};

		sendRequest(payload, function(response:Dynamic):Void
		{
			var room:MultiplayerRoom = parseRoom(response);

			if (room == null)
			{
				failConnection("Invalid response joining room");
				return;
			}

			if (room.players.length > maxPlayers)
			{
				failConnection("Room is full");
				return;
			}

			enterRoom(room);
			onComplete(room);
		});
	}

	public static function leaveRoom():Void
	{
		if (status != IN_ROOM || currentRoom == null)
			return;

		var payload:Dynamic = {
			type: "leave_room",
			code: currentRoom.code,
			playerId: localPlayerId
		};

		sendRequest(payload, function(_):Void {}, function(_):Void {});

		stopPolling();
		disconnect();
	}

	public static function sendAction(actionType:String, data:Dynamic):Void
	{
		if (status != IN_ROOM || currentRoom == null)
		{
			reportError("Not currently in a room");
			return;
		}

		var payload:Dynamic = {
			type: "action",
			code: currentRoom.code,
			playerId: localPlayerId,
			action: actionType,
			data: data
		};

		sendRequest(payload, function(response:Dynamic):Void
		{
			var room:MultiplayerRoom = parseRoom(response);

			if (room != null)
				applyRoomUpdate(room);
		});
	}

	static function resolveLocalPlayerId():String
	{
		return User.userId != null ? User.userId : "guest-" + Std.string(Std.int(Math.random() * 1000000));
	}

	static function enterRoom(room:MultiplayerRoom):Void
	{
		status = IN_ROOM;
		currentRoom = room;
		knownPlayerIds = [for (player in room.players) player.id];
		totalRoomsJoined++;

		CrasherLog.addBreadcrumb('Joined multiplayer room "${room.code}" for game "${room.gameId}"', "multiplayer");
		Vibration.trigger(HapticStyle.SUCCESS);

		startPolling();
	}

	static function startPolling():Void
	{
		if (isPolling)
			return;

		isPolling = true;
		pollFailureCount = 0;
		scheduleNextPoll();
	}

	static function stopPolling():Void
	{
		isPolling = false;

		if (pollTimer != null)
		{
			pollTimer.stop();
			pollTimer = null;
		}
	}

	static function scheduleNextPoll():Void
	{
		if (!isPolling)
			return;

		pollTimer = Timer.delay(pollRoomState, Std.int(pollIntervalSeconds * 1000));
	}

	static function pollRoomState():Void
	{
		if (!isPolling || currentRoom == null)
			return;

		var payload:Dynamic = {
			type: "poll",
			code: currentRoom.code,
			playerId: localPlayerId
		};

		sendRequest(payload, function(response:Dynamic):Void
		{
			pollFailureCount = 0;

			var room:MultiplayerRoom = parseRoom(response);

			if (room != null)
				applyRoomUpdate(room);

			scheduleNextPoll();
		}, function(error:String):Void
		{
			pollFailureCount++;

			if (pollFailureCount >= MAX_POLL_FAILURES)
			{
				CrasherLog.logWarning('Multiplayer polling failed $pollFailureCount times in a row - disconnecting from room "${currentRoom.code}"',
					"multiplayer");

				stopPolling();
				disconnect();

				if (onDisconnected != null)
					onDisconnected();

				return;
			}

			scheduleNextPoll();
		});
	}

	static function applyRoomUpdate(room:MultiplayerRoom):Void
	{
		currentRoom = room;

		var newPlayerIds:Array<String> = [for (player in room.players) player.id];

		for (player in room.players)
			if (knownPlayerIds.indexOf(player.id) == -1 && onPlayerJoined != null)
				onPlayerJoined(player);

		for (oldId in knownPlayerIds)
		{
			if (newPlayerIds.indexOf(oldId) == -1 && onPlayerLeft != null)
			{
				var leftPlayer:MultiplayerPlayer = {id: oldId, name: "", isHost: false};
				onPlayerLeft(leftPlayer);
			}
		}

		knownPlayerIds = newPlayerIds;

		if (onRoomUpdated != null)
			onRoomUpdated(room);
	}

	static function sendRequest(payload:Dynamic, onComplete:Dynamic->Void, ?onFail:String->Void):Void
	{
		var endpoint:String = getEndpoint();

		if (endpoint == null || endpoint.length == 0)
		{
			var message:String = "No multiplayer endpoint configured for the active server";
			CrasherLog.logWarning(message, "multiplayer");

			if (onFail != null)
				onFail(message);
			else
				failConnection(message);

			return;
		}

		Network.postJson(endpoint, payload, new Map<String, String>(), function(response:NetworkResponse):Void
		{
			if (!response.success)
			{
				if (onFail != null)
					onFail(response.error);
				else
					failConnection(response.error);

				return;
			}

			try
			{
				var parsed:Dynamic = Json.parse(response.data);
				onComplete(parsed);
			}
			catch (e:Dynamic)
			{
				var message:String = 'Invalid multiplayer response: ${Std.string(e)}';

				if (onFail != null)
					onFail(message);
				else
					failConnection(message);
			}
		}, null, maxRetries);
	}

	static function getEndpoint():String
	{
		var profile = Servers.getActiveProfile();

		if (profile == null)
			return null;

		return safeField(profile, "multiplayerEndpoint");
	}

	static function safeField(source:Dynamic, field:String):String
	{
		try
		{
			var value:Dynamic = Reflect.field(source, field);
			return value != null && Std.string(value).length > 0 ? Std.string(value) : null;
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	static function parseRoom(raw:Dynamic):MultiplayerRoom
	{
		if (raw == null)
			return null;

		try
		{
			var playersRaw:Array<Dynamic> = Reflect.field(raw, "players");
			var players:Array<MultiplayerPlayer> = [];

			if (playersRaw != null)
			{
				for (entry in playersRaw)
				{
					players.push({
						id: Reflect.field(entry, "id"),
						name: Reflect.field(entry, "name"),
						isHost: Reflect.field(entry, "isHost") == true,
						score: Reflect.hasField(entry, "score") ? Reflect.field(entry, "score") : 0
					});
				}
			}

			return {
				code: Reflect.field(raw, "code"),
				gameId: Reflect.field(raw, "gameId"),
				hostId: Reflect.field(raw, "hostId"),
				players: players,
				state: Reflect.hasField(raw, "state") ? Reflect.field(raw, "state") : {},
				createdAt: Reflect.hasField(raw, "createdAt") ? Reflect.field(raw, "createdAt") : 0
			};
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	static function failConnection(message:String):Void
	{
		status = FAILED;
		CrasherLog.logWarning('Multiplayer error: $message', "multiplayer");
		Vibration.trigger(HapticStyle.WARNING);

		if (onError != null)
			onError(message);
	}

	static function reportError(message:String):Void
	{
		if (onError != null)
			onError(message);
	}

	static function disconnect():Void
	{
		status = DISCONNECTED;
		currentRoom = null;
		knownPlayerIds = [];
	}

	public static function isHost():Bool
	{
		return currentRoom != null && localPlayerId != null && currentRoom.hostId == localPlayerId;
	}

	public static function getLocalPlayer():MultiplayerPlayer
	{
		if (currentRoom == null)
			return null;

		for (player in currentRoom.players)
			if (player.id == localPlayerId)
				return player;

		return null;
	}

	public static function getStatusSummary():String
	{
		var roomInfo:String = currentRoom != null ? '${currentRoom.code} (${currentRoom.players.length}/$maxPlayers players)' : "none";
		return 'MultiPlayer: status=$status, room=$roomInfo, rooms joined this session=$totalRoomsJoined';
	}
}
