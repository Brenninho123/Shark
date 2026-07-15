package shark.backend;

class JsonObject
{
	var data:Dynamic;

	public function new(?source:Dynamic)
	{
		data = source != null ? source : {};
	}

	public static function parse(raw:String):JsonObject
	{
		if (raw == null)
			return new JsonObject();

		try
		{
			return new JsonObject(haxe.Json.parse(raw));
		}
		catch (e:Dynamic)
		{
			return new JsonObject();
		}
	}

	public static function fromDynamic(source:Dynamic):JsonObject
	{
		return new JsonObject(source);
	}

	public function has(key:String):Bool
	{
		return data != null && Reflect.hasField(data, key) && Reflect.field(data, key) != null;
	}

	public function getString(key:String, defaultValue:String = ""):String
	{
		if (!has(key))
			return defaultValue;

		return Std.string(Reflect.field(data, key));
	}

	public function getInt(key:String, defaultValue:Int = 0):Int
	{
		if (!has(key))
			return defaultValue;

		var value:Dynamic = Reflect.field(data, key);

		if (Std.isOfType(value, Int) || Std.isOfType(value, Float))
			return Std.int(value);

		var parsed:Null<Int> = Std.parseInt(Std.string(value));

		return parsed != null ? parsed : defaultValue;
	}

	public function getFloat(key:String, defaultValue:Float = 0):Float
	{
		if (!has(key))
			return defaultValue;

		var value:Dynamic = Reflect.field(data, key);

		if (Std.isOfType(value, Int) || Std.isOfType(value, Float))
			return cast(value, Float);

		var parsed:Null<Float> = Std.parseFloat(Std.string(value));

		return !Math.isNaN(parsed) ? parsed : defaultValue;
	}

	public function getBool(key:String, defaultValue:Bool = false):Bool
	{
		if (!has(key))
			return defaultValue;

		var value:Dynamic = Reflect.field(data, key);

		if (Std.isOfType(value, Bool))
			return value;

		return Std.string(value).toLowerCase() == "true";
	}

	public function getObject(key:String):JsonObject
	{
		if (!has(key))
			return new JsonObject();

		return new JsonObject(Reflect.field(data, key));
	}

	public function getArray(key:String):Array<Dynamic>
	{
		if (!has(key))
			return [];

		var value:Dynamic = Reflect.field(data, key);

		return Std.isOfType(value, Array) ? cast(value, Array<Dynamic>) : [];
	}

	public function getStringArray(key:String):Array<String>
	{
		var raw:Array<Dynamic> = getArray(key);
		var result:Array<String> = [];

		for (item in raw)
			result.push(Std.string(item));

		return result;
	}

	public function getObjectArray(key:String):Array<JsonObject>
	{
		var raw:Array<Dynamic> = getArray(key);
		var result:Array<JsonObject> = [];

		for (item in raw)
			result.push(new JsonObject(item));

		return result;
	}

	public function getPath(path:String, ?defaultValue:Dynamic):Dynamic
	{
		var parts:Array<String> = path.split(".");
		var current:Dynamic = data;

		for (part in parts)
		{
			if (current == null || !Reflect.hasField(current, part))
				return defaultValue;

			current = Reflect.field(current, part);
		}

		return current != null ? current : defaultValue;
	}

	public function set(key:String, value:Dynamic):JsonObject
	{
		Reflect.setField(data, key, value);
		return this;
	}

	public function keys():Array<String>
	{
		return data != null ? Reflect.fields(data) : [];
	}

	public function toDynamic():Dynamic
	{
		return data;
	}

	public function stringify(pretty:Bool = false):String
	{
		return haxe.Json.stringify(data, pretty ? "\t" : null);
	}
}
