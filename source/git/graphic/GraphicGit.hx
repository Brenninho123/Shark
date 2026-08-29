package git.graphic;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.GradientType;
import openfl.display.CapsStyle;
import openfl.display.JointStyle;
import openfl.display.LineScaleMode;
import openfl.geom.Matrix;

typedef CornerRadii = {
	topLeft:Float,
	topRight:Float,
	bottomRight:Float,
	bottomLeft:Float
}

enum abstract BubbleTail(Int)
{
	var LEFT = 0;
	var RIGHT = 1;
	var NONE = 2;
}

class GraphicGit
{
	static inline var CACHE_LIMIT:Int = 60;

	static var cache:Map<String, BitmapData> = new Map();
	static var cacheOrder:Array<String> = [];

	public static function createRoundedRect(width:Int, height:Int, color:FlxColor, radius:Float = 8, alpha:Float = 1):BitmapData
	{
		var key:String = 'rect:$width:$height:${color.rgb}:$radius:$alpha';

		return cachedClone(key, function():BitmapData
		{
			var shape = new Shape();
			shape.graphics.beginFill(color.rgb, alpha);
			shape.graphics.drawRoundRect(0, 0, width, height, radius * 2, radius * 2);
			shape.graphics.endFill();

			var bitmapData = new BitmapData(width, height, true, 0x00000000);
			bitmapData.draw(shape, null, null, null, null, true);
			return bitmapData;
		});
	}

	public static function makeRoundedRectSprite(x:Float, y:Float, width:Int, height:Int, color:FlxColor, radius:Float = 8, alpha:Float = 1):FlxSprite
	{
		return spriteFrom(x, y, createRoundedRect(width, height, color, radius, alpha));
	}

	public static function createRoundedRectComplex(width:Int, height:Int, color:FlxColor, radii:CornerRadii, alpha:Float = 1):BitmapData
	{
		var key:String = 'rectComplex:$width:$height:${color.rgb}:${radii.topLeft}:${radii.topRight}:${radii.bottomRight}:${radii.bottomLeft}:$alpha';

		return cachedClone(key, function():BitmapData
		{
			var shape = new Shape();
			shape.graphics.beginFill(color.rgb, alpha);
			shape.graphics.drawRoundRectComplex(0, 0, width, height, radii.topLeft, radii.topRight, radii.bottomLeft, radii.bottomRight);
			shape.graphics.endFill();

			var bitmapData = new BitmapData(width, height, true, 0x00000000);
			bitmapData.draw(shape, null, null, null, null, true);
			return bitmapData;
		});
	}

	public static function makeRoundedRectComplexSprite(x:Float, y:Float, width:Int, height:Int, color:FlxColor, radii:CornerRadii, alpha:Float = 1):FlxSprite
	{
		return spriteFrom(x, y, createRoundedRectComplex(width, height, color, radii, alpha));
	}

	public static function createPill(width:Int, height:Int, color:FlxColor, alpha:Float = 1):BitmapData
	{
		return createRoundedRect(width, height, color, height / 2, alpha);
	}

	public static function makePillSprite(x:Float, y:Float, width:Int, height:Int, color:FlxColor, alpha:Float = 1):FlxSprite
	{
		return spriteFrom(x, y, createPill(width, height, color, alpha));
	}

	public static function createFilledRoundedRectWithBorder(width:Int, height:Int, fillColor:FlxColor, borderColor:FlxColor, radius:Float = 8,
			borderThickness:Float = 2, fillAlpha:Float = 1, borderAlpha:Float = 1):BitmapData
	{
		var key:String = 'rectBordered:$width:$height:${fillColor.rgb}:${borderColor.rgb}:$radius:$borderThickness:$fillAlpha:$borderAlpha';

		return cachedClone(key, function():BitmapData
		{
			var shape = new Shape();
			shape.graphics.beginFill(fillColor.rgb, fillAlpha);
			shape.graphics.lineStyle(borderThickness, borderColor.rgb, borderAlpha);
			shape.graphics.drawRoundRect(borderThickness / 2, borderThickness / 2, width - borderThickness, height - borderThickness, radius * 2,
				radius * 2);
			shape.graphics.endFill();

			var bitmapData = new BitmapData(width, height, true, 0x00000000);
			bitmapData.draw(shape, null, null, null, null, true);
			return bitmapData;
		});
	}

