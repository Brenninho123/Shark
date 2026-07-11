package;

import flixel.FlxG;
import flixel.FlxGame;
import lime.manager.LimeManager;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.errors.Error;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.UncaughtErrorEvent;
import openfl.ui.Keyboard;
import shark.menus.MainMenuState;

class Main extends Sprite
{
	public static var lastError:String = "";
	public static var isActive(default, null):Bool = true;

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
		setupLifecycle();
		setupInput();

		LimeManager.initialize();

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

	function setupLifecycle():Void
	{
		stage.addEventListener(Event.ACTIVATE, onActivate);
		stage.addEventListener(Event.DEACTIVATE, onDeactivate);
	}

	function setupInput():Void
	{
		#if android
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
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

	function onActivate(e:Event):Void
	{
		isActive = true;

		if (FlxG.sound != null)
			FlxG.sound.resume();
	}

	function onDeactivate(e:Event):Void
	{
		isActive = false;

		if (FlxG.sound != null)
			FlxG.sound.pause();
	}

	function onKeyDown(e:KeyboardEvent):Void
	{
		#if android
		if (e.keyCode == Keyboard.BACK)
		{
			e.preventDefault();
			handleBackButton();
		}
		#end
	}

	function handleBackButton():Void
	{
		if (FlxG.state == null)
			return;

		if (Std.isOfType(FlxG.state, MainMenuState))
			return;

		FlxG.switchState(new MainMenuState());
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
