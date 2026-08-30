package shark.menus.options;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.FlixelShark;
import git.graphic.GraphicGit;
import shark.backend.Language;
import shark.menus.MainMenuState;
import shark.ui.debug.CrasherLog;
import Main;

typedef OptionEntry = {
	label:String,
	description:String,
	getValue:Void->Bool,
	onToggle:Void->Bool
}

typedef ToggleVisual = {
	track:FlxSprite,
	knob:FlxSprite
}

class OptionsState extends FlxState
{
	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_DEEP:FlxColor = 0xFF012A4A;
	static inline var COLOR_MID:FlxColor = 0xFF01497C;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;
	static inline var COLOR_ON:FlxColor = 0xFF4ADE80;
	static inline var COLOR_OFF:FlxColor = 0xFFF87171;

	var options:Array<OptionEntry>;

	var titleText:FlxText;
	var isMobile:Bool;
	var contentEndY:Float;

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;

		options = buildOptions();

		FlixelShark.createDepthGradient(this, [COLOR_ABYSS, COLOR_DEEP, COLOR_MID]);

		titleText = new FlxText(0, isMobile ? 26 : 18, FlxG.width, Language.get("options.title"));
		titleText.setFormat(null, isMobile ? 34 : 28, COLOR_FOAM, FlxTextAlign.CENTER);
		titleText.setBorderStyle(SHADOW, COLOR_ACCENT, 2);
		add(titleText);

