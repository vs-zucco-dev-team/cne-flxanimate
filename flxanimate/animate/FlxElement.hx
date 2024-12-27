package flxanimate.animate;

import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flxanimate.data.AnimationData;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;

class FlxElement implements IFlxDestroyable
{
	@:allow(flxanimate.animate.FlxKeyFrame)
	var _parent:FlxKeyFrame;
	/**
	 * All the other parameters that are exclusive to the symbol (instance, type, symbol name, etc.)
	 */
	public var symbol(default, null):SymbolParameters;
	/**
	 * The name of the frame itself.
	 */
	public var bitmap(default,null):String;
	/**
	 * The matrix that the symbol or bitmap has.
	 */
	public var matrix(default, null):FlxMatrix;
	/**
	 * Creates a new `FlxElement` instance.
	 * @param name the name of the element. `WARNING:` this name is dynamic, in other words, this name can used for the limb or the symbol!
	 * @param symbol the symbol settings, ignore this if you want to add a limb.
	 * @param matrix the matrix of the element.
	 */
	public function new(?bitmap:String, ?symbol:SymbolParameters, ?matrix:FlxMatrix)
	{
		this.bitmap = bitmap;
		this.symbol = symbol;
		this.matrix = (matrix == null) ? new FlxMatrix() : matrix;
	}

	public function toString()
	{
		return '{matrix: $matrix, bitmap: $bitmap}';
	}
	public function destroy()
	{
		_parent = null;
		if (symbol != null) {
			symbol.destroy();
			symbol = null;
		}
		bitmap = null;
		matrix = null;
	}

	static var m:Array<Float>;
	static var params:SymbolParameters;

	static var matrixNames = ["m00","m01","m10","m11","m30","m31"];

	static function blendFromString(value:String):BlendMode
	{
		return switch (value.toUpperCase())
		{
			case "ADD": BlendMode.ADD;
			case "ALPHA": BlendMode.ALPHA;
			case "DARKEN": BlendMode.DARKEN;
			case "DIFFERENCE": BlendMode.DIFFERENCE;
			case "ERASE": BlendMode.ERASE;
			case "HARDLIGHT": BlendMode.HARDLIGHT;
			case "INVERT": BlendMode.INVERT;
			case "LAYER": BlendMode.LAYER;
			case "LIGHTEN": BlendMode.LIGHTEN;
			case "MULTIPLY": BlendMode.MULTIPLY;
			case "NORMAL": BlendMode.NORMAL;
			case "OVERLAY": BlendMode.OVERLAY;
			case "SCREEN": BlendMode.SCREEN;
			case "SHADER": BlendMode.SHADER;
			case "SUBTRACT": BlendMode.SUBTRACT;
			default: cast Std.parseInt(value);
		}
	}

	static function parseBlendMode(name:String, blendMode:BlendMode):ParseBlendModeResult {
		var _bl = name.indexOf("_bl");
		if (_bl != -1)
		{
			_bl += 3;

			var end = name.indexOf("_", _bl);
			var temp = name.substring(_bl, end);
			blendMode = blendFromString(temp);

			name = name.substring(end + 1);
		}

		// _BLEND_<mode>_instance
		// If invalid the instance will be the same as input
		var _blend = name.indexOf("_BLEND_");
		if (_blend != -1) {
			var end = name.indexOf("_", _blend + 8);
			if(end != -1) {
				var temp = name.substring(_blend + 7, end);
				blendMode = blendFromString(temp);
				name = name.substring(end + 1);
			}
		}

		return {
			name: name,
			blendMode: blendMode
		};
	}

	public static function fromJSON(element:Element)
	{
		var symbol = element.SI != null;
		if (symbol)
		{
			params = new SymbolParameters();
			params.instance = element.SI.IN;
			params.name = element.SI.SN;
			params.type = switch (element.SI.ST)
			{
				case movieclip, "movieclip": MovieClip;
				case button, "button": Button;
				default: Graphic;
			}

			var temp = parseBlendMode(params.name, params.blendMode);
			//params.name = temp.name;
			params.blendMode = temp.blendMode;

			var temp = parseBlendMode(params.instance, params.blendMode);
			params.instance = temp.name;
			params.blendMode = temp.blendMode;

			var lp:LoopType = (element.SI.LP == null) ? loop : element.SI.LP.split("R")[0];
			params.loop = switch (lp) // remove the reverse sufix
			{
				case playonce, "playonce": PlayOnce;
				case singleframe, "singleframe": SingleFrame;
				default: Loop;
			}
			params.reverse = (element.SI.LP == null) ? false : StringTools.contains(element.SI.LP, "R");
			params.firstFrame = element.SI.FF;
			params.colorEffect = AnimationData.fromColorJson(element.SI.C);
			params.transformationPoint.set(element.SI.TRP.x, element.SI.TRP.y);
		} else {
			params = null;
		}

		var m3d = (symbol) ? element.SI.M3D : element.ASI.M3D;

		m = if((m3d is Array)) {
			[m3d[0], m3d[1], m3d[4], m3d[5], m3d[12], m3d[13]];
		} else {
			[for (field in matrixNames) Reflect.field(m3d,field)];
		}

		if (!symbol && m3d == null)
		{
			m[0] = m[3] = 1;
			m[1] = m[2] = m[4] = m[5] = 0;
		}

		var pos = (symbol) ? element.SI.bitmap.POS : element.ASI.POS;
		if (pos == null)
			pos = {x: 0, y: 0};
		return new FlxElement(
			(symbol) ? element.SI.bitmap.N : element.ASI.N,
			params,
			new FlxMatrix(m[0], m[1], m[2], m[3], m[4] + pos.x, m[5] + pos.y)
		);
	}
}

@:structInit
@:dox(hide)
class ParseBlendModeResult
{
	public var name:String;
	public var blendMode:BlendMode;
}