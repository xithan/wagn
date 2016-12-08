wrapDeckoLayout = ->
  $footer  = $('body > footer').first()
  $('body > article, body > aside').wrapAll("<div class='#{containerClass()}'/>")
  $('body > div > article, body > div > aside')
    .wrapAll('<div class="row row-offcanvas">')
  if $footer
    $('body').append $footer

wrapSidebarToggle = (toggle) ->
  "<div class='container'><div class='row'>#{toggle}</div></div>"

containerClass = ->
  if $('body').hasClass('fluid') then "container-fluid" else "container"


sidebarToggle = (side) ->
  icon_dir = if side == 'left' then 'right' else 'left'
  "<button class='offcanvas-toggle offcanvas-toggle-#{side} btn btn-secondary "+
    "visible-xs' data-toggle='offcanvas-#{side}'>" +
    "<span class='glyphicon glyphicon-chevron-#{icon_dir}'/></button>"

singleSidebar = (side, width=3) ->
  $article = $('body > article').first()
  $aside   = $('body > aside').first()
  $article.addClass("col-xs-12 col-sm-#{12 - width} col-md-#{12 - width}")
  $aside.addClass(
    "col-xs-6 col-sm-#{width} col-md-#{width} sidebar-offcanvas sidebar-offcanvas-#{side}"
  )
  if side == 'left'
    $('body').append($aside).append($article)
  else
    $('body').append($article).append($aside)
  wrapDeckoLayout()
  $article.prepend(wrapSidebarToggle(sidebarToggle(side)))

doubleSidebar = ->
  $article    = $('body > article').first()
  $asideLeft  = $('body > aside').first()
  $asideRight = $($('body > aside')[1])
  $article.addClass("col-xs-12 col-sm-6")
  sideClass = "col-xs-6 col-sm-3 sidebar-offcanvas"
  $asideLeft.addClass("#{sideClass} sidebar-offcanvas-left")
  $asideRight.addClass("#{sideClass} sidebar-offcanvas-right")
  $('body').append($asideLeft).append($article).append($asideRight)
  wrapDeckoLayout()
  toggles = wrapSidebarToggle(sidebarToggle('right') + sidebarToggle('left'))
  $article.prepend(toggles)

$(window).ready ->
  width = if $('body').hasClass('thin-sidebar') then 2 else 3
  switch
    when $('body').hasClass('right-sidebar')
      singleSidebar('right', width)
    when $('body').hasClass('left-sidebar')
      singleSidebar('left', width)
    when $('body').hasClass('two-sidebar')
      doubleSidebar()

  $('[data-toggle="offcanvas-left"]').click ->
    $('.row-offcanvas').removeClass('right-active').toggleClass('left-active')
    $(this).find('span.glyphicon')
      .toggleClass('glyphicon-chevron-left glyphicon-chevron-right')
  $('[data-toggle="offcanvas-right"]').click ->
    $('.row-offcanvas').removeClass('left-active').toggleClass('right-active')
    $(this).find('span.glyphicon')
      .toggleClass('glyphicon-chevron-left glyphicon-chevron-right')