		createOptionsList();
		createLanguageRow();
		createFooterButtons();
	}

	function buildOptions():Array<OptionEntry>
	{
		return [
			{
				label: Language.get("options.fpsCounter"),
				description: Language.get("options.fpsCounterDescription"),
				getValue: Main.isFpsCounterVisible,
				onToggle: Main.toggleFpsCounter
			},
			{
				label: Language.get("options.vibration"),
				description: Language.get("options.vibrationDescription"),
				getValue: function():Bool return Main.settings.data.vibrationEnabled,
				onToggle: toggleVibration
			},
			{
				label: Language.get("options.reducedMotion"),
				description: Language.get("options.reducedMotionDescription"),
				getValue: function():Bool return Main.settings.data.reducedMotion,
				onToggle: toggleReducedMotion
			},
			{
				label: Language.get("options.devMode"),
				description: Language.get("options.devModeDescription"),
				getValue: Main.isDevModeEnabled,
				onToggle: Main.toggleDevMode
			}
		];
	}

	static function toggleVibration():Bool
	{
		var newValue:Bool = !Main.settings.data.vibrationEnabled;

		Main.settings.update(function(d) d.vibrationEnabled = newValue);
		shark.mobile.backend.Vibration.setEnabled(newValue);

		return newValue;
	}

	static function toggleReducedMotion():Bool
	{
		var newValue:Bool = !Main.settings.data.reducedMotion;

		Main.settings.update(function(d) d.reducedMotion = newValue);

		return newValue;
	}

	function rowWidth():Float
	{
		return FlxG.width - (isMobile ? 50 : 120);
	}

	function rowX():Float
	{
		return (FlxG.width - rowWidth()) / 2;
	}

	function rowSpacing():Float
	{
		return isMobile ? 80 : 64;
	}

	function rowHeight():Float
	{
		return rowSpacing() - 12;
	}

	function createOptionsList():Void
	{
		var startY:Float = isMobile ? 110 : 90;

		for (i in 0...options.length)
		{
			var entry:OptionEntry = options[i];
			var rowY:Float = startY + i * rowSpacing();

			createRowBackground(rowY);

			var labelText = new FlxText(rowX() + 16, rowY + 8, rowWidth() * 0.6, entry.label);
			labelText.setFormat(null, isMobile ? 20 : 16, COLOR_FOAM, FlxTextAlign.LEFT);
			add(labelText);

			var descText = new FlxText(rowX() + 16, rowY + 8 + (isMobile ? 26 : 20), rowWidth() * 0.6, entry.description);
			descText.setFormat(null, isMobile ? 13 : 11, COLOR_ACCENT, FlxTextAlign.LEFT);
			add(descText);

			createToggleRow(entry, rowY);
		}

		contentEndY = startY + options.length * rowSpacing();
	}

	function createRowBackground(rowY:Float):Void
	{
		var row = GraphicGit.makeRoundedRectSprite(rowX(), rowY, Std.int(rowWidth()), Std.int(rowHeight()), COLOR_MID, 10, 0.3);
		add(row);
	}

	function createToggleRow(entry:OptionEntry, rowY:Float):Void
	{
		var switchWidth:Float = isMobile ? 64 : 52;
		var switchHeight:Float = isMobile ? 32 : 26;
		var switchX:Float = rowX() + rowWidth() - switchWidth - 16;
		var switchY:Float = rowY + rowHeight() / 2 - switchHeight / 2;

		var visual:ToggleVisual = createToggleSwitch(switchX, switchY, switchWidth, switchHeight, entry.getValue());

		var hitArea:FlxButton = FlixelShark.createIconButton(this, rowX(), rowY, Std.int(rowWidth()), Std.int(rowHeight()), FlxColor.TRANSPARENT,
			function():Void
			{
				var newValue:Bool = entry.onToggle();
				setToggleState(visual, newValue, switchX, switchWidth, switchHeight);
			});

		hitArea.alpha = 0;
	}

	function createToggleSwitch(x:Float, y:Float, width:Float, height:Float, isOn:Bool):ToggleVisual
	{
		var knobRadius:Float = height / 2 - 3;

		var track:FlxSprite = GraphicGit.makePillSprite(x, y, Std.int(width), Std.int(height), isOn ? COLOR_ON : COLOR_OFF);
		add(track);

		var knob:FlxSprite = new FlxSprite();
		knob.pixels = GraphicGit.createPolygon(knobRadius, 28, FlxColor.WHITE);
		knob.y = y + height / 2 - knobRadius;
		knob.x = isOn ? x + width - knobRadius * 2 - 3 : x + 3;
		add(knob);

		return {track: track, knob: knob};
	}

	function setToggleState(visual:ToggleVisual, isOn:Bool, x:Float, width:Float, height:Float):Void
	{
		visual.track.pixels = GraphicGit.createPill(Std.int(width), Std.int(height), isOn ? COLOR_ON : COLOR_OFF);

		var knobRadius:Float = height / 2 - 3;
		var targetX:Float = isOn ? x + width - knobRadius * 2 - 3 : x + 3;

		FlxTween.tween(visual.knob, {x: targetX}, 0.15, {ease: FlxEase.quadOut});
	}

	function createLanguageRow():Void
	{
		var rowY:Float = contentEndY;

		createRowBackground(rowY);

		var labelText = new FlxText(rowX() + 16, rowY + 8, rowWidth() - 140, Language.get("options.language"));
		labelText.setFormat(null, isMobile ? 20 : 16, COLOR_FOAM, FlxTextAlign.LEFT);
		add(labelText);

		var buttonWidth:Float = isMobile ? 110 : 84;
		var buttonHeight:Float = isMobile ? 44 : 32;

		var languageButton:FlxButton = FlixelShark.makeButton(rowX() + rowWidth() - buttonWidth - 16, rowY + rowHeight() / 2 - buttonHeight / 2,
			Language.getLanguageName(Language.current), onLanguagePressed, Std.int(buttonWidth), Std.int(buttonHeight), COLOR_ACCENT, COLOR_ABYSS);
		add(languageButton);

		contentEndY = rowY + rowSpacing();
	}

	function createFooterButtons():Void
	{
		var backWidth:Float = isMobile ? 120 : 90;
		var backHeight:Float = isMobile ? 50 : 32;

		var backButton:FlxButton = FlixelShark.makeButton(20, FlxG.height - (isMobile ? 70 : 50), Language.get("menu.backButton"), onBackPressed,
			Std.int(backWidth), Std.int(backHeight), COLOR_MID, COLOR_FOAM);
		add(backButton);

		var resetWidth:Float = isMobile ? 160 : 130;

		var resetButton:FlxButton = FlixelShark.makeButton(FlxG.width - resetWidth - 20, FlxG.height - (isMobile ? 70 : 50), Language.get("options.reset"),
			onResetPressed, Std.int(resetWidth), Std.int(backHeight), COLOR_OFF, COLOR_ABYSS);
		add(resetButton);
	}

	function onLanguagePressed():Void
	{
		var list:Array<String> = Language.supportedLanguages;
		var currentIndex:Int = list.indexOf(Language.current);
		var nextIndex:Int = (currentIndex + 1) % list.length;

		Language.setLanguage(list[nextIndex]);

		FlixelShark.switchState(new OptionsState(), false);
	}

	function onResetPressed():Void
	{
		Main.settings.reset();
		Main.settings.forceSave();

		CrasherLog.addBreadcrumb("Settings reset to defaults", "settings");

		FlixelShark.switchState(new OptionsState(), false);
	}

	function onBackPressed():Void
	{
		FlixelShark.switchState(new MainMenuState(), true, 0.4, COLOR_ABYSS);
	}
}
