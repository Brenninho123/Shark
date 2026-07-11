package shark.functions;

import haxe.Http;
import haxe.Json;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import openfl.display.BitmapData;
import openfl.display.Loader;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.utils.ByteArray;

class ImageCreator
{
	public static var endpoint:String = "";
	public static var apiKey:String = "";

	public static function generate(prompt:String, onComplete:BitmapData->Void, onError:String->Void, width:Int = 512, height:Int = 512):Void
	{
		var request = new Http(endpoint);
		request.setHeader("Content-Type", "application/json");

		if (apiKey != "")
			request.setHeader("Authorization", 'Bearer $apiKey');

		var payload = {
			prompt: prompt,
			width: width,
			height: height
		};

		request.setPostData(Json.stringify(payload));

		request.onData = function(data:String):Void
		{
			try
			{
				var response = Json.parse(data);
				var base64Image:String = response.image;
				decodeBase64Image(base64Image, onComplete, onError);
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

	static function decodeBase64Image(base64Data:String, onComplete:BitmapData->Void, onError:String->Void):Void
	{
		var bytes:Bytes = Base64.decode(base64Data);
		var byteArray:ByteArray = ByteArray.fromBytes(bytes);

		var loader = new Loader();

		loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function(e:Event):Void
		{
			var bitmapData:BitmapData = cast(loader.content, openfl.display.Bitmap).bitmapData;
			onComplete(bitmapData);
		});

		loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):Void
		{
			onError(e.text);
		});

		loader.loadBytes(byteArray);
	}
}
