package shark.ui.security;

import haxe.io.Bytes;
import haxe.crypto.Sha256;

#if cpp
import hxcpp.CPP;
#end

class Guard
{
	public static var maxInputLength:Int = 4000;
	public static var maxRequestsPerWindow:Int = 20;
	public static var rateLimitWindowSeconds:Float = 60;
	public static var maxImagePayloadBytes:Int = 15 * 1024 * 1024;

	public static var trustedHosts:Array<String> = [];

	static var rateLimitBuckets:Map<String, Array<Float>> = new Map();

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

		if (allowedUrlSchemes.indexOf(scheme) == -1)
			return false;

		if (trustedHosts.length == 0)
			return true;

		var host:String = extractHost(url, schemeEnd);

		return host != null && trustedHosts.indexOf(host) != -1;
	}

	static function extractHost(url:String, schemeEnd:Int):String
	{
		var hostStart:Int = schemeEnd + 3;
		var rest:String = url.substr(hostStart);

		var endIndex:Int = rest.length;

		for (marker in ["/", "?", "#", ":"])
		{
			var idx:Int = rest.indexOf(marker);

			if (idx != -1 && idx < endIndex)
				endIndex = idx;
		}

		var host:String = rest.substr(0, endIndex).toLowerCase();

		return host.length > 0 ? host : null;
	}

	public static function isValidPayloadSize(bytes:Bytes, maxSizeBytes:Int):Bool
	{
		return bytes != null && bytes.length > 0 && bytes.length <= maxSizeBytes;
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
		if (!isValidPayloadSize(bytes, maxImagePayloadBytes))
			return false;

		return isValidPngSignature(bytes) || isValidJpegSignature(bytes);
	}

	public static function hashContent(text:String):String
	{
		return Sha256.encode(text);
	}

	public static function generateToken(length:Int = 16):String
	{
		var chars:String = "0123456789abcdef";
		var buffer:StringBuf = new StringBuf();

		for (i in 0...length)
		{
			#if cpp
			var index:Int = CPP.secureRandomInt(0, chars.length - 1);
			#else
			var index:Int = Std.random(chars.length);
			#end

			buffer.addChar(chars.charCodeAt(index));
		}

		return buffer.toString();
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

	public static function isRateLimited(bucket:String = "default"):Bool
	{
		var timestamps:Array<Float> = getBucket(bucket);
		var now:Float = haxe.Timer.stamp();
		var windowStart:Float = now - rateLimitWindowSeconds;

		timestamps = timestamps.filter(function(t:Float):Bool
		{
			return t >= windowStart;
		});

		rateLimitBuckets.set(bucket, timestamps);

		return timestamps.length >= maxRequestsPerWindow;
	}

	public static function registerRequest(bucket:String = "default"):Void
	{
		var timestamps:Array<Float> = getBucket(bucket);
		timestamps.push(haxe.Timer.stamp());
		rateLimitBuckets.set(bucket, timestamps);
	}

	public static function checkAndRegister(bucket:String = "default"):Bool
	{
		if (isRateLimited(bucket))
			return false;

		registerRequest(bucket);
		return true;
	}

	public static function resetRateLimit(bucket:String = "default"):Void
	{
		rateLimitBuckets.set(bucket, []);
	}

	public static function resetAllRateLimits():Void
	{
		rateLimitBuckets = new Map();
	}

	static function getBucket(bucket:String):Array<Float>
	{
		if (!rateLimitBuckets.exists(bucket))
			rateLimitBuckets.set(bucket, []);

		return rateLimitBuckets.get(bucket);
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
