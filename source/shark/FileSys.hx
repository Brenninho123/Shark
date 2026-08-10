package shark;

class FileSys
{
	public static var isSupported(default, null):Bool;

	public static function initialize():Void
	{
		#if sys
		isSupported = true;
		#else
		isSupported = false;
		#end
	}

	public static function isSafePath(path:String):Bool
	{
		if (path == null || path.length == 0)
			return false;

		if (path.indexOf("..") != -1)
			return false;

		if (path.indexOf("\x00") != -1)
			return false;

		if (StringTools.startsWith(path, "/") || StringTools.startsWith(path, "\\"))
			return false;

		if (path.length > 1 && path.charAt(1) == ":")
			return false;

		return true;
	}

	public static function joinPath(base:String, part:String):String
	{
		if (base.length == 0)
			return part;

		if (StringTools.endsWith(base, "/") || StringTools.endsWith(base, "\\"))
			return base + part;

		return base + "/" + part;
	}

	public static function exists(path:String):Bool
	{
		#if sys
		try
		{
			return sys.FileSystem.exists(path);
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	public static function isDirectory(path:String):Bool
	{
		#if sys
		try
		{
			return sys.FileSystem.exists(path) && sys.FileSystem.isDirectory(path);
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	public static function ensureDirectory(path:String):Bool
	{
		#if sys
		try
		{
			if (!sys.FileSystem.exists(path))
				sys.FileSystem.createDirectory(path);

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

	public static function readText(path:String):String
	{
		#if sys
		try
		{
			return sys.FileSystem.exists(path) ? sys.io.File.getContent(path) : null;
		}
		catch (e:Dynamic)
		{
			return null;
		}
		#else
		return null;
		#end
	}

	public static function writeText(path:String, content:String):Bool
	{
		#if sys
		try
		{
			sys.io.File.saveContent(path, content);
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

	public static function readBytes(path:String):haxe.io.Bytes
	{
		#if sys
		try
		{
			return sys.FileSystem.exists(path) ? sys.io.File.getBytes(path) : null;
		}
		catch (e:Dynamic)
		{
			return null;
		}
		#else
		return null;
		#end
	}

	public static function writeBytes(path:String, bytes:haxe.io.Bytes):Bool
	{
		#if sys
		try
		{
			var output = sys.io.File.write(path, true);
			output.writeBytes(bytes, 0, bytes.length);
			output.close();
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

	public static function delete(path:String):Bool
	{
		#if sys
		try
		{
			if (!sys.FileSystem.exists(path))
				return false;

			sys.FileSystem.deleteFile(path);
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

	public static function deleteDirectory(path:String, recursive:Bool = false):Bool
	{
		#if sys
		try
		{
			if (!sys.FileSystem.exists(path) || !sys.FileSystem.isDirectory(path))
				return false;

			if (recursive)
			{
				for (entry in sys.FileSystem.readDirectory(path))
				{
					var fullPath:String = joinPath(path, entry);

					if (sys.FileSystem.isDirectory(fullPath))
						deleteDirectory(fullPath, true);
					else
						sys.FileSystem.deleteFile(fullPath);
				}
			}

			sys.FileSystem.deleteDirectory(path);
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

	public static function listFiles(path:String, ?extensionFilter:String):Array<String>
	{
		#if sys
		try
		{
			if (!sys.FileSystem.exists(path) || !sys.FileSystem.isDirectory(path))
				return [];

			var entries:Array<String> = sys.FileSystem.readDirectory(path);

			if (extensionFilter == null)
				return entries;

			var suffix:String = StringTools.startsWith(extensionFilter, ".") ? extensionFilter : "." + extensionFilter;
			var filtered:Array<String> = [];

			for (entry in entries)
				if (StringTools.endsWith(entry, suffix))
					filtered.push(entry);

			return filtered;
		}
		catch (e:Dynamic)
		{
			return [];
		}
		#else
		return [];
		#end
	}

	public static function copy(sourcePath:String, destPath:String):Bool
	{
		#if sys
		try
		{
			if (!sys.FileSystem.exists(sourcePath))
				return false;

			var bytes:haxe.io.Bytes = sys.io.File.getBytes(sourcePath);
			return writeBytes(destPath, bytes);
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	public static function getFileSize(path:String):Int
	{
		#if sys
		try
		{
			return sys.FileSystem.exists(path) ? sys.FileSystem.stat(path).size : -1;
		}
		catch (e:Dynamic)
		{
			return -1;
		}
		#else
		return -1;
		#end
	}

	public static function getDirectorySize(path:String):Int
	{
		#if sys
		var total:Int = 0;

		try
		{
			if (!sys.FileSystem.exists(path) || !sys.FileSystem.isDirectory(path))
				return 0;

			for (entry in sys.FileSystem.readDirectory(path))
			{
				var fullPath:String = joinPath(path, entry);

				if (sys.FileSystem.isDirectory(fullPath))
					total += getDirectorySize(fullPath);
				else
					total += sys.FileSystem.stat(fullPath).size;
			}
		}
		catch (e:Dynamic) {}

		return total;
		#else
		return 0;
		#end
	}
}