	public static function makeFilledRoundedRectWithBorderSprite(x:Float, y:Float, width:Int, height:Int, fillColor:FlxColor, borderColor:FlxColor,
			radius:Float = 8, borderThickness:Float = 2, fillAlpha:Float = 1, borderAlpha:Float = 1):FlxSprite
	{
		return spriteFrom(x, y, createFilledRoundedRectWithBorder(width, height, fillColor, borderColor, radius, borderThickness, fillAlpha, borderAlpha));
	}

	public static function createRoundedRectBorder(width:Int, height:Int, color:FlxColor, radius:Float = 8, thickness:Float = 2, alpha:Float = 1):BitmapData
	{
		var key:String = 'rectBorder:$width:$height:${color.rgb}:$radius:$thickness:$alpha';

		return cachedClone(key, function():BitmapData
		{
			var shape = new Shape();
			shape.graphics.lineStyle(thickness, color.rgb, alpha);
			shape.graphics.drawRoundRect(thickness / 2, thickness / 2, width - thickness, height - thickness, radius * 2, radius * 2);

			var bitmapData = new BitmapData(width, height, true, 0x00000000);
			bitmapData.draw(shape, null, null, null, null, true);
			return bitmapData;
		});
	}

	public static function makeRoundedRectBorderSprite(x:Float, y:Float, width:Int, height:Int, color:FlxColor, radius:Float = 8, thickness:Float = 2,
			alpha:Float = 1):FlxSprite
	{
		return spriteFrom(x, y, createRoundedRectBorder(width, height, color, radius, thickness, alpha));
	}

	public static function createChatBubble(width:Int, height:Int, color:FlxColor, radius:Float = 12, tail:BubbleTail = LEFT, tailSize:Float = 10,
			alpha:Float = 1):BitmapData
	{
		var key:String = 'bubble:$width:$height:${color.rgb}:$radius:$tail:$tailSize:$alpha';

		return cachedClone(key, function():BitmapData
		{
			var padding:Int = Std.int(tail == NONE ? 0 : tailSize);
			var totalWidth:Int = width + padding;

			var shape = new Shape();
			shape.graphics.beginFill(color.rgb, alpha);

			var bodyX:Float = tail == LEFT ? padding : 0;
			shape.graphics.drawRoundRect(bodyX, 0, width, height, radius * 2, radius * 2);

			if (tail != NONE)
			{
				var tailY:Float = height - radius - tailSize * 0.6;

				if (tail == LEFT)
				{
					shape.graphics.moveTo(bodyX, tailY);
					shape.graphics.lineTo(0, tailY + tailSize * 0.5);
					shape.graphics.lineTo(bodyX, tailY + tailSize);
				}
				else
				{
					shape.graphics.moveTo(bodyX + width, tailY);
					shape.graphics.lineTo(totalWidth, tailY + tailSize * 0.5);
					shape.graphics.lineTo(bodyX + width, tailY + tailSize);
				}
			}

			shape.graphics.endFill();

			var bitmapData = new BitmapData(totalWidth, height, true, 0x00000000);
			bitmapData.draw(shape, null, null, null, null, true);
			return bitmapData;
		});
	}

	public static function makeChatBubbleSprite(x:Float, y:Float, width:Int, height:Int, color:FlxColor, radius:Float = 12, tail:BubbleTail = LEFT,
			tailSize:Float = 10, alpha:Float = 1):FlxSprite
	{
		return spriteFrom(x, y, createChatBubble(width, height, color, radius, tail, tailSize, alpha));
	}

