global.jQuery = global.$ = require('jquery')
global._ = require('underscore')
require('reveal.js/lib/js/head.min.js')
global.Reveal = require('reveal.js')
util = require('../util.js.tmp')

queryParams = util.getQueryStringParams()

initFlashcardSlides = (surveyData,
                       siteCodes = queryParams.siteCodes?.split(',') ? [],
                       minFreq = parseFloat(queryParams.minFreq ? 0.0),
                       sampleSize = parseInt(queryParams.sampleSize ? 25)) ->
  [numSurveys, speciesCounts] = surveyData.sumSites(siteCodes)
  minCount = minFreq * numSurveys
  items = []
  for id, count of speciesCounts
    continue if count < minCount
    item = surveyData.species[id]
    for image in item.images
      items.push(_.extend({image: image, freq: (100 * count / numSurveys).toFixed(2)}, item))
  $slides = $('.slides')
  compiledTemplate = _.template($('#fish-slide-template').html())
  for item in _.sample(items, sampleSize)
    $slides.append(compiledTemplate(item))
  $('#fish-number').html("#{Math.min(sampleSize, items.length)} out of the #{items.length}")

util.loadSurveyData (surveyData) ->
  initFlashcardSlides(surveyData)
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
