d3 = require('d3')
jStat = require('jStat').jStat

class BetaDistribution
  constructor: (@alpha, @beta) ->
    @betaInverse = jStat.gammaln(@alpha + @beta) - jStat.gammaln(@alpha) - jStat.gammaln(@beta)

  lpdf: (x) ->
    return Number.NEGATIVE_INFINITY if x < 0 or x > 1
    @betaInverse + (@alpha - 1) * Math.log(x) + (@beta - 1) * Math.log(1 - x)

  pdf: (x) ->
    return 0 if x < 0 or x > 1
    return 1 if @alpha == 1 and @beta == 1
    Math.exp(@lpdf(x))

  rvs: (n) ->
    jStat.beta.sample(@alpha, @beta) for [1..n]

class BetaModel
  constructor: (@alpha, @beta) ->

  distribution: ->
    new BetaDistribution(@alpha, @beta)

  getPDF: (noPoints) ->
    pdf = []
    distribution = @distribution()
    for i in [0..noPoints - 1]
      val = distribution.pdf(i / noPoints)
      pdf.push
        'x': i / noPoints
        'y': if val == Number.POSITIVE_INFINITY then 0 else val
    pdf

  getRvs: (noSamples) ->
    @distribution().rvs(noSamples)

  update: (successes, failures) ->
    @alpha = @alpha + successes
    @beta = @beta + failures

  percentileOfScore: (arr, score) ->
    counter = 0
    for value in arr
      counter++ if value <= score
    counter / arr.length

class Plots
  MARGIN:
    top: 20
    right: 20
    bottom: 30
    left: 50
  WIDTH: 690 - Plots::MARGIN.left - Plots::MARGIN.right
  HEIGHT: 350 - Plots::MARGIN.top - Plots::MARGIN.bottom

  NUM_SAMPLES: 5000

  constructor: (alpha, beta) ->
    @controlBeta = new BetaModel(alpha, beta)
    @testBeta = new BetaModel(alpha, beta)

  getHistogramElements: ->
    noBins = 200
    controlData = @controlBeta.getRvs(@NUM_SAMPLES)
    testData = @testBeta.getRvs(@NUM_SAMPLES)
    differenceData = (testData[i] - controlData[i] for i in [0..controlData.length - 1])
    x = d3.scale.linear().domain([-1, 1]).range([0, @WIDTH])
    histogram = d3.layout.histogram().bins(x.ticks(noBins))(differenceData)
    y = d3.scale.linear().domain([0, d3.max(histogram, (d) -> d.y)]).range([@HEIGHT, 0])
    {
      'margin': @MARGIN
      'width': @WIDTH
      'height': @HEIGHT
      'xAxis': d3.svg.axis().scale(x).orient('bottom')
      'yAxis': d3.svg.axis().scale(y).orient('left')
      'x': x
      'y': y
      'differenceData': differenceData
      'histogram': histogram
    }

  getPDFElements: ->
    controlData = @controlBeta.getPDF(@NUM_SAMPLES)
    testData = @testBeta.getPDF(@NUM_SAMPLES)
    allData = controlData.concat(testData)
    interpolationMode = 'cardinal'
    x = d3.scale.linear().domain(d3.extent(allData, (d) -> d.x)).range([0, @WIDTH])
    y = d3.scale.linear().domain([0, d3.max(allData, (d) -> d.y) + 1]).range([@HEIGHT, 0])
    xAxis = d3.svg.axis().scale(x).orient('bottom')
    yAxis = d3.svg.axis().scale(y).orient('left')
    controlLine = d3.svg.area().x((d) -> x d.x).y1(@HEIGHT).y0((d) -> y d.y).interpolate(interpolationMode)
    testLine = d3.svg.area().x((d) -> x d.x).y1(@HEIGHT).y0((d) -> y d.y).interpolate(interpolationMode)
    {
      'margin': @MARGIN
      'width': @WIDTH
      'height': @HEIGHT
      'xAxis': xAxis
      'yAxis': yAxis
      'testLine': testLine
      'controlLine': controlLine
      'testData': testData
      'controlData': controlData
    }

  drawHistogram: ->
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

  drawPDF: ->
    d = @getPDFElements()
    svg = d3.select('#pdfplot').append('svg').attr('width', d.width + d.margin.left + d.margin.right).attr('height', d.height + d.margin.top + d.margin.bottom).append('g').attr('transform', 'translate(' + d.margin.left + ',' + d.margin.top + ')')
    svg.append('g').attr('class', 'x axis').attr('transform', 'translate(0,' + d.height + ')').call d.xAxis
    svg.append('g').attr('class', 'y axis').call(d.yAxis).append('text').attr('transform', 'rotate(-90)').attr('y', 6).attr('dy', '.71em').style('text-anchor', 'end').text 'Density'
    svg.append('path').datum(d.testData).attr('class', 'line').attr('d', d.testLine).attr 'id', 'testLine'
    svg.append('path').datum(d.controlData).attr('class', 'area').attr('d', d.controlLine).attr 'id', 'controlLine'
    @pdfSVG = svg

  drawTable: (arr1, arr2) ->
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

  drawSummaryStatistics: (el) ->
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
    differenceMean = jStat.mean(el.differenceData)
    differenceMeanHTML.innerHTML = Math.round(100 * differenceMean) / 100

  redrawHistogram: ->
    el = @getHistogramElements()
    svg = @histogramSVG
    svg.selectAll('rect').data(el.histogram).transition().duration(1000).attr('y', (d) ->
      el.y d.y
    ).attr 'height', (d) ->
      el.height - el.y(d.y)
    @drawSummaryStatistics(el)

  redrawPDF: ->
    d = @getPDFElements()
    svg = @pdfSVG
    svg.select('#testLine').datum(d.testData).transition().duration(1000).attr 'd', d.testLine
    svg.select('#controlLine').datum(d.controlData).transition().duration(1000).attr 'd', d.controlLine
    svg.select('.y.axis').transition().duration(1000).call d.yAxis
    svg.select('.x.axis').transition().call d.xAxis

  updatePrior: (alpha, beta) ->
    @controlBeta = new BetaModel(alpha, beta)
    @testBeta = new BetaModel(alpha, beta)

  updatePosterior: (testSuccesses, testFailures, controlSuccesses, controlFailures) ->
    @controlBeta.update(controlSuccesses, controlFailures)
    @testBeta.update(testSuccesses, testFailures)

getInputs = ->
  new class then constructor: ->
    @[id] = Number(document.getElementById(id).value) for id in \
      ['priorAlpha', 'priorBeta', 'controlSuccesses', 'controlFailures', 'testSuccesses', 'testFailures']

initializePlots = ->
  inputs = getInputs()
  plots = new Plots(inputs.priorAlpha, inputs.priorBeta)
  plots.drawPDF()
  plots.drawHistogram()
  window.plots = plots

bindInputs = ->
  document.getElementById('form').onsubmit = (event) ->
    event.preventDefault()
    inputs = getInputs()
    plots = window.plots
    plots.updatePrior(inputs.priorAlpha, inputs.priorBeta)
    plots.updatePosterior(inputs.testSuccesses, inputs.testFailures, inputs.controlSuccesses, inputs.controlFailures)
    plots.redrawPDF()
    plots.redrawHistogram()
    return

initializePlots()
bindInputs()
