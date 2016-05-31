d3 = require('d3')
jStat = require('jStat').jStat

BetaDistribution = (alpha, beta) ->
  gammaln = jStat.gammaln
  @alpha = alpha
  @beta = beta
  @betaInverse = gammaln(@alpha + @beta) - gammaln(@alpha) - gammaln(@beta)
  return

BetaDistribution::lpdf = (x) ->
  if x < 0 or x > 1
    return Number.NEGATIVE_INFINITY
  @betaInverse + (@alpha - 1) * Math.log(x) + (@beta - 1) * Math.log(1 - x)

BetaDistribution::pdf = (x) ->
  if x < 0 or x > 1
    return 0
  if @alpha == 1 and @beta == 1
    return 1
  Math.exp @lpdf(x)

BetaDistribution::rv = ->
  jStat.beta.sample @alpha, @beta

BetaDistribution::rvs = (n) ->
  rvs = []
  i = 0
  while i < n
    rvs.push @rv()
    i++
  rvs

BetaModel = (alpha, beta) ->
  @alpha = alpha
  @beta = beta
  return

BetaModel::distribution = ->
  new BetaDistribution(@alpha, @beta)

BetaModel::getPDF = (noPoints) ->
  pdf = []
  distribution = @distribution()
  i = 0
  while i < noPoints
    val = distribution.pdf(i / noPoints)
    # Get rid of density singularities for plotting
    if val == Number.POSITIVE_INFINITY
      val = 0
    pdf.push
      'x': i / noPoints
      'y': val
    i++
  pdf

BetaModel::getRvs = (noSamples) ->
  @distribution().rvs noSamples

BetaModel::update = (successes, failures) ->
  @alpha = @alpha + successes
  @beta = @beta + failures
  return

BetaModel::percentileOfScore = (arr, score, kind) ->
  counter = 0
  len = arr.length
  strict = false
  value = undefined
  i = undefined
  if kind == 'strict'
    strict = true
  i = 0
  while i < len
    value = arr[i]
    if strict and value < score or !strict and value <= score
      counter++
    i++
  counter / len

BetaModel::mean = (arr) ->
  i = 0
  counter = 0
  i = 0
  while i < arr.length
    counter = counter + arr[i]
    i++
  counter / i

# -----------------------------------------------

Plots = (alpha, beta) ->
  @controlBeta = new BetaModel(alpha, beta)
  @testBeta = new BetaModel(alpha, beta)
  return

Plots::getHistogramElements = ->
  noSamples = 5000
  noBins = 200
  controlData = @controlBeta.getRvs(noSamples)
  testData = @testBeta.getRvs(noSamples)
  differenceData = []
  i = 0
  while i < controlData.length
    differenceData.push testData[i] - (controlData[i])
    i++
  margin =
    top: 20
    right: 20
    bottom: 30
    left: 50
  width = 690 - (margin.left) - (margin.right)
  height = 350 - (margin.top) - (margin.bottom)
  x = d3.scale.linear().domain([
    -1
    1
  ]).range([
    0
    width
  ])
  histogram = d3.layout.histogram().bins(x.ticks(noBins))(differenceData)
  y = d3.scale.linear().domain([
    0
    d3.max(histogram, (d) ->
      d.y
    )
  ]).range([
    height
    0
  ])
  xAxis = d3.svg.axis().scale(x).orient('bottom')
  yAxis = d3.svg.axis().scale(y).orient('left')
  {
    'margin': margin
    'width': width
    'height': height
    'xAxis': xAxis
    'yAxis': yAxis
    'x': x
    'y': y
    'differenceData': differenceData
    'histogram': histogram
  }

Plots::getPDFElements = ->
  numSamples = 2500
  controlData = @controlBeta.getPDF(numSamples)
  testData = @testBeta.getPDF(numSamples)
  allData = controlData.concat(testData)
  interpolationMode = 'cardinal'
  margin =
    top: 20
    right: 20
    bottom: 30
    left: 50
  width = 690 - (margin.left) - (margin.right)
  height = 350 - (margin.top) - (margin.bottom)
  x = d3.scale.linear().domain(d3.extent(allData, (d) ->
    d.x
  )).range([
    0
    width
  ])
  y = d3.scale.linear().domain([
    0
    d3.max(allData, (d) ->
      d.y
    ) + 1
  ]).range([
    height
    0
  ])
  xAxis = d3.svg.axis().scale(x).orient('bottom')
  yAxis = d3.svg.axis().scale(y).orient('left')
  controlLine = d3.svg.area().x((d) ->
    x d.x
  ).y1(height).y0((d) ->
    y d.y
  ).interpolate(interpolationMode)
  testLine = d3.svg.area().x((d) ->
    x d.x
  ).y1(height).y0((d) ->
    y d.y
  ).interpolate(interpolationMode)
  {
    'margin': margin
    'width': width
    'height': height
    'xAxis': xAxis
    'yAxis': yAxis
    'testLine': testLine
    'controlLine': controlLine
    'testData': testData
    'controlData': controlData
  }

