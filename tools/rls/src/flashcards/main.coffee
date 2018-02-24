global.jQuery = global.$ = require('jquery')
global._ = require('underscore')
require('reveal.js/lib/js/head.min.js')
global.Reveal = require('reveal.js')
util = require('../util.js.tmp')

DEFAULT_NUM_PHOTOS = 25
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
footerTemplate = _.template($('#footer-template').html())
flashcardTemplate = _.template($('#flashcard-template').html())
selectedEcoregion = null

$('body').keyup((event) ->
  if event.key == '\\'
    $(Reveal.getCurrentSlide()).children('input').focus()
)

getSelectedSites = ->
  util.getQueryStringParams().siteCodes?.split(',') ? []

generateItems = (surveyData, minFreq, selectedMethod) ->
  [numSurveys, speciesCounts] = surveyData.sumSites(getSelectedSites())
  minCount = numSurveys * minFreq / 100
  items = []
  for id, count of speciesCounts
    continue if count < minCount
    item = surveyData.species[id]
    continue if selectedMethod == 'M1' and item.method == 'M2' or selectedMethod == 'M2' and item.method == 'M1'
    for image in item.images
      items.push(_.extend({image: image, freq: (100 * count / numSurveys).toFixed(2)}, item))
  items

generateOptions = (valueNamePairs, selectedValue, includeEmpty = false) ->
  options = if includeEmpty then ['<option></option>'] else []
  for valueNamePair in valueNamePairs
    [value, name] = if valueNamePair instanceof Array then valueNamePair else [valueNamePair, valueNamePair]
    selected = if value == selectedValue then 'selected' else ''
    options.push("""<option value="#{value}" #{selected}>#{name}</option>""")
  options.join('')

initSlides = (surveyData, minFreq = 0, selectedMethod = 'all', numPhotos = DEFAULT_NUM_PHOTOS) ->
  items = generateItems(surveyData, minFreq, selectedMethod)
  numPhotos = Math.min(numPhotos, items.length)
  ecoregionValueNamePairs = ([er, "#{er} (#{sc.length} sites)"] for er, sc of surveyData.ecoregionToSiteCodes).sort()
  $slides = $('.slides')
  $slides.append(headerTemplate(
    numPhotosOptions: generateOptions(i for i in [25, 50, 100] when i <= items.length, numPhotos)
    totalPhotos: items.length
    minFreq: minFreq
    ecoregionOptions: generateOptions(ecoregionValueNamePairs, selectedEcoregion, true)
    methodOptions: generateOptions(['all', 'M1', 'M2'], selectedMethod)
    frequencyExplorerUrl: util.getFrequencyExplorerUrl(),
    numSelectedSites: getSelectedSites().length
  ))
  for item in _.sample(items, numPhotos)
    $slides.append(flashcardTemplate(item))
  $slides.append(footerTemplate()) if numPhotos > 0
  Reveal.initialize(REVEAL_SETTINGS)

  slideScores = {}
  calculateScore = ->
    answered = 0
    correct = 0
    for i in [1..numPhotos]
      if slideScores.hasOwnProperty(i)
        answered++
        correct++ if slideScores[i]
    score = (100 * correct / numPhotos).toFixed(2)
    $('.js-running-score').html(
      "Score: #{score}% (correct: #{correct}; attempted: #{answered}; unanswered: #{numPhotos - answered})"
    )
  $('.js-scientific-name').keyup((event) ->
    if event.key == 'Enter'
      $this = $(this)
      $this.removeClass('alert-success alert-error')
      slideIndex = Reveal.getIndices().h
      if $this.val().trim() == $this.data('name')
        $this.addClass('alert-success')
        $this.blur()
        slideScores[slideIndex] = true if not slideScores.hasOwnProperty(slideIndex)
        setTimeout(Reveal.right, 500)
      else
        $this.addClass('alert-error')
        slideScores[slideIndex] = false
        setTimeout(Reveal.down, 500)
        setTimeout(Reveal.right, 2000)
      calculateScore()
  )

  refreshSlides = (delay = 250) ->
    minFreq = parseFloat($('.js-min-freq').val())
    selectedMethod = $('.js-method').val()
    numPhotos = parseInt($('.js-num-photos').val() ? DEFAULT_NUM_PHOTOS)
    $slides.html('')
    $('body').addClass('loading') if delay
    delayCallback = ->
      initSlides(surveyData, minFreq, selectedMethod, numPhotos)
      $('body').removeClass('loading') if delay
      Reveal.toggleOverview(false)
    setTimeout(delayCallback, delay)

  $('.js-resample').click(refreshSlides)
  $('.js-min-freq, .js-method, .js-num-photos').change(-> refreshSlides(0))
  $('.js-ecoregion').change(->
    selectedEcoregion = $('.js-ecoregion').val()
    ecoregionSiteCodes = surveyData.ecoregionToSiteCodes[selectedEcoregion]
    if ecoregionSiteCodes
      history.pushState(null, null, '?' + $.param(siteCodes: ecoregionSiteCodes.join(',')))
      refreshSlides()
  )

util.loadSurveyData(initSlides)
