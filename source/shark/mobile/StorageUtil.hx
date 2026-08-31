package shark.mobile;

import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.geom.Matrix;
import openfl.utils.ByteArray;
import lime.system.System;
import shark.modding.Module;
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

enum abstract StorageLocation(Int)
{
	var DATA = 0;
	var EXTERNAL = 1;
	var MODS = 2;
}

class StorageUtil
{
	public static inline var CONTENT_FOLDER:String = "content";
	public static var maxStoredImages:Int = 200;
	public static var maxStorageMB:Float = 250;
	public static var generateThumbnails:Bool = true;
	public static var thumbnailMaxDimension:Int = 256;

	static inline var THUMBNAIL_SUFFIX:String = "_thumb.png";

	static var cachedInfo:Map<Int, Array<StoredImageInfo>> = new Map();
	static var cachedExternalPath:String;
	static var externalPathChecked:Bool = false;

	public static function isSupported():Bool
	{
		#if sys
		return true;
		#else
		return false;
		#end
	}

	public static function isExternalStorageAvailable():Bool
	{
		#if android
		return resolveExternalStoragePath() != null;
		#else
		return false;
		#end
	}

	public static function getBasePath(location:StorageLocation = DATA):String
	{
		if (location == EXTERNAL)
		{
			#if android
			var external:String = resolveExternalStoragePath();

			if (external != null)
				return stripTrailingSlash(external);
			#end

			return getBasePath(DATA);
		}

		if (location == MODS)
		{
			try
			{
				return stripTrailingSlash(Module.getModsDirectory());
			}
			catch (e:Dynamic)
			{
				return getBasePath(DATA) + "/mods";
			}
		}

		return stripTrailingSlash(System.applicationStorageDirectory);
	}

	static function stripTrailingSlash(path:String):String
	{
		if (path == null)
			return "";

		if (StringTools.endsWith(path, "/") || StringTools.endsWith(path, "\\"))
			return path.substr(0, path.length - 1);

		return path;
	}

	#if android
	static function resolveExternalStoragePath():String
	{
		if (externalPathChecked)
			return cachedExternalPath;

		externalPathChecked = true;

		var candidates:Array<String> = [
			"extension.androidtools.device.Device",
			"extension.androidtools.Device",
			"extension.androidtools.device.Storage",
			"extension.androidtools.Storage"
		];

		var methodNames:Array<String> = ["getExternalFilesDir", "getExternalStorageDirectory", "getExternalStoragePath"];

		for (className in candidates)
		{
			var cls:Dynamic = Type.resolveClass(className);

			if (cls == null)
				continue;

			for (methodName in methodNames)
			{
				var fn:Dynamic = Reflect.field(cls, methodName);

				if (fn == null || !Reflect.isFunction(fn))
					continue;

				try
				{
					var result:Dynamic = Reflect.callMethod(cls, fn, []);

					if (result != null)
					{
						cachedExternalPath = Std.string(result);
						return cachedExternalPath;
					}
				}
				catch (e:Dynamic) {}
			}
		}

		CrasherLog.logWarning("No external storage binding found in extension-androidtools - falling back to internal storage.", "storage");
		return null;
	}

	public static function hasExternalStoragePermission():Bool
	{
		var candidates:Array<String> = ["extension.androidtools.permissions.Permissions", "extension.androidtools.Permissions"];
		var methodNames:Array<String> = ["hasPermission", "checkPermission"];

		for (className in candidates)
		{
			var cls:Dynamic = Type.resolveClass(className);

			if (cls == null)
				continue;

			for (methodName in methodNames)
			{
				var fn:Dynamic = Reflect.field(cls, methodName);

				if (fn == null || !Reflect.isFunction(fn))
					continue;

				try
				{
					var result:Dynamic = Reflect.callMethod(cls, fn, ["android.permission.WRITE_EXTERNAL_STORAGE"]);

					if (result != null)
						return result == true;
				}
				catch (e:Dynamic) {}
			}
		}

		return true;
	}

