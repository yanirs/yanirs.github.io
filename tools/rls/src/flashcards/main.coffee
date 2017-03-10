global.jQuery = global.$ = require('jquery')
global._ = require('underscore')
require('reveal.js/lib/js/head.min.js')
global.Reveal = require('reveal.js')
util = require('../util.js.tmp')

queryParams = util.getQueryStringParams()
headerTemplate = _.template($('#header-template').html())
flashcardTemplate = _.template($('#flashcard-template').html())

initSlides = (surveyData,
              minFreq = 0,
              siteCodes = queryParams.siteCodes?.split(',') ? [],
              sampleSize = parseInt(queryParams.sampleSize ? 25)) ->
  [numSurveys, speciesCounts] = surveyData.sumSites(siteCodes)
  minCount = numSurveys * minFreq / 100
  items = []
  for id, count of speciesCounts
    continue if count < minCount
    item = surveyData.species[id]
    for image in item.images
      items.push(_.extend({image: image, freq: (100 * count / numSurveys).toFixed(2)}, item))
  $slides = $('.slides')
  $slides.append(headerTemplate(
    shownPhotos: Math.min(sampleSize, items.length)
    totalPhotos: items.length
    minFreq: minFreq
  ))
  for item in _.sample(items, sampleSize)
    $slides.append(flashcardTemplate(item))
  Reveal.initialize(
    width: 1000
    height: 760
    margin: 0.1
    history: true
    theme: 'night'
    slideNumber: true
  )

  refreshSlides = (delay = 250) ->
    minFreq = parseFloat($('.js-min-freq').val())
    $slides.html('')
    $('body').addClass('loading') if delay
    delayCallback = ->
      initSlides(surveyData, minFreq)
      $('body').removeClass('loading') if delay
      Reveal.toggleOverview(false)
    setTimeout(delayCallback, delay)

  $('.js-resample').click(refreshSlides)
  $('.js-min-freq').change(-> refreshSlides(0))

util.loadSurveyData(initSlides)
