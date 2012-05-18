package com.flamesproductions.audio
{
	import flash.events.Event;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.media.SoundTransform;
	
	import org.osflash.signals.Signal;

	public class Record
	{
		public var done:Signal;
		private var _id:String;
		
		public function Record(s:Sound, id:String)
		{
			_id = id;
			done = new Signal(String);
			this._song = s;
			_transform = new SoundTransform();
		}
		
		private var _channel:SoundChannel;
		private var _song:Sound;
		public var isPlaying:Boolean;
		private var _loops:int;
		private var _currentTime:int;
		private var _startTime:int;
		private var _transform:SoundTransform;
		
		public function play(time:int = 0, loops:int=0, volume:Number=1, pan:Number=0):SoundChannel
		{
			this._loops = loops;
			
			_transform.volume = volume;
			_transform.pan = pan;
			
			if (_song!=null)
			{
				_startTime = time;
				_currentTime = time;
				
				createChannel(time);
			}
			
			return _channel;
		}
		
		protected function onSoundComplete(event:Event):void
		{
			//trace("sound complete");
			if (_loops == 0)
			{
				cleanupChannel();
				done.dispatch(_id);
				return;
			}
			else if (_loops > 0)
			{
				_loops--;
			}
			
				cleanupChannel();
				createChannel(_startTime);
			
		}
		public function stop():void
		{
			if (isPlaying)
			{
				cleanupChannel();
				_song = null;
			}
		}
		
		public function toggle():void
		{
			if (isPlaying)
				pause();
			else
				resume();
		}
		
		public function pause():void
		{
			_currentTime = _channel.position;
			cleanupChannel();
		}
		
		public function resume():void
		{
			createChannel(_currentTime);
		}
		private function cleanupChannel():void
		{
			_channel.stop();
			
			
			if (_loops>0)
			_channel.removeEventListener(Event.SOUND_COMPLETE, onSoundComplete);
			_channel = null;
			
			isPlaying = false;
		}
		private function createChannel(time:int):void
		{
			_channel = _song.play(time, 1, _transform);
			if (_loops>0)
			_channel.addEventListener(Event.SOUND_COMPLETE, onSoundComplete);
			
			isPlaying = true;
		}
		
		public function seek(time:int):void
		{
			cleanupChannel();
			createChannel(time);
		}
		
		public function seekPrecent(percent:Number):void
		{
			cleanupChannel();
			createChannel(percent * _song.length);
		}
		public function equalize(volume:Number=0, pan:Number=0):void
		{
			_transform.volume = volume;
			_transform.pan = pan;
		}
		public function getProgress():Number
		{
			return _channel.position/_song.length;
		}

		public function get id():String
		{
			return _id;
		}

		public function set id(value:String):void
		{
			_id = value;
		}

		public function get song():Sound
		{
			return _song;
		}

		public function set song(value:Sound):void
		{
			_song = value;
		}


	}
}