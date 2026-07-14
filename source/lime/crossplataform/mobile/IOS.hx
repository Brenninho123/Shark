package lime.crossplataform.mobile;

import lime.tools.HXProject;
import lime.tools.Icon;

class IOS
{
	public static var deploymentTarget:String = "12.0";
	public static var deviceFamily:String = "universal";
	public static var allowExtensions:Bool = false;

	public static var codeSigningIdentity:String = "";
	public static var provisioningProfile:String = "";

	public static function configure(project:HXProject):Void
	{
		configureWindow(project);
		configureDeployment(project);
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
		project.window.vsync = false;
		project.window.antialiasing = 0;
		project.window.background = 0x00111F;
	}

	static function configureDeployment(project:HXProject):Void
	{
		project.config.set("ios.deployment", deploymentTarget);
		project.config.set("ios.device", deviceFamily);
		project.config.set("ios.extension", allowExtensions ? "true" : "false");
	}

	static function configureDefines(project:HXProject):Void
	{
		project.haxedefs.set("SHARK_PLATFORM", "ios");
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
		project.haxeflags.push("-D no-traces");
	}

	static function configureIcon(project:HXProject):Void
	{
		project.icons.push(new Icon("assets/images/icon.png"));
	}

	static function configureSigning(project:HXProject):Void
	{
		if (project.debug)
			return;

		if (codeSigningIdentity != "")
			project.config.set("ios.identity", codeSigningIdentity);

		if (provisioningProfile != "")
			project.config.set("ios.provisioning-profile", provisioningProfile);
	}
}
