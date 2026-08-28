package shark.data;

import haxe.Json;
import haxe.Timer;
import haxe.io.Bytes;
import haxe.crypto.Md5;
import haxe.crypto.Base64;
import flixel.util.FlxSave;
import shark.ui.debug.CrasherLog;

typedef DataEnvelope = {
	version:Int,
	checksum:String,
	obfuscated:Bool,
	payload:String,
	savedAt:Float
}

class DataFile<T>
{
	static inline var OBFUSCATION_KEY:Int = 91;

	public var name(default, null):String;
	public var slot(default, null):Int;
	public var currentVersion(default, null):Int;
	public var isDirty(default, null):Bool = false;
	public var isLoaded(default, null):Bool = false;
	public var lastSavedAt(default, null):Float = -1;
	public var lastLoadedAt(default, null):Float = -1;
	public var saveCount(default, null):Int = 0;
	public var corruptionRecoveries(default, null):Int = 0;

	public var obfuscate:Bool = false;
	public var autosaveDebounceMs:Int = 1500;
	public var validator:T->Bool;

	public var onSaved:Void->Void;
	public var onLoaded:Void->Void;
	public var onCorruptionRecovered:String->Void;

	public var data(default, null):T;

	var defaults:T;
	var migrations:Map<Int, Dynamic->Dynamic>;

	var mainSave:FlxSave;
	var backupSave:FlxSave;

	var autosaveTimer:Timer;
	var autosaveScheduled:Bool = false;

	public function new(name:String, defaults:T, currentVersion:Int = 1, ?migrations:Map<Int, Dynamic->Dynamic>, ?slot:Int = 0)
	{
		this.name = name;
		this.defaults = defaults;
		this.currentVersion = currentVersion;
		this.migrations = migrations != null ? migrations : new Map();
		this.slot = slot;
		this.data = cast cloneDynamic(defaults);

		mainSave = new FlxSave();

		if (!mainSave.bind(resolveSaveName("")))
			CrasherLog.logError('DataFile "$name" failed to bind main save slot.', "data");

		backupSave = new FlxSave();

		if (!backupSave.bind(resolveSaveName("_backup")))
			CrasherLog.logError('DataFile "$name" failed to bind backup save slot.', "data");
	}

	function resolveSaveName(suffix:String):String
	{
		var slotTag:String = slot > 0 ? '_slot$slot' : "";
		return 'shark_${name}$slotTag$suffix';
	}

	public function load():Bool
	{
		if (tryLoadFrom(mainSave, "main"))
		{
			finishLoad();
			return true;
		}

		if (tryLoadFrom(backupSave, "backup"))
		{
			corruptionRecoveries++;
			CrasherLog.logWarning('DataFile "$name" main save was unreadable - recovered from backup.', "data");

			if (onCorruptionRecovered != null)
				onCorruptionRecovered("main-corrupt-backup-restored");

			finishLoad();
			markDirty();
			return true;
		}

		corruptionRecoveries++;
		CrasherLog.logError('DataFile "$name" could not be loaded from main or backup - resetting to defaults.', "data");

		if (onCorruptionRecovered != null)
			onCorruptionRecovered("full-reset-to-defaults");

		data = cast cloneDynamic(defaults);
		finishLoad();
		markDirty();
		return false;
	}

	function finishLoad():Void
	{
		isLoaded = true;
		lastLoadedAt = Date.now().getTime() / 1000;

		if (onLoaded != null)
			onLoaded();
	}

