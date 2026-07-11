package shark.functions;

import haxe.Http;
import haxe.Json;

class ChatEngine
{
	public static var endpoint:String = "";
	public static var apiKey:String = "";
	public static var systemPrompt:String = "";

	static var history:Array<{role:String, content:String}> = [];

	public static function send(message:String, onComplete:String->Void, onError:String->Void):Void
	{
		history.push({role: "user", content: message});

		var request = new Http(endpoint);
		request.setHeader("Content-Type", "application/json");

		if (apiKey != "")
			request.setHeader("Authorization", 'Bearer $apiKey');

		var payload = {
			system: systemPrompt,
			messages: history
		};

		request.setPostData(Json.stringify(payload));

		request.onData = function(data:String):Void
		{
			try
			{
				var response = Json.parse(data);
				var reply:String = response.reply;

				history.push({role: "assistant", content: reply});
				onComplete(reply);
			}
			catch (e:Dynamic)
			{
				onError(Std.string(e));
			}
		};

		request.onError = function(msg:String):Void
		{
			onError(msg);
		};

		request.request(true);
	}

	public static function reset():Void
	{
		history = [];
	}
}
