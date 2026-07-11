package shark.mobile;

import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.utils.ByteArray;
import lime.system.System;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class StorageUtil
{
	public static inline var CONTENT_FOLDER:String = "content";

	public static function getContentPath():String
	{
		var base:String = System.applicationStorageDirectory;

		if (!StringTools.endsWith(base, "/") && !StringTools.endsWith(base, "\\"))
			base += "/";

		return base + CONTENT_FOLDER;
	}

	public static function ensureContentFolder():Bool
	{
		#if sys
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

	public static function saveImage(bitmapData:BitmapData, filename:String, onComplete:String->Void, onError:String->Void):Void
	{
		#if sys
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

		try
		{
			var safeName:String = sanitizeFilename(filename);
			var fullPath:String = getContentPath() + "/" + safeName + ".png";

			var encoded:ByteArray = bitmapData.encode(bitmapData.rect, new PNGEncoderOptions());

			File.saveBytes(fullPath, encoded);

			onComplete(fullPath);
		}
		catch (e:Dynamic)
		{
			onError(Std.string(e));
		}
		#else
		onError("Saving images is not supported on this target");
		#end
	}

	public static function listSavedImages():Array<String>
	{
		#if sys
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

	public static function deleteImage(filename:String):Bool
	{
		#if sys
		var safeName:String = sanitizeFilename(filename);
		var fullPath:String = getContentPath() + "/" + safeName + ".png";

		try
		{
			if (FileSystem.exists(fullPath))
			{
				FileSystem.deleteFile(fullPath);
				return true;
			}

			return false;
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
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
