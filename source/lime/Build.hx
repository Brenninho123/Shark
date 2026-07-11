package lime;

import lime.tools.HXProject;
import lime.tools.Platform;
import lime.tools.PlatformTarget;
import lime.tools.Architecture;
import lime.tools.Asset;
import lime.tools.AssetType;
import lime.tools.Haxelib;
import lime.tools.Icon;
import lime.tools.NDLL;
import lime.tools.Window;

class Build extends HXProject
{
	public function new()
	{
		super();

		setupMeta();
		setupApp();
		setupWindow();
		setupSource();
		setupHaxelibs();
		setupAssets();
		setupDefines();

		switch (target)
		{
			case WINDOWS:
				setupWindows();
			case ANDROID:
				setupAndroid();
			case IOS:
				setupIOS();
			case HTML5:
				setupHTML5();
			case LINUX:
				setupLinux();
			case MAC:
				setupMac();
			default:
		}
	}

	function setupMeta():Void
	{
		meta.title = "Shark";
		meta.description = "An artificial intelligence made with HaxeFlixel.";
		meta.packageName = "com.brenninho.shark";
		meta.version = "0.1.0";
		meta.company = "Brenninho";
	}

	function setupApp():Void
	{
		app.main = "Main";
		app.file = "Shark";
		app.path = "export";
	}

	function setupWindow():Void
	{
		window.width = 1280;
		window.height = 720;
		window.fps = 60;
		window.background = 0x000000;
		window.hardware = true;
		window.vsync = false;
	}

	function setupSource():Void
	{
		sources.push("source");
	}

	function setupHaxelibs():Void
	{
		haxelibs.push(new Haxelib("flixel"));
		haxelibs.push(new Haxelib("flixel-addons"));
		haxelibs.push(new Haxelib("flixel-ui"));
	}

	function setupAssets():Void
	{
		assets.push(new Asset("assets", "assets", AssetType.BINARY));
	}

	function setupDefines():Void
	{
		if (!debug)
			haxedefs.set("FLX_NO_DEBUG", "");
	}

	function setupWindows():Void
	{
		window.width = 1280;
		window.height = 720;
		window.resizable = true;
	}

	function setupAndroid():Void
	{
		window.orientation = LANDSCAPE;
		window.fullscreen = true;
		window.allowShaders = true;

		haxedefs.set("FLX_NO_NATIVE_CURSOR", "");

		config.set("android.permissions", "android.permission.INTERNET android.permission.WRITE_EXTERNAL_STORAGE android.permission.READ_EXTERNAL_STORAGE");
		config.set("android.target-sdk-version", "35");
		config.set("android.minimum-sdk-version", "21");
		config.set("android.install-location", "auto");
	}

	function setupIOS():Void
	{
		window.orientation = LANDSCAPE;
		window.fullscreen = true;

		haxedefs.set("FLX_NO_NATIVE_CURSOR", "");

		config.set("ios.deployment", "12.0");
		config.set("ios.device", "universal");
	}

	function setupHTML5():Void
	{
		window.resizable = true;
		window.allowHighDPI = true;
	}

	function setupLinux():Void
	{
		window.width = 1280;
		window.height = 720;
		window.resizable = true;
	}

	function setupMac():Void
	{
		window.width = 1280;
		window.height = 720;
		window.resizable = true;
	}
}