	function tryLoadFrom(save:FlxSave, sourceLabel:String):Bool
	{
		try
		{
			var raw:String = Reflect.field(save.data, "envelope");

			if (raw == null || raw.length == 0)
				return false;

			var envelope:DataEnvelope = Json.parse(raw);
			var payload:String = envelope.obfuscated ? deobfuscate(envelope.payload) : envelope.payload;

			if (computeChecksum(payload) != envelope.checksum)
			{
				CrasherLog.logWarning('DataFile "$name" checksum mismatch in $sourceLabel save.', "data");
				return false;
			}

			var parsed:Dynamic = Json.parse(payload);
			parsed = runMigrations(parsed, envelope.version);

			var merged:Dynamic = deepMerge(defaults, parsed);
			var candidate:T = cast merged;

			if (validator != null && !validator(candidate))
			{
				CrasherLog.logWarning('DataFile "$name" failed validation in $sourceLabel save.', "data");
				return false;
			}

			data = candidate;
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	function runMigrations(parsed:Dynamic, fromVersion:Int):Dynamic
	{
		var version:Int = fromVersion;

		while (version < currentVersion)
		{
			if (migrations.exists(version))
			{
				try
				{
					parsed = migrations.get(version)(parsed);
				}
				catch (e:Dynamic)
				{
					CrasherLog.logWarning('DataFile "$name" migration from version $version failed.', "data");
					break;
				}
			}

			version++;
		}

		return parsed;
	}

	public function markDirty():Void
	{
		isDirty = true;
		scheduleSave(false);
	}

	public function set(newData:T):Void
	{
		data = newData;
		markDirty();
	}

	public function update(mutator:T->Void):Void
	{
		mutator(data);
		markDirty();
	}

	public function forceSave():Void
	{
		scheduleSave(true);
	}

	function scheduleSave(immediate:Bool):Void
	{
		if (immediate)
		{
			if (autosaveTimer != null)
			{
				autosaveTimer.stop();
				autosaveTimer = null;
			}

			autosaveScheduled = false;
			performSave();
			return;
		}

		if (autosaveScheduled)
			return;

		autosaveScheduled = true;

		autosaveTimer = Timer.delay(function():Void
		{
			autosaveScheduled = false;
			performSave();
		}, autosaveDebounceMs);
	}

	function performSave():Void
	{
		try
		{
			var json:String = Json.stringify(data);
			var checksum:String = computeChecksum(json);
			var payload:String = obfuscate ? obfuscateText(json) : json;

			var envelope:DataEnvelope = {
				version: currentVersion,
				checksum: checksum,
				obfuscated: obfuscate,
				payload: payload,
				savedAt: Date.now().getTime() / 1000
			};

			var envelopeJson:String = Json.stringify(envelope);
			var previous:String = Reflect.field(mainSave.data, "envelope");

			if (previous != null && previous.length > 0)
			{
				Reflect.setField(backupSave.data, "envelope", previous);
				backupSave.flush();
			}

			Reflect.setField(mainSave.data, "envelope", envelopeJson);
			mainSave.flush();

			isDirty = false;
			saveCount++;
			lastSavedAt = Date.now().getTime() / 1000;

			if (onSaved != null)
				onSaved();
		}
		catch (e:Dynamic)
		{
			CrasherLog.logError('DataFile "$name" failed to save: $e', "data");
		}
	}

	public function reset():Void
	{
		data = cast cloneDynamic(defaults);
		markDirty();
	}

	public function erase():Void
	{
		try
		{
			mainSave.erase();
			backupSave.erase();
		}
		catch (e:Dynamic) {}

		mainSave.bind(resolveSaveName(""));
		backupSave.bind(resolveSaveName("_backup"));

		data = cast cloneDynamic(defaults);
		isDirty = false;
		saveCount = 0;
	}

	public function exportToString():String
	{
		return Json.stringify(data);
	}

	public function importFromString(json:String):Bool
	{
		try
		{
			var parsed:Dynamic = Json.parse(json);
			var merged:Dynamic = deepMerge(defaults, parsed);
			var candidate:T = cast merged;

			if (validator != null && !validator(candidate))
				return false;

			data = candidate;
			markDirty();
			forceSave();
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	public function getStatusSummary():String
	{
		var lines:Array<String> = [];

		lines.push('name: $name${slot > 0 ? " (slot " + slot + ")" : ""}');
		lines.push('loaded: $isLoaded, dirty: $isDirty');
		lines.push('saves: $saveCount, corruption recoveries: $corruptionRecoveries');
		lines.push('last saved: ${lastSavedAt < 0 ? "never" : Std.string(lastSavedAt)}');
		lines.push('obfuscated: $obfuscate, version: $currentVersion');

		return lines.join("\n");
	}

	static function computeChecksum(text:String):String
	{
		return Md5.encode(text);
	}

	static function obfuscateText(text:String):String
	{
		var bytes:Bytes = Bytes.ofString(text);
		var xored:Bytes = Bytes.alloc(bytes.length);

		for (i in 0...bytes.length)
			xored.set(i, bytes.get(i) ^ OBFUSCATION_KEY);

		return Base64.encode(xored);
	}

	static function deobfuscate(encoded:String):String
	{
		var xored:Bytes = Base64.decode(encoded);
		var bytes:Bytes = Bytes.alloc(xored.length);

		for (i in 0...xored.length)
			bytes.set(i, xored.get(i) ^ OBFUSCATION_KEY);

		return bytes.toString();
	}

	static function cloneDynamic(value:Dynamic):Dynamic
	{
		return Json.parse(Json.stringify(value));
	}

	static function deepMerge(defaultsValue:Dynamic, loadedValue:Dynamic):Dynamic
	{
		if (loadedValue == null)
			return defaultsValue;

		if (Std.isOfType(defaultsValue, Array) || Std.isOfType(loadedValue, Array))
			return loadedValue;

		if (!Reflect.isObject(defaultsValue) || !Reflect.isObject(loadedValue))
			return loadedValue;

		var result:Dynamic = {};

		for (field in Reflect.fields(defaultsValue))
		{
			var defaultValue:Dynamic = Reflect.field(defaultsValue, field);

			if (Reflect.hasField(loadedValue, field))
				Reflect.setField(result, field, deepMerge(defaultValue, Reflect.field(loadedValue, field)));
			else
				Reflect.setField(result, field, defaultValue);
		}

		for (field in Reflect.fields(loadedValue))
			if (!Reflect.hasField(result, field))
				Reflect.setField(result, field, Reflect.field(loadedValue, field));

		return result;
	}
}
