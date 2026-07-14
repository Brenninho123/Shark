package lime;

import lime.tools.HXProject;
import lime.tools.Platform;
import lime.tools.Architecture;
import lime.tools.Asset;
import lime.tools.AssetType;
import lime.tools.Haxelib;
import lime.tools.Icon;
import lime.tools.Certificate;
import lime.crossplataform.Windows;

class Build extends HXProject
{
	static inline var APP_TITLE:String = "Shark";
	static inline var APP_PACKAGE:String = "com.brenninho.shark";
	static inline var APP_VERSION:String = "0.1.0";
	static inline var APP_COMPANY:String = "Brenninho";

	public function new()
	{
		super();

		setupMeta();
		setupApp();
		setupWindow();
		setupSource();
		setupHaxelibs();
		setupAssets();
		setupIcon();
		setupDefines();
		setupOptimizations();

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
		meta.title = APP_TITLE;
		meta.description = "An artificial intelligence made with HaxeFlixel.";
		meta.packageName = APP_PACKAGE;
		meta.version = APP_VERSION;
		meta.company = APP_COMPANY;
		meta.buildNumber = resolveBuildNumber();
	}

	function setupApp():Void
	{
		app.main = "Main";
		app.file = APP_TITLE;
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
		window.antialiasing = 0;
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

	function setupIcon():Void
	{
		icons.push(new Icon("assets/images/icon.png"));
	}

	function setupDefines():Void
	{
		if (!debug)
		{
			haxedefs.set("FLX_NO_DEBUG", "");
			haxedefs.set("FLX_NO_FOCUS_LOST_SCREEN", "");
		}

		haxedefs.set("SHARK_VERSION", APP_VERSION);
	}

	function setupOptimizations():Void
	{
		if (!debug)
		{
			haxeflags.push("-dce full");
			haxeflags.push("--no-traces");
		}
	}

	function setupWindows():Void
	{
		Windows.configure(this);
	}

	function setupAndroid():Void
	{
		window.orientation = LANDSCAPE;
		window.fullscreen = true;
		window.allowShaders = true;

		architectures = [Architecture.ARMV7, Architecture.ARM64];

		haxedefs.set("FLX_NO_NATIVE_CURSOR", "");

		config.set("android.permissions", "android.permission.INTERNET android.permission.WRITE_EXTERNAL_STORAGE android.permission.READ_EXTERNAL_STORAGE");
		config.set("android.target-sdk-version", "35");
		config.set("android.minimum-sdk-version", "21");
		config.set("android.install-location", "auto");

		if (!debug)
			setupAndroidSigning();
	}

	function setupAndroidSigning():Void
	{
		certificate = new Certificate("Certificates/android.keystore", "android", "android", "android");
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

	function resolveBuildNumber():String
	{
		var timestamp:Float = Date.now().getTime();
		return Std.string(Std.int(timestamp / 1000));
	}
}
