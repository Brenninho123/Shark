package shark.ui.debug;

import haxe.Json;
import haxe.Timer;
import haxe.CallStack;
import lime.manager.LimeManager;
import shark.FileSys;

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
	?count:Int,
	?category:String,
	?sessionId:String,
	?breadcrumbTrail:String,
	?stackTrace:String,
	?contextSnapshot:String,
	?buildVersion:String,
	?buildCommit:String,
	?buildEnvironment:String
}

typedef Breadcrumb = {
	timestamp:Float,
	message:String,
	category:String
}

class CrasherLog
{
	static inline var LOG_FILENAME:String = "crash_log.json";
	static inline var MAX_ENTRIES:Int = 200;
	static inline var MAX_BREADCRUMBS:Int = 25;
	static inline var DEDUPLICATION_WINDOW_SECONDS:Float = 5;
	static inline var MAX_MESSAGE_LENGTH:Int = 500;
	static inline var MAX_BREADCRUMB_LENGTH:Int = 120;
	static inline var MAX_STACK_TRACE_LENGTH:Int = 1000;
	static inline var MAX_LOG_FILE_BYTES:Int = 2000000;
	static inline var DEFAULT_CATEGORY:String = "general";

	public static var recentCrashes(default, null):Array<CrashEntry> = [];
	public static var totalCrashCount(default, null):Int = 0;
	public static var sessionId(default, null):String = generateSessionId();

	public static var minLogSeverity:String = "trace";
	public static var maxEntriesPerMinute:Int = 120;
	public static var persistDebounceMs:Int = 1500;

	public static var repeatedCrashWindowSeconds:Float = 30;
	public static var repeatedCrashThreshold:Int = 5;

	public static var autoReportSeverities:Array<String> = ["error", "security", "fatal"];
	public static var remoteReporter:CrashEntry->Void;
	public static var onRepeatedCrash:String->Int->Void;

	static var breadcrumbs:Array<Breadcrumb> = [];
	static var globalContext:Map<String, String> = new Map();

	static var loaded:Bool = false;
	static var cachedBuildInfo:Dynamic;

	static var entriesThisMinute:Int = 0;
	static var minuteWindowStart:Float = -1;
	static var suppressedThisWindow:Int = 0;

	static var hasFlaggedRepeatedCrash:Bool = false;

	static var persistScheduled:Bool = false;
	static var persistTimer:Timer;

	static var entryListeners:Array<CrashEntry->Void> = [];

	static var redactionPatterns:Array<EReg> = [
		~/sk-[a-zA-Z0-9]{16,}/g,
		~/Bearer\s+[A-Za-z0-9\-_.]+/g,
		~/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g
	];

	public static function log(message:String, severity:String = "error", category:String = DEFAULT_CATEGORY):Void
	{
		ensureLoaded();
		loadBuildInfoOnce();

		if (severityRank(severity) < severityRank(minLogSeverity))
			return;

		var now:Float = Date.now().getTime() / 1000;

		ensureFloodWindow(now);

		if (entriesThisMinute >= maxEntriesPerMinute)
		{
			suppressedThisWindow++;
			return;
		}

		entriesThisMinute++;

		storeEntry(sanitizeMessage(message), severity, category != null ? category : DEFAULT_CATEGORY, now);
	}

	public static function logError(message:String, category:String = DEFAULT_CATEGORY):Void
	{
		log(message, "error", category);
	}

	public static function logFatal(message:String, category:String = DEFAULT_CATEGORY):Void
	{
		log(message, "fatal", category);
	}

	public static function logSecurity(message:String, category:String = DEFAULT_CATEGORY):Void
	{
		log(message, "security", category);
	}

	public static function logWarning(message:String, category:String = DEFAULT_CATEGORY):Void
	{
		log(message, "warning", category);
	}

	public static function logInfo(message:String, category:String = DEFAULT_CATEGORY):Void
	{
		log(message, "info", category);
	}

	public static function addBreadcrumb(message:String, category:String = "action"):Void
	{
		var trimmed:String = StringTools.trim(message);
		var capped:String = trimmed.length > MAX_BREADCRUMB_LENGTH ? trimmed.substr(0, MAX_BREADCRUMB_LENGTH) : trimmed;

		breadcrumbs.push({
			timestamp: Date.now().getTime() / 1000,
			message: capped,
			category: category
		});

		if (breadcrumbs.length > MAX_BREADCRUMBS)
			breadcrumbs.shift();
	}

