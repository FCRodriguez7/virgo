/* downloadButtonReplacer.js */
alert("js loaded");
$(document).ready(function(){
	alert("ready");
	document.getElementsByClass("minimiseButtons")[0].children[3].remove();
	
	var minimiseButtons = document.getElementsByClass("minimiseButtons")[0];
	minimiseButtons.insertBefore(document.createTextNode("hello there"), minimiseButtons.children[0]);
	
	var downloadButton = document.getElementsByClass("download")[0];
	
	var newDownloadButton = document.createElement("a");
	newDownloadButton.style.width = "30px";
	newDownloadButton.style.height = "30px";
	newDownloadButton.style.backgroundImage = "url('themes/uv-en-GB-theme/img/uv-shared-module/download.png')";
	
	
	
	//newDownloadButton.setAttribute("href", "");
	$(".download:first").replaceWith(newDownloadButton);
	alert("winner");
});