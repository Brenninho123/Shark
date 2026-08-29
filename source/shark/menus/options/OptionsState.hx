package shark.menus.options;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.ui.Toolkit;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.components.Button as UIButton;
import haxe.ui.components.Switch as UISwitch;
import flixel.FlixelShark;
import git.graphic.GraphicGit;
import shark.backend.Language;
import shark.menus.MainMenuState;
import shark.mobile.backend.HapticStyle;
import shark.mobile.backend.Vibration;
import shark.ui.debug.CrasherLog;
import Main;

typedef OptionEntry = {
	label:String,
	description:String,
	getValue:Void->Bool,
	onToggle:Void->Bool
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

	static var toolkitInitialized:Bool = false;

	var options:Array<OptionEntry>;

	var titleText:FlxText;
	var isMobile:Bool;
	var contentEndY:Float;
	var uiComponents:Array<Component> = [];

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;

		ensureToolkit();

		options = buildOptions();

		FlixelShark.createDepthGradient(this, [COLOR_ABYSS, COLOR_DEEP, COLOR_MID]);

		titleText = new FlxText(0, isMobile ? 26 : 18, FlxG.width, Language.get("options.title"));
		titleText.setFormat(null, isMobile ? 34 : 28, COLOR_FOAM, CENTER);
		titleText.setBorderStyle(SHADOW, COLOR_ACCENT, 2);
		add(titleText);

		createOptionsList();
		createLanguageRow();
		createFooterButtons();
	}

	static function ensureToolkit():Void
	{
		if (toolkitInitialized)
			return;

		toolkitInitialized = true;
		Toolkit.init();
	}

	function addUI<T:Component>(component:T):T
	{
		Screen.instance.addComponent(component);
		uiComponents.push(component);
		return component;
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
		Vibration.setEnabled(newValue);

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

			var labelText = new FlxText(rowX() + 16, rowY + 8, rowWidth() - 140, entry.label);
			labelText.setFormat(null, isMobile ? 20 : 16, COLOR_FOAM, LEFT);
			add(labelText);

			var descText = new FlxText(rowX() + 16, rowY + 8 + (isMobile ? 26 : 20), rowWidth() - 140, entry.description);
			descText.setFormat(null, isMobile ? 13 : 11, COLOR_ACCENT, LEFT);
			add(descText);

			createToggleSwitch(entry, rowY);
		}

		contentEndY = startY + options.length * rowSpacing();
	}

	function createRowBackground(rowY:Float):Void
	{
		var row = GraphicGit.makeRoundedRectSprite(rowX(), rowY, Std.int(rowWidth()), Std.int(rowHeight()), COLOR_MID, 10, 0.3);
		add(row);
	}

	function createToggleSwitch(entry:OptionEntry, rowY:Float):Void
	{
		var switchWidth:Float = isMobile ? 64 : 52;
		var switchHeight:Float = isMobile ? 32 : 26;

		var toggle = addUI(new UISwitch());
		toggle.selected = entry.getValue();
		toggle.left = rowX() + rowWidth() - switchWidth - 16;
		toggle.top = rowY + rowHeight() / 2 - switchHeight / 2;
		toggle.width = switchWidth;
		toggle.height = switchHeight;
		toggle.onChange = function(e:Dynamic):Void
		{
			Vibration.trigger(HapticStyle.SELECTION);
			entry.onToggle();
		};
	}

	function createLanguageRow():Void
	{
		var rowY:Float = contentEndY;

		createRowBackground(rowY);

		var labelText = new FlxText(rowX() + 16, rowY + 8, rowWidth() - 140, Language.get("options.language"));
		labelText.setFormat(null, isMobile ? 20 : 16, COLOR_FOAM, LEFT);
		add(labelText);

		var buttonWidth:Float = isMobile ? 110 : 84;
		var buttonHeight:Float = isMobile ? 44 : 32;

		var languageButton = addUI(new UIButton());
		languageButton.text = Language.getLanguageName(Language.current);
		languageButton.left = rowX() + rowWidth() - buttonWidth - 16;
		languageButton.top = rowY + rowHeight() / 2 - buttonHeight / 2;
		languageButton.width = buttonWidth;
		languageButton.height = buttonHeight;
		languageButton.onClick = function(e:Dynamic):Void
		{
			Vibration.trigger(HapticStyle.SELECTION);
			onLanguagePressed();
		};

		contentEndY = rowY + rowSpacing();
	}

	function createFooterButtons():Void
	{
		var backWidth:Float = isMobile ? 120 : 90;
		var backHeight:Float = isMobile ? 50 : 32;

		var backButton = addUI(new UIButton());
		backButton.text = Language.get("menu.backButton");
		backButton.left = 20;
		backButton.top = FlxG.height - (isMobile ? 70 : 50);
		backButton.width = backWidth;
		backButton.height = backHeight;
		backButton.onClick = function(e:Dynamic):Void
		{
			Vibration.menuSelect();
			onBackPressed();
		};

		var resetWidth:Float = isMobile ? 160 : 130;

		var resetButton = addUI(new UIButton());
		resetButton.text = Language.get("options.reset");
		resetButton.left = FlxG.width - resetWidth - 20;
		resetButton.top = FlxG.height - (isMobile ? 70 : 50);
		resetButton.width = resetWidth;
		resetButton.height = backHeight;
		resetButton.onClick = function(e:Dynamic):Void
		{
			Vibration.trigger(HapticStyle.WARNING);
			onResetPressed();
		};
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

	override public function destroy():Void
	{
		for (component in uiComponents)
			Screen.instance.removeComponent(component);

		uiComponents = [];

		super.destroy();
	}
}
