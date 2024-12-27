package flxanimate;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxPool;
import flxanimate.animate.*;
import flxanimate.animate.FlxAnim;
import flxanimate.data.AnimationData;
import flxanimate.frames.FlxAnimateFrames;
import flxanimate.zip.Zip;
import haxe.io.BytesInput;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;

typedef Settings = {
	?ButtonSettings:Map<String, flxanimate.animate.FlxAnim.ButtonSettings>,
	?FrameRate:Float,
	?Reversed:Bool,
	?OnComplete:Void->Void,
	?ShowPivot:Bool,
	?Antialiasing:Bool,
	?ScrollFactor:FlxPoint,
	?Offset:FlxPoint,
}

class DestroyableColorTransform extends ColorTransform implements IFlxDestroyable {
	public function destroy() {
		@:privateAccess
		__identity();
	}
}

class DestroyableFlxMatrix extends FlxMatrix implements IFlxDestroyable {
	public function destroy() {
		identity();
	}
}

@:access(openfl.geom.Rectangle)
class FlxAnimate extends FlxSprite
{
	public static var colorTransformsPool:FlxPool<DestroyableColorTransform> = new FlxPool(DestroyableColorTransform);
	public static var matrixesPool:FlxPool<DestroyableFlxMatrix> = new FlxPool(DestroyableFlxMatrix);
	public var anim(default, null):FlxAnim;

	//var rect:Rectangle;

	// #if FLX_SOUND_SYSTEM
	// public var audio:FlxSound;
	// #end

	// public var rectangle:FlxRect;

	#if !FLX_CNE_FORK
	public var shaderEnabled:Bool = false;
	#end

	public var showPivot(default, set):Bool = false;

	var _pivot:FlxFrame;
	/**
	 * # Description
	 * `FlxAnimate` is a texture atlas parser from the drawing software *Adobe Animate* (once being *Adobe Flash*).
	 * It tries to replicate how Adobe Animate works on Haxe so it would be considered (as *MrCheemsAndFriends* likes to call it,) a "*Flash--*", in other words, a replica of Animate's work
	 * on the side of drawing, making symbols, etc.
	 * ## WARNINGS
	 * - This does **NOT** convert the frames into a spritesheet
	 * - Since this is some sort of beta, expect that there could be some inconveniences (bugs, crashes, etc).
	 *
	 * @param X 		The initial X position of the sprite.
	 * @param Y 		The initial Y position of the sprite.
	 * @param Path      The path to the texture atlas, **NOT** the path of the any of the files inside the texture atlas (`Animation.json`, `spritemap.json`, etc).
	 * @param Settings  Optional settings for the animation (antialiasing, framerate, reversed, etc.).
	 */
	public function new(X:Float = 0, Y:Float = 0, ?Path:String, ?Settings:Settings)
	{
		super(X, Y);
		shaderEnabled = false;
		anim = new FlxAnim(this);
		if (Path != null)
			loadAtlas(Path);
		if (Settings != null)
			setTheSettings(Settings);

		//rect = new Rectangle();
	}

	function set_showPivot(v:Bool) {
		if(v && _pivot == null) {
			@:privateAccess
			_pivot = new FlxFrame(FlxGraphic.fromBitmapData(Assets.getBitmapData("flxanimate/images/pivot.png")));
			_pivot.frame = new FlxRect(0, 0, _pivot.parent.width, _pivot.parent.height);
			_pivot.name = "pivot";
		}
		return showPivot = v;
	}

