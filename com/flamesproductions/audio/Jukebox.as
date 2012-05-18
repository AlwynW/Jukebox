package com.flamesproductions.audio
{
	import flash.events.Event;
	import flash.media.Sound;
	import flash.media.SoundMixer;
	import flash.media.SoundTransform;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.getDefinitionByName;
	import flash.utils.getTimer;
	
	import org.osflash.signals.Signal;

	/**
	 * Author: Alwyn Wymeersch
	 * www.flamesproductions.com
	 */
	public class Jukebox
	{
		public var ready:Signal;
		public var done:Signal;
		
		private var _recordsPlaying:Object;
		private var _records:Object;
		
		private var _selectedRecord:Record;
		
		private static var _instance:Jukebox;
		
		public static var MAX_CHANNELS:int = 256;
		
		private var _soundsLoading:Array;
		
		public function Jukebox()
		{
			init();
		}
		
		public static function getInstance():Jukebox
		{
			if (_instance == null)
				_instance = new Jukebox();
			
			return _instance;
		}
		
		private function init():void
		{
			_recordsPlaying = new Object();
			_records = new Object();
			_bytes = new ByteArray;
			
			done = new Signal();
			ready = new Signal();
		}
		
		/**
		 * Function to download record from server (or local file when running in AIR)
		 * @url				pass in url to file
		 * @id				id for later use
		 * @selectRecord	if the record should be set as the default song
		 * @autoplay		autostart file after loading?
		 */
		public function getRecord(url:String, id:String, selectRecord:Boolean = false, autoplay:Boolean = false):void
		{
			if (_soundsLoading == null)
				_soundsLoading = new Array();
			
			var delayedSound:Sound = new Sound();
			delayedSound.addEventListener(Event.COMPLETE, getRecordComplete);
			var delayedLoader:Object = {sound: delayedSound, id:id, selectRecord:selectRecord, autoplay:autoplay};
			delayedSound.load(new URLRequest(url));
			
			_soundsLoading.push(delayedLoader);
		}
		private function getRecordComplete(e:Event):void
		{
			// look up sound
			for each(var delayedSound:Object in _soundsLoading)
			{
				if (delayedSound.sound == e.target)
				{
					var newRecord:Record = new Record(delayedSound.sound, delayedSound.id);
					newRecord.done.add(recordDoneHandler);
					addRecord(newRecord, delayedSound.id);
					if (delayedSound.selectRecord)
					{
						chooseRecord(delayedSound.id);
					}
					if (delayedSound.autoplay)
					{
						playRecord(delayedSound.id);
					}
			
					ready.dispatch(delayedSound.id);
					
					_soundsLoading.splice(_soundsLoading.indexOf(delayedSound), 1);
				}
			}
		}
		
		/**
		 * Function to instantiate a sound from swf library asset or swc class
		 * 
		 * @classid			name of the class
		 * @id				id for later use
		 * @selectRecord	if the record should be set as the default song
		 * @autoplay		autostart file after loading?
		 */
		public function createRecord(classid:String, id:String, selectRecord:Boolean = false, autoPlay:Boolean= true):void
		{
			var Cname:Class = getDefinitionByName(classid) as Class;
			var snd:Sound = new Cname();
			
			var newRecord:Record = new Record(snd, id);
			newRecord.done.add(recordDoneHandler);
			addRecord(newRecord, id);
			if (selectRecord)
			{
				chooseRecord(id);
			}
			if (autoPlay)
			{
				playRecord('id');
			}
			ready.dispatch(id);
		}
		/**
		 * Function to instantiate a sound from swf library asset or swc class
		 * 
		 * @snd			sound object
		 * @id				id for later use
		 * @selectRecord	if the record should be set as the default song
		 * @autoplay		autostart file after loading?
		 */
		public function useRecord(snd:Sound, id:String, selectRecord:Boolean = false, autoPlay:Boolean = false):void
		{
			var newRecord:Record = new Record(snd, id);
			newRecord.done.add(recordDoneHandler);
			addRecord(newRecord, id);
			if (selectRecord)
			{
				chooseRecord(id);
			}
			if (autoPlay)
			{
				playRecord(id);
			}
			ready.dispatch(id);
		}
		/**
		 * Show browser for file dialog and parse song
		 *
		 * @id	id for later use
		 */
		public function insertDisc(id:String):void
		{
			FileBrowser.getInstance().selected.addOnce(discInserted);
			FileBrowser.getInstance().browseForFile(id, FileTypes.MP3FILES);
		}
		private function discInserted(data:ByteArray, id:String):void
		{
			var sound:Sound = new Sound();
			sound.loadCompressedDataFromByteArray(data, data.length);
			var newRecord:Record = new Record(sound, id);
			newRecord.done.add(recordDoneHandler);
			addRecord(newRecord, id);
			
			ready.dispatch(id);
		}
		private function recordDoneHandler(id:String):void
		{
			_records[id] = null;
			delete _records[id];
			done.dispatch(id);
		}
		
		private function addRecord(record:Record, id:String):void
		{
			_records[id] = record;
		}
		
		/**
		 * Select default record
		 *
		 * @id	song id
		 */
		public function chooseRecord(id:String):Boolean
		{		
			var lookup:Record = lookupSong(id);
			
			if (lookup!=null)
				_selectedRecord = lookup;
			
			return lookup != null;
		}
		/**
		 * Start playing a song
		 *
		 * @id				song id
		 * @silenceOthers	stops all other (playing) sounds
		 * @time			start time in song
		 * @loops			number of loops
		 */
		public function playRecord(id:String="", silenceOthers:Boolean=false, time:int = 0, loops:int=0, volume:Number = 1, pan:Number=0):Boolean
		{
			if (silenceOthers)
				stopAll();
			
			var lookup:Record = lookupSong(id);
			
			if (lookup!=null && !lookup.isPlaying)
			{
				lookup.play(time, loops, volume, pan);
				_recordsPlaying[lookup.id] = lookup;
			}
			
			return lookup != null;
		}
		/**
		 * Function to play or pause a song
		 * 
		 * @id	song id
		 **/
		public function togglePause(id:String=""):Boolean
		{
			var lookup:Record = lookupSong(id);
			
			if (lookup!=null)
				lookup.toggle();
			
			return lookup != null;
		}
		/**
		 * Function to stop a playing sound
		 * 
		 * @id	song id
		 **/
		public function stopRecord(id:String=""):Boolean
		{
			var record:Record = _recordsPlaying[id] as Record;
			
			if (id=="")
				record = _selectedRecord;
			
			if (record!=null)
			{
				record.stop();
				_recordsPlaying[record.id] = null;
				delete _recordsPlaying[record.id];
			}
			return record!=null;
		}
		/**
		 * Function to stop all playing sounds
		 * 
		 **/
		public function stopAll():void
		{
			for (var key:String in _recordsPlaying)
			{
				var record:Record = _recordsPlaying[key] as Record;
				
				if (record!=null)
				{
					record.stop();
					_recordsPlaying[key] = null;
					delete _recordsPlaying[key];
					// _recordsPlaying[key] = null;
				}
			}
			if (_selectedRecord!=null)
			{
				_selectedRecord.stop();
				_selectedRecord = null;
			}
		}
		
		private var _bytes:ByteArray;
		private var _spectrum:Vector.<Number>;
			
		/**
		 * Function to analyze all playing sounds
		 * 
		 * @channels	the number of channels you want to receive (1-255)
		 * @average		average channel samples or peaks
		 * @fft			use fft or not
		 **/
		public function getSpectrum(channels:int, average:Boolean=false, fft:Boolean=true):Vector.<Number>
		{
			// var start:int = getTimer();
			
			SoundMixer.computeSpectrum(_bytes, fft);
			
			if (_spectrum == null)
				_spectrum = new Vector.<Number>();
			
			_spectrum.length = 0;
			
			var l:int = _bytes.length;
			
			var ccount:int = 0;
			var csub:Number = 0;
			var cmax:int = Math.floor(255/channels);
			
			if (average)
			{
				var left:Number;
				
				for (var i:int = 0; i < 256; i++)
				{
					ccount ++;
					
					left = _bytes.readFloat();
								
					csub+=left;
					
					if (ccount == cmax)
					{
						_spectrum.push(csub/cmax);
						ccount = 0;
						csub = 0;
					}
				}
			}
			else
			{
				var value:Number;
				var c:int=0;
				for (var j:int = 0; j < 256; j++)
				{
					value = _bytes.readFloat();
					
					if (c == cmax)
					{
						c=0;
						_spectrum.push(value);
					}
					c++;
				}
			}
			//trace(getTimer()-start);
			return _spectrum;
		}
		
		/**
		 * Function to seek base on number of milliseconds
		 * 
		 * @id		song id
		 * @time	time in milliseconds
		 */
		public function seek(id:String = "", time:int = 0):void
		{
			var lookup:Record = lookupSong(id);
			
			if (lookup!=null)
				lookup.seek(time);
			
		}
		/**
		 * Function to seek base on percentage
		 * 
		 * @id		song id
		 * @time	time in milliseconds 0-1
		 */
		public function seekPercent(id:String = "", time:Number = 0):void
		{
			var lookup:Record = lookupSong(id);
			
			if (lookup!=null)
				lookup.seekPrecent(time);
			
		}
		/**
		 * Function to change volume or pan of one or more songs
		 * 
		 * @id			song id
		 * @volume		new volume value 0-1
		 * @pan			pan value -1 - 1
		 */
		public function equalize(id:String = "", volume:Number=0, pan:Number=0):void
		{
			
				var lookup:Record = lookupSong(id);
				
				if (lookup!=null)
					lookup.equalize(volume, pan)
			
			
		}
		/**
		 * Function to lookup the played back time in percentage
		 * 
		 * @id	song id
		 */
		public function getProgress(id:String=""):Number
		{
			var progress:Number = 0;
			
			var lookup:Record = lookupSong(id);
			
			if (lookup!=null)
				progress = lookup.getProgress();
			
			return progress;
		}
		/**
		 * Function to get immediate access to a Record
		 * 
		 * @id	song id
		 */
		public function lookupSong(id:String=""):Record
		{
			var selectedRecord:Record;
			if (id == "" && _selectedRecord!=null)
			{
				selectedRecord = _selectedRecord;
			}
			else
			{
				var record:Record = _records[id] as Record;
				
				if (record!=null)
				{
					selectedRecord = record;
				}
			}
			
			return selectedRecord;
		}
		private var _globalSoundTransform:SoundTransform;
		
		/**
		 * Function to set volume and pan of global SoundMixer
		 * 
		 * @volume		new volume value 0-1
		 * @pan			pan value -1 - 1
		 */
		public function equalizeGlobal(volume:Number=0, pan:Number=0):void
		{
			if (_globalSoundTransform == null)
				_globalSoundTransform = new SoundTransform();
			
			_globalSoundTransform.volume = volume;
			_globalSoundTransform.pan = pan;
			SoundMixer.soundTransform = _globalSoundTransform;
		}
		
	}
}
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.net.FileReference;
	import flash.utils.ByteArray;
	
	import org.osflash.signals.Signal;
	import flash.net.FileFilter;
	
	internal class FileBrowser
	{
		public static var BYTES_MODE:String = "bytes";
		public static var OBJECT_MODE:String = "object";
		
		
		public var selected:Signal;
		
		private static var _instance:FileBrowser;
		
		private var _id:String;
		
		public function FileBrowser()
		{
			init();
		}
		public static function getInstance():FileBrowser
		{
			if (_instance==null)
				_instance = new FileBrowser();
			
			return _instance;
		}
		
		/////////// local file implementation		
		private var fileReference:FileReference;
		
		private function init():void
		{
			selected = new Signal(ByteArray, String);
			fileReference=new FileReference();
			fileReference.addEventListener(Event.SELECT, onFileSelected);
		}
		
		public function browseForFile(id:String, ... filetypes):void
		{
			
			_id = id;
			fileReference.browse(filetypes);
		}
		
		public function onFileSelected(event:Event):void
		{
			
			fileReference.addEventListener(Event.COMPLETE, onFileLoaded);
			// fileReference.addEventListener(IOErrorEvent.IO_ERROR, onFileLoadError);
			fileReference.addEventListener(ProgressEvent.PROGRESS, progressHandler);
			fileReference.load();
		}
		
		private function progressHandler(event:ProgressEvent):void
		{
			var file:FileReference = FileReference(event.target);
			var percentLoaded:Number=event.bytesLoaded/event.bytesTotal*100;
			
		}
		
		public function onFileLoaded(event:Event):void
		{
			var fileReference:FileReference=event.target as FileReference;
			var data:ByteArray=fileReference["data"];
			
			selected.dispatch(data, _id);
		}
	}
	internal class FileTypes
	{
		public static var MP3FILES:FileFilter = new FileFilter("MP3 Files (*.mp3)","*.mp3");;
		
	}