	public static function createGradient(width:Int, height:Int, colorTop:FlxColor, colorBottom:FlxColor, vertical:Bool = true, alphaTop:Float = 1,
			alphaBottom:Float = 1):BitmapData
	{
		var key:String = 'gradient:$width:$height:${colorTop.rgb}:${colorBottom.rgb}:$vertical:$alphaTop:$alphaBottom';

		return cachedClone(key, function():BitmapData
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
			bitmapData.draw(shape, null, null, null, null, true);
			return bitmapData;
		});
	}

	public static function makeGradientSprite(x:Float, y:Float, width:Int, height:Int, colorTop:FlxColor, colorBottom:FlxColor, vertical:Bool = true,
			alphaTop:Float = 1, alphaBottom:Float = 1):FlxSprite
	{
		return spriteFrom(x, y, createGradient(width, height, colorTop, colorBottom, vertical, alphaTop, alphaBottom));
	}

	public static function createGradientMultiStop(width:Int, height:Int, colors:Array<FlxColor>, alphas:Array<Float>, ratios:Array<Float>,
			angleDegrees:Float = 90):BitmapData
	{
		var key:String = 'gradientMulti:$width:$height:${colors.join(",")}:${alphas.join(",")}:${ratios.join(",")}:$angleDegrees';

		return cachedClone(key, function():BitmapData
		{
			var shape = new Shape();
			var matrix = new Matrix();
			matrix.createGradientBox(width, height, angleDegrees * Math.PI / 180, 0, 0);

			var rgbColors:Array<Int> = [for (c in colors) c.rgb];
			var ratioBytes:Array<Int> = [for (r in ratios) Std.int(r * 255)];

			shape.graphics.beginGradientFill(GradientType.LINEAR, rgbColors, alphas, ratioBytes, matrix);
			shape.graphics.drawRect(0, 0, width, height);
			shape.graphics.endFill();

			var bitmapData = new BitmapData(width, height, true, 0x00000000);
			bitmapData.draw(shape, null, null, null, null, true);
			return bitmapData;
		});
	}

	public static function makeGradientMultiStopSprite(x:Float, y:Float, width:Int, height:Int, colors:Array<FlxColor>, alphas:Array<Float>,
			ratios:Array<Float>, angleDegrees:Float = 90):FlxSprite
	{
		return spriteFrom(x, y, createGradientMultiStop(width, height, colors, alphas, ratios, angleDegrees));
	}

	public static function createRadialGlow(size:Int, color:FlxColor, intensity:Float = 1):BitmapData
	{
		var key:String = 'glow:$size:${color.rgb}:$intensity';

		return cachedClone(key, function():BitmapData
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
			bitmapData.draw(shape, offsetMatrix, null, null, null, true);
			return bitmapData;
		});
	}

	public static function makeGlowSprite(x:Float, y:Float, size:Int, color:FlxColor, intensity:Float = 1):FlxSprite
	{
		return spriteFrom(x - size / 2, y - size / 2, createRadialGlow(size, color, intensity));
	}

	public static function createSoftShadow(width:Int, height:Int, color:FlxColor = FlxColor.BLACK, layers:Int = 4, spread:Float = 6,
			baseAlpha:Float = 0.25):BitmapData
	{
		var key:String = 'softShadow:$width:$height:${color.rgb}:$layers:$spread:$baseAlpha';

		return cachedClone(key, function():BitmapData
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

				bitmapData.draw(shape, null, null, null, null, true);
			}

			return bitmapData;
		});
	}

	public static function createDropShadow(width:Int, height:Int, offsetX:Float = 4, offsetY:Float = 4, color:FlxColor = FlxColor.BLACK,
			radius:Float = 8, layers:Int = 4, spread:Float = 6, baseAlpha:Float = 0.3):BitmapData
	{
		var key:String = 'dropShadow:$width:$height:$offsetX:$offsetY:${color.rgb}:$radius:$layers:$spread:$baseAlpha';

		return cachedClone(key, function():BitmapData
		{
			var padX:Int = Std.int(Math.abs(offsetX) + spread * 2);
			var padY:Int = Std.int(Math.abs(offsetY) + spread * 2);
			var totalWidth:Int = width + padX * 2;
			var totalHeight:Int = height + padY * 2;

			var bitmapData = new BitmapData(totalWidth, totalHeight, true, 0x00000000);

			for (i in 0...layers)
			{
				var t:Float = i / layers;
				var inset:Float = spread * (1 - t);
				var alpha:Float = baseAlpha * (1 - t);

				var shape = new Shape();
				shape.graphics.beginFill(color.rgb, alpha);
				shape.graphics.drawRoundRect(padX + offsetX - inset, padY + offsetY - inset, width + inset * 2, height + inset * 2, radius * 2,
					radius * 2);
				shape.graphics.endFill();

				bitmapData.draw(shape, null, null, null, null, true);
			}

			return bitmapData;
		});
	}

	public static function createPolygon(radius:Float, sides:Int, color:FlxColor, rotationDegrees:Float = -90, alpha:Float = 1):BitmapData
	{
		var key:String = 'polygon:$radius:$sides:${color.rgb}:$rotationDegrees:$alpha';

		return cachedClone(key, function():BitmapData
		{
			var size:Int = Std.int(radius * 2);
			var shape = new Shape();
			shape.graphics.beginFill(color.rgb, alpha);

			var rotationRad:Float = rotationDegrees * Math.PI / 180;

			for (i in 0...sides)
			{
				var angle:Float = rotationRad + (i / sides) * Math.PI * 2;
				var px:Float = radius + Math.cos(angle) * radius;
				var py:Float = radius + Math.sin(angle) * radius;

				if (i == 0)
					shape.graphics.moveTo(px, py);
				else
					shape.graphics.lineTo(px, py);
			}

			shape.graphics.closePath();
			shape.graphics.endFill();

			var bitmapData = new BitmapData(size, size, true, 0x00000000);
			bitmapData.draw(shape, null, null, null, null, true);
			return bitmapData;
		});
	}

	public static function makePolygonSprite(x:Float, y:Float, radius:Float, sides:Int, color:FlxColor, rotationDegrees:Float = -90,
			alpha:Float = 1):FlxSprite
	{
		return spriteFrom(x - radius, y - radius, createPolygon(radius, sides, color, rotationDegrees, alpha));
	}

	public static function createStar(outerRadius:Float, innerRadius:Float, points:Int, color:FlxColor, rotationDegrees:Float = -90,
			alpha:Float = 1):BitmapData
	{
		var key:String = 'star:$outerRadius:$innerRadius:$points:${color.rgb}:$rotationDegrees:$alpha';

		return cachedClone(key, function():BitmapData
		{
			var size:Int = Std.int(outerRadius * 2);
			var shape = new Shape();
			shape.graphics.beginFill(color.rgb, alpha);

			var rotationRad:Float = rotationDegrees * Math.PI / 180;
			var totalPoints:Int = points * 2;

			for (i in 0...totalPoints)
			{
				var isOuter:Bool = i % 2 == 0;
				var r:Float = isOuter ? outerRadius : innerRadius;
				var angle:Float = rotationRad + (i / totalPoints) * Math.PI * 2;
				var px:Float = outerRadius + Math.cos(angle) * r;
				var py:Float = outerRadius + Math.sin(angle) * r;

				if (i == 0)
					shape.graphics.moveTo(px, py);
				else
					shape.graphics.lineTo(px, py);
			}

			shape.graphics.closePath();
			shape.graphics.endFill();

			var bitmapData = new BitmapData(size, size, true, 0x00000000);
			bitmapData.draw(shape, null, null, null, null, true);
			return bitmapData;
		});
	}

	public static function makeStarSprite(x:Float, y:Float, outerRadius:Float, innerRadius:Float, points:Int, color:FlxColor,
			rotationDegrees:Float = -90, alpha:Float = 1):FlxSprite
	{
		return spriteFrom(x - outerRadius, y - outerRadius, createStar(outerRadius, innerRadius, points, color, rotationDegrees, alpha));
	}

	public static function createCheckmark(size:Int, color:FlxColor, thickness:Float = 3, alpha:Float = 1):BitmapData
	{
		var key:String = 'check:$size:${color.rgb}:$thickness:$alpha';

		return cachedClone(key, function():BitmapData
		{
			var shape = new Shape();
			shape.graphics.lineStyle(thickness, color.rgb, alpha, false, LineScaleMode.NORMAL, CapsStyle.ROUND, JointStyle.ROUND);
			shape.graphics.moveTo(size * 0.2, size * 0.55);
			shape.graphics.lineTo(size * 0.42, size * 0.75);
			shape.graphics.lineTo(size * 0.82, size * 0.28);

			var bitmapData = new BitmapData(size, size, true, 0x00000000);
			bitmapData.draw(shape, null, null, null, null, true);
			return bitmapData;
		});
	}

	public static function makeCheckmarkSprite(x:Float, y:Float, size:Int, color:FlxColor, thickness:Float = 3, alpha:Float = 1):FlxSprite
	{
		return spriteFrom(x, y, createCheckmark(size, color, thickness, alpha));
	}

	public static function createCross(size:Int, color:FlxColor, thickness:Float = 3, alpha:Float = 1):BitmapData
	{
		var key:String = 'cross:$size:${color.rgb}:$thickness:$alpha';

		return cachedClone(key, function():BitmapData
		{
			var shape = new Shape();
			var margin:Float = size * 0.22;

			shape.graphics.lineStyle(thickness, color.rgb, alpha, false, LineScaleMode.NORMAL, CapsStyle.ROUND, JointStyle.ROUND);
			shape.graphics.moveTo(margin, margin);
			shape.graphics.lineTo(size - margin, size - margin);
			shape.graphics.moveTo(size - margin, margin);
			shape.graphics.lineTo(margin, size - margin);

			var bitmapData = new BitmapData(size, size, true, 0x00000000);
			bitmapData.draw(shape, null, null, null, null, true);
			return bitmapData;
		});
	}

	public static function makeCrossSprite(x:Float, y:Float, size:Int, color:FlxColor, thickness:Float = 3, alpha:Float = 1):FlxSprite
	{
		return spriteFrom(x, y, createCross(size, color, thickness, alpha));
	}

	public static function createPlus(size:Int, color:FlxColor, thickness:Float = 3, alpha:Float = 1):BitmapData
	{
		var key:String = 'plus:$size:${color.rgb}:$thickness:$alpha';

		return cachedClone(key, function():BitmapData
		{
			var shape = new Shape();
			var margin:Float = size * 0.18;

			shape.graphics.lineStyle(thickness, color.rgb, alpha, false, LineScaleMode.NORMAL, CapsStyle.ROUND, JointStyle.ROUND);
			shape.graphics.moveTo(size / 2, margin);
			shape.graphics.lineTo(size / 2, size - margin);
			shape.graphics.moveTo(margin, size / 2);
			shape.graphics.lineTo(size - margin, size / 2);

			var bitmapData = new BitmapData(size, size, true, 0x00000000);
			bitmapData.draw(shape, null, null, null, null, true);
			return bitmapData;
		});
	}

	public static function makePlusSprite(x:Float, y:Float, size:Int, color:FlxColor, thickness:Float = 3, alpha:Float = 1):FlxSprite
	{
		return spriteFrom(x, y, createPlus(size, color, thickness, alpha));
	}

	public static function createNoiseTexture(width:Int, height:Int, color:FlxColor = FlxColor.WHITE, minAlpha:Float = 0, maxAlpha:Float = 0.15):BitmapData
	{
		var key:String = 'noise:$width:$height:${color.rgb}:$minAlpha:$maxAlpha';

		return cachedClone(key, function():BitmapData
		{
			var bitmapData = new BitmapData(width, height, true, 0x00000000);
			bitmapData.lock();

			for (px in 0...width)
			{
				for (py in 0...height)
				{
					var alpha:Float = minAlpha + Math.random() * (maxAlpha - minAlpha);
					var pixelColor:FlxColor = FlxColor.fromRGB(color.red, color.green, color.blue, Std.int(alpha * 255));
					bitmapData.setPixel32(px, py, pixelColor);
				}
			}

			bitmapData.unlock();
			return bitmapData;
		});
	}

	public static function createPerlinNoise(width:Int, height:Int, scaleX:Float = 40, scaleY:Float = 40, octaves:Int = 4, seed:Int = 0,
			grayscale:Bool = true):BitmapData
	{
		var key:String = 'perlin:$width:$height:$scaleX:$scaleY:$octaves:$seed:$grayscale';

		return cachedClone(key, function():BitmapData
		{
			var bitmapData = new BitmapData(width, height, true, 0x00000000);
			bitmapData.perlinNoise(scaleX, scaleY, octaves, seed, false, true, 7, grayscale);
			return bitmapData;
		});
	}

	static function cachedClone(key:String, build:Void->BitmapData):BitmapData
	{
		if (!cache.exists(key))
			storeInCache(key, build());

		return cache.get(key).clone();
	}

	static function storeInCache(key:String, bitmapData:BitmapData):Void
	{
		cache.set(key, bitmapData);
		cacheOrder.push(key);

		if (cacheOrder.length > CACHE_LIMIT)
		{
			var oldestKey:String = cacheOrder.shift();

			if (oldestKey != key && cache.exists(oldestKey))
			{
				cache.get(oldestKey).dispose();
				cache.remove(oldestKey);
			}
		}
	}

	public static function clearCache():Void
	{
		for (key in cacheOrder)
			if (cache.exists(key))
				cache.get(key).dispose();

		cache = new Map();
		cacheOrder = [];
	}

	public static function getCacheSize():Int
	{
		return cacheOrder.length;
	}

	static function spriteFrom(x:Float, y:Float, bitmapData:BitmapData):FlxSprite
	{
		var sprite = new FlxSprite(x, y);
		sprite.pixels = bitmapData;
		return sprite;
	}
}
