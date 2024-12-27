package flxanimate.animate;

import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil;
import flxanimate.data.AnimationData;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;

class SymbolParameters
{
	public var instance:String;

	public var type(default, set):SymbolT;

	public var loop(default, set):Loop;

	public var reverse:Bool;

	public var firstFrame:Int;

	public var name:String;

	public var colorEffect:ColorEffect;

	public var blendMode(default, set):BlendMode = null;

	@:allow(flxanimate.FlxAnimate)
	@:allow(flxanimate.animate.FlxAnim)
	var _colorEffect(get, never):ColorTransform;

	public var transformationPoint:FlxPoint;


	public function new(?name = null, ?instance:String = "", ?type:SymbolT = Graphic, ?loop:Loop = Loop)
	{
		this.name = name;
		this.instance = instance;
		this.type = type;
		this.loop = loop;
		firstFrame = 0;
		transformationPoint = FlxPoint.get();
		colorEffect = None;
	}

	public function destroy()
	{
		instance = null;
		type = null;
		reverse = false;
		firstFrame = 0;
		name = null;
		colorEffect = null;
		transformationPoint = FlxDestroyUtil.put(transformationPoint);
	}

	function set_type(type:SymbolT)
	{
		this.type = type;
		loop = (type == null) ? null : Loop;

		if(type == Graphic) {
			blendMode = null;
		}

		return type;
	}

	function set_loop(loop:Loop)
	{
		if (type == null) return this.loop = null;
		this.loop = switch (type)
		{
			case MovieClip: Loop;
			case Button: SingleFrame;
			default: loop;
		}

		return loop;
	}

	function set_blendMode(value:BlendMode)
	{
		if (type == Graphic) return blendMode = null;
		if (blendMode != value)
		{
			blendMode = value;
			//if (blendMode != NORMAL && _filterFrame == null)
			//	_renderDirty = true;
		}
		return value;
	}

	function get__colorEffect()
	{
		return AnimationData.parseColorEffect(colorEffect);
	}
}