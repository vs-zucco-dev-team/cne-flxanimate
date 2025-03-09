package flxanimate.animate;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.util.FlxStringUtil;
import flxanimate.animate.SymbolParameters;
import flxanimate.data.AnimationData;
import haxe.extern.EitherType;
import openfl.geom.ColorTransform;
#if FLX_SOUND_SYSTEM
import flixel.system.FlxSound;
#end

class FlxSymbolAnimation {
	public var instance:FlxElement;
	public var frameRate:Float;

	public var onFinish:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var onFinishEnd:FlxTypedSignal<Void->Void> = new FlxTypedSignal();

	public function new(instance:FlxElement, frameRate:Float) {
		this.instance = instance;
		this.frameRate = frameRate;
	}
}


typedef ClickStuff = {
	?OnClick:Void->Void,
	?OnRelease:Void->Void
}
typedef ButtonSettings = {
	?Callbacks:ClickStuff,
	#if FLX_SOUND_SYSTEM
	?Sound:FlxSound
	#end
}
class FlxAnim implements IFlxDestroyable
{
	public var length(get, never):Int;

	public var stageInstance:FlxElement;

	public var curInstance:FlxElement;
	public var curAnimation:FlxSymbolAnimation;

	public var metadata:FlxMetaData;

	public var curSymbol(get, never):FlxSymbol;
	public var finished(get, never):Bool;
	public var isAtEnd(get, never):Bool;
	public var reversed(get, set):Bool;
	/**
		Checks if the MovieClip should move or not. for having a similar experience to SWFs
	**/
	public var swfRender:Bool = false;

	var buttonMap:Map<String, ButtonSettings> = new Map();
	/**
	 * When ever the animation is playing.
	 */
	public var isPlaying(default, null):Bool = false;
	public var onComplete:()->Void;

	public var onFinishEnd:FlxTypedSignal<String->Void> = new FlxTypedSignal();

	public var framerate(default, set):Float;

	/**
	 * Internal, used for each skip between frames.
	 */
	var frameDelay:Float;

	public var curFrame(get, set):Int;

	var animsMap:Map<String, FlxSymbolAnimation> = new Map();

	/**
	 * Internal, the parsed loop type
	 */
	var loopType(get, never):Loop;

	public var symbolType(get, set):SymbolT;

	var _parent:FlxAnimate;

	var _tick:Float = 0;

	/**
	 * How fast or slow time should pass for this animation controller
	 */
	public var timeScale:Float = 1.0;

	public function new(parent:FlxAnimate, ?coolParsed:AnimAtlas)
	{
		_parent = parent;
		if (coolParsed != null) _loadAtlas(coolParsed);
	}
	@:allow(flxanimate.FlxAnimate)
	function _loadAtlas(animationFile:AnimAtlas)
	{
		symbolDictionary = [];
		stageInstance = null;

		setSymbols(animationFile);

		stageInstance = (animationFile.AN.STI != null) ? FlxElement.fromJSON(cast animationFile.AN.STI) : new FlxElement(new SymbolParameters(animationFile.AN.SN));

		curInstance = stageInstance;

		curFrame = stageInstance.symbol.firstFrame;

		_parent.origin.copyFrom(stageInstance.symbol.transformationPoint);
		metadata = new FlxMetaData(animationFile.AN.N, animationFile.MD.FRT);
		framerate = metadata.frameRate;
	}
	public var symbolDictionary:Map<String, FlxSymbol> = [];

