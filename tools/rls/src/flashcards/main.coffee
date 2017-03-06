global.jQuery = global.$ = require('jquery')
global._ = require('underscore')
require('reveal.js/lib/js/head.min.js')
global.Reveal = require('reveal.js')

minFreq = parseFloat(Reveal.getQueryHash()['minFreq']) or 0.0

# TODO: clean up code
fish = _.map(window.fish, (item) ->
  if item.common_name == ''
    item.common_name = species[item.name]
  item
)
fish = _.shuffle(_.filter(fish, (item) ->
  if !item.source.includes('australianmuseum')
    return false
  (item.freq or 0) >= minFreq
))
slidesElement = $('.slides')
compiledTemplate = _.template($('#fish-slide-template').html())
sliceSize = 25
_.forEach fish.slice(0, sliceSize), (item) ->
  if item.local_image
    if item.local_image.match(/^joe/)
      item.source = 'http://Joe\'s photos'
    else if item.local_image.match(/^mine/)
      item.source = 'http://Yanir\'s photos'
  else
    item.local_image = null
    item.common_name = /<b>(.*)<\/b>/g.exec(item.name)[1]
    item.name = /<i>(.*)<\/i>/g.exec(item.name)[1]
    item.name = item.name[0].toUpperCase() + item.name.slice(1)
  slidesElement.append(compiledTemplate(item))
$('#fish-number').html("#{Math.min(sliceSize, fish.length)} out of the #{fish.length}")

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
