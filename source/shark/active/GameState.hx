package shark.active;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.group.FlxGroup.FlxTypedGroup;
import shark.active.games.BubblePopState;
import shark.active.games.ReefRunnerState;
import shark.active.games.DeepDiveState;
import shark.menus.MainMenuState;

typedef GameEntry = {
	id:String,
	title:String,
	description:String,
	?stateClass:Class<FlxState>
}

class GameState extends FlxState
{
	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_DEEP:FlxColor = 0xFF012A4A;
	static inline var COLOR_MID:FlxColor = 0xFF01497C;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;

	var games:Array<GameEntry> = [
		{id: "bubble_pop", title: "Bubble Pop", description: "Pop rising bubbles before they escape.", stateClass: BubblePopState},
		{id: "reef_runner", title: "Reef Runner", description: "Dodge obstacles swimming through the reef.", stateClass: ReefRunnerState},
		{id: "deep_dive", title: "Deep Dive", description: "See how far you can dive before hitting a rock.", stateClass: DeepDiveState}
	];

	var buttonGroup:FlxTypedGroup<FlxButton>;
	var titleText:FlxText;
	var backButton:FlxButton;
	var isMobile:Bool;

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;

		createBackground();

		titleText = new FlxText(0, isMobile ? 30 : 20, FlxG.width, "SELECT A GAME");
		titleText.setFormat(null, isMobile ? 32 : 26, COLOR_FOAM, CENTER);
		titleText.setBorderStyle(SHADOW, COLOR_ACCENT, 2);
		add(titleText);

		createGameList();

		backButton = new FlxButton(20, FlxG.height - (isMobile ? 70 : 50), "Back", onBackPressed);
		backButton.setSize(isMobile ? 120 : 90, isMobile ? 50 : 32);
		backButton.color = COLOR_MID;
		backButton.label.color = COLOR_FOAM;
		add(backButton);
	}

	function createBackground():Void
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

	function createGameList():Void
	{
		buttonGroup = new FlxTypedGroup<FlxButton>();
		add(buttonGroup);

		var startY:Float = isMobile ? 110 : 90;
		var spacing:Float = isMobile ? 110 : 80;
		var cardWidth:Float = FlxG.width - (isMobile ? 60 : 120);
		var cardX:Float = (FlxG.width - cardWidth) / 2;

		for (i in 0...games.length)
		{
			var entry:GameEntry = games[i];
			var cardY:Float = startY + i * spacing;

			var card = new FlxSprite(cardX, cardY).makeGraphic(Std.int(cardWidth), Std.int(spacing - 12), COLOR_MID);
			card.alpha = 0.35;
			add(card);

			var titleLabel = new FlxText(cardX + 16, cardY + 8, cardWidth - 32, entry.title);
			titleLabel.setFormat(null, isMobile ? 22 : 18, COLOR_FOAM, LEFT);
			add(titleLabel);

			var descLabel = new FlxText(cardX + 16, cardY + 8 + (isMobile ? 30 : 24), cardWidth - 140, entry.description);
			descLabel.setFormat(null, isMobile ? 14 : 12, COLOR_ACCENT, LEFT);
			add(descLabel);

			var playButton = new FlxButton(cardX + cardWidth - (isMobile ? 110 : 90), cardY + (spacing - 12 - (isMobile ? 44 : 32)) / 2, "Play", makeSelectHandler(entry));
			playButton.setSize(isMobile ? 90 : 70, isMobile ? 44 : 32);
			playButton.color = COLOR_ACCENT;
			playButton.label.color = COLOR_ABYSS;
			buttonGroup.add(playButton);
		}
	}

	function makeSelectHandler(entry:GameEntry):Void->Void
	{
		return function():Void
		{
			onGameSelected(entry);
		};
	}

	function onGameSelected(entry:GameEntry):Void
	{
		if (entry.stateClass != null)
		{
			FlxG.switchState(Type.createInstance(entry.stateClass, []));
			return;
		}
	}

	function onBackPressed():Void
	{
		FlxG.switchState(new MainMenuState());
	}
}
