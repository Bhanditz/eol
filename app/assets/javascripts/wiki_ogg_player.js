var wgOggPlayer={'detectionDone':false,'msie':false,'safari':false,'opera':false,'mozilla':false,'players':['videoElement','cortado','quicktime-mozilla','quicktime-activex','vlc-mozilla','vlc-activex','totem','kmplayer','kaffeine','mplayerplug-in','oggPlugin'],'clientSupports':{'thumbnail':true},'mimeTypes':{'quicktime-mozilla':'video/quicktime','quicktime-activex':'video/quicktime','vlc-mozilla':'application/x-vlc-plugin','oggPlugin':'application/ogg','totem':'application/ogg','kmplayer':'application/ogg','kaffeine':'application/ogg','mplayerplug-in':'application/ogg'},'savedThumbs':{},'qtTimers':{},'defaultMsg':{'ogg-player-totem':'Totem','ogg-player-kmplayer':'KMPlayer','ogg-player-kaffeine':'Kaffeine','ogg-player-mplayerplug-in':'mplayerplug-in'},'msg':{},'cortadoUrl':'','extPathUrl':'','showPlayerSelect':true,'controlsHeightGuess':20,'init':function(player,params){elt=document.getElementById(params.id);if(!(params.id in this.savedThumbs)){var thumb=document.createDocumentFragment();for(i=0;i<elt.childNodes.length;i++){thumb.appendChild(elt.childNodes.item(i).cloneNode(true));}
this.savedThumbs[params.id]=thumb;}
this.detect();if(!player){var cookieVal=this.getCookie('ogg_player');if(cookieVal&&cookieVal!='thumbnail'){player=cookieVal;}}
if(!this.clientSupports[player]){player=false;}
if(!player){for(var i=0;i<this.players.length;i++){if(this.clientSupports[this.players[i]]){player=this.players[i];break;}}}
elt.innerHTML='';switch(player){case'videoElement':this.embedVideoElement(elt,params);break;case'oggPlugin':case'kaffeine':case'totem':case'kmplayer':case'mplayerplug-in':this.embedOggPlugin(elt,params,player);break;case'vlc-mozilla':this.embedVlcPlugin(elt,params);break;case'vlc-activex':this.embedVlcActiveX(elt,params);break;case'cortado':this.embedCortado(elt,params);break;case'quicktime-mozilla':case'quicktime-activex':this.embedQuicktimePlugin(elt,params,player);break;case'thumbnail':default:if(params.id in this.savedThumbs){elt.appendChild(this.savedThumbs[params.id].cloneNode(true));}else{elt.appendChild(document.createTextNode('Missing saved thumbnail for '+params.id));}
if(player!='thumbnail'){var div=document.createElement('div');div.className='ogg-player-options';div.style.cssText='width: '+(params.width-10)+'px;';div.innerHTML=this.msg['ogg-no-player'];elt.appendChild(div);player='none';}}
if(player!='thumbnail'){var optionsBox=this.makeOptionsBox(player,params);var optionsLink=this.makeOptionsLink(params.id);var div=document.createElement('div');div.appendChild(optionsBox);div.appendChild(optionsLink);elt.appendChild(div);}},'debug':function(s){},'supportedMimeType':function(mimetype){for(var i=navigator.plugins.length;i-->0;){var plugin=navigator.plugins[i];if(typeof plugin[mimetype]!="undefined")
return true;}
return false;},'detect':function(){if(this.detectionDone){return;}
this.detectionDone=true;this.msie=(navigator.appName=="Microsoft Internet Explorer");this.mozilla=(navigator.appName=="Netscape");this.opera=(navigator.appName=='Opera');this.safari=(navigator.vendor&&navigator.vendor.substr(0,5)=='Apple');this.konqueror=(navigator.appName=='Konqueror');var javaEnabled=navigator.javaEnabled();var invisibleJava=this.opera;if(invisibleJava&&javaEnabled){this.clientSupports['cortado']=true;}
if(this.konqueror){javaEnabled=false;}
if(this.testActiveX('VideoLAN.VLCPlugin.2')){this.clientSupports['vlc-activex']=true;}
if(javaEnabled&&this.testActiveX('JavaWebStart.isInstalled')){this.clientSupports['cortado']=true;}
if(this.testActiveX('QuickTimeCheckObject.QuickTimeCheck.1')){this.clientSupports['quicktime-activex']=true;}
if(typeof HTMLVideoElement=='object'||typeof HTMLVideoElement=='function')
{if(wgOggPlayer.safari){try{var dummyvid=document.createElement("video");if(dummyvid.canPlayType&&dummyvid.canPlayType("video/ogg;codecs=\"theora,vorbis\"")=="probably")
{this.clientSupports['videoElement']=true;}else if(this.supportedMimeType('video/ogg')){this.clientSupports['videoElement']=true;}else{}}catch(e){}}else{this.clientSupports['videoElement']=true;}}
if(!navigator.mimeTypes||navigator.mimeTypes.length==0){return;}
var typesByPlayer={};var playersByType={};var numPlayersByType={};var player;var i;for(i=0;i<navigator.mimeTypes.length;i++){var entry=navigator.mimeTypes[i];var type=entry.type;var semicolonPos=type.indexOf(';');if(semicolonPos>-1){type=type.substr(0,semicolonPos);}
var plugin=entry.enabledPlugin;var pluginName=plugin&&plugin.name?plugin.name:'';var pluginFilename=plugin&&plugin.filename?plugin.filename:'';player='';if(javaEnabled&&type=='application/x-java-applet'){this.clientSupports['cortado']=true;player='';}else if(pluginFilename.indexOf('libtotem')>-1){player='totem';}else if(pluginFilename.indexOf('libkmplayerpart')>-1){if(pluginName=='Windows Media Player Plugin'||pluginName=='QuickTime Plug-in')
{player='kmplayer';}}else if(pluginFilename.indexOf('kaffeineplugin')>-1){player='kaffeine';}else if(pluginName.indexOf('mplayerplug-in')>-1){player='mplayerplug-in';}else if(pluginFilename.indexOf('mplayerplug-in-qt')>-1){player='';}else if(pluginName.indexOf('QuickTime Plug-in')>-1){player='quicktime-mozilla';}else if(pluginName.toLowerCase()=='vlc multimedia plugin'){player='vlc-mozilla';}else if(type=='application/ogg'){player='oggPlugin';}
if(this.konqueror&&player=='vlc-mozilla'){player='';}
if(!(player in typesByPlayer)){typesByPlayer[player]={};}
typesByPlayer[player][type]=true;if(!(type in playersByType)){playersByType[type]={};numPlayersByType[type]=0;}
if(!(player in playersByType[type])){playersByType[type][player]=true;numPlayersByType[type]++;}}
for(i=0;i<this.players.length;i++){player=this.players[i];if(!(player in typesByPlayer)){continue;}
var defaultType=this.mimeTypes[player];if(defaultType in numPlayersByType&&numPlayersByType[defaultType]==1&&defaultType in typesByPlayer[player])
{this.debug(player+" -> "+defaultType);this.clientSupports[player]=true;continue;}
for(var type in typesByPlayer[player]){if(numPlayersByType[type]==1){this.mimeTypes[player]=type;this.clientSupports[player]=true;this.debug(player+" => "+type);break;}}
if(!(player in this.clientSupports)){if(typesByPlayer[player].length>0){this.debug("No unique MIME type for "+player);}else{this.debug("No types for player "+player);}}}},'testActiveX':function(name){if(this.mozilla)return false;var hasObj=true;try{var obj=new ActiveXObject(''+name);}catch(e){hasObj=false;}
return hasObj;},'addOption':function(select,value,text,selected){var option=document.createElement('option');option.value=value;option.appendChild(document.createTextNode(text));if(selected){option.selected=true;}
select.appendChild(option);},'hx':function(s){if(typeof s!='String'){s=s.toString();}
return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');},'hq':function(s){return'"'+this.hx(s)+'"';},'getMsg':function(key){if(key in this.msg){return this.msg[key];}else if(key in this.defaultMsg){return this.defaultMsg[key];}else{return'['+key+']';}},'makeOptionsBox':function(selectedPlayer,params){var div,p,a,ul,li,button;div=document.createElement('div');div.style.cssText="width: "+(params.width-10)+"px; display: none;";div.className='ogg-player-options';div.id=params.id+'_options_box';div.align='center';ul=document.createElement('ul');if(params.linkUrl){li=document.createElement('li');a=document.createElement('a');a.href=params.linkUrl;a.appendChild(document.createTextNode(this.msg['ogg-desc-link']));li.appendChild(a);ul.appendChild(li);}
li=document.createElement('li');a=document.createElement('a');a.href=params.videoUrl;a.appendChild(document.createTextNode(this.msg['ogg-download']));li.appendChild(a);ul.appendChild(li);div.appendChild(ul);p=document.createElement('p');p.appendChild(document.createTextNode(this.msg['ogg-use-player']));div.appendChild(p);ul=document.createElement('ul');for(var i=0;i<this.players.length+1;i++){var player,playerMsg;if(i==this.players.length){player='thumbnail';if(params.isVideo){playerMsg='ogg-player-thumbnail';}else{playerMsg='ogg-player-soundthumb';}}else{player=this.players[i];if(!this.clientSupports[player]){continue;}
playerMsg='ogg-player-'+player;}
li=document.createElement('li');if(player==selectedPlayer){var strong=document.createElement('strong');strong.appendChild(document.createTextNode(this.getMsg(playerMsg)+' '+this.msg['ogg-player-selected']));li.appendChild(strong);}else{a=document.createElement('a');a.href='javascript:void("'+player+'")';a.onclick=this.makePlayerFunction(player,params);a.appendChild(document.createTextNode(this.getMsg(playerMsg)));li.appendChild(a);}
ul.appendChild(li);}
div.appendChild(ul);div2=document.createElement('div');div2.style.cssText='text-align: center;';button=document.createElement('button');button.appendChild(document.createTextNode(this.msg['ogg-dismiss']));button.onclick=this.makeDismissFunction(params.id);div2.appendChild(button);div.appendChild(div2);return div;},'makeOptionsLink':function(id){var a=document.createElement('a');a.href='javascript:void("options")';a.id=id+'_options_link';a.onclick=this.makeDisplayOptionsFunction(id);a.appendChild(document.createTextNode(this.msg['ogg-more']));return a;},'setCssProperty':function(elt,prop,value){var re=new RegExp(prop+':[^;](;|$)');if(elt.style.cssText.search(re)>-1){elt.style.cssText=elt.style.cssText.replace(re,prop+':'+value+'$1');}else if(elt.style.cssText==''){elt.style.cssText=prop+':'+value+';';}else if(elt.style.cssText[elt.style.cssText.length-1]==';'){elt.style.cssText+=prop+':'+value+';';}else{elt.style.cssText+=';'+prop+':'+value+';';}},'makeDismissFunction':function(id){var this_=this;return function(){var optionsLink=document.getElementById(id+'_options_link');var optionsBox=document.getElementById(id+'_options_box');this_.setCssProperty(optionsLink,'display','inline');this_.setCssProperty(optionsBox,'display','none');}},'makeDisplayOptionsFunction':function(id){var this_=this;return function(){var optionsLink=document.getElementById(id+'_options_link');var optionsBox=document.getElementById(id+'_options_box');this_.setCssProperty(optionsLink,'display','none');this_.setCssProperty(optionsBox,'display','block');}},'makePlayerFunction':function(player,params){var this_=this;return function(){if(player!='thumbnail'){var week=7*86400*1000;this_.setCookie('ogg_player',player,week,false,false,false,false);}
this_.init(player,params);};},'newButton':function(caption,image,callback){var elt=document.createElement('input');elt.type='image';elt.src=this.extPathUrl+'/'+image;elt.alt=elt.value=elt.title=this.msg[caption];elt.onclick=callback;return elt;},'newPlayButton':function(videoElt){return this.newButton('ogg-play','play.png',function(){videoElt.play();});},'newPauseButton':function(videoElt){return this.newButton('ogg-pause','pause.png',function(){videoElt.pause();});},'newStopButton':function(videoElt){return this.newButton('ogg-stop','stop.png',function(){videoElt.stop();});},'embedVideoElement':function(elt,params){var id=elt.id+"_obj";var mtag=(params.isVideo?'video':'audio');var html='<div><'+mtag+' id='+this.hq(id)+' width='+this.hq(params.width)+' height='+this.hq((params.height>0)?params.height:this.controlsHeightGuess)+' src='+this.hq(params.videoUrl)+' autoplay';if(!this.safari)
html+=' controls';html+=' ></'+mtag+'></div>';elt.innerHTML=html;},'embedOggPlugin':function(elt,params,player){var id=elt.id+"_obj";elt.innerHTML+="<div><object id="+this.hq(id)+" type='"+this.mimeTypes[player]+"'"+" width="+this.hq(params.width)+" height="+this.hq(params.height+this.controlsHeightGuess)+" data="+this.hq(params.videoUrl)+"></object></div>";},'embedVlcPlugin':function(elt,params){var id=elt.id+"_obj";elt.innerHTML+="<div><object id="+this.hq(id)+" type='"+this.mimeTypes['vlc-mozilla']+"'"+" width="+this.hq(params.width)+" height="+this.hq(params.height)+" data="+this.hq(params.videoUrl)+"></object></div>";var videoElt=document.getElementById(id);var div=document.createElement('div');div.appendChild(this.newPlayButton(videoElt));div.appendChild(this.newPauseButton(videoElt));div.appendChild(this.newStopButton(videoElt));elt.appendChild(div);},'embedVlcActiveX':function(elt,params){var id=elt.id+"_obj";var html='<div><object id='+this.hq(id)+' classid="clsid:9BE31822-FDAD-461B-AD51-BE1D1C159921"'+' codebase="http://downloads.videolan.org/pub/videolan/vlc/latest/win32/axvlc.cab#Version=0,8,6,0"'+' width='+this.hq(params.width)+' height='+this.hq(params.height)+' style="width: '+this.hx(params.width)+'px; height: '+this.hx(params.height)+'px;"'+">"+'<param name="mrl" value='+this.hq(params.videoUrl)+'/>'+'</object></div>';elt.innerHTML+=html;var videoElt=document.getElementById(id);if(params.width&&params.height){videoElt.width=params.width;videoElt.height=params.height;videoElt.style.width=params.width+'px';videoElt.style.height=params.height+'px';}
var div=document.createElement('div');div.appendChild(this.newButton('ogg-play','play.png',function(){videoElt.playlist.play();}));div.appendChild(this.newButton('ogg-stop','stop.png',function(){videoElt.playlist.stop();}));elt.appendChild(div);},'embedCortado':function(elt,params){var statusHeight=18;var playerHeight=params.height+statusHeight;var html='<applet code="com.fluendo.player.Cortado.class" '+'      width='+this.hq(params.width)+'      height='+this.hq(playerHeight)+'      archive='+this.hq(this.cortadoUrl)+'>'+'  <param name="url"  value='+this.hq(params.videoUrl)+'/>'+'  <param name="duration"  value='+this.hq(params.length)+'/>'+'  <param name="seekable"  value="true"/>'+'  <param name="autoPlay" value="true"/>'+'  <param name="showStatus"  value="show"/>'+'  <param name="showSpeaker" value="false"/>'+'  <param name="statusHeight"  value="'+statusHeight+'"/>'+'</applet>';if(this.mozilla){var iframe=document.createElement('iframe');iframe.setAttribute('width',params.width);iframe.setAttribute('height',playerHeight);iframe.setAttribute('scrolling','no');iframe.setAttribute('frameborder',0);iframe.setAttribute('marginWidth',0);iframe.setAttribute('marginHeight',0);elt.appendChild(iframe);var newDoc=iframe.contentDocument;newDoc.open();newDoc.write('<html><body>'+html+'</body></html>');newDoc.close();}else{elt.innerHTML='<div>'+html+'</div>';}},'embedQuicktimePlugin':function(elt,params,player){var id=elt.id+"_obj";var controllerHeight=16;var extraAttribs='';if(player=='quicktime-activex'){extraAttribs='classid="clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B"';}
elt.innerHTML+="<div><object id="+this.hq(id)+" type='"+this.mimeTypes[player]+"'"+" width="+this.hq(params.width)+" height="+this.hq(params.height+controllerHeight)+" data="+this.hq(this.extPathUrl+'/null_file.mov')+' '+extraAttribs+">"+"<param name='SCALE' value='Aspect'/>"+"<param name='AUTOPLAY' value='True'/>"+"<param name='src' value="+this.hq(this.extPathUrl+'/null_file.mov')+"/>"+"<param name='QTSRC' value="+this.hq(params.videoUrl)+"/>"+"</object></div>";var this_=this;this.qtTimers[params.id]=window.setInterval(this.makeQuickTimePollFunction(params),500);},'makeQuickTimePollFunction':function(params){var this_=this;return function(){var elt=document.getElementById(params.id);var id=params.id+'_obj';var videoElt=document.getElementById(id);if(elt&&videoElt){var xiphQtVersion=false,done=false;try{xiphQtVersion=videoElt.GetComponentVersion('imdc','XiTh','Xiph');done=true;}catch(e){}
if(done){window.clearInterval(this_.qtTimers[params.id]);if(!xiphQtVersion||xiphQtVersion=='0.0'){var div=document.createElement('div');div.className='ogg-player-options';div.style.cssText='width:'+(params.width-10)+'px;'
div.innerHTML=this_.getMsg('ogg-no-xiphqt');var optionsDiv=document.getElementById(params.id+'_options_box');if(optionsDiv){elt.insertBefore(div,optionsDiv.parentNode);}else{elt.appendChild(div);}}
this_.setParam(videoElt,'AUTOPLAY','False');}}};},'addParam':function(elt,name,value){var param=document.createElement('param');param.setAttribute('name',name);param.setAttribute('value',value);elt.appendChild(param);},'setParam':function(elt,name,value){var params=elt.getElementsByTagName('param');for(var i=0;i<params.length;i++){if(params[i].name.toLowerCase()==name.toLowerCase()){params[i].value=value;return;}}
this.addParam(elt,name,value);},'setCookie':function(name,value,expiry,path,domain,secure){var expiryDate=false;if(expiry){expiryDate=new Date();expiryDate.setTime(expiryDate.getTime()+expiry);}
document.cookie=name+"="+escape(value)+
(expiryDate?("; expires="+expiryDate.toGMTString()):"")+
(path?("; path="+path):"")+
(domain?("; domain="+domain):"")+
(secure?"; secure":"");},'getCookie':function(cookieName){var m=document.cookie.match(cookieName+'=(.*?)(;|$)');return m?unescape(m[1]):false;}};wgOggPlayer.msg={"ogg-play":"Play","ogg-pause":"Pause","ogg-stop":"Stop","ogg-no-player":"Sorry, your system does not appear to have any supported player software.\nPlease \x3ca href=\"http://www.mediawiki.org/wiki/Extension:OggHandler/Client_download\"\x3edownload a player\x3c/a\x3e.","ogg-player-videoElement":"Native browser support","ogg-player-oggPlugin":"Browser plugin","ogg-player-cortado":"Cortado (Java)","ogg-player-vlc-mozilla":"VLC","ogg-player-vlc-activex":"VLC (ActiveX)","ogg-player-quicktime-mozilla":"QuickTime","ogg-player-quicktime-activex":"QuickTime (ActiveX)","ogg-player-totem":"Totem","ogg-player-kaffeine":"Kaffeine","ogg-player-kmplayer":"KMPlayer","ogg-player-mplayerplug-in":"mplayerplug-in","ogg-player-thumbnail":"Still image only","ogg-player-selected":"(selected)","ogg-use-player":"Use player:","ogg-more":"More...","ogg-download":"Download file","ogg-desc-link":"About this file","ogg-dismiss":"Close","ogg-player-soundthumb":"No player","ogg-no-xiphqt":"You do not appear to have the XiphQT component for QuickTime.\nQuickTime cannot play Ogg files without this component.\nPlease \x3ca href=\"http://www.mediawiki.org/wiki/Extension:OggHandler/Client_download\"\x3edownload XiphQT\x3c/a\x3e or choose another player."};wgOggPlayer.cortadoUrl="http://upload.wikimedia.org/jars/cortado.jar";wgOggPlayer.extPathUrl="http://en.wikipedia.org/w/extensions/OggHandler";