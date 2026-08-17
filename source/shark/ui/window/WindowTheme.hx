package shark.ui.window;

class WindowTheme
{
	public static var isSupported(default, null):Bool = false;
	public static var isDarkMode(default, null):Bool = true;

	public static function initialize():Void {}

	public static function applyAquaticTheme():Void {}

	public static function setDark():Void {}

	public static function setLight():Void {}

	public static function toggle():Bool
	{
		return isDarkMode;
	}

	public static function setBorderColor(r:Int, g:Int, b:Int, header:Bool = true, border:Bool = true):Void {}

	public static function resetToAquaticTheme():Void {}
}
