!function(){CKEDITOR.dialog.add("attachment",function(e){function t(e){var t=e.split("/").pop(),i=t.split(".").pop();return{filename:t,className:"attach_"+i}}var i=/^(_(?:self|top|parent|blank))$/,n=function(e,t){var n=t?t.getAttribute("_cke_saved_href")||t.getAttribute("href"):"",s={};if(s.type="url",s.url=n,t){var r=t.getAttribute("target");if(s.target={},r){var o=r.match(i);o?s.target.type=s.target.name=r:(s.target.type="frame",s.target.name=r)}s.title=t.getAttribute("title")}for(var a=e.document.getElementsByTag("img"),l=new CKEDITOR.dom.nodeList(e.document.$.anchors),c=s.anchors=[],u=0;u<a.count();u++){var h=a.getItem(u);h.getAttribute("_cke_realelement")&&"anchor"==h.getAttribute("_cke_real_element_type")&&c.push(e.restoreRealElement(h))}for(u=0;u<l.count();u++)c.push(l.getItem(u));for(u=0;u<c.length;u++)h=c[u],c[u]={name:h.getAttribute("name"),id:h.getAttribute("id")};return this._.selectedElement=t,s},s=function(){var t=this.getDialog(),i=t.getContentElement("general","linkTargetName"),n=this.getValue();i&&(i.setLabel(e.lang.link.targetFrameName),this.getDialog().setValueOf("general","linkTargetName","_"==n.charAt(0)?n:""))};return{title:e.lang.attachment.title,minWidth:420,minHeight:200,onShow:function(){this.fakeObj=!1;var e=this.getParentEditor(),t=e.getSelection(),i=t.getRanges(),s=null;if(1==i.length){var r=i[0].getCommonAncestor(!0);s=r.getAscendant("a",!0),s&&s.getAttribute("href")?t.selectElement(s):(s=r.getAscendant("img",!0))&&s.getAttribute("_cke_real_element_type")&&"anchor"==s.getAttribute("_cke_real_element_type")?(this.fakeObj=s,s=e.restoreRealElement(this.fakeObj),t.selectElement(this.fakeObj)):s=null}this.setupContent(n.apply(this,[e,s]))},onOk:function(){var e={href:"javascript:void(0)/*"+CKEDITOR.tools.getNextNumber()+"*/"},i=[],n={href:e.href},s=this.getParentEditor();this.commitContent(n);var r=n.url||"";e._cke_saved_href=0===r.indexOf("/")?r:"http://"+r;{var o=t(r);n.title||""}if(e.title=0==n.title.length?o.filename:n.title,e["class"]=o.className,n.target&&("notSet"!=n.target.type&&n.target.name?e.target=n.target.name:i.push("target"),i.push("_cke_pa_onclick","onclick")),this._.selectedElement){var a=this._.selectedElement;if(CKEDITOR.env.ie&&e.name!=a.getAttribute("name")){var l=new CKEDITOR.dom.element('<a name="'+CKEDITOR.tools.htmlEncode(e.name)+'">',s.document);c=s.getSelection(),a.moveChildren(l),a.copyAttributes(l,{name:1}),l.replace(a),a=l,c.selectElement(a)}a.setAttributes(e),a.removeAttributes(i),a.getAttribute("title")&&a.setHtml(a.getAttribute("title")),a.getAttribute("name")?a.addClass("cke_anchor"):a.removeClass("cke_anchor"),this.fakeObj&&s.createFakeElement(a,"cke_anchor","anchor").replace(this.fakeObj),delete this._.selectedElement}else{var c=s.getSelection(),u=c.getRanges();if(1==u.length&&u[0].collapsed){var h=new CKEDITOR.dom.text(e.title,s.document);u[0].insertNode(h),u[0].selectNodeContents(h),c.selectRanges(u)}var d=new CKEDITOR.style({element:"a",attributes:e});d.type=CKEDITOR.STYLE_INLINE,d.apply(s.document)}},contents:[{label:e.lang.common.generalTab,id:"general",accessKey:"I",elements:[{type:"vbox",padding:0,children:[{type:"html",html:"<span>"+CKEDITOR.tools.htmlEncode(e.lang.attachment.url)+"</span>"},{type:"hbox",widths:["280px","110px"],align:"right",children:[{id:"src",type:"text",label:"",validate:CKEDITOR.dialog.validate.notEmpty(e.lang.flash.validateSrc),setup:function(e){e.url&&this.setValue(e.url),this.select()},commit:function(e){e.url=this.getValue()}},{type:"button",id:"browse",filebrowser:"general:src",hidden:!0,align:"center",label:e.lang.common.browseServer}]}]},{type:"vbox",padding:0,children:[{id:"name",type:"text",label:e.lang.attachment.name,setup:function(e){e.title&&this.setValue(e.title)},commit:function(e){e.title=this.getValue()}}]},{type:"hbox",widths:["50%","50%"],children:[{type:"select",id:"linkTargetType",label:e.lang.link.target,"default":"notSet",style:"width : 100%;",items:[[e.lang.link.targetNotSet,"notSet"],[e.lang.link.targetFrame,"frame"],[e.lang.link.targetNew,"_blank"],[e.lang.link.targetTop,"_top"],[e.lang.link.targetSelf,"_self"],[e.lang.link.targetParent,"_parent"]],onChange:s,setup:function(e){e.target&&this.setValue(e.target.type)},commit:function(e){e.target||(e.target={}),e.target.type=this.getValue()}},{type:"text",id:"linkTargetName",label:e.lang.link.targetFrameName,"default":"",setup:function(e){e.target&&this.setValue(e.target.name)},commit:function(e){e.target||(e.target={}),e.target.name=this.getValue()}}]}]},{id:"Upload",hidden:!0,filebrowser:"uploadButton",label:e.lang.common.upload,elements:[{type:"file",id:"upload",label:e.lang.common.upload,size:38},{type:"fileButton",id:"uploadButton",label:e.lang.common.uploadSubmit,filebrowser:"general:src","for":["Upload","upload"]}]}]}})}();