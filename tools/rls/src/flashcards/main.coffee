global.jQuery = global.$ = require('jquery')
global._ = require('underscore')
require('reveal.js/lib/js/head.min.js')
global.Reveal = require('reveal.js')
util = require('../util.js.tmp')

SAMPLE_SIZE = 100
REVEAL_SETTINGS =
  width: 1000
  height: 760
  margin: 0.1
  history: true
  theme: 'night'
  slideNumber: true
if util.isCrossOriginFrame()
  REVEAL_SETTINGS.height = '100%'
  REVEAL_SETTINGS.center = false
  delete REVEAL_SETTINGS.margin

headerTemplate = _.template($('#header-template').html())
flashcardTemplate = _.template($('#flashcard-template').html())
selectedEcoregion = null

generateItems = (surveyData, minFreq, selectedMethod) ->
  queryParams = util.getQueryStringParams()
  [numSurveys, speciesCounts] = surveyData.sumSites(queryParams.siteCodes?.split(',') ? [])
  minCount = numSurveys * minFreq / 100
  items = []
  for id, count of speciesCounts
    continue if count < minCount
    item = surveyData.species[id]
    continue if selectedMethod == 'M1' and item.method == 'M2' or selectedMethod == 'M2' and item.method == 'M1'
    for image in item.images
      items.push(_.extend({image: image, freq: (100 * count / numSurveys).toFixed(2)}, item))
  items

initSlides = (surveyData, minFreq = 0, selectedMethod = 'all') ->
  items = generateItems(surveyData, minFreq, selectedMethod)
  ecoregionOptions = ["<option></option>"]
  for [ecoregion, ecoregionCodes] in _.pairs(surveyData.ecoregionToSiteCodes).sort()
    selected = if ecoregion == selectedEcoregion then 'selected' else ''
    ecoregionOptions.push(
      """<option value="#{ecoregion}" #{selected}>#{ecoregion} (#{ecoregionCodes.length} sites)</option>"""
    )
  methodOptions = []
  for method in ['all', 'M1', 'M2']
    selected = if method == selectedMethod then 'selected' else ''
    methodOptions.push("""<option #{selected}>#{method}</option>""")
  $slides = $('.slides')
  $slides.append(headerTemplate(
    shownPhotos: Math.min(SAMPLE_SIZE, items.length)
    totalPhotos: items.length
    minFreq: minFreq
    ecoregionOptions: ecoregionOptions.join('')
    methodOptions: methodOptions.join('')
    frequencyExplorerUrl: util.getFrequencyExplorerUrl()
  ))
  for item in _.sample(items, SAMPLE_SIZE)
    $slides.append(flashcardTemplate(item))
  Reveal.initialize(REVEAL_SETTINGS)

  refreshSlides = (delay = 250) ->
    minFreq = parseFloat($('.js-min-freq').val())
    selectedMethod = $('.js-method').val()
    $slides.html('')
    $('body').addClass('loading') if delay
    delayCallback = ->
      initSlides(surveyData, minFreq, selectedMethod)
      $('body').removeClass('loading') if delay
      Reveal.toggleOverview(false)
    setTimeout(delayCallback, delay)

  $('.js-resample').click(refreshSlides)
  $('.js-min-freq, .js-method').change(-> refreshSlides(0))
  $('.js-ecoregion').change(->
    selectedEcoregion = $('.js-ecoregion').val()
    ecoregionSiteCodes = surveyData.ecoregionToSiteCodes[selectedEcoregion]
    if ecoregionSiteCodes
      history.pushState(null, null, '?' + $.param(siteCodes: ecoregionSiteCodes.join(',')))
      refreshSlides()
  )

util.loadSurveyData(initSlides)