	static function requestExternalStoragePermissionNative(onResult:Bool->Void):Bool
	{
		var candidates:Array<String> = ["extension.androidtools.permissions.Permissions", "extension.androidtools.Permissions"];
		var methodNames:Array<String> = ["requestPermission", "requestPermissions"];

		for (className in candidates)
		{
			var cls:Dynamic = Type.resolveClass(className);

			if (cls == null)
				continue;

			for (methodName in methodNames)
			{
				var fn:Dynamic = Reflect.field(cls, methodName);

				if (fn == null || !Reflect.isFunction(fn))
					continue;

				try
				{
					Reflect.callMethod(cls, fn, ["android.permission.WRITE_EXTERNAL_STORAGE", onResult]);
					return true;
				}
				catch (e:Dynamic) {}
			}
		}

		return false;
	}
	#end

	public static function requestExternalStoragePermission(onResult:Bool->Void):Void
	{
		#if android
		if (requestExternalStoragePermissionNative(onResult))
			return;

		CrasherLog.logWarning("No permission-request binding found in extension-androidtools - assuming current status.", "storage");
		onResult(hasExternalStoragePermission());
		#else
		onResult(true);
		#end
	}

	public static function getContentPath(location:StorageLocation = DATA):String
	{
		return getBasePath(location) + "/" + CONTENT_FOLDER;
	}

	public static function ensureFolder(location:StorageLocation = DATA):Bool
	{
		#if sys
		var path:String = location == MODS ? getBasePath(MODS) : getContentPath(location);

		try
		{
			if (!FileSystem.exists(path))
				FileSystem.createDirectory(path);

			return true;
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to create folder for $location: ${Std.string(e)}', "storage");
			return false;
		}
		#else
		return false;
		#end
	}

	public static function ensureContentFolder(location:StorageLocation = DATA):Bool
	{
		return ensureFolder(location);
	}

