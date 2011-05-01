$(document).ready(function() {
	initPolling();
	initTooltips();
	initCompleteTask();
});

var initPolling = function() {
	var polling;
	if (polling = $.cookie('taskwarrior-web-polling')) {
		var pollingInterval = startPolling();
	} else {
		$('#polling-info a').text('Start polling');
	}

	$('#polling-info a').click(function(e) {
		if (polling) {
			window.clearInterval(pollingInterval);
			polling = false;
			$(this).text('Start polling');
			$.cookie('taskwarrior-web-polling', null);
		} else {
			pollingInterval = startPolling();
			polling = true;
			$(this).text('Stop polling');
			$.cookie('taskwarrior-web-polling', true);
		}
		e.preventDefault();
	});
};

var startPolling = function() {
	var pollingInterval = window.setInterval('refreshPageContents()', 3000);
	return pollingInterval;
};

var refreshPageContents = function() {
	$.ajax({
		url: window.location,
		success: function(data) {
			$('#listing').replaceWith($('#listing', data));
		}
	});
};

var initTooltips = function() {
	$('.tooltip').tipsy({
		title: 'data-tooltip',
		gravity: 's'
	});
};

var initCompleteTask = function() {
	$('input.pending').change(function() {
		var checkbox = $(this);
		var row = checkbox.closest('tr');
		var task_id = $(this).data('task');
		$.ajax({
			url: '/tasks/' + task_id + '/complete',
			type: 'post',
			beforeSend: function() {
				checkbox.replaceWith('<img src="/images/ajax-loader.gif" />');
			},
			success: function(data) {
				set_message('Task ' + task_id + ' completed.');
				row.fadeOut('slow', function() { row.remove(); });
			}
		});
	});
};

function set_message(msg, severity) {
	severity = severity ? severity : 'info';

	$('#flash-messages').append('<div class="message ' + severity + '">' + msg + '</div>');
}
