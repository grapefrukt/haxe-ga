package googleAnalytics;

#if (flash || openfl)
import extension.locale.Locale;
import flash.net.SharedObject;
import flash.system.Capabilities;
import flash.Lib;
import haxe.Unserializer;
import haxe.Serializer;
#end

class Stats {

	private static var accountId:String=null;
	private static var cache:Map<String,GATrackObject>=null;
	private static var domainName:String=null;
	private static var paused:Bool=false;
	private static var session:Session=null;
	private static var tracker:Tracker=null;
	private static var visitor:Visitor=null;
	
	public static function init(accountId:String,domainName:String,useSSL:Bool=false){
		if(Stats.accountId!=null) return;
		Stats.accountId=accountId;
		Stats.domainName=domainName;
		tracker = new Tracker(accountId,domainName,new Config(useSSL));
		cache = new Map<String,GATrackObject>();
		session = new Session();
		loadVisitor();
	}
	
	public static function trackPageview(path:String,title:String=null){
		var hash='page:'+path;
		if(!cache.exists(hash)){
			var p=new Page(path);
			if(title!=null) p.setTitle(title);
			cache.set(hash,new GATrackObject(p,null));
		}
		Stats.track(hash);
	}

	public static function trackEvent(category:String,event:String,label:String,value:Int=0){
		var hash='event:'+category+'/'+event+'/'+label+':'+value;
		if(!cache.exists(hash)){
			cache.set(hash,new GATrackObject(null,new Event(category,event,label,value)));
		}
		Stats.track(hash);
	}

	private static function track(hash:String){
		if(paused) return;
		cache.get(hash).track(tracker,visitor,session);
		Stats.persistVisitor();
	}

	public static function pause() {
		paused = true;
	}

	public static function resume() {
		paused = false;
	}

	private static function loadVisitor(){
		var version:String=" [haxe]";
		visitor = new Visitor();
		#if (flash || openfl)
		var ld:SharedObject=SharedObject.getLocal('ga-visitor');
		if(ld.data!=null && ld.data.gaVisitor!=null){
			try{
				visitor=Unserializer.run(ld.data.gaVisitor);
			}catch(e:Dynamic){
				visitor = new Visitor();
			}
		}
		#end
		
		#if (openfl && !flash && !html5)
			#if openfl_next
			version+="/" + Lib.application.config.packageName + "." + Lib.application.config.version;
			#else
			version+="/" + Lib.packageName + "." + Lib.version;
			#end
		#end

		#if ios
		visitor.setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 5_0 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A334 Safari/7534.48.3');
		#elseif android
		visitor.setUserAgent('Mozilla/5.0 (Linux; Android 4.1.1; Nexus 7 Build/JRO03D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166  Safari/535.19');
		#elseif mac
		visitor.setUserAgent('Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_6; en-US) AppleWebKit/533.20.25 (KHTML, like Gecko) Version/5.0.4 Safari/533.20.27');
		#elseif tizen
		visitor.setUserAgent("Tizen"+version);
		#elseif blackberry
		visitor.setUserAgent("BlackBerry"+version);
		#elseif windows
		visitor.setUserAgent('Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.94 Safari/537.36');
		#elseif linux
		visitor.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Ubuntu/11.10 Chromium/27.0.1453.93 Chrome/27.0.1453.93 Safari/537.36');
		#else
		visitor.setUserAgent('-not-set-'+version);
		#end

		#if (flash || openfl)
		visitor.setScreenResolution(''+Capabilities.screenResolutionX+'x'+Capabilities.screenResolutionY);
		visitor.setLocale(Locale.getLangCode());
		#else
		visitor.setScreenResolution('1024x768');
		visitor.setLocale('en_US');
		#end

		visitor.getUniqueId();
		visitor.addSession(session);
		Stats.persistVisitor();
	}

	private static function persistVisitor(){
		#if (flash || openfl)
		var ld=SharedObject.getLocal('ga-visitor');
		var oldSerializerValue = Serializer.USE_CACHE;
		Serializer.USE_CACHE = true;
		ld.data.gaVisitor = Serializer.run(visitor);
		Serializer.USE_CACHE = oldSerializerValue;
		try{
			ld.flush();
		}catch( e:Dynamic ){
			trace("No se puede salvar el Visitor de Google Analytics!");
		}
		#end
	}

}

private class GATrackObject {

	private var event:Event;
	private var page:Page;

	public function new(page:Page,event:Event) {
		this.page=page;
		this.event=event;
	}
	
	public function track(tracker:Tracker,visitor:Visitor,session:Session){
		if(this.page!=null){
			tracker.trackPageview(page,session,visitor);
		}
		if(this.event!=null){
			tracker.trackEvent(event,session,visitor);
		}
	}
}
