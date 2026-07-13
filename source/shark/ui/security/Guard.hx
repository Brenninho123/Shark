package shark.ui.security;

import haxe.io.Bytes;
import haxe.crypto.Sha256;

class Guard
{
	public static var maxInputLength:Int = 4000;
	public static var maxRequestsPerWindow:Int = 20;
	public static var rateLimitWindowSeconds:Float = 60;

	static var requestTimestamps:Array<Float> = [];

	static var suspiciousPatterns:Array<String> = [
		"ignore previous instructions",
		"ignore all previous instructions",
		"disregard previous instructions",
		"you are now",
		"system prompt",
		"reveal your instructions",
		"jailbreak"
	];

	static var allowedUrlSchemes:Array<String> = ["https", "http"];

	public static function sanitizeInput(text:String):String
	{
		if (text == null)
			return "";

		var result:String = StringTools.trim(text);

		if (result.length > maxInputLength)
			result = result.substr(0, maxInputLength);

		var buffer:StringBuf = new StringBuf();

		for (i in 0...result.length)
		{
			var code:Int = result.charCodeAt(i);

			if (code == 9 || code == 10 || code == 13 || code >= 32)
				buffer.addChar(code);
		}

		return buffer.toString();
	}

	public static function isValidUrl(url:String):Bool
	{
		if (url == null || url.length == 0)
			return false;

		var schemeEnd:Int = url.indexOf("://");

		if (schemeEnd == -1)
			return false;

		var scheme:String = url.substr(0, schemeEnd).toLowerCase();

		return allowedUrlSchemes.indexOf(scheme) != -1;
	}

	public static function isValidPngSignature(bytes:Bytes):Bool
	{
		if (bytes == null || bytes.length < 8)
			return false;

		var signature:Array<Int> = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

		for (i in 0...signature.length)
			if (bytes.get(i) != signature[i])
				return false;

		return true;
	}

	public static function isValidJpegSignature(bytes:Bytes):Bool
	{
		if (bytes == null || bytes.length < 3)
			return false;

		return bytes.get(0) == 0xFF && bytes.get(1) == 0xD8 && bytes.get(2) == 0xFF;
	}

	public static function isValidImagePayload(bytes:Bytes):Bool
	{
		return isValidPngSignature(bytes) || isValidJpegSignature(bytes);
	}

	public static function hashContent(text:String):String
	{
		return Sha256.encode(text);
	}

	public static function detectPromptInjection(text:String):Bool
	{
		if (text == null)
			return false;

		var normalized:String = text.toLowerCase();

		for (pattern in suspiciousPatterns)
			if (normalized.indexOf(pattern) != -1)
				return true;

		return false;
	}

	public static function isRateLimited():Bool
	{
		var now:Float = haxe.Timer.stamp();
		var windowStart:Float = now - rateLimitWindowSeconds;

		requestTimestamps = requestTimestamps.filter(function(t:Float):Bool
		{
			return t >= windowStart;
		});

		return requestTimestamps.length >= maxRequestsPerWindow;
	}

	public static function registerRequest():Void
	{
		requestTimestamps.push(haxe.Timer.stamp());
	}

	public static function checkAndRegister():Bool
	{
		if (isRateLimited())
			return false;

		registerRequest();
		return true;
	}

	public static function resetRateLimit():Void
	{
		requestTimestamps = [];
	}

	public static function isSafeFilename(filename:String):Bool
	{
		if (filename == null || filename.length == 0)
			return false;

		if (filename.indexOf("..") != -1)
			return false;

		if (filename.indexOf("/") != -1 || filename.indexOf("\\") != -1)
			return false;

		return true;
	}
}