	public function loadAtlas(Path:String)
	{
		if (!Assets.exists('$Path/Animation.json') && haxe.io.Path.extension(Path) != "zip")
		{
			FlxG.log.error('Animation file not found in specified path: "$Path", have you written the correct path?');
			return;
		}
		anim._loadAtlas(atlasSetting(Path));
		frames = FlxAnimateFrames.fromTextureAtlas(Path);
	}
	/**
	 * the function `draw()` renders the symbol that `anim` has currently plus a pivot that you can toggle on or off.
	 */
	public override function draw():Void
	{
		if(alpha <= 0) return;

		updateSkewMatrix();

		if(anim.curInstance != null)
			parseElement(anim.curInstance, anim.curFrame, _matrix, colorTransform, blend, true);
		if (showPivot)
			drawLimb(_pivot, new FlxMatrix(1,0,0,1, origin.x, origin.y));
	}
	/**
	 * This basically renders an element of any kind, both limbs and symbols.
	 * It should be considered as the main function that makes rendering a symbol possible.
	 */
	function parseElement(instance:FlxElement, curFrame:Int, m:FlxMatrix, colorFilter:ColorTransform, blendMode:BlendMode, mainSymbol:Bool = false)
	{
		if (instance == null)
			return;

		var colorEffect = colorTransformsPool.get();
		var matrix = matrixesPool.get();

		if (instance.symbol != null) colorEffect.concat(instance.symbol._colorEffect);
		if (instance.symbol != null && instance.symbol.blendMode != null) blendMode = instance.symbol.blendMode;
		matrix.concat(instance.matrix);

		colorEffect.concat(colorFilter);
		matrix.concat(m);


		if (instance.bitmap != null)
		{
			drawLimb(frames.getByName(instance.bitmap), matrix, colorEffect, blendMode);

			colorTransformsPool.put(colorEffect);
			matrixesPool.put(matrix);
			return;
		}

		var symbol = anim.symbolDictionary.get(instance.symbol.name);
		var firstFrame:Int = instance.symbol.firstFrame + curFrame;
		switch (instance.symbol.type)
		{
			case Button: firstFrame = setButtonFrames(firstFrame);
			default:
		}

		firstFrame = switch (instance.symbol.loop)
		{
			case Loop: firstFrame % symbol.length;
			case PlayOnce: cast FlxMath.bound(firstFrame, 0, symbol.length - 1);
			default: firstFrame;
		}

		var layers = symbol.timeline.getList();
		for (i in 0...layers.length)
		{
			var layer = layers[layers.length - 1 - i];

			if (!layer.visible && mainSymbol) continue;
			var frame = layer.get(firstFrame);

			if (frame == null) continue;

			if (frame.callbacks != null)
			{
				frame.fireCallbacks();
			}

			for (element in frame.getList())
			{
				var firstframe = 0;
				if (element.symbol != null && element.symbol.loop != SingleFrame)
				{
					firstframe = firstFrame - frame.index;
				}
				var coloreffect = colorTransformsPool.get();
				coloreffect.concat(frame._colorEffect);
				coloreffect.concat(colorEffect);
				parseElement(element, firstframe, matrix, coloreffect, blendMode);
				colorTransformsPool.put(coloreffect);
			}
		}

		colorTransformsPool.put(colorEffect);
		matrixesPool.put(matrix);
	}

