global.jQuery = global.$ = require('jquery')
global._ = require('underscore')
require('reveal.js/lib/js/head.min.js')
global.Reveal = require('reveal.js')
util = require('../util.js.tmp')

DEFAULT_NUM_PHOTOS = 25
SLIDE_CHANGE_DELAY = 500
TEST_SECONDS_PER_SLIDE = 10
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

updateDisplayedScore = (slideScores, numPhotos) ->
  answered = 0
  correct = 0
  almostCorrect = 0
  mistakes = ''
  partialMistakes = ''
  for i in [1..numPhotos]
    if slideScores.hasOwnProperty(i)
      answered++
      slideLink = """ <a href="#/#{i}">(#{i}) <i>#{slideScores[i].name}</i></a>"""
      if slideScores[i].correct
        correct++
      else if slideScores[i].almostCorrect
        almostCorrect++
        partialMistakes += " #{slideLink}"
      else
        mistakes += " #{slideLink}"
  score = ((100 * correct + 50 * almostCorrect) / numPhotos).toFixed(2)
  $('.js-running-score').html(
    "<b>Score:</b> #{score}% (correct: #{correct}; almost correct: #{almostCorrect}; attempted: #{answered}; unanswered: #{numPhotos - answered})"
  )
  $('.js-review-mistakes').html("""
    <b>Mistakes:</b> #{if mistakes then mistakes else '<i>None</i>'}<br>
    <b>Almost correct:</b> #{if partialMistakes then partialMistakes else '<i>None</i>'}
  """)

testTimerTimeoutId = null
updateTestTimer = (testStartTime, timeLimitSeconds) ->
  secondsLeft = timeLimitSeconds - Math.floor((Date.now() - testStartTime) / 1000)
  if secondsLeft > 0
    $('.js-test-timer').html(
      "<b>Time left:</b> #{Math.floor(secondsLeft / 60)}:#{(secondsLeft % 60).toString().padStart(2, '0')}"
    )
    testTimerTimeoutId = setTimeout(
      -> updateTestTimer(testStartTime, timeLimitSeconds),
      1000
    )
  else
    endTest()

endTest = (jumpToLastSlide = true) ->
  clearTimeout(testTimerTimeoutId)
  $('.js-test-info').html('Test over! You can now go through the slides to review your answers.')
  $('.slides').removeClass('test-active')
  $('.js-scientific-name').blur().prop('disabled', true)
  $('.js-correct-answer').removeClass('hidden')
  Reveal.slide(Number.MAX_VALUE) if jumpToLastSlide

calculateLevenshteinDistance = (source, target) ->
  return target.length if source.length == 0
  return source.length if target.length == 0

  distances = []
  distances[i] = [] for i in [0..source.length]
  distances[i][0] = i for i in [0..source.length]
  distances[0][j] = j for j in [0..target.length]

  for i in [0...source.length]
    for j in [0...target.length]
      deletionCost = distances[i][j + 1] + 1
      insertionCost = distances[i + 1][j] + 1
      substitutionCost = distances[i][j] + (if source[i] == target[j] then 0 else 1)
      distances[i + 1][j + 1] = Math.min(deletionCost, insertionCost, substitutionCost)

  distances[source.length][target.length]

checkAnswer = ($input, slideScores, testMode, almostCorrectMaxDistance = 3) ->
  $input.blur()
  name = $input.data('name')
  editDistance = calculateLevenshteinDistance($input.val().trim().toLowerCase(), name.toLowerCase())
  correct = editDistance == 0
  almostCorrect = not correct and editDistance <= almostCorrectMaxDistance
  alertType =
    if correct
      'success'
    else if almostCorrect
      'warning'
    else
      'error'
  $input.removeClass('alert-success alert-error alert-warning')
  $input.addClass("alert-#{alertType}")
  $input.siblings('.js-correct-answer').removeClass('hidden')
  # Only record the result on the first attempt.
  slideIndex = Reveal.getIndices().h
  if not slideScores.hasOwnProperty(slideIndex)
    slideScores[slideIndex] =
      correct: correct
      almostCorrect: almostCorrect
      name: name
  # Only show the answer slides if incorrect and out of test mode. Otherwise, just move to the next slide.
  if correct or testMode
    setTimeout(Reveal.right, SLIDE_CHANGE_DELAY)
  else
    setTimeout(Reveal.down, SLIDE_CHANGE_DELAY)
    setTimeout(Reveal.right, SLIDE_CHANGE_DELAY * 4)

refreshSlides = (surveyData, delay = 250, testMode = false) ->
  endTest(false) if testTimerTimeoutId
  minFreq = parseFloat($('.js-min-freq').val())
  selectedMethod = $('.js-method').val()
  numPhotos = parseInt($('.js-num-photos').val() ? DEFAULT_NUM_PHOTOS)
  $('.slides').html('')
  $('body').addClass('loading') if delay
  delayCallback = ->
    initSlides(surveyData, minFreq, selectedMethod, numPhotos, testMode)
    $('body').removeClass('loading') if delay
    Reveal.toggleOverview(false)
    setTimeout(Reveal.right, SLIDE_CHANGE_DELAY) if testMode
  setTimeout(delayCallback, delay)

initSlides = (surveyData, minFreq = 0, selectedMethod = 'all', numPhotos = DEFAULT_NUM_PHOTOS, testMode = false) ->
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
  if testMode
    $slides.addClass('test-active')
    $('.js-test-info').html(
      """<div class="js-test-timer"></div><a href="#/#{numPhotos + 1}" class="js-end-test">End test</a>"""
    )
    updateTestTimer(Date.now(), numPhotos * TEST_SECONDS_PER_SLIDE)
    updateDisplayedScore(slideScores, numPhotos)
  $('.js-scientific-name').keyup((event) ->
    if event.key == 'Enter'
      checkAnswer($(this), slideScores, testMode)
      updateDisplayedScore(slideScores, numPhotos)
  )

  $('.js-resample').click(-> refreshSlides(surveyData))
  $('.js-min-freq, .js-method, .js-num-photos').change(-> refreshSlides(surveyData, 0))
  $('.js-start-test').click(-> refreshSlides(surveyData, 0, true))
  $('.js-end-test').click(endTest)
  $('.js-ecoregion').change(->
    selectedEcoregion = $('.js-ecoregion').val()
    ecoregionSiteCodes = surveyData.ecoregionToSiteCodes[selectedEcoregion]
    if ecoregionSiteCodes
      history.pushState(null, null, '?' + $.param(siteCodes: ecoregionSiteCodes.join(',')))
      refreshSlides(surveyData)
  )

util.loadSurveyData(initSlides)