	public static function getBreadcrumbs():Array<Breadcrumb>
	{
		return breadcrumbs.copy();
	}

	public static function clearBreadcrumbs():Void
	{
		breadcrumbs = [];
	}

	public static function setContext(key:String, value:String):Void
	{
		globalContext.set(key, value);
	}

	public static function clearContext(?key:String):Void
	{
		if (key == null)
			globalContext = new Map();
		else
			globalContext.remove(key);
	}

	public static function addEntryListener(listener:CrashEntry->Void):Void
	{
		if (entryListeners.indexOf(listener) == -1)
			entryListeners.push(listener);
	}

	public static function removeEntryListener(listener:CrashEntry->Void):Void
	{
		entryListeners.remove(listener);
	}

	static function ensureFloodWindow(now:Float):Void
	{
		if (minuteWindowStart < 0)
		{
			minuteWindowStart = now;
			return;
		}

		if (now - minuteWindowStart < 60)
			return;

		if (suppressedThisWindow > 0)
		{
			var plural:String = suppressedThisWindow == 1 ? "entry" : "entries";
			storeEntry('Suppressed $suppressedThisWindow log $plural due to flood protection', "warning", DEFAULT_CATEGORY, now);
		}

		minuteWindowStart = now;
		entriesThisMinute = 0;
		suppressedThisWindow = 0;
	}

	static function storeEntry(sanitized:String, severity:String, category:String, now:Float):Void
	{
		totalCrashCount++;

		if (recentCrashes.length > 0)
		{
			var last:CrashEntry = recentCrashes[recentCrashes.length - 1];

			if (last.message == sanitized && last.severity == severity && last.category == category
				&& (now - last.timestamp) < DEDUPLICATION_WINDOW_SECONDS)
			{
				last.count = (last.count == null ? 1 : last.count) + 1;
				last.timestamp = now;

				schedulePersist(isCriticalSeverity(severity));
				notifyListeners(last);
				checkRepeatedCrash(severity, category);
				return;
			}
		}

		var isSevereEnough:Bool = severityRank(severity) >= severityRank("error");

		var entry:CrashEntry = {
			timestamp: now,
			message: sanitized,
			severity: severity,
			platform: LimeManager.getPlatformName(),
			buildSummary: LimeManager.getBuildSummary(),
			count: 1,
			category: category,
			sessionId: sessionId,
			breadcrumbTrail: isSevereEnough ? formatBreadcrumbs() : null,
			stackTrace: isSevereEnough ? captureStackTrace() : null,
			contextSnapshot: formatContext(),
			buildVersion: cachedBuildInfo != null ? Reflect.field(cachedBuildInfo, "version") : null,
			buildCommit: cachedBuildInfo != null ? Reflect.field(cachedBuildInfo, "commit") : null,
			buildEnvironment: cachedBuildInfo != null ? Reflect.field(cachedBuildInfo, "environment") : null
		};

		recentCrashes.push(entry);

		if (recentCrashes.length > MAX_ENTRIES)
			recentCrashes.shift();

		schedulePersist(isCriticalSeverity(severity));
		notifyListeners(entry);

		if (autoReportSeverities.indexOf(severity) != -1 && remoteReporter != null)
		{
			try
			{
				remoteReporter(entry);
			}
			catch (e:Dynamic) {}
		}

		checkRepeatedCrash(severity, category);
	}

	static function checkRepeatedCrash(severity:String, category:String):Void
	{
		if (severityRank(severity) < severityRank("error"))
			return;

		if (isCrashingRepeatedly(repeatedCrashWindowSeconds, repeatedCrashThreshold))
		{
			if (!hasFlaggedRepeatedCrash)
			{
				hasFlaggedRepeatedCrash = true;

				if (onRepeatedCrash != null)
					onRepeatedCrash(category, getRecentCount(repeatedCrashWindowSeconds));
			}
		}
		else
		{
			hasFlaggedRepeatedCrash = false;
		}
	}

