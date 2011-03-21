// Project listing hovers.
(function($) {
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
})(jQuery);