	public function play(?Name:String = "", ?Force:Bool = false, ?Reverse:Bool = false, ?Frame:Int = 0)
	{
		pause();
		var isNewAnim = false;
		@:privateAccess
		if(Name != null && Name != "")
		{
			var curThing = animsMap.get(Name);
			if (curThing == null)
			{
				var symbol = symbolDictionary.get(Name);
				if (symbol != null)
					curThing = new FlxSymbolAnimation(
						(symbol.name == curSymbol.name) ? curInstance : new FlxElement(new SymbolParameters(Name)),
						metadata.frameRate
					);


				if (curThing == null)
				{
					FlxG.log.error('there\'s no animation called "$Name"!');
					isPlaying = true;
					return;
				}
			}

			framerate = (curThing.frameRate == 0) ? metadata.frameRate : curThing.frameRate;

			if (curInstance != curThing.instance)
				isNewAnim = true;

			curInstance = curThing.instance;
			curAnimation = curThing;
		}
		if (Force || finished || isNewAnim) {
			curFrame = (Reverse) ? Frame - length : Frame;
			_tick = 0;
		}
		reversed = Reverse;
		isPlaying = true;
	}

	public function pause()
	{
		isPlaying = false;
	}
	public function stop()
	{
		pause();
		curFrame = 0;
	}

	function setSymbols(Anim:AnimAtlas)
	{
		symbolDictionary.set(Anim.AN.SN, new FlxSymbol(Anim.AN.SN, FlxTimeline.fromJSON(Anim.AN.TL)));
		if (Anim.SD != null)
		{
			for (symbol in Anim.SD.S)
			{
				symbolDictionary.set(symbol.SN, new FlxSymbol(symbol.SN, FlxTimeline.fromJSON(symbol.TL)));
			}
		}
	}

	inline function _doFinishedEndCallback():Void
	{
		if (curAnimation != null)
			curAnimation.onFinishEnd.dispatch();
		onFinishEnd.dispatch(_frameFinishedName);
	}

	/**
	 * Internal, used to wait the frameDuration at the end of the animation.
	 */
	var _frameFinishedEndTimer:Float = 0;

	var _frameFinishedName:String = null;

	public function update(elapsed:Float)
	{
		if (!isPlaying)
			return;
		if (_frameFinishedEndTimer > 0)
		{
			_frameFinishedEndTimer -= elapsed * timeScale;
			if (_frameFinishedEndTimer <= 0)
			{
				if (curInstance != null && curInstance.symbol != null && curInstance.symbol.name != _frameFinishedName)
				{
					_frameFinishedEndTimer = 0;
					_doFinishedEndCallback();
				}
			}
		}
		if (finished)
			return;
		if (frameDelay == 0)
			return;

		_tick += elapsed * timeScale;

		while (_tick > frameDelay)
		{
			(reversed) ? curFrame-- : curFrame++;
			_tick -= frameDelay;

			//@:privateAccess
			//curSymbol._shootCallback = true;
		}

		if (finished)
		{
			if(curAnimation != null)
				curAnimation.onFinish.dispatch();
			if (onComplete != null)
				onComplete();
			_frameFinishedEndTimer = frameDelay;
			if (curInstance != null && curInstance.symbol != null)
				_frameFinishedName = curInstance.symbol.name;
			pause();
		}
	}
	function get_finished() {
		return (loopType == PlayOnce) && isAtEnd;
	}
	inline function get_isAtEnd() {
		return (reversed && curFrame == 0 || !reversed && curFrame >= length - 1);
	}
	function get_curFrame()
	{
		return curSymbol.curFrame;
	}
	function set_curFrame(Value:Int)
	{
		curSymbol.curFrame = switch (loopType)
		{
			case Loop: Value % curSymbol.length;
			case PlayOnce: cast FlxMath.bound(Value, 0, curSymbol.length - 1);
			case _: Value;
		}

		return curSymbol.curFrame;
	}

	public function existsSymbol(SymbolName:String):String {
		for (name in symbolDictionary.keys())
		{
			if (startsWith(name, SymbolName))
			{
				return name;
			}
		}
		return null;
	}

