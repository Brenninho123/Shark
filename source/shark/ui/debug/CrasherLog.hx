package shark.ui.debug;

import haxe.Json;
import lime.manager.LimeManager;

#if sys
import sys.io.File;
import sys.FileSystem;
import lime.system.System;
#end

typedef CrashEntry = {
	timestamp:Float,
	message:String,
	severity:String,
	platform:String,
	buildSummary:String,
	?count:Int
}

class CrasherLog
{
	static inline var LOG_FILENAME:String = "crash_log.json";
	static inline var MAX_ENTRIES:Int = 200;
	static inline var DEDUPLICATION_WINDOW_SECONDS:Float = 5;
	static inline var MAX_MESSAGE_LENGTH:Int = 500;

	public static var recentCrashes(default, null):Array<CrashEntry> = [];
	public static var totalCrashCount(default, null):Int = 0;

	static var loaded:Bool = false;

	public static function log(message:String, severity:String = "error"):Void
	{
		ensureLoaded();

		var sanitized:String = sanitizeMessage(message);
		var now:Float = Date.now().getTime() / 1000;

		totalCrashCount++;

		if (recentCrashes.length > 0)
		{
			var last:CrashEntry = recentCrashes[recentCrashes.length - 1];

			if (last.message == sanitized && last.severity == severity && (now - last.timestamp) < DEDUPLICATION_WINDOW_SECONDS)
			{
				last.count = (last.count == null ? 1 : last.count) + 1;
				last.timestamp = now;
				persist();
				return;
			}
		}

		var entry:CrashEntry = {
			timestamp: now,
			message: sanitized,
			severity: severity,
			platform: LimeManager.getPlatformName(),
			buildSummary: LimeManager.getBuildSummary(),
			count: 1
		};

		recentCrashes.push(entry);

		if (recentCrashes.length > MAX_ENTRIES)
			recentCrashes.shift();

		persist();
	}

	public static function logError(message:String):Void
	{
		log(message, "error");
	}

	public static function logSecurity(message:String):Void
	{
		log(message, "security");
	}

	public static function logWarning(message:String):Void
	{
		log(message, "warning");
	}

	static function sanitizeMessage(message:String):String
	{
		if (message == null)
			return "Unknown error";

		var trimmed:String = StringTools.trim(message);

		return trimmed.length > MAX_MESSAGE_LENGTH ? trimmed.substr(0, MAX_MESSAGE_LENGTH) : trimmed;
	}

	static function ensureLoaded():Void
	{
		if (loaded)
			return;

		loaded = true;

		#if sys
		try
		{
			var path:String = getLogPath();

			if (FileSystem.exists(path))
			{
				var raw:String = File.getContent(path);
				var parsed:Array<CrashEntry> = Json.parse(raw);

				recentCrashes = parsed;
				totalCrashCount = recentCrashes.length;
			}
		}
		catch (e:Dynamic) {}
		#end
	}

	static function getLogPath():String
	{
		#if sys
		var base:String = System.applicationStorageDirectory;

		if (!StringTools.endsWith(base, "/") && !StringTools.endsWith(base, "\\"))
			base += "/";

		return base + LOG_FILENAME;
		#else
		return "";
		#end
	}

	static function persist():Void
	{
		#if sys
		try
		{
			File.saveContent(getLogPath(), Json.stringify(recentCrashes));
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function clear():Void
	{
		recentCrashes = [];
		totalCrashCount = 0;
		persist();
	}

	public static function getFormattedReport(maxEntries:Int = 20):String
	{
		ensureLoaded();

		if (recentCrashes.length == 0)
			return "No crashes logged.";

		var lines:Array<String> = [];
		var start:Int = Std.int(Math.max(0, recentCrashes.length - maxEntries));

		for (i in start...recentCrashes.length)
		{
			var entry:CrashEntry = recentCrashes[i];
			var countTag:String = entry.count != null && entry.count > 1 ? ' (x${entry.count})' : "";

			lines.push('[${entry.severity}] ${entry.message}$countTag - ${entry.buildSummary}');
		}

		return lines.join("\n");
	}

	public static function getRecentCount(windowSeconds:Float):Int
	{
		ensureLoaded();

		var now:Float = Date.now().getTime() / 1000;
		var count:Int = 0;

		for (entry in recentCrashes)
			if (now - entry.timestamp <= windowSeconds)
				count++;

		return count;
	}

	public static function isCrashingRepeatedly(windowSeconds:Float, threshold:Int):Bool
	{
		return getRecentCount(windowSeconds) >= threshold;
	}
}