	public static function saveImage(bitmapData:BitmapData, filename:String, onComplete:String->Void, onError:String->Void, ?prompt:String,
			location:StorageLocation = DATA):Void
	{
		#if sys
		if (bitmapData == null || bitmapData.width <= 0 || bitmapData.height <= 0)
		{
			onError("No image data to save");
			return;
		}

		#if android
		if (location == EXTERNAL && !hasExternalStoragePermission())
		{
			CrasherLog.logWarning("External storage permission not granted - saving to internal storage instead.", "storage");
			location = DATA;
		}
		#end

		if (!ensureFolder(location))
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
			enforceQuota(location);

			var fullPath:String = getContentPath(location) + "/" + safeName + ".png";
			var encoded:ByteArray = bitmapData.encode(bitmapData.rect, new PNGEncoderOptions());

			File.saveBytes(fullPath, encoded);
			writeMetadata(safeName, location, prompt);

			if (generateThumbnails)
				saveThumbnail(bitmapData, safeName, location);

			invalidateCache(location);

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

	static function saveThumbnail(source:BitmapData, safeName:String, location:StorageLocation):Void
	{
		#if sys
		try
		{
			var thumbnail:BitmapData = createThumbnail(source, thumbnailMaxDimension);
			var encoded:ByteArray = thumbnail.encode(thumbnail.rect, new PNGEncoderOptions());
			File.saveBytes(getContentPath(location) + "/" + safeName + THUMBNAIL_SUFFIX, encoded);
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

	public static function getThumbnailPath(filename:String, location:StorageLocation = DATA):String
	{
		var safeName:String = stripPngExtension(sanitizeFilename(filename));
		return getContentPath(location) + "/" + safeName + THUMBNAIL_SUFFIX;
	}

	public static function hasThumbnail(filename:String, location:StorageLocation = DATA):Bool
	{
		#if sys
		return FileSystem.exists(getThumbnailPath(filename, location));
		#else
		return false;
		#end
	}

	static function stripPngExtension(name:String):String
	{
		return StringTools.endsWith(name.toLowerCase(), ".png") ? name.substr(0, name.length - 4) : name;
	}

	static function writeMetadata(safeName:String, location:StorageLocation, ?prompt:String):Void
	{
		#if sys
		try
		{
			var metadata = {
				prompt: prompt != null ? prompt : "",
				savedAt: Date.now().getTime()
			};

			File.saveContent(getContentPath(location) + "/" + safeName + ".json", Json.stringify(metadata));
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to write metadata for "$safeName": ${Std.string(e)}', "storage");
		}
		#end
	}

	static function readMetadata(safeName:String, location:StorageLocation):{?prompt:String, ?savedAt:Float}
	{
		#if sys
		try
		{
			var metaPath:String = getContentPath(location) + "/" + safeName + ".json";

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

	static function invalidateCache(location:StorageLocation):Void
	{
		cachedInfo.remove(cast location);
	}

	public static function listSavedImages(location:StorageLocation = DATA):Array<String>
	{
		#if sys
		var path:String = getContentPath(location);

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

	public static function listSavedImagesWithMetadata(location:StorageLocation = DATA):Array<StoredImageInfo>
	{
		if (cachedInfo.exists(cast location))
			return cachedInfo.get(cast location).copy();

		var result:Array<StoredImageInfo> = [];

		#if sys
		for (filename in listSavedImages(location))
		{
			var safeName:String = stripPngExtension(filename);
			var fullPath:String = getContentPath(location) + "/" + filename;

			var sizeBytes:Int = 0;

			try
			{
				sizeBytes = FileSystem.stat(fullPath).size;
			}
			catch (e:Dynamic) {}

			var meta = readMetadata(safeName, location);

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

		cachedInfo.set(cast location, result);

		return result.copy();
	}

	public static function getStorageUsageMB(location:StorageLocation = DATA):Float
	{
		var totalBytes:Int = 0;

		for (info in listSavedImagesWithMetadata(location))
			totalBytes += info.sizeBytes;

		return totalBytes / 1024 / 1024;
	}

	static function enforceQuota(location:StorageLocation):Void
	{
		#if sys
		var images:Array<StoredImageInfo> = listSavedImagesWithMetadata(location);

		while (images.length >= maxStoredImages)
		{
			var oldest:StoredImageInfo = images.pop();
			deleteImage(stripPngExtension(oldest.filename), location);
		}

		var usageMB:Float = getStorageUsageMB(location);

		while (usageMB > maxStorageMB && images.length > 0)
		{
			var oldest:StoredImageInfo = images.pop();
			deleteImage(stripPngExtension(oldest.filename), location);
			usageMB -= oldest.sizeBytes / 1024 / 1024;
		}
		#end
	}

	public static function deleteImage(filename:String, location:StorageLocation = DATA):Bool
	{
		#if sys
		var safeName:String = sanitizeFilename(filename);

		if (!Guard.isSafeFilename(safeName + ".png"))
		{
			CrasherLog.logSecurity('Rejected delete for unsafe filename "$filename"', "storage");
			return false;
		}

		var imagePath:String = getContentPath(location) + "/" + safeName + ".png";
		var metaPath:String = getContentPath(location) + "/" + safeName + ".json";
		var thumbPath:String = getContentPath(location) + "/" + safeName + THUMBNAIL_SUFFIX;

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

			invalidateCache(location);

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

	public static function clearAll(location:StorageLocation = DATA):Int
	{
		var count:Int = 0;

		#if sys
		for (filename in listSavedImages(location))
		{
			deleteImage(stripPngExtension(filename), location);
			count++;
		}

		invalidateCache(location);
		#end

		return count;
	}

	public static function findByPrompt(searchText:String, location:StorageLocation = DATA):Array<StoredImageInfo>
	{
		var query:String = searchText.toLowerCase();
		var results:Array<StoredImageInfo> = [];

		for (info in listSavedImagesWithMetadata(location))
		{
			if (info.prompt != null && info.prompt.toLowerCase().indexOf(query) != -1)
				results.push(info);
		}

		return results;
	}

	public static function renameImage(oldFilename:String, newFilename:String, location:StorageLocation = DATA):Bool
	{
		#if sys
		var oldSafeName:String = sanitizeFilename(oldFilename);
		var newSafeName:String = sanitizeFilename(newFilename);

		if (!Guard.isSafeFilename(newSafeName + ".png"))
		{
			CrasherLog.logSecurity('Rejected rename to unsafe filename "$newFilename"', "storage");
			return false;
		}

		var oldImagePath:String = getContentPath(location) + "/" + oldSafeName + ".png";
		var newImagePath:String = getContentPath(location) + "/" + newSafeName + ".png";
		var oldMetaPath:String = getContentPath(location) + "/" + oldSafeName + ".json";
		var newMetaPath:String = getContentPath(location) + "/" + newSafeName + ".json";
		var oldThumbPath:String = getContentPath(location) + "/" + oldSafeName + THUMBNAIL_SUFFIX;
		var newThumbPath:String = getContentPath(location) + "/" + newSafeName + THUMBNAIL_SUFFIX;

		if (!FileSystem.exists(oldImagePath))
			return false;

		try
		{
			FileSystem.rename(oldImagePath, newImagePath);

			if (FileSystem.exists(oldMetaPath))
				FileSystem.rename(oldMetaPath, newMetaPath);

			if (FileSystem.exists(oldThumbPath))
				FileSystem.rename(oldThumbPath, newThumbPath);

			invalidateCache(location);

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

	public static function exportImageBytes(filename:String, location:StorageLocation = DATA):haxe.io.Bytes
	{
		#if sys
		var safeName:String = sanitizeFilename(filename);

		if (!Guard.isSafeFilename(safeName + ".png"))
			return null;

		var path:String = getContentPath(location) + "/" + safeName + ".png";

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

	public static function getOldestImage(location:StorageLocation = DATA):StoredImageInfo
	{
		var images:Array<StoredImageInfo> = listSavedImagesWithMetadata(location);
		return images.length > 0 ? images[images.length - 1] : null;
	}

	public static function getNewestImage(location:StorageLocation = DATA):StoredImageInfo
	{
		var images:Array<StoredImageInfo> = listSavedImagesWithMetadata(location);
		return images.length > 0 ? images[0] : null;
	}

	public static function getModsPath():String
	{
		return getBasePath(MODS);
	}

	public static function listModFolders():Array<String>
	{
		#if sys
		var path:String = getBasePath(MODS);

		if (!FileSystem.exists(path))
			return [];

		var folders:Array<String> = [];

		for (entry in FileSystem.readDirectory(path))
		{
			var fullPath:String = path + "/" + entry;

			try
			{
				if (FileSystem.isDirectory(fullPath))
					folders.push(entry);
			}
			catch (e:Dynamic) {}
		}

		return folders;
		#else
		return [];
		#end
	}

	public static function getModsStorageUsageMB():Float
	{
		#if sys
		var totalBytes:Int = 0;

		sumDirectorySize(getBasePath(MODS), function(bytes:Int):Void
		{
			totalBytes += bytes;
		});

		return totalBytes / 1024 / 1024;
		#else
		return 0;
		#end
	}

	#if sys
	static function sumDirectorySize(path:String, onBytes:Int->Void):Void
	{
		if (!FileSystem.exists(path))
			return;

		for (entry in FileSystem.readDirectory(path))
		{
			var fullPath:String = path + "/" + entry;

			try
			{
				if (FileSystem.isDirectory(fullPath))
					sumDirectorySize(fullPath, onBytes);
				else
					onBytes(FileSystem.stat(fullPath).size);
			}
			catch (e:Dynamic) {}
		}
	}
	#end

	public static function getStatusSummary():String
	{
		var lines:Array<String> = [];

		var dataImages:Array<StoredImageInfo> = listSavedImagesWithMetadata(DATA);
		lines.push('Data: ${dataImages.length}/$maxStoredImages images, ${formatDecimal(getStorageUsageMB(DATA), 1)}/${formatDecimal(maxStorageMB, 1)}MB');

		if (isExternalStorageAvailable())
		{
			var externalImages:Array<StoredImageInfo> = listSavedImagesWithMetadata(EXTERNAL);
			lines.push('External: ${externalImages.length} images, ${formatDecimal(getStorageUsageMB(EXTERNAL), 1)}MB');
		}
		else
		{
			lines.push("External: not available");
		}

		lines.push('Mods: ${listModFolders().length} folder(s), ${formatDecimal(getModsStorageUsageMB(), 1)}MB');

		return "StorageUtil: " + lines.join(" | ");
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