	/**
	 * Creates an animation using an already made symbol from a texture atlas
	 * @param Name The name of the animation
	 * @param SymbolName the name of the symbol you're looking. if you have two symbols beginning by the same name, use `\` at the end to differ one symbol from another
	 * @param X the *x* axis of the animation.
	 * @param Y  the *y* axis of the animation.
	 * @param FrameRate the framerate of the animation.
	 */
	public function addBySymbol(Name:String, SymbolName:String, FrameRate:Float = 0, Looped:Bool = true, X:Float = 0, Y:Float = 0)
	{
		var params = new FlxElement(new SymbolParameters((Looped) ? Loop : PlayOnce), new FlxMatrix(1,0,0,1,X,Y));
		params.symbol.name = existsSymbol(SymbolName);

		if (params.symbol.name != null)
			animsMap.set(Name, new FlxSymbolAnimation(params, FrameRate));
		else
			FlxG.log.error('No symbol was found with the name $SymbolName!');
	}
	function startsWith(reference:String, string:String):Bool
	{
		if (StringTools.endsWith(string, "\\"))
			return reference == string.substring(0, string.length - 1)
		else
			return StringTools.startsWith(reference, string);
	}
	/**
	 * Creates an animation using the indices, looking as a reference the main animation of the texture atlas.
	 * @param Name The name of the animation you're creating
	 * @param Indices The indices you're gonna be using for the animation, like `[0,1,2]`.
	 * @param FrameRate the framerate of the animation.
	 */
	public function addByAnimIndices(Name:String, Indices:Array<Int>, FrameRate:Float = 0)
	{
		addBySymbolIndices(Name, stageInstance.symbol.name, Indices, FrameRate, stageInstance.symbol.loop == Loop, 0,0);
	}
	public function addBySymbolIndices(Name:String, SymbolName:String, Indices:Array<Int>, FrameRate:Float = 0, Looped:Bool = true, X:Float = 0, Y:Float = 0)
	{
		var detectedName:String = existsSymbol(SymbolName);
		if (detectedName == null)
		{
			FlxG.log.error('$SymbolName does not exist as a symbol! maybe you misspelled it?');
			return;
		}
		var params = new FlxElement(new SymbolParameters((Looped) ? Loop : PlayOnce), new FlxMatrix(1,0,0,1,X,Y));
		var timeline = new FlxTimeline();
		timeline.add("Layer 1");

		for (index in 0...Indices.length)
		{
			var i = Indices[index];
			var keyframe = new FlxKeyFrame(index);

			var params = new SymbolParameters(detectedName, params.symbol.loop);
			params.firstFrame = i;
			keyframe.add(new FlxElement(params));
			timeline.get(0).add(keyframe);
		}
		var symbol = new FlxSymbol(Name, timeline);
		params.symbol.name = symbol.name;

		symbolDictionary.set(Name, symbol);

		animsMap.set(Name, new FlxSymbolAnimation(params, FrameRate));
	}


	function set_framerate(value:Float):Float
	{
		frameDelay = 1 / value;
		return framerate = value;
	}
	/**
	 * This adds a new animation by adding a custom timeline, obviously taking as a reference the timeline syntax!
	 * **WARNING**: I, *CheemsAndFriends*, do **NOT** recommend this unless you're using an extern json file to do this!
	 * if you wanna make a custom symbol to play around and is separated from the texture atlas, go ahead! but if you wanna just make a new symbol,
	 * just do it in Flash directly
	 * @param Name The name of the new Symbol.
	 * @param Timeline The timeline which will have the symbol.
	 * @param FrameRate The framerate it'll go, by default is 30.
	 */
	public function addByCustomTimeline(Name:String, Timeline:FlxTimeline, FrameRate:Float = 0, Looped:Bool = true)
	{
		symbolDictionary.set(Name, new FlxSymbol(Name, Timeline));
		var params = new FlxElement(new SymbolParameters((Looped) ? Loop : PlayOnce));
		animsMap.set(Name, new FlxSymbolAnimation(params, FrameRate));
	}

	public inline function get_length()
	{
		return curSymbol.length;
	}

