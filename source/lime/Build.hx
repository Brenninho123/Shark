package lime;

import lime.tools.HXProject;
import lime.tools.Platform;
import lime.tools.Asset;
import lime.tools.AssetType;
import lime.tools.Haxelib;
import lime.tools.Icon;
import lime.crossplataform.Windows;
import lime.crossplataform.HTML5;
import lime.crossplataform.Linux;
import lime.crossplataform.Mac;
import lime.crossplataform.mobile.Android;
import lime.crossplataform.mobile.IOS;

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
				Windows.configure(this);
			case ANDROID:
				Android.configure(this);
			case IOS:
				IOS.configure(this);
			case HTML5:
				HTML5.configure(this);
			case LINUX:
				Linux.configure(this);
			case MAC:
				Mac.configure(this);
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
		window.background = 0x00111F;
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
		haxelibs.push(new Haxelib("openfl"));
		haxelibs.push(new Haxelib("flixel"));
		haxelibs.push(new Haxelib("flixel-addons"));
		haxelibs.push(new Haxelib("flixel-ui"));
		haxelibs.push(new Haxelib("hscript"));
	}

	function setupAssets():Void
	{
		assets.push(new Asset("assets/images", "assets/images", AssetType.BINARY));
		assets.push(new Asset("assets/data", "assets/data", AssetType.TEXT));
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
			haxeflags.push("-D no-traces");
		}
	}

	function resolveBuildNumber():String
	{
		var timestamp:Float = Date.now().getTime();
		return Std.string(Std.int(timestamp / 1000));
	}
}
