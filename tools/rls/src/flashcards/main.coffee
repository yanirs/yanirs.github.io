global.jQuery = global.$ = require('jquery')
global._ = require('underscore')
require('reveal.js/lib/js/head.min.js')
global.Reveal = require('reveal.js')

initFlashcardSlides = (items = window.fish,
                       minFreq = parseFloat(Reveal.getQueryHash()['minFreq']) or 0.0,
                       sliceSize = parseInt(Reveal.getQueryHash()['sliceSize']) or 25) ->
  for item in items
    item.common_name = species[item.name] if item.common_name == ''
  items = _.shuffle(_.filter(items, (item) -> (item.freq or 0) >= minFreq))
  $slides = $('.slides')
  compiledTemplate = _.template($('#fish-slide-template').html())
  for item in items.slice(0, sliceSize)
    $slides.append(compiledTemplate(item))
  $('#fish-number').html("#{Math.min(sliceSize, items.length)} out of the #{items.length}")

initFlashcardSlides()
Reveal.initialize(
  width: 1000
  height: 760
  controls: true
  progress: true
  history: true
  center: true
  theme: 'night'
  slideNumber: true
)
