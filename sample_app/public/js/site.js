(function($) {
  // Project listing hovers.
  var z = 1;

  $(document).delegate('ul.projects > li > a', 'hover', function( e ) {
    var hover = e.type == 'mouseenter',
        li = $(this).parent(),
        reveal = li.find('.reveal');

    // By always increasing the z-index of the currently hovered element,
    // odd overlapping issues on hover out are eliminated.
    li.css('z-index', ++z).toggleClass('hover', hover);

    // Because -webkit-transition won't animate from 0 to auto, a numeric
    // height has to be used!
    reveal.css('height', hover ? reveal.css('height', 'auto').height() : 0);
  });

  // Project listing Github integration.
  // TODO: use localStorage.
  $(function() {
    $('ul.projects li[data-github]').each(function() {
      var li = $(this),
          meta = li.find('.meta'),
          repo = li.data('github');

      $.getJSON('http://github.com/api/v2/json/repos/show/' + repo + '?callback=?', function( d ) {
        var r = d && d.repository;
        if ( !r ) { return; }
        
        function link( txt, link, num ) {
          link = link ? '/' + link : '';
          txt = num == undefined ? txt : num + ' ' + txt + (num == 1 ? '' : 's');
          return '<a href="http://github.com/' + repo + link + '">' + txt + '</a>';
        }
        
        $('<span class="github"/>')
          .html([
            link('GitHub'),
            link('watcher', 'watchers', r.watchers),
            link('fork', 'network', r.forks),
          ].join(' '))
          .appendTo(meta);
      })
    });
  });
})(jQuery);
