package shark.mobile;

import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.geom.Matrix;
import openfl.utils.ByteArray;
import lime.system.System;
import shark.ui.debug.CrasherLog;
import shark.ui.security.Guard;

#if sys
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
	public static var generateThumbnails:Bool = true;
	public static var thumbnailMaxDimension:Int = 256;

	static inline var THUMBNAIL_SUFFIX:String = "_thumb.png";

	static var cachedInfo:Array<StoredImageInfo>;
	static var cacheValid:Bool = false;

	public static function isSupported():Bool
	{
		#if sys
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
			CrasherLog.logWarning('Failed to create content folder: ${Std.string(e)}', "storage");
			return false;
		}
		#else
		return false;
		#end
	}

	public static function saveImage(bitmapData:BitmapData, filename:String, onComplete:String->Void, onError:String->Void, ?prompt:String):Void
	{
		#if sys
		if (bitmapData == null || bitmapData.width <= 0 || bitmapData.height <= 0)
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

			if (generateThumbnails)
				saveThumbnail(bitmapData, safeName);

			invalidateCache();

			onComplete(fullPath);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to save image "$safeName": ${Std.string(e)}', "storage");
			onError(Std.string(e));
		}
		#else
		onError("Image storage is only available on this target");
		#end
	}

	static function saveThumbnail(source:BitmapData, safeName:String):Void
	{
		#if sys
		try
		{
			var thumbnail:BitmapData = createThumbnail(source, thumbnailMaxDimension);
			var encoded:ByteArray = thumbnail.encode(thumbnail.rect, new PNGEncoderOptions());
			File.saveBytes(getContentPath() + "/" + safeName + THUMBNAIL_SUFFIX, encoded);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to generate thumbnail for "$safeName": ${Std.string(e)}', "storage");
		}
		#end
	}

	static function createThumbnail(source:BitmapData, maxDimension:Int):BitmapData
	{
		var scale:Float = Math.min(1, maxDimension / Math.max(source.width, source.height));
		var thumbWidth:Int = Std.int(Math.max(1, source.width * scale));
		var thumbHeight:Int = Std.int(Math.max(1, source.height * scale));

		var thumbnail:BitmapData = new BitmapData(thumbWidth, thumbHeight, true, 0x00000000);
		var matrix:Matrix = new Matrix();
		matrix.scale(scale, scale);
		thumbnail.draw(source, matrix, null, null, null, true);

		return thumbnail;
	}

	public static function getThumbnailPath(filename:String):String
	{
		var safeName:String = stripPngExtension(sanitizeFilename(filename));
		return getContentPath() + "/" + safeName + THUMBNAIL_SUFFIX;
	}

	public static function hasThumbnail(filename:String):Bool
	{
		#if sys
		return FileSystem.exists(getThumbnailPath(filename));
		#else
		return false;
		#end
	}

	static function stripPngExtension(name:String):String
	{
		return StringTools.endsWith(name.toLowerCase(), ".png") ? name.substr(0, name.length - 4) : name;
	}

	static function writeMetadata(safeName:String, ?prompt:String):Void
	{
		#if sys
		try
		{
			var metadata = {
				prompt: prompt != null ? prompt : "",
				savedAt: Date.now().getTime()
			};

			File.saveContent(getContentPath() + "/" + safeName + ".json", Json.stringify(metadata));
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to write metadata for "$safeName": ${Std.string(e)}', "storage");
		}
		#end
	}

	static function readMetadata(safeName:String):{?prompt:String, ?savedAt:Float}
	{
		#if sys
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

	static function invalidateCache():Void
	{
		cacheValid = false;
		cachedInfo = null;
	}

	public static function listSavedImages():Array<String>
	{
		#if sys
		var path:String = getContentPath();

		if (!FileSystem.exists(path))
			return [];

		return FileSystem.readDirectory(path).filter(function(name:String):Bool
		{
			var lower:String = name.toLowerCase();
			return StringTools.endsWith(lower, ".png") && !StringTools.endsWith(lower, THUMBNAIL_SUFFIX);
		});
		#else
		return [];
		#end
	}

	public static function listSavedImagesWithMetadata():Array<StoredImageInfo>
	{
		if (cacheValid && cachedInfo != null)
			return cachedInfo.copy();

		var result:Array<StoredImageInfo> = [];

		#if sys
		for (filename in listSavedImages())
		{
			var safeName:String = stripPngExtension(filename);
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

		cachedInfo = result;
		cacheValid = true;

		return result.copy();
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
		#if sys
		var images:Array<StoredImageInfo> = listSavedImagesWithMetadata();

		while (images.length >= maxStoredImages)
		{
			var oldest:StoredImageInfo = images.pop();
			deleteImage(stripPngExtension(oldest.filename));
		}

		var usageMB:Float = getStorageUsageMB();

		while (usageMB > maxStorageMB && images.length > 0)
		{
			var oldest:StoredImageInfo = images.pop();
			deleteImage(stripPngExtension(oldest.filename));
			usageMB -= oldest.sizeBytes / 1024 / 1024;
		}
		#end
	}

	public static function deleteImage(filename:String):Bool
	{
		#if sys
		var safeName:String = sanitizeFilename(filename);

		if (!Guard.isSafeFilename(safeName + ".png"))
		{
			CrasherLog.logSecurity('Rejected delete for unsafe filename "$filename"', "storage");
			return false;
		}

		var imagePath:String = getContentPath() + "/" + safeName + ".png";
		var metaPath:String = getContentPath() + "/" + safeName + ".json";
		var thumbPath:String = getContentPath() + "/" + safeName + THUMBNAIL_SUFFIX;

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

			if (FileSystem.exists(thumbPath))
				FileSystem.deleteFile(thumbPath);

			invalidateCache();

			return deleted;
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to delete image "$safeName": ${Std.string(e)}', "storage");
			return false;
		}
		#else
		return false;
		#end
	}

	public static function clearAll():Int
	{
		var count:Int = 0;

		#if sys
		for (filename in listSavedImages())
		{
			deleteImage(stripPngExtension(filename));
			count++;
		}

		invalidateCache();
		#end

		return count;
	}

	public static function findByPrompt(searchText:String):Array<StoredImageInfo>
	{
		var query:String = searchText.toLowerCase();
		var results:Array<StoredImageInfo> = [];

		for (info in listSavedImagesWithMetadata())
		{
			if (info.prompt != null && info.prompt.toLowerCase().indexOf(query) != -1)
				results.push(info);
		}

		return results;
	}

	public static function renameImage(oldFilename:String, newFilename:String):Bool
	{
		#if sys
		var oldSafeName:String = sanitizeFilename(oldFilename);
		var newSafeName:String = sanitizeFilename(newFilename);

		if (!Guard.isSafeFilename(newSafeName + ".png"))
		{
			CrasherLog.logSecurity('Rejected rename to unsafe filename "$newFilename"', "storage");
			return false;
		}

		var oldImagePath:String = getContentPath() + "/" + oldSafeName + ".png";
		var newImagePath:String = getContentPath() + "/" + newSafeName + ".png";
		var oldMetaPath:String = getContentPath() + "/" + oldSafeName + ".json";
		var newMetaPath:String = getContentPath() + "/" + newSafeName + ".json";
		var oldThumbPath:String = getContentPath() + "/" + oldSafeName + THUMBNAIL_SUFFIX;
		var newThumbPath:String = getContentPath() + "/" + newSafeName + THUMBNAIL_SUFFIX;

		if (!FileSystem.exists(oldImagePath))
			return false;

		try
		{
			FileSystem.rename(oldImagePath, newImagePath);

			if (FileSystem.exists(oldMetaPath))
				FileSystem.rename(oldMetaPath, newMetaPath);

			if (FileSystem.exists(oldThumbPath))
				FileSystem.rename(oldThumbPath, newThumbPath);

			invalidateCache();

			return true;
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to rename image "$oldSafeName" to "$newSafeName": ${Std.string(e)}', "storage");
			return false;
		}
		#else
		return false;
		#end
	}

	public static function exportImageBytes(filename:String):haxe.io.Bytes
	{
		#if sys
		var safeName:String = sanitizeFilename(filename);

		if (!Guard.isSafeFilename(safeName + ".png"))
			return null;

		var path:String = getContentPath() + "/" + safeName + ".png";

		if (!FileSystem.exists(path))
			return null;

		try
		{
			return File.getBytes(path);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to export image "$safeName": ${Std.string(e)}', "storage");
			return null;
		}
		#else
		return null;
		#end
	}

	public static function getOldestImage():StoredImageInfo
	{
		var images:Array<StoredImageInfo> = listSavedImagesWithMetadata();
		return images.length > 0 ? images[images.length - 1] : null;
	}

	public static function getNewestImage():StoredImageInfo
	{
		var images:Array<StoredImageInfo> = listSavedImagesWithMetadata();
		return images.length > 0 ? images[0] : null;
	}

	public static function getStatusSummary():String
	{
		var images:Array<StoredImageInfo> = listSavedImagesWithMetadata();
		var usageMB:Float = getStorageUsageMB();

		return 'StorageUtil: ${images.length}/$maxStoredImages images, ${formatDecimal(usageMB, 1)}/${formatDecimal(maxStorageMB, 1)}MB';
	}

	static function formatDecimal(value:Float, decimals:Int):String
	{
		var factor:Float = Math.pow(10, decimals);
		var rounded:Float = Math.round(value * factor) / factor;
		var text:String = Std.string(rounded);

		if (text.indexOf(".") == -1)
			text += ".0";

		return text;
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
