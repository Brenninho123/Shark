package shark.ui.debug;

import flixel.group.FlxSpriteGroup;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.manager.LimeManager;

#if cpp
import hxcpp.CPP;
#end

class DebugDisplay extends FlxSpriteGroup
{
	static inline var PADDING_X:Float = 8;
	static inline var PADDING_Y:Float = 4;
	static inline var BAR_HEIGHT:Float = 20;
	static inline var REFRESH_INTERVAL:Float = 0.25;

	var background:FlxSprite;
	var label:FlxText;

	var refreshTimer:Float = 0;

	public var extraTag(default, set):String = "";

	public function new(x:Float = 10, y:Float = 10)
	{
		super(x, y);

		background = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.BLACK);
		background.alpha = 0.65;
		add(background);

		label = new FlxText(PADDING_X, PADDING_Y, 0, "");
		label.setFormat(null, 12, FlxColor.LIME, LEFT);
		add(label);

		refresh();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		refreshTimer += elapsed;

		if (refreshTimer >= REFRESH_INTERVAL)
		{
			refreshTimer = 0;
			refresh();
		}
	}

	function refresh():Void
	{
		var fps:Int = getFps();
		var memoryLabel:String = getMemoryLabel();
		var tagSuffix:String = extraTag != "" ? ' \u2022 $extraTag' : "";

		label.text = 'FPS: $fps \u2022 Memory: $memoryLabel$tagSuffix';

		var barWidth:Float = label.width + PADDING_X * 2;
		background.setGraphicSize(Std.int(barWidth), Std.int(BAR_HEIGHT));
		background.updateHitbox();
	}

	function set_extraTag(value:String):String
	{
		extraTag = value;
		refresh();
		return value;
	}

	function getFps():Int
	{
		if (LimeManager.averageFrameTimeMs <= 0)
			return 0;

		return Std.int(1000 / LimeManager.averageFrameTimeMs);
	}

	function getMemoryLabel():String
	{
		#if cpp
		return '${Std.int(CPP.getMemoryUsageMB())}MB';
		#else
		return "n/a";
		#end
	}
}
