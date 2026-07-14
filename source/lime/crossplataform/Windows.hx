package lime.crossplataform;

import lime.tools.HXProject;
import lime.tools.Icon;

class Windows
{
	public static function configure(project:HXProject):Void
	{
		configureWindow(project);
		configureDefines(project);
		configureOptimizations(project);
		configureIcon(project);
	}

	static function configureWindow(project:HXProject):Void
	{
		project.window.width = 1280;
		project.window.height = 720;
		project.window.fps = 60;
		project.window.background = 0x00111F;
		project.window.hardware = true;
		project.window.vsync = false;
		project.window.antialiasing = 0;
		project.window.resizable = true;
	}

	static function configureDefines(project:HXProject):Void
	{
		project.haxedefs.set("SHARK_PLATFORM", "windows");

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
}
