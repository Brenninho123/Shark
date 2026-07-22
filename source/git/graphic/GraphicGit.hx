package git.graphic;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.GradientType;
import openfl.geom.Matrix;

class GraphicGit
{
	public static function createRoundedRect(width:Int, height:Int, color:FlxColor, radius:Float = 8, alpha:Float = 1):BitmapData
	{
		var shape = new Shape();
		shape.graphics.beginFill(color.rgb, alpha);
		shape.graphics.drawRoundRect(0, 0, width, height, radius * 2, radius * 2);
		shape.graphics.endFill();

		var bitmapData = new BitmapData(width, height, true, 0x00000000);
		bitmapData.draw(shape);

		return bitmapData;
	}

	public static function makeRoundedRectSprite(x:Float, y:Float, width:Int, height:Int, color:FlxColor, radius:Float = 8, alpha:Float = 1):FlxSprite
	{
		var sprite = new FlxSprite(x, y);
		sprite.pixels = createRoundedRect(width, height, color, radius, alpha);
		return sprite;
	}

	public static function createRoundedRectBorder(width:Int, height:Int, color:FlxColor, radius:Float = 8, thickness:Float = 2, alpha:Float = 1):BitmapData
	{
		var shape = new Shape();
		shape.graphics.lineStyle(thickness, color.rgb, alpha);
		shape.graphics.drawRoundRect(thickness / 2, thickness / 2, width - thickness, height - thickness, radius * 2, radius * 2);

		var bitmapData = new BitmapData(width, height, true, 0x00000000);
		bitmapData.draw(shape);

		return bitmapData;
	}

	public static function createGradient(width:Int, height:Int, colorTop:FlxColor, colorBottom:FlxColor, vertical:Bool = true, alphaTop:Float = 1,
			alphaBottom:Float = 1):BitmapData
	{
		var shape = new Shape();
		var matrix = new Matrix();

		if (vertical)
			matrix.createGradientBox(width, height, Math.PI / 2, 0, 0);
		else
			matrix.createGradientBox(width, height, 0, 0, 0);

		shape.graphics.beginGradientFill(GradientType.LINEAR, [colorTop.rgb, colorBottom.rgb], [alphaTop, alphaBottom], [0, 255], matrix);
		shape.graphics.drawRect(0, 0, width, height);
		shape.graphics.endFill();

		var bitmapData = new BitmapData(width, height, true, 0x00000000);
		bitmapData.draw(shape);

		return bitmapData;
	}

	public static function makeGradientSprite(x:Float, y:Float, width:Int, height:Int, colorTop:FlxColor, colorBottom:FlxColor, vertical:Bool = true,
			alphaTop:Float = 1, alphaBottom:Float = 1):FlxSprite
	{
		var sprite = new FlxSprite(x, y);
		sprite.pixels = createGradient(width, height, colorTop, colorBottom, vertical, alphaTop, alphaBottom);
		return sprite;
	}

	public static function createRadialGlow(size:Int, color:FlxColor, intensity:Float = 1):BitmapData
	{
		var shape = new Shape();
		var matrix = new Matrix();
		matrix.createGradientBox(size, size, 0, -size / 2, -size / 2);

		shape.graphics.beginGradientFill(GradientType.RADIAL, [color.rgb, color.rgb], [intensity, 0], [0, 255], matrix);
		shape.graphics.drawCircle(0, 0, size / 2);
		shape.graphics.endFill();

		var bitmapData = new BitmapData(size, size, true, 0x00000000);
		var offsetMatrix = new Matrix();
		offsetMatrix.translate(size / 2, size / 2);
		bitmapData.draw(shape, offsetMatrix);

		return bitmapData;
	}

	public static function makeGlowSprite(x:Float, y:Float, size:Int, color:FlxColor, intensity:Float = 1):FlxSprite
	{
		var sprite = new FlxSprite(x - size / 2, y - size / 2);
		sprite.pixels = createRadialGlow(size, color, intensity);
		return sprite;
	}

	public static function createSoftShadow(width:Int, height:Int, color:FlxColor = FlxColor.BLACK, layers:Int = 4, spread:Float = 6,
			baseAlpha:Float = 0.25):BitmapData
	{
		var totalSize:Int = width + Std.int(spread * 2);
		var bitmapData = new BitmapData(totalSize, totalSize, true, 0x00000000);

		for (i in 0...layers)
		{
			var t:Float = i / layers;
			var inset:Float = spread * (1 - t);
			var alpha:Float = baseAlpha * (1 - t);

			var shape = new Shape();
			shape.graphics.beginFill(color.rgb, alpha);
			shape.graphics.drawRoundRect(inset, inset, width + (spread - inset) * 2, height + (spread - inset) * 2, 12, 12);
			shape.graphics.endFill();

			bitmapData.draw(shape);
		}

		return bitmapData;
	}

	public static function createNoiseTexture(width:Int, height:Int, color:FlxColor = FlxColor.WHITE, minAlpha:Float = 0, maxAlpha:Float = 0.15):BitmapData
	{
		var bitmapData = new BitmapData(width, height, true, 0x00000000);

		for (px in 0...width)
		{
			for (py in 0...height)
			{
				var alpha:Float = minAlpha + Math.random() * (maxAlpha - minAlpha);
				var pixelColor:FlxColor = FlxColor.fromRGB(color.red, color.green, color.blue, Std.int(alpha * 255));
				bitmapData.setPixel32(px, py, pixelColor);
			}
		}

		return bitmapData;
	}
}
