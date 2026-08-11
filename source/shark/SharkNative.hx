package shark;

#if desktop
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
import lime.system.Clipboard;
import lime.app.Application;
#end

import shark.ui.debug.CrasherLog;

class SharkNative
{
	public static var isSupported(default, null):Bool;

	public static function initialize():Void
	{
		#if desktop
		isSupported = true;
		#else
		isSupported = false;
		#end
	}

	public static function openFileDialog(onSelect:String->Void, ?onCancel:Void->Void, ?filter:String, ?title:String):Void
	{
		#if desktop
		try
		{
			var dialog = new FileDialog();

			dialog.onSelect.add(function(path:String):Void
			{
				onSelect(path);
			});

			if (onCancel != null)
				dialog.onCancel.add(onCancel);

			dialog.browse(FileDialogType.OPEN, filter, null, title);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('SharkNative.openFileDialog failed: ${Std.string(e)}', "native");

			if (onCancel != null)
				onCancel();
		}
		#else
		if (onCancel != null)
			onCancel();
		#end
	}

	public static function saveFileDialog(onSelect:String->Void, ?onCancel:Void->Void, ?defaultName:String, ?filter:String, ?title:String):Void
	{
		#if desktop
		try
		{
			var dialog = new FileDialog();

			dialog.onSelect.add(function(path:String):Void
			{
				onSelect(path);
			});

			if (onCancel != null)
				dialog.onCancel.add(onCancel);

			dialog.save(filter, defaultName, title);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('SharkNative.saveFileDialog failed: ${Std.string(e)}', "native");

			if (onCancel != null)
				onCancel();
		}
		#else
		if (onCancel != null)
			onCancel();
		#end
	}

	public static function chooseDirectory(onSelect:String->Void, ?onCancel:Void->Void, ?title:String):Void
	{
		#if desktop
		try
		{
			var dialog = new FileDialog();

			dialog.onSelect.add(function(path:String):Void
			{
				onSelect(path);
			});

			if (onCancel != null)
				dialog.onCancel.add(onCancel);

			dialog.browse(FileDialogType.OPEN_DIRECTORY, null, null, title);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('SharkNative.chooseDirectory failed: ${Std.string(e)}', "native");

			if (onCancel != null)
				onCancel();
		}
		#else
		if (onCancel != null)
			onCancel();
		#end
	}

	public static function getClipboardText():String
	{
		#if desktop
		try
		{
			return Clipboard.text;
		}
		catch (e:Dynamic)
		{
			return null;
		}
		#else
		return null;
		#end
	}

	public static function setClipboardText(text:String):Bool
	{
		#if desktop
		try
		{
			Clipboard.text = text;
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

	public static function getWindow():#if desktop lime.ui.Window #else Dynamic #end
	{
		#if desktop
		return Application.current != null ? Application.current.window : null;
		#else
		return null;
		#end
	}

	public static function setAlwaysOnTop(value:Bool):Bool
	{
		#if desktop
		var window = getWindow();

		if (window == null)
			return false;

		try
		{
			window.alwaysOnTop = value;
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

	public static function setMinimized(value:Bool):Bool
	{
		#if desktop
		var window = getWindow();

		if (window == null)
			return false;

		try
		{
			window.minimized = value;
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

	public static function setMaximized(value:Bool):Bool
	{
		#if desktop
		var window = getWindow();

		if (window == null)
			return false;

		try
		{
			window.maximized = value;
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

	public static function getStatusSummary():String
	{
		if (!isSupported)
			return "SharkNative: desktop-only, not supported on this target";

		return "SharkNative: ready (file dialogs, clipboard, window control)";
	}
}
