package lime.crossplataform.mobile;

import lime.tools.HXProject;
import lime.tools.Icon;
import lime.tools.Certificate;
import lime.tools.Architecture;

class Android
{
	public static var targetSdkVersion:String = "35";
	public static var minimumSdkVersion:String = "21";
	public static var installLocation:String = "auto";

	public static var permissions:Array<String> = [
		"android.permission.INTERNET",
		"android.permission.WRITE_EXTERNAL_STORAGE",
		"android.permission.READ_EXTERNAL_STORAGE"
	];

	public static var keystorePath:String = "Certificates/android.keystore";
	public static var keystoreAlias:String = "android";
	public static var keystorePassword:String = "android";

	public static function configure(project:HXProject):Void
	{
		configureWindow(project);
		configureArchitectures(project);
		configureManifest(project);
		configureDefines(project);
		configureOptimizations(project);
		configureIcon(project);
		configureSigning(project);
	}

	static function configureWindow(project:HXProject):Void
	{
		project.window.orientation = LANDSCAPE;
		project.window.fullscreen = true;
		project.window.hardware = true;
		project.window.allowShaders = true;
		project.window.vsync = false;
		project.window.antialiasing = 0;
		project.window.background = 0x00111F;
	}

	static function configureArchitectures(project:HXProject):Void
	{
		project.architectures = [Architecture.ARMV7, Architecture.ARM64];
	}

	static function configureManifest(project:HXProject):Void
	{
		project.config.set("android.permissions", permissions.join(" "));
		project.config.set("android.target-sdk-version", targetSdkVersion);
		project.config.set("android.minimum-sdk-version", minimumSdkVersion);
		project.config.set("android.install-location", installLocation);
	}

	static function configureDefines(project:HXProject):Void
	{
		project.haxedefs.set("SHARK_PLATFORM", "android");
		project.haxedefs.set("FLX_NO_NATIVE_CURSOR", "");
		project.haxedefs.set("FLX_NO_SOUND_TRAY", "");

		if (!project.debug)
			project.haxedefs.set("FLX_NO_FOCUS_LOST_SCREEN", "");
	}

	static function configureOptimizations(project:HXProject):Void
	{
		if (project.debug)
			return;

		project.haxeflags.push("-dce full");
		project.haxeflags.push("--no-traces");
	}

	static function configureIcon(project:HXProject):Void
	{
		project.icons.push(new Icon("assets/images/icon.png"));
	}

	static function configureSigning(project:HXProject):Void
	{
		if (project.debug)
			return;

		project.certificate = new Certificate(keystorePath, keystorePassword, keystoreAlias, keystorePassword);
	}
}