	static function notifyListeners(entry:CrashEntry):Void
	{
		for (listener in entryListeners)
		{
			try
			{
				listener(entry);
			}
			catch (e:Dynamic) {}
		}
	}

	static function isCriticalSeverity(severity:String):Bool
	{
		return severity == "fatal" || severity == "security";
	}

	static function severityRank(severity:String):Int
	{
		return switch (severity)
		{
			case "trace": 0;
			case "debug": 1;
			case "info": 2;
			case "warning": 3;
			case "error": 4;
			case "security": 5;
			case "fatal": 6;
			default: 3;
		}
	}

	static function formatBreadcrumbs():Null<String>
	{
		if (breadcrumbs.length == 0)
			return null;

		var parts:Array<String> = [];

		for (crumb in breadcrumbs)
			parts.push('[${crumb.category}] ${crumb.message}');

		return parts.join(" -> ");
	}

	static function formatContext():Null<String>
	{
		var parts:Array<String> = [];

		for (key => value in globalContext)
			parts.push('$key=$value');

		return parts.length > 0 ? parts.join("; ") : null;
	}

	static function captureStackTrace():Null<String>
	{
		try
		{
			var text:String = CallStack.toString(CallStack.callStack());
			return text.length > MAX_STACK_TRACE_LENGTH ? text.substr(0, MAX_STACK_TRACE_LENGTH) : text;
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	static function sanitizeMessage(message:String):String
	{
		if (message == null)
			return "Unknown error";

		var trimmed:String = StringTools.trim(message);
		var redacted:String = redact(trimmed);

		return redacted.length > MAX_MESSAGE_LENGTH ? redacted.substr(0, MAX_MESSAGE_LENGTH) : redacted;
	}

	static function redact(message:String):String
	{
		var result:String = message;

		for (pattern in redactionPatterns)
			result = pattern.replace(result, "[REDACTED]");

		return result;
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

	static function loadBuildInfoOnce():Void
	{
		if (cachedBuildInfo != null)
			return;

		#if sys
		try
		{
			var path:String = "assets/data/build_info.json";

			if (FileSystem.exists(path))
				cachedBuildInfo = Json.parse(File.getContent(path));
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

	static function schedulePersist(immediate:Bool):Void
	{
		if (immediate)
		{
			if (persistTimer != null)
			{
				persistTimer.stop();
				persistTimer = null;
			}

			persistScheduled = false;
			writeToDisk();
			return;
		}

		if (persistScheduled)
			return;

		persistScheduled = true;

		persistTimer = Timer.delay(function():Void
		{
			persistScheduled = false;
			writeToDisk();
		}, persistDebounceMs);
	}

	public static function flush():Void
	{
		schedulePersist(true);
	}

	static function writeToDisk():Void
	{
		#if sys
		try
		{
			var path:String = getLogPath();

			rotateIfNeeded(path);

			File.saveContent(path, Json.stringify(recentCrashes));
		}
		catch (e:Dynamic) {}
		#end
	}

	static function rotateIfNeeded(path:String):Void
	{
		#if sys
		try
		{
			if (!FileSystem.exists(path))
				return;

			var size:Int = FileSystem.stat(path).size;

			if (size < MAX_LOG_FILE_BYTES)
				return;

			var rotated1:String = '$path.1';
			var rotated2:String = '$path.2';

			if (FileSystem.exists(rotated2))
				FileSystem.deleteFile(rotated2);

			if (FileSystem.exists(rotated1))
				FileSystem.rename(rotated1, rotated2);

			FileSystem.rename(path, rotated1);
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function clear():Void
	{
		recentCrashes = [];
		totalCrashCount = 0;
		hasFlaggedRepeatedCrash = false;
		schedulePersist(true);
	}

	public static function getEntriesByCategory(category:String):Array<CrashEntry>
	{
		ensureLoaded();

		var results:Array<CrashEntry> = [];

		for (entry in recentCrashes)
			if (entry.category == category)
				results.push(entry);

		return results;
	}

	public static function getEntriesBySeverity(severity:String):Array<CrashEntry>
	{
		ensureLoaded();

		var results:Array<CrashEntry> = [];

		for (entry in recentCrashes)
			if (entry.severity == severity)
				results.push(entry);

		return results;
	}

	public static function getCategorySummary():String
	{
		ensureLoaded();

		var counts:Map<String, Int> = new Map();

		for (entry in recentCrashes)
		{
			var category:String = entry.category != null ? entry.category : DEFAULT_CATEGORY;
			counts.set(category, (counts.exists(category) ? counts.get(category) : 0) + 1);
		}

		var lines:Array<String> = [];

		for (category => count in counts)
			lines.push('$category: $count');

		return lines.length > 0 ? lines.join(", ") : "no entries";
	}

	public static function getFormattedReport(maxEntries:Int = 20, ?severityFilter:String, ?categoryFilter:String):String
	{
		ensureLoaded();

		var filtered:Array<CrashEntry> = recentCrashes;

		if (severityFilter != null)
			filtered = filtered.filter(function(entry:CrashEntry):Bool
			{
				return entry.severity == severityFilter;
			});

		if (categoryFilter != null)
			filtered = filtered.filter(function(entry:CrashEntry):Bool
			{
				return entry.category == categoryFilter;
			});

		if (filtered.length == 0)
			return "No crashes logged.";

		var lines:Array<String> = [];
		var start:Int = Std.int(Math.max(0, filtered.length - maxEntries));

		for (i in start...filtered.length)
		{
			var entry:CrashEntry = filtered[i];
			var countTag:String = entry.count != null && entry.count > 1 ? ' (x${entry.count})' : "";
			var categoryTag:String = entry.category != null ? '[${entry.category}] ' : "";

			lines.push('$categoryTag[${entry.severity}] ${entry.message}$countTag - ${entry.buildSummary}');
		}

		return lines.join("\n");
	}

	public static function exportReport(?destPath:String, format:String = "text"):Bool
	{
		ensureLoaded();

		var extension:String = format == "json" ? ".report.json" : format == "markdown" ? ".report.md" : ".report.txt";
		var path:String = destPath != null ? destPath : (getLogPath() + extension);

		var content:String = switch (format)
		{
			case "json": buildJsonReport();
			case "markdown": buildMarkdownReport();
			default: buildTextReport();
		}

		return FileSys.writeText(path, content);
	}

	static function buildTextReport():String
	{
		var header:String = 'Shark crash report - ${Date.now().toString()}\nSession: $sessionId\nTotal entries: $totalCrashCount\nBy category: ${getCategorySummary()}\n\n';

		return header + getFormattedReport(recentCrashes.length);
	}

	static function buildJsonReport():String
	{
		return Json.stringify(recentCrashes, null, "\t");
	}

	static function buildMarkdownReport():String
	{
		var lines:Array<String> = [
			"# Shark Crash Report",
			"",
			'Generated: ${Date.now().toString()}',
			'Session: $sessionId',
			'Total entries: $totalCrashCount',
			'By category: ${getCategorySummary()}',
			"",
			"| Severity | Category | Count | Message | Build |",
			"|---|---|---|---|---|"
		];

		for (entry in recentCrashes)
		{
			var count:Int = entry.count != null ? entry.count : 1;
			var category:String = entry.category != null ? entry.category : DEFAULT_CATEGORY;

			lines.push('| ${entry.severity} | $category | $count | ${entry.message} | ${entry.buildSummary} |');
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

	public static function getStatusSummary():String
	{
		ensureLoaded();

		var lines:Array<String> = [];

		lines.push('session: $sessionId');
		lines.push('total: $totalCrashCount, stored: ${recentCrashes.length}/$MAX_ENTRIES');
		lines.push('by category: ${getCategorySummary()}');
		lines.push('this minute: $entriesThisMinute logged, $suppressedThisWindow suppressed');
		lines.push('breadcrumbs: ${breadcrumbs.length}/$MAX_BREADCRUMBS');

		if (cachedBuildInfo != null)
			lines.push('build: ${Reflect.field(cachedBuildInfo, "version")} (${Reflect.field(cachedBuildInfo, "commit")}) [${Reflect.field(cachedBuildInfo, "environment")}]');

		return lines.join("\n");
	}

	static function generateSessionId():String
	{
		var timePart:String = Std.string(Std.int(Date.now().getTime()));
		var randomPart:String = Std.string(Std.int(Math.random() * 1000000));

		return '$timePart-$randomPart';
	}
}