	var pressed:Bool = false;
	function setButtonFrames(frame:Int)
	{
		var badPress:Bool = false;
		var goodPress:Bool = false;
		#if FLX_MOUSE
		var overlaps = FlxG.mouse.overlaps(this);
		if (FlxG.mouse.pressed && overlaps)
			goodPress = true;
		if (FlxG.mouse.pressed && !overlaps && !goodPress)
		{
			badPress = true;
		}
		if (!FlxG.mouse.pressed)
		{
			badPress = false;
			goodPress = false;
		}
		if (overlaps && !badPress)
		{
			@:privateAccess
			var event = anim.buttonMap.get(anim.curSymbol.name);
			if (FlxG.mouse.justPressed && !pressed)
			{
				if (event != null)
					new ButtonEvent((event.Callbacks != null) ? event.Callbacks.OnClick : null #if FLX_SOUND_SYSTEM, event.Sound #end).fire();
				pressed = true;
			}
			frame = (FlxG.mouse.pressed) ? 2 : 1;

			if (FlxG.mouse.justReleased && pressed)
			{
				if (event != null)
					new ButtonEvent((event.Callbacks != null) ? event.Callbacks.OnRelease : null #if FLX_SOUND_SYSTEM, event.Sound #end).fire();
				pressed = false;
			}
		}
		else
		{
			frame = 0;
		}
		#else
		FlxG.log.error("Button stuff isn't available for mobile!");
		#end
		return frame;
	}

	static var rMatrix = new FlxMatrix();

	function drawLimb(limb:FlxFrame, _matrix:FlxMatrix, ?colorTransform:ColorTransform, ?blendMode:BlendMode)
	{
		if (alpha == 0 || colorTransform != null && (colorTransform.alphaMultiplier == 0 || colorTransform.alphaOffset == -255) || limb == null || limb.type == EMPTY)
			return;

		if (blendMode == null)
			blendMode = BlendMode.NORMAL;

		for (camera in cameras)
		{
			rMatrix.identity();
			//rMatrix.translate(-limb.offset.x, -limb.offset.y);
			#if FLX_CNE_FORK
			limb.prepareMatrix(rMatrix, FlxFrameAngle.ANGLE_0, _checkFlipX() != camera.flipX, _checkFlipY() != camera.flipY);
			#else
			limb.prepareMatrix(rMatrix, FlxFrameAngle.ANGLE_0, _checkFlipX(), _checkFlipY());
			#end
			rMatrix.concat(_matrix);
			if (!camera.visible || !camera.exists || !limbOnScreen(limb, _matrix, camera))
				return;

			getScreenPosition(_point, camera).subtractPoint(offset);
			rMatrix.translate(-origin.x, -origin.y);
			if (limb != _pivot)
				rMatrix.scale(scale.x, scale.y);
			else
				rMatrix.a = rMatrix.d = 0.7 / camera.zoom;

			if (matrixExposed)
			{
				rMatrix.concat(transformMatrix);
			}
			else
			{
				rMatrix.concat(_skewMatrix);
			}

			_point.addPoint(origin);
			if (isPixelPerfectRender(camera))
			{
				_point.floor();
			}

			rMatrix.translate(_point.x, _point.y);
			camera.drawPixels(limb, null, rMatrix, colorTransform, blendMode, antialiasing, shaderEnabled ? shader : null);
			#if FLX_DEBUG
			FlxBasic.visibleCount++;
			#end
		}
		// doesnt work, needs to be remade
		//#if FLX_DEBUG
		//if (FlxG.debugger.drawDebug)
		//	drawDebug();
		//#end
	}

	@:noCompletion
	inline function _checkFlipX():Bool
	{
		//var doFlipX = (flipX != _frame.flipX);
		var doFlipX = (false != _frame.flipX);
		//if (animation.curAnim != null)
		//{
		//	return doFlipX != animation.curAnim.flipX;
		//}
		return doFlipX;
	}

	@:noCompletion
	inline function _checkFlipY():Bool
	{
		//var doFlipY = (flipY != _frame.flipY);
		var doFlipY = (false != _frame.flipY);
		//if (animation.curAnim != null)
		//{
		//	return doFlipY != animation.curAnim.flipY;
		//}
		return doFlipY;
	}

	public var skew(default, null):FlxPoint = FlxPoint.get();

	static var _skewMatrix:FlxMatrix = new FlxMatrix();

	/**
	 * Tranformation matrix for this sprite.
	 * Used only when matrixExposed is set to true
	 */
	public var transformMatrix(default, null):Matrix = new Matrix();

	/**
	 * Bool flag showing whether transformMatrix is used for rendering or not.
	 * False by default, which means that transformMatrix isn't used for rendering
	 */
	public var matrixExposed:Bool = false;

	function updateSkewMatrix():Void
	{
		_skewMatrix.identity();

		if (skew.x != 0 || skew.y != 0)
		{
			_skewMatrix.b = Math.tan(skew.y * FlxAngle.TO_RAD);
			_skewMatrix.c = Math.tan(skew.x * FlxAngle.TO_RAD);
		}
	}

	function limbOnScreen(limb:FlxFrame, m:FlxMatrix, ?Camera:FlxCamera)
	{
		if (Camera == null)
			Camera = FlxG.camera;

		var minX:Float = x + m.tx - offset.x - scrollFactor.x * Camera.scroll.x;
		var minY:Float = y + m.ty - offset.y - scrollFactor.y * Camera.scroll.y;

		var radiusX:Float = limb.frame.width * Math.max(1, m.a);
		var radiusY:Float = limb.frame.height * Math.max(1, m.d);
		var radius:Float = Math.max(radiusX, radiusY);
		radius *= FlxMath.SQUARE_ROOT_OF_TWO;
		minY -= radius;
		minX -= radius;
		radius *= 2;

		_point.set(minX, minY);

		return Camera.containsPoint(_point, radius, radius);
	}
	/*function limbOnScreen(limb:FlxFrame, m:FlxMatrix, ?Camera:FlxCamera = null)
	{
		if (Camera == null)
			Camera = FlxG.camera;

		limb.frame.copyToFlash(rect);

		rect.offset(-rect.x, -rect.y);

		rect.__transform(rect, m);

		_point.copyFromFlash(rect.topLeft);

		//if ([_indicator, _pivot].indexOf(limb) == -1)
		//if (_indicator != limb && _pivot != limb)
		if (_pivot != limb)
			_flashRect = _flashRect.union(rect);

		return Camera.containsPoint(_point, rect.width, rect.height);
	}*/

	// function checkSize(limb:FlxFrame, m:FlxMatrix)
	// {
	// 	// var rect = new Rectangle(x,y,limb.frame.width,limb.frame.height);
	// 	// @:privateAccess
	// 	// rect.__transform(rect, m);
	// 	return {width: rect.width, height: rect.height};
	// }
	var oldMatrix:FlxMatrix;
	override function set_flipX(Value:Bool)
	{
		if (oldMatrix == null)
		{
			oldMatrix = new FlxMatrix();
			oldMatrix.concat(_matrix);
		}
		if (Value)
		{
			_matrix.a = -oldMatrix.a;
			_matrix.c = -oldMatrix.c;
		}
		else
		{
			_matrix.a = oldMatrix.a;
			_matrix.c = oldMatrix.c;
		}
		return flipX = Value;
	}
	override function set_flipY(Value:Bool)
	{
		if (oldMatrix == null)
		{
			oldMatrix = new FlxMatrix();
			oldMatrix.concat(_matrix);
		}
		if (Value)
		{
			_matrix.b = -oldMatrix.b;
			_matrix.d = -oldMatrix.d;
		}
		else
		{
			_matrix.b = oldMatrix.b;
			_matrix.d = oldMatrix.d;
		}
		return flipY = Value;
	}

	override function destroy()
	{
		/*#if FLX_SOUND_SYSTEM
		audio = FlxDestroyUtil.destroy(audio);
		#end*/
		anim = FlxDestroyUtil.destroy(anim);
		skew = FlxDestroyUtil.put(skew);
		super.destroy();
	}

	public override function updateAnimation(elapsed:Float)
	{
		anim.update(elapsed);
	}

	public function setButtonPack(button:String, callbacks:ClickStuff #if FLX_SOUND_SYSTEM , sound:FlxSound #end):Void
	{
		@:privateAccess
		anim.buttonMap.set(button, {Callbacks: callbacks, #if FLX_SOUND_SYSTEM Sound:  sound #end});
	}

	function setTheSettings(?Settings:Settings):Void
	{
		@:privateAccess
		if (true)
		{
			antialiasing = Settings.Antialiasing;
			if (Settings.ButtonSettings != null)
			{
				anim.buttonMap = Settings.ButtonSettings;
				if (anim.symbolType != Button)
					anim.symbolType = Button;
			}
			if (Settings.Reversed != null)
				anim.reversed = Settings.Reversed;
			if (Settings.FrameRate != null)
				anim.framerate = (Settings.FrameRate > 0) ? anim.metadata.frameRate : Settings.FrameRate;
			if (Settings.OnComplete != null)
				anim.onComplete = Settings.OnComplete;
			if (Settings.ShowPivot != null)
				showPivot = Settings.ShowPivot;
			if (Settings.Antialiasing != null)
				antialiasing = Settings.Antialiasing;
			if (Settings.ScrollFactor != null)
				scrollFactor = Settings.ScrollFactor;
			if (Settings.Offset != null)
				offset = Settings.Offset;
		}
	}

	function atlasSetting(Path:String):AnimAtlas
	{
		var jsontxt:AnimAtlas = null;
		if (haxe.io.Path.extension(Path) == "zip")
		{
			var thing = Zip.readZip(Assets.getBytes(Path));

			for (list in Zip.unzip(thing))
			{
				if (list.fileName.indexOf("Animation.json") != -1)
				{
					jsontxt = haxe.Json.parse(list.data.toString());
					thing.remove(list);
					continue;
				}
			}
			@:privateAccess
			FlxAnimateFrames.zip = thing;
		}
		else
		{
			jsontxt = haxe.Json.parse(openfl.Assets.getText('$Path/Animation.json'));
		}

		return jsontxt;
	}
}
