package shark.menus.options;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import shark.backend.Language;
import shark.menus.MainMenuState;

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

	var options:Array<OptionEntry>;

	var titleText:FlxText;
	var backButton:FlxButton;
	var toggleButtons:Array<FlxButton> = [];
	var languageButton:FlxButton;
	var isMobile:Bool;
	var contentEndY:Float;

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;

		options = [
			{
				label: Language.get("options.fpsCounter"),
				description: Language.get("options.fpsCounterDescription"),
				getValue: Main.isFpsCounterVisible,
				onToggle: Main.toggleFpsCounter
			}
		];

		createDepthGradient();

		titleText = new FlxText(0, isMobile ? 26 : 18, FlxG.width, Language.get("options.title"));
		titleText.setFormat(null, isMobile ? 34 : 28, COLOR_FOAM, CENTER);
		titleText.setBorderStyle(SHADOW, COLOR_ACCENT, 2);
		add(titleText);

		createOptionsList();
		createLanguageRow();

		backButton = new FlxButton(20, FlxG.height - (isMobile ? 70 : 50), Language.get("menu.backButton"), onBackPressed);
		backButton.setSize(isMobile ? 120 : 90, isMobile ? 50 : 32);
		backButton.color = COLOR_MID;
		backButton.label.color = COLOR_FOAM;
		add(backButton);
	}

	function createDepthGradient():Void
	{
		var bands:Array<FlxColor> = [COLOR_ABYSS, COLOR_DEEP, COLOR_MID];
		var bandHeight:Int = Std.int(FlxG.height / bands.length) + 2;

		for (i in 0...bands.length)
		{
			var band = new FlxSprite(0, i * bandHeight);
			band.makeGraphic(FlxG.width, bandHeight, bands[i]);
			band.scrollFactor.set(0, 0);
			add(band);
		}
	}

	function createOptionsList():Void
	{
		var startY:Float = isMobile ? 110 : 90;
		var spacing:Float = isMobile ? 80 : 64;
		var rowWidth:Float = FlxG.width - (isMobile ? 50 : 120);
		var rowX:Float = (FlxG.width - rowWidth) / 2;
		var rowHeight:Float = spacing - 12;

		for (i in 0...options.length)
		{
			var entry:OptionEntry = options[i];
			var rowY:Float = startY + i * spacing;

			var row = new FlxSprite(rowX, rowY).makeGraphic(Std.int(rowWidth), Std.int(rowHeight), COLOR_MID);
			row.alpha = 0.3;
			add(row);

			var labelText = new FlxText(rowX + 16, rowY + 8, rowWidth - 140, entry.label);
			labelText.setFormat(null, isMobile ? 20 : 16, COLOR_FOAM, LEFT);
			add(labelText);

			var descText = new FlxText(rowX + 16, rowY + 8 + (isMobile ? 26 : 20), rowWidth - 140, entry.description);
			descText.setFormat(null, isMobile ? 13 : 11, COLOR_ACCENT, LEFT);
			add(descText);

			var isOn:Bool = entry.getValue();

			var toggleButton = new FlxButton(rowX + rowWidth - (isMobile ? 100 : 80), rowY + rowHeight / 2 - (isMobile ? 22 : 16), isOn ? "ON" : "OFF",
				makeToggleHandler(entry, toggleButtons.length));
			toggleButton.setSize(isMobile ? 80 : 64, isMobile ? 44 : 32);
			toggleButton.color = isOn ? COLOR_ON : COLOR_OFF;
			toggleButton.label.color = COLOR_ABYSS;
			add(toggleButton);

			toggleButtons.push(toggleButton);
		}

		contentEndY = startY + options.length * spacing;
	}

	function createLanguageRow():Void
	{
		var rowWidth:Float = FlxG.width - (isMobile ? 50 : 120);
		var rowX:Float = (FlxG.width - rowWidth) / 2;
		var rowHeight:Float = (isMobile ? 80 : 64) - 12;
		var rowY:Float = contentEndY;

		var row = new FlxSprite(rowX, rowY).makeGraphic(Std.int(rowWidth), Std.int(rowHeight), COLOR_MID);
		row.alpha = 0.3;
		add(row);

		var labelText = new FlxText(rowX + 16, rowY + 8, rowWidth - 140, Language.get("options.language"));
		labelText.setFormat(null, isMobile ? 20 : 16, COLOR_FOAM, LEFT);
		add(labelText);

		languageButton = new FlxButton(rowX + rowWidth - (isMobile ? 130 : 100), rowY + rowHeight / 2 - (isMobile ? 22 : 16),
			Language.getLanguageName(Language.current), onLanguagePressed);
		languageButton.setSize(isMobile ? 110 : 84, isMobile ? 44 : 32);
		languageButton.color = COLOR_ACCENT;
		languageButton.label.color = COLOR_ABYSS;
		add(languageButton);
	}

	function onLanguagePressed():Void
	{
		var list:Array<String> = Language.supportedLanguages;
		var currentIndex:Int = list.indexOf(Language.current);
		var nextIndex:Int = (currentIndex + 1) % list.length;

		Language.setLanguage(list[nextIndex]);

		FlxG.switchState(new OptionsState());
	}

	function makeToggleHandler(entry:OptionEntry, index:Int):Void->Void
	{
		return function():Void
		{
			var newValue:Bool = entry.onToggle();
			var button:FlxButton = toggleButtons[index];

			button.text = newValue ? "ON" : "OFF";
			button.color = newValue ? COLOR_ON : COLOR_OFF;

			button.scale.set(1.1, 1.1);
			FlxTween.tween(button.scale, {x: 1, y: 1}, 0.15, {ease: FlxEase.quadOut});
		};
	}

	function onBackPressed():Void
	{
		FlxG.switchState(new MainMenuState());
	}
}
