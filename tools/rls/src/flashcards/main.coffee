global.jQuery = global.$ = require('jquery')
global._ = require('underscore')
require('reveal.js/lib/js/head.min.js')
global.Reveal = require('reveal.js')
util = require('../util.js.tmp')

queryHash = Reveal.getQueryHash()

initFlashcardSlides = (surveyData,
                       siteCodes = queryHash.siteCodes?.split(' ') ? [],
                       minFreq = parseFloat(queryHash.minFreq ? 0.0),
                       sampleSize = parseInt(queryHash.sampleSize ? 25)) ->
  [numSurveys, speciesCounts] = surveyData.sumSites(siteCodes)
  minCount = minFreq * numSurveys
  filteredSpeciesIds = (id for id, count of speciesCounts when count >= minCount)
  $slides = $('.slides')
  compiledTemplate = _.template($('#fish-slide-template').html())
  for id in _.sample(filteredSpeciesIds, sampleSize)
    item = surveyData.species[id]
    $slides.append(compiledTemplate(
      image: _.sample(item.images)
      freq: (100 * speciesCounts[id] / numSurveys).toFixed(2),
      url: item.url,
      name: item.name,
      commonName: item.commonName
    ))
  $('#fish-number').html("#{Math.min(sampleSize, filteredSpeciesIds.length)} out of the #{filteredSpeciesIds.length}")

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
