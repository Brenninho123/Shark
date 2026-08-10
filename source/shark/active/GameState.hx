package shark.active;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.FlixelShark;
import git.graphic.GraphicGit;
import git.resolution.Resolution4K;
import shark.active.games.BubblePopState;
import shark.active.games.ReefRunnerState;
import shark.active.games.DeepDiveState;
import shark.backend.Language;
import shark.menus.MainMenuState;

typedef GameEntry = {
	id:String,
	titleKey:String,
	descriptionKey:String,
	icon:String,
	accentColor:FlxColor,
	?stateClass:Class<FlxState>
}

class GameState extends FlxState
{
	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_DEEP:FlxColor = 0xFF012A4A;
	static inline var COLOR_MID:FlxColor = 0xFF01497C;
	static inline var COLOR_WAVE:FlxColor = 0xFF2C7DA0;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;
	static inline var COLOR_KELP:FlxColor = 0xFF14746F;
	static inline var COLOR_BUBBLE:FlxColor = 0xFF7FD8E8;
	static inline var COLOR_REEF:FlxColor = 0xFFEF9F76;

	var games:Array<GameEntry> = [
		{
			id: "bubble_pop",
			titleKey: "games.bubblePop",
			descriptionKey: "games.bubblePopDescription",
			icon: "o O o",
			accentColor: COLOR_BUBBLE,
			stateClass: BubblePopState
		},
		{
			id: "reef_runner",
			titleKey: "games.reefRunner",
			descriptionKey: "games.reefRunnerDescription",
			icon: ">>>",
			accentColor: COLOR_REEF,
			stateClass: ReefRunnerState
		},
		{
			id: "deep_dive",
			titleKey: "games.deepDive",
			descriptionKey: "games.deepDiveDescription",
			icon: "\\ /",
			accentColor: COLOR_ACCENT,
			stateClass: DeepDiveState
		}
	];

	var buttonGroup:FlxTypedGroup<FlxButton>;
	var titleText:FlxText;
	var subtitleText:FlxText;
	var backButton:FlxButton;
	var isMobile:Bool;

	var cardSprites:Array<{sprite:FlxSprite, baseY:Float, offset:Float}> = [];
	var bubbles:Array<FlxSprite> = [];
	var kelpBlades:Array<{sprite:FlxSprite, offset:Float, speed:Float}> = [];
	var lightRays:Array<FlxSprite> = [];

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;

		FlixelShark.createDepthGradient(this, [COLOR_ABYSS, COLOR_DEEP, COLOR_MID]);
		lightRays = FlixelShark.createLightRays(this, isMobile ? 3 : 5, COLOR_FOAM);
		kelpBlades = FlixelShark.createKelpField(this, isMobile ? 4 : 7, COLOR_KELP);
		bubbles = FlixelShark.createBubbleField(this, isMobile ? 6 : 10, COLOR_ACCENT);

		titleText = FlixelShark.makeLocalizedShadowText(0, isMobile ? 26 : 18, FlxG.width, "games.title", isMobile ? 34 : 28, COLOR_FOAM, COLOR_ACCENT,
			CENTER);
		add(titleText);

		subtitleText = FlixelShark.makeLocalizedText(0, titleText.y + titleText.height + 2, FlxG.width, "games.subtitle", isMobile ? 14 : 12, COLOR_ACCENT,
			CENTER);
		add(subtitleText);

		createGameList();

		backButton = FlixelShark.makeLocalizedButton(20, FlxG.height - (isMobile ? 70 : 50), "menu.backButton", onBackPressed, isMobile ? 120 : 90,
			isMobile ? 50 : 32, COLOR_MID, COLOR_FOAM);
		backButton.alpha = 0;
		add(backButton);

		FlxTween.tween(backButton, {alpha: 1}, 0.4, {startDelay: 0.2 + games.length * 0.1});
	}

	function createGameList():Void
	{
		buttonGroup = new FlxTypedGroup<FlxButton>();
		add(buttonGroup);

		var startY:Float = isMobile ? 130 : 100;
		var spacing:Float = isMobile ? 130 : 92;
		var cardWidth:Float = FlxG.width - (isMobile ? 50 : 120);
		var cardX:Float = (FlxG.width - cardWidth) / 2;
		var cardHeight:Float = spacing - 14;

		for (i in 0...games.length)
		{
			var entry:GameEntry = games[i];
			var cardY:Float = startY + i * spacing;

			var card:FlxSprite = FlixelShark.createRoundedCard(this, cardX, cardY, cardWidth, cardHeight, COLOR_MID, entry.accentColor, 10, COLOR_ABYSS);

			var iconBadge = GraphicGit.makeRoundedRectSprite(cardX + 20, cardY + cardHeight / 2 - 18, 36, 36, entry.accentColor, 8, 0.85);
			add(iconBadge);

			var iconLabel = FlixelShark.makeText(cardX + 20, cardY + cardHeight / 2 - 18, 36, entry.icon, Resolution4K.scaledInt(10), COLOR_ABYSS, CENTER);
			add(iconLabel);

			var titleLabel = FlixelShark.makeLocalizedText(cardX + 70, cardY + 12, cardWidth - 90, entry.titleKey, Resolution4K.scaledInt(isMobile ? 22 : 18),
				COLOR_FOAM, LEFT);
			add(titleLabel);

			var descLabel = FlixelShark.makeLocalizedText(cardX + 70, cardY + 12 + (isMobile ? 28 : 24), cardWidth - 190, entry.descriptionKey,
				Resolution4K.scaledInt(isMobile ? 13 : 12), COLOR_ACCENT, LEFT);
			add(descLabel);

			var playButton = FlixelShark.makeDebouncedButton(cardX + cardWidth - (isMobile ? 100 : 80), cardY + cardHeight / 2 - (isMobile ? 22 : 16), "Play",
				makeSelectHandler(entry), isMobile ? 80 : 64, isMobile ? 44 : 32, entry.accentColor, COLOR_ABYSS);
			buttonGroup.add(playButton);

			var delay:Float = i * 0.1;

			animateCardElement(card, 0.35, delay);
			animateCardElement(iconBadge, 0.85, delay);
			animateCardElement(iconLabel, 1, delay);
			animateCardElement(titleLabel, 1, delay);
			animateCardElement(descLabel, 1, delay);
			animateCardElement(playButton, 1, delay);

			cardSprites.push({sprite: card, baseY: cardY, offset: Std.random(6283) / 1000});
		}
	}

	function animateCardElement(sprite:FlxSprite, targetAlpha:Float, delay:Float):Void
	{
		var startY:Float = sprite.y;
		sprite.y += 20;
		sprite.alpha = 0;

		FlxTween.tween(sprite, {y: startY, alpha: targetAlpha}, 0.4, {
			ease: FlxEase.quadOut,
			startDelay: delay
		});
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
			FlixelShark.safeSwitchState(Type.createInstance(entry.stateClass, []));
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		FlixelShark.updateBubbleField(bubbles, elapsed);
		FlixelShark.updateKelpField(kelpBlades, elapsed);
	}

	function onBackPressed():Void
	{
		FlixelShark.safeSwitchState(new MainMenuState());
	}
}