Plots::drawHistogram = ->
  el = @getHistogramElements()
  svg = d3.select('#histogram').append('svg').attr('width', el.width + el.margin.left + el.margin.right).attr('height', el.height + el.margin.top + el.margin.bottom).append('g').attr('transform', 'translate(' + el.margin.left + ',' + el.margin.top + ')')
  svg.append('g').attr('class', 'x axis').attr('transform', 'translate(0,' + el.height + ')').call el.xAxis
  svg.append('g').attr('class', 'y axis').call(el.yAxis).append('text').attr('transform', 'rotate(-90)').attr('y', 6).attr('dy', '.71em').style('text-anchor', 'end').text 'Samples'
  bar = svg.selectAll('.bar').data(el.histogram).enter().append('g').attr('class', 'bar').attr('transform', (d) ->
    'translate(' + el.x(d.x) + ',0)'
  )
  bar.append('rect').attr('x', 1).attr('y', (d) ->
    el.y d.y
  ).attr('width', el.histogram[0].dx / 2 * el.width).attr 'height', (d) ->
    el.height - el.y(d.y)
  @histogramSVG = svg
  @drawSummaryStatistics el
  return

Plots::drawPDF = ->
  d = @getPDFElements()
  svg = d3.select('#pdfplot').append('svg').attr('width', d.width + d.margin.left + d.margin.right).attr('height', d.height + d.margin.top + d.margin.bottom).append('g').attr('transform', 'translate(' + d.margin.left + ',' + d.margin.top + ')')
  svg.append('g').attr('class', 'x axis').attr('transform', 'translate(0,' + d.height + ')').call d.xAxis
  svg.append('g').attr('class', 'y axis').call(d.yAxis).append('text').attr('transform', 'rotate(-90)').attr('y', 6).attr('dy', '.71em').style('text-anchor', 'end').text 'Density'
  svg.append('path').datum(d.testData).attr('class', 'line').attr('d', d.testLine).attr 'id', 'testLine'
  svg.append('path').datum(d.controlData).attr('class', 'area').attr('d', d.controlLine).attr 'id', 'controlLine'
  @pdfSVG = svg
  return

Plots::drawTable = (arr1, arr2) ->
  `var i`
  tb = ''
  tb += '<tr>'
  tb += '<td class="table-row-title">Percentiles</td>'
  i = 0
  while i < arr1.length
    tb += '<td>' + arr1[i] * 100 + '%</td>'
    i++
  tb += '</tr><tr>'
  tb += '<td class="table-row-title">Value</td>'
  i = 0
  while i < arr1.length
    tb += '<td>' + Math.round(100 * arr2[i]) / 100 + '</td>'
    i++
  tb += '</tr>'
  tb

Plots::drawSummaryStatistics = (el) ->
  quantiles = [
    0.01
    0.025
    0.05
    0.1
    0.25
    0.5
    0.75
    0.9
    0.95
    0.975
    0.99
  ]
  differenceQuantiles = jStat.quantiles(el.differenceData, quantiles)
  tableElement = document.getElementById('quantileTable')
  tableElement.innerHTML = @drawTable(quantiles, differenceQuantiles)
  percentileOfZero = BetaModel::percentileOfScore(el.differenceData, 0)
  testSuccessProbability = document.getElementById('testSuccessProbability')
  testSuccessProbability.innerHTML = Math.round((1.0 - percentileOfZero) * 100) / 100
  differenceMeanHTML = document.getElementById('differenceMean')
  differenceMean = BetaModel::mean(el.differenceData)
  differenceMeanHTML.innerHTML = Math.round(100 * differenceMean) / 100
  return

Plots::redrawHistogram = ->
  el = @getHistogramElements()
  svg = @histogramSVG
  svg.selectAll('rect').data(el.histogram).transition().duration(1000).attr('y', (d) ->
    el.y d.y
  ).attr 'height', (d) ->
    el.height - el.y(d.y)
  @drawSummaryStatistics el
  return

Plots::redrawPDF = ->
  d = @getPDFElements()
  svg = @pdfSVG
  svg.select('#testLine').datum(d.testData).transition().duration(1000).attr 'd', d.testLine
  svg.select('#controlLine').datum(d.controlData).transition().duration(1000).attr 'd', d.controlLine
  svg.select('.y.axis').transition().duration(1000).call d.yAxis
  svg.select('.x.axis').transition().call d.xAxis
  return

Plots::updatePrior = (alpha, beta) ->
  @controlBeta = new BetaModel(alpha, beta)
  @testBeta = new BetaModel(alpha, beta)
  return

Plots::updatePosterior = (testSuccesses, testFailures, controlSuccesses, controlFailures) ->
  @testBeta.update testSuccesses, testFailures
  @controlBeta.update controlSuccesses, controlFailures
  return

getInputs = ->
  priorAlpha = Number(document.getElementById('priorAlpha').value)
  priorBeta = Number(document.getElementById('priorBeta').value)
  controlSuccesses = Number(document.getElementById('controlSuccesses').value)
  controlFailures = Number(document.getElementById('controlFailures').value)
  testSuccesses = Number(document.getElementById('testSuccesses').value)
  testFailures = Number(document.getElementById('testFailures').value)
  {
    'priorAlpha': priorAlpha
    'priorBeta': priorBeta
    'controlSuccesses': controlSuccesses
    'controlFailures': controlFailures
    'testSuccesses': testSuccesses
    'testFailures': testFailures
  }

initializePlots = ->
  inputs = getInputs()
  plots = new Plots(inputs.priorAlpha, inputs.priorBeta)
  plots.drawPDF()
  plots.drawHistogram()
  window.plots = plots
  return

initializePlots()

updatePlots = ->
  inputs = getInputs()
  plots = window.plots
  plots.updatePrior inputs.priorAlpha, inputs.priorBeta
  plots.updatePosterior inputs.testSuccesses, inputs.testFailures, inputs.controlSuccesses, inputs.controlFailures
  plots.redrawPDF()
  plots.redrawHistogram()
  return

bindInputs = ->

  document.getElementById('form').onsubmit = (event) ->
    event.preventDefault()
    updatePlots()
    return

  return

bindInputs()