	public function getFrameLabel(name:String, ?layer:EitherType<Int, String>)
	{
		return curSymbol.getFrameLabel(name, layer);
	}
	public function toString()
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("symbolDictionary", symbolDictionary),
			LabelValuePair.weak("framerate", framerate)
		]);
	}
	/**
	 * Redirects the frame into a frame with a frame label of that type.
	 * @param name the name of the label.
	 */
	public function goToFrameLabel(name:String)
	{
		pause();

		var label = getFrameLabel(name);

		if (label != null)
			curFrame = label.index;

		play();
	}
	/**
	 * Checks the next frame label name you're looking for.
	 * **WARNING: DO NOT** confuse with `anim.curSymbol.getNextToFrameLabel`!!
	 * @param name the name of the frame label.
	 * @return A `String`. WARNING: it can be `null`
	 */
	public function getNextToFrameLabel(name:String):Null<String>
	{
		return curSymbol.getNextToFrameLabel(name).name;
	}
	/**
	 * Links a callback into a label.
	 * @param label the name of the label.
	 * @param callback the callback you're going to add
	 */
	public function addCallbackTo(label:String, callback:()->Void)
	{
		return curSymbol.addCallbackTo(label, callback);
	}


	public function removeCallbackFrom(label:String, callback:()->Void)
	{
		return curSymbol.removeCallbackFrom(label, callback);
	}


	public function removeAllCallbacksFrom(label:String)
	{
		return curSymbol.removeAllCallbacksFrom(label);
	}


	public function getFrameLabels(?layer:EitherType<Int, String>)
	{
		return curSymbol.getFrameLabels(layer);
	}

	inline function get_loopType()
	{
		return curInstance.symbol.loop;
	}
	inline function get_symbolType()
	{
		return curInstance.symbol.type;
	}
	inline function set_symbolType(type:SymbolT)
	{
		return curInstance.symbol.type = type;
	}
	inline function get_reversed()
	{
		return curInstance.symbol.reverse;
	}
	inline function set_reversed(value:Bool)
	{
		return curInstance.symbol.reverse = value;
	}
	inline public function getByName(name:String)
	{
		return animsMap.get(name);
	}
	inline public function existsByName(name:String)
	{
		return animsMap.exists(name);
	}

	public function getByInstance(instance:String, ?frame:Int = null, ?layer:EitherType<String, Int>)
	{
		if (frame == null) frame = curFrame;

		var symbol:FlxSymbol = null;

		var layers = (layer == null) ? curSymbol.timeline.getList() : [curSymbol.timeline.get(layer)];

		for (layer in layers)
		{
			if (layer == null) continue;

			for (element in layer.get(frame).getList())
			{
				if (element.symbol == null) continue;
				if (element.symbol.instance != "" && element.symbol.instance == instance)
				{
					symbol = symbolDictionary.get(element.symbol.name);
					break;
				}
			}
		}
		if (symbol == null)
			FlxG.log.error("This instance doesn't exist! Have you checked if the layer exists or the instance isn't misspelled?");
		return symbol;
	}

	function get_curSymbol()
	{
		if(curInstance == null) return null;
		if(curInstance.symbol == null) return null;
		return symbolDictionary.get(curInstance.symbol.name);
	}

	public function destroy()
	{
		isPlaying = false;
		curFrame = 0;
		framerate = 0;
		_tick = 0;
		buttonMap = null;
		animsMap = null;
		curInstance = FlxDestroyUtil.destroy(curInstance);
		stageInstance = FlxDestroyUtil.destroy(stageInstance);
		metadata = FlxDestroyUtil.destroy(metadata);
		swfRender = false;
		_parent = null;
		symbolDictionary = null;
	}
}
/**
 * This class shows what framerate the animation was initially set.
 */
class FlxMetaData implements IFlxDestroyable
{
	public var name:String;
	/**
	 * The frame rate the animation was exported in the texture atlas in the beginning.
	 */
	public var frameRate:Float;

	public function new(name:String, frameRate:Float)
	{
		this.name = name;
		this.frameRate = frameRate;
	}
	public function destroy()
	{
		name = null;
		frameRate = 0;
	}
}