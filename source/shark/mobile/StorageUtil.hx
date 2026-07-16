package shark.mobile;

import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.utils.ByteArray;
import lime.system.System;
import shark.ui.security.Guard;

#if (android || ios)
import sys.FileSystem;
import sys.io.File;
import haxe.Json;
#end

typedef StoredImageInfo = {
	filename:String,
	path:String,
	sizeBytes:Int,
	?prompt:String,
	?savedAt:Float
}

class StorageUtil
{
	public static inline var CONTENT_FOLDER:String = "content";
	public static var maxStoredImages:Int = 200;
	public static var maxStorageMB:Float = 250;

	public static function isSupported():Bool
	{
		#if (android || ios)
		return true;
		#else
		return false;
		#end
	}

	public static function getContentPath():String
	{
		var base:String = System.applicationStorageDirectory;

		if (!StringTools.endsWith(base, "/") && !StringTools.endsWith(base, "\\"))
			base += "/";

		return base + CONTENT_FOLDER;
	}

	public static function ensureContentFolder():Bool
	{
		#if (android || ios)
		var path:String = getContentPath();

		try
		{
			if (!FileSystem.exists(path))
				FileSystem.createDirectory(path);

			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	public static function saveImage(bitmapData:BitmapData, filename:String, onComplete:String->Void, onError:String->Void, ?prompt:String):Void
	{
		#if (android || ios)
		if (bitmapData == null)
		{
			onError("No image data to save");
			return;
		}

		if (!ensureContentFolder())
		{
			onError("Could not create content folder");
			return;
		}

		var safeName:String = sanitizeFilename(filename);

		if (!Guard.isSafeFilename(safeName + ".png"))
		{
			onError("Unsafe filename rejected");
			return;
		}

		try
		{
			enforceQuota();

			var fullPath:String = getContentPath() + "/" + safeName + ".png";
			var encoded:ByteArray = bitmapData.encode(bitmapData.rect, new PNGEncoderOptions());

			File.saveBytes(fullPath, encoded);
			writeMetadata(safeName, prompt);

			onComplete(fullPath);
		}
		catch (e:Dynamic)
		{
			onError(Std.string(e));
		}
		#else
		onError("Image storage is only available on mobile targets");
		#end
	}

	static function writeMetadata(safeName:String, ?prompt:String):Void
	{
		#if (android || ios)
		try
		{
			var metadata = {
				prompt: prompt != null ? prompt : "",
				savedAt: Date.now().getTime()
			};

			File.saveContent(getContentPath() + "/" + safeName + ".json", Json.stringify(metadata));
		}
		catch (e:Dynamic) {}
		#end
	}

	static function readMetadata(safeName:String):{?prompt:String, ?savedAt:Float}
	{
		#if (android || ios)
		try
		{
			var metaPath:String = getContentPath() + "/" + safeName + ".json";

			if (!FileSystem.exists(metaPath))
				return {};

			return Json.parse(File.getContent(metaPath));
		}
		catch (e:Dynamic)
		{
			return {};
		}
		#else
		return {};
		#end
	}

	public static function listSavedImages():Array<String>
	{
		#if (android || ios)
		var path:String = getContentPath();

		if (!FileSystem.exists(path))
			return [];

		return FileSystem.readDirectory(path).filter(function(name:String):Bool
		{
			return StringTools.endsWith(name.toLowerCase(), ".png");
		});
		#else
		return [];
		#end
	}

	public static function listSavedImagesWithMetadata():Array<StoredImageInfo>
	{
		var result:Array<StoredImageInfo> = [];

		#if (android || ios)
		for (filename in listSavedImages())
		{
			var safeName:String = filename.substr(0, filename.length - 4);
			var fullPath:String = getContentPath() + "/" + filename;

			var sizeBytes:Int = 0;

			try
			{
				sizeBytes = FileSystem.stat(fullPath).size;
			}
			catch (e:Dynamic) {}

			var meta = readMetadata(safeName);

			result.push({
				filename: filename,
				path: fullPath,
				sizeBytes: sizeBytes,
				prompt: meta.prompt,
				savedAt: meta.savedAt
			});
		}

		result.sort(function(a:StoredImageInfo, b:StoredImageInfo):Int
		{
			var aTime:Float = a.savedAt != null ? a.savedAt : 0;
			var bTime:Float = b.savedAt != null ? b.savedAt : 0;
			return aTime < bTime ? 1 : (aTime > bTime ? -1 : 0);
		});
		#end

		return result;
	}

	public static function getStorageUsageMB():Float
	{
		var totalBytes:Int = 0;

		for (info in listSavedImagesWithMetadata())
			totalBytes += info.sizeBytes;

		return totalBytes / 1024 / 1024;
	}

	static function enforceQuota():Void
	{
		#if (android || ios)
		var images:Array<StoredImageInfo> = listSavedImagesWithMetadata();

		while (images.length >= maxStoredImages)
		{
			var oldest:StoredImageInfo = images.pop();
			deleteImage(oldest.filename.substr(0, oldest.filename.length - 4));
		}

		var usageMB:Float = getStorageUsageMB();

		while (usageMB > maxStorageMB && images.length > 0)
		{
			var oldest:StoredImageInfo = images.pop();
			deleteImage(oldest.filename.substr(0, oldest.filename.length - 4));
			usageMB -= oldest.sizeBytes / 1024 / 1024;
		}
		#end
	}

	public static function deleteImage(filename:String):Bool
	{
		#if (android || ios)
		var safeName:String = sanitizeFilename(filename);
		var imagePath:String = getContentPath() + "/" + safeName + ".png";
		var metaPath:String = getContentPath() + "/" + safeName + ".json";

		try
		{
			var deleted:Bool = false;

			if (FileSystem.exists(imagePath))
			{
				FileSystem.deleteFile(imagePath);
				deleted = true;
			}

			if (FileSystem.exists(metaPath))
				FileSystem.deleteFile(metaPath);

			return deleted;
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	public static function clearAll():Int
	{
		var count:Int = 0;

		#if (android || ios)
		for (filename in listSavedImages())
		{
			deleteImage(filename.substr(0, filename.length - 4));
			count++;
		}
		#end

		return count;
	}

	static function sanitizeFilename(filename:String):String
	{
		var result:String = filename;
		var invalidChars:Array<String> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"];

		for (char in invalidChars)
			result = StringTools.replace(result, char, "_");

		return result;
	}
}
