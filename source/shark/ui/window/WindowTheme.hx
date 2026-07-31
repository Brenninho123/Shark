package shark.ui.window;

#if windows
import hxwindowmode.WindowColorMode;
#end

class WindowTheme
{
	public static var isSupported(default, null):Bool;
	public static var isDarkMode(default, null):Bool = true;

	static inline var HEADER_COLOR:Array<Int> = [1, 17, 31];
	static inline var BORDER_COLOR:Array<Int> = [97, 165, 194];
	static inline var TITLE_COLOR:Array<Int> = [224, 251, 252];

	public static function initialize():Void
	{
		#if windows
		isSupported = true;
		applyAquaticTheme();
		#else
		isSupported = false;
		#end
	}

	public static function applyAquaticTheme():Void
	{
		#if windows
		try
		{
			WindowColorMode.setDarkMode();
			WindowColorMode.setWindowBorderColor(HEADER_COLOR, true, true);
			WindowColorMode.setWindowTitleColor(TITLE_COLOR);
			WindowColorMode.redrawWindowHeader();

			isDarkMode = true;
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function setDark():Void
	{
		#if windows
		try
		{
			WindowColorMode.setDarkMode();
			WindowColorMode.redrawWindowHeader();
			isDarkMode = true;
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function setLight():Void
	{
		#if windows
		try
		{
			WindowColorMode.setLightMode();
			WindowColorMode.redrawWindowHeader();
			isDarkMode = false;
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function toggle():Bool
	{
		if (isDarkMode)
			setLight();
		else
			setDark();

		return isDarkMode;
	}

	public static function setBorderColor(r:Int, g:Int, b:Int, header:Bool = true, border:Bool = true):Void
	{
		#if windows
		try
		{
			WindowColorMode.setWindowBorderColor([r, g, b], header, border);
			WindowColorMode.redrawWindowHeader();
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function resetToAquaticTheme():Void
	{
		applyAquaticTheme();
	}
}
