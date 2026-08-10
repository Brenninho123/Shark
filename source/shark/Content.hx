package shark;

import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.utils.ByteArray;
import shark.FileSys;
import shark.ui.security.Guard;
import shark.ui.debug.CrasherLog;
import lime.system.System;

typedef ContentEntry = {
	filename:String,
	path:String,
	sizeBytes:Int,
	savedAt:Float,
	?prompt:String
}

class Content
{
	static inline var CONTENT_FOLDER:String = "content";

	public static var maxStoredItems:Int = 200;
	public static var maxStorageMB:Float = 250;

	static var isInitialized:Bool = false;

	public static function initialize():Void
	{
		if (isInitialized)
			return;

		isInitialized = true;
		ensureContentFolder();
	}

	public static function getContentDirectory():String
	{
		#if sys
		var base:String = System.applicationStorageDirectory;

		if (!StringTools.endsWith(base, "/") && !StringTools.endsWith(base, "\\"))
			base += "/";

		return base + CONTENT_FOLDER;
		#else
		return "";
		#end
	}

	public static function ensureContentFolder():Bool
	{
		return FileSys.ensureDirectory(getContentDirectory());
	}

	public static function saveImage(bitmapData:BitmapData, filename:String, ?prompt:String):Bool
	{
		#if sys
		if (bitmapData == null)
			return false;

		ensureContentFolder();

		var safeName:String = Guard.isSafeFilename(filename) ? filename : sanitizeFilename(filename);

		try
		{
			var encoded:ByteArray = bitmapData.encode(bitmapData.rect, new PNGEncoderOptions());
			var imagePath:String = FileSys.joinPath(getContentDirectory(), '$safeName.png');

			sys.io.File.saveBytes(imagePath, encoded);

			if (prompt != null)
			{
				var metaPath:String = FileSys.joinPath(getContentDirectory(), '$safeName.json');
				var meta:String = haxe.Json.stringify({prompt: prompt, savedAt: Date.now().getTime() / 1000});
				FileSys.writeText(metaPath, meta);
			}

			enforceQuota();

			return true;
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Content.saveImage failed: ${Std.string(e)}', "content");
			return false;
		}
		#else
		return false;
		#end
	}

	static function sanitizeFilename(filename:String):String
	{
		var buffer:StringBuf = new StringBuf();

		for (i in 0...filename.length)
		{
			var code:Int = filename.charCodeAt(i);
			var isAlphaNum:Bool = (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122);

			buffer.addChar(isAlphaNum || code == "_".code || code == "-".code ? code : "_".code);
		}

		return buffer.toString();
	}

	public static function listSavedImages():Array<ContentEntry>
	{
		var entries:Array<ContentEntry> = [];

		for (filename in FileSys.listFiles(getContentDirectory(), ".png"))
		{
			var baseName:String = filename.substr(0, filename.length - 4);
			var fullPath:String = FileSys.joinPath(getContentDirectory(), filename);
			var metaPath:String = FileSys.joinPath(getContentDirectory(), '$baseName.json');

			var prompt:String = null;
			var savedAt:Float = 0;

			var metaContent:String = FileSys.readText(metaPath);

			if (metaContent != null)
			{
				try
				{
					var meta:Dynamic = haxe.Json.parse(metaContent);
					prompt = meta.prompt;
					savedAt = meta.savedAt;
				}
				catch (e:Dynamic) {}
			}

			entries.push({
				filename: filename,
				path: fullPath,
				sizeBytes: FileSys.getFileSize(fullPath),
				savedAt: savedAt,
				prompt: prompt
			});
		}

		entries.sort(function(a:ContentEntry, b:ContentEntry):Int
		{
			return a.savedAt > b.savedAt ? -1 : (a.savedAt < b.savedAt ? 1 : 0);
		});

		return entries;
	}

	public static function findByPrompt(query:String):Array<ContentEntry>
	{
		var lowerQuery:String = query.toLowerCase();
		var results:Array<ContentEntry> = [];

		for (entry in listSavedImages())
			if (entry.prompt != null && entry.prompt.toLowerCase().indexOf(lowerQuery) != -1)
				results.push(entry);

		return results;
	}

	public static function deleteImage(filename:String):Bool
	{
		var baseName:String = StringTools.endsWith(filename, ".png") ? filename.substr(0, filename.length - 4) : filename;
		var imagePath:String = FileSys.joinPath(getContentDirectory(), '$baseName.png');
		var metaPath:String = FileSys.joinPath(getContentDirectory(), '$baseName.json');

		var deleted:Bool = FileSys.delete(imagePath);
		FileSys.delete(metaPath);

		return deleted;
	}

	public static function getStorageUsageMB():Float
	{
		return FileSys.getDirectorySize(getContentDirectory()) / 1024 / 1024;
	}

	public static function enforceQuota():Void
	{
		var entries:Array<ContentEntry> = listSavedImages();

		while (entries.length > maxStoredItems || getStorageUsageMB() > maxStorageMB)
		{
			if (entries.length == 0)
				break;

			var oldest:ContentEntry = entries[entries.length - 1];
			deleteImage(oldest.filename);
			entries.pop();
		}
	}

	public static function getSummary():String
	{
		var entries:Array<ContentEntry> = listSavedImages();
		return '${entries.length} saved images, ${Math.round(getStorageUsageMB() * 10) / 10}MB used';
	}
}
