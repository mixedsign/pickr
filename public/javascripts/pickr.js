
// Array Remove - By John Resig (MIT Licensed)
Array.prototype.remove = function(from, to) {
  var rest = this.slice((to || from) + 1 || this.length);
  this.length = from < 0 ? this.length + from : from;
  return this.push.apply(this, rest);
};

pickr = (function(){

	var selector = new PhotoBucket("#selector");

	function PhotoBucket(sel) {
		return {
			photos : [],
			show   : function()   { showSelector(sel) },
			hide   : function()   { hideSelector(sel) },
			add    : function(id) { selectPhoto(sel, id) },
			remove : function(id) { deSelectPhoto(id) },
		}
	}
	
	function selectPhoto(sel, id) {
		selector.photos.push(id);
	
		$.get('/thumbnail/' + id, function(data) {
				$("#selected_photos").append(data);
		});
		if ($(sel).css('display') == 'none') {
			showSelector();
		}
		$('#photo_' + id).animate({ opacity : 0.3 });
	}
	
	function deSelectPhoto(id) {
		var i = jQuery.inArray(id, pickr.selected)
		if ( i != -1 ) selector.photos.remove(i); // it's in there
	
		if ( selector.photos.length == 0 ) hideSelector();
	
		$('#photo_' + id).animate({ opacity : 1 });
	
		// remove thumb from selector
		$("#selector-thumb-" + id).remove();
	
		// uncheck checkbox
		$box = $("#select_" + id);
		if ( $box.attr('checked') == true ) $box.attr('checked', false);
	}

	function showSelector(sel) {
		$(sel).slideDown();
	}
	
	function hideSelector(sel) {
		$(sel).slideUp();
	}

	function toggleCheckBox($box) {
		if ( $box.attr('checked') == true ) {
			$box.attr('checked', false);
			deSelectPhoto($box.val());
		}
		else { 
			$box.attr('checked', true);
			selectPhoto($box.val());
		}
		return false;
	}

	return {
		PhotoBucket    : PhotoBucket,
		selector       : selector,
		toggleCheckBox : toggleCheckBox,
	}
}());

$(document).ready(function(){
	$('#selector #close-button').click(pickr.selector.hide);

	$('input[name=photo]').change(function(){
		alert("changed");
		if ( $(this).attr('checked') == true ) { pickr.selector.add($(this).val()) }
		else                                   { pickr.selector.remove($(this).val()) }
	});
});
