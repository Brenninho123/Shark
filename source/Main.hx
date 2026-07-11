package;

import flixel.FlxGame;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import shark.menus.MainMenuState;

class Main extends Sprite
{
	public function new()
	{
		super();

		if (stage != null)
		{
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
		}

		addChild(new FlxGame(0, 0, MainMenuState, 60, 60, true));

		#if debug
		addChild(new FPS(10, 10, 0xFFFFFF));
		#end
	}
}
