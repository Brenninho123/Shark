package;

import flixel.FlxGame;
import openfl.display.Sprite;
import shark.active.PlayState;

class Main extends Sprite
{
	public function new()
	{
		super();
		addChild(new FlxGame(0, 0, PlayState, 60, 60, true));
	}
}
