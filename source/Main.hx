package;

import flixel.FlxG;
import flixel.FlxGame;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.errors.Error;
import openfl.events.Event;
import openfl.events.UncaughtErrorEvent;
import shark.menus.MainMenuState;

class Main extends Sprite
{
	public static var lastError:String = "";

	public function new()
	{
		super();

		if (stage != null)
			init();
		else
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
	}

	function onAddedToStage(e:Event):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		init();
	}

	function init():Void
	{
		setupStage();
		setupErrorHandling();
		setupGame();

		#if debug
		addChild(new FPS(10, 10, 0xFFFFFF));
		#end
	}

	function setupStage():Void
	{
		stage.align = StageAlign.TOP_LEFT;
		stage.scaleMode = StageScaleMode.NO_SCALE;

		#if mobile
		stage.addEventListener(Event.RESIZE, onStageResize);
		#end
	}

	function setupErrorHandling():Void
	{
		#if (openfl >= "8.0.0")
		if (stage.loaderInfo.uncaughtErrorEvents != null)
			stage.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
		#end
	}

	function setupGame():Void
	{
		var game = new FlxGame(0, 0, MainMenuState, 60, 60, true);
		addChild(game);

		FlxG.autoPause = true;
		FlxG.mouse.visible = true;

		#if mobile
		FlxG.mouse.useSystemCursor = false;
		FlxG.scaleMode = new flixel.system.scaleModes.RatioScaleMode();
		#end
	}

	function onStageResize(e:Event):Void
	{
		if (FlxG.game != null)
		{
			FlxG.game.x = 0;
			FlxG.game.y = 0;
		}
	}

	function onUncaughtError(e:UncaughtErrorEvent):Void
	{
		e.preventDefault();

		if (Std.isOfType(e.error, Error))
			lastError = cast(e.error, Error).message;
		else if (Std.isOfType(e.error, String))
			lastError = cast(e.error, String);
		else
			lastError = "Unknown error";
	}
}
