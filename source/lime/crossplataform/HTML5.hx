package lime.crossplataform;

import lime.tools.HXProject;
import lime.tools.Icon;

class HTML5
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
		project.window.resizable = true;
		project.window.allowHighDPI = true;
		project.window.background = 0x00111F;
		project.window.vsync = false;
	}

	static function configureDefines(project:HXProject):Void
	{
		project.haxedefs.set("SHARK_PLATFORM", "html5");

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
