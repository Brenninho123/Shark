package shark.menus;

import flixel.FlxState;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.addons.ui.FlxInputText;
import flixel.util.FlxColor;
import shark.functions.ChatEngine;

class MainMenuState extends FlxState
{
	var inputField:FlxInputText;
	var historyText:FlxText;
	var sendHint:FlxText;

	var conversation:Array<String> = [];

	override public function create():Void
	{
		super.create();

		bgColor = FlxColor.BLACK;

		historyText = new FlxText(20, 20, FlxG.width - 40, "");
		historyText.setFormat(null, 16, FlxColor.WHITE, LEFT);
		add(historyText);

		inputField = new FlxInputText(20, FlxG.height - 60, FlxG.width - 40, "", 16, FlxColor.WHITE);
		inputField.backgroundColor = FlxColor.GRAY;
		add(inputField);

		sendHint = new FlxText(20, FlxG.height - 80, FlxG.width - 40, "Press ENTER to send");
		sendHint.setFormat(null, 12, FlxColor.GRAY, LEFT);
		add(sendHint);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.ENTER && inputField.text.length > 0)
			sendMessage(inputField.text);
	}

	function sendMessage(message:String):Void
	{
		appendToHistory("You: " + message);
		inputField.text = "";

		ChatEngine.send(message, onReply, onError);
	}

	function onReply(reply:String):Void
	{
		appendToHistory("Shark: " + reply);
	}

	function onError(error:String):Void
	{
		appendToHistory("Error: " + error);
	}

	function appendToHistory(line:String):Void
	{
		conversation.push(line);
		historyText.text = conversation.join("\n");
	}
}
