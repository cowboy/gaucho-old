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
  // TODO: use localStorage and a TTL.
  $(function() {
    var cache = {},
        queues = {};

    $('ul.projects li[data-github]').each(function() {
      var li = $(this),
          meta = li.find('.meta'),
          parts = li.data('github').split('/'),
          user = parts[0],
          repo = parts[1],
          userObj = cache[user];

      if ( userObj && userObj[repo] ) {
        // This user & repo combo already exists in cache, so just render.
        render(user, repo);

      } else {
        // User & repo combo doesn't exist in cache.
        if ( !userObj ) {
          // User doesn't exist in cache, so create user as well as a per-user
          // queue.
          cache[user] = {};
          queues[user] = [];

          // Fetch user repo(s).
          $.getJSON('http://github.com/api/v2/json/repos/show/' + user + '?callback=?', function( d ) {
            var repos = d && d.repositories;
            if ( !repos ) { return; }

            // Add user's repos into the cache.
            $.each(repos, function( i, r ) {
              var user = r.owner,
                  userObj = cache[user] || (cache[user] = {});
              //console.log('found %s/%s', user, r.name);
              userObj[r.name] = r;
            });

            // Execute any queued methods.
            $.each(queues[user], function( i, fn ) {
              fn();
            });
          });
        }

        //console.log('enqueue %s/%s', user, repo);
        queues[user].push(function() {
          render(user, repo);
        });
      }

      // Draw stuff into the page and stuff.
      function render( user, repo ) {
        //console.log('render %s/%s', user, repo);
        var userObj = cache[user],
            r = userObj && userObj[repo];

        if ( !r ) { return; }

        $('<span class="github"/>')
          .html([
            githubLink('GitHub'),
            githubLink('watcher', 'watchers', r.watchers),
            githubLink('fork', 'network', r.forks),
          ].join(' '))
          .appendTo(meta);

        function githubLink( txt, link, num ) {
          link = link ? '/' + link : '';
          txt = num == undefined ? txt : num + ' ' + txt + (num == 1 ? '' : 's');
          return '<a href="http://github.com/' + user + '/' + repo + link + '">' + txt + '</a>';
        }
      }

    });
  });
})(jQuery);
