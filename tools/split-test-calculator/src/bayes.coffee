d3 = require('d3')
jStat = require('jStat').jStat

round = (x) -> Math.round(x * 1000) / 1000
INPUTS =
  new class then constructor: ->
    @[id] = document.getElementById(id) for id in \
      ['prior-mean', 'prior-uncertainty', 'control-trials', 'control-successes', 'test-trials', 'test-successes']

class BetaModel
  constructor: (@alpha, @beta) ->

  getPdf: (noPoints) ->
    betaInverse = jStat.gammaln(@alpha + @beta) - jStat.gammaln(@alpha) - jStat.gammaln(@beta)
    distributionVal = (x) =>
      return 1 if @alpha == 1 and @beta == 1
      val = Math.exp(betaInverse + (@alpha - 1) * Math.log(x) + (@beta - 1) * Math.log(1 - x))
      if val == Number.POSITIVE_INFINITY then 0 else val
    {x: i / noPoints, y: distributionVal(i / noPoints)} for i in [0..noPoints - 1]

  getRvs: (numSamples) ->
    jStat.beta.sample(@alpha, @beta) for [1..numSamples]

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
  HEIGHT: 350 - Plots::MARGIN.top - Plots::MARGIN.bottom

  NUM_SAMPLES: 5000
  NUM_HISTOGRAM_BINS: 200
  PDF_INTERPOLATION_MODE: 'cardinal'

  constructor: ->
    @models = {}
    @width = @_calculateWidth()
    @update()
    @_draw()

  _calculateWidth: ->
    document.getElementsByClassName('content')[0].offsetWidth - @MARGIN.left - @MARGIN.right - 20

  _generatePlotData: ->
    @histData =
      control: @models.control.getRvs(@NUM_SAMPLES)
      test: @models.test.getRvs(@NUM_SAMPLES)
    @histData.diffs = (@histData.test[i] - @histData.control[i] for i in [0..@histData.control.length - 1])
    @pdfData =
      control: @models.control.getPdf(@NUM_SAMPLES)
      test: @models.test.getPdf(@NUM_SAMPLES)
    @pdfData.all = @pdfData.control.concat(@pdfData.test)

  _getHistogramElements: ->
    x = d3.scale.linear().domain([-1, 1]).range([0, @width])
    histogram = d3.layout.histogram().bins(x.ticks(@NUM_HISTOGRAM_BINS))(@histData.diffs)
    y = d3.scale.linear().domain([0, d3.max(histogram, (d) -> d.y)]).range([@HEIGHT, 0])
    el =
      'x': x
      'y': y
      'histogram': histogram
    @_addCommonElements(el, x, y)

  _getPdfElements: ->
    x = d3.scale.linear().domain(d3.extent(@pdfData.all, (d) -> d.x)).range([0, @width])
    y = d3.scale.linear().domain([0, d3.max(@pdfData.all, (d) -> d.y) + 1]).range([@HEIGHT, 0])
    el =
      'testLine': d3.svg.area().x((d) -> x d.x).y1(@HEIGHT).y0((d) -> y d.y).interpolate(@PDF_INTERPOLATION_MODE)
      'controlLine': d3.svg.area().x((d) -> x d.x).y1(@HEIGHT).y0((d) -> y d.y).interpolate(@PDF_INTERPOLATION_MODE)
    @_addCommonElements(el, x, y)

  _addCommonElements: (el, x, y) ->
    el.margin = @MARGIN
    el.height = @HEIGHT
    el.xAxis = d3.svg.axis().scale(x).orient('bottom')
    el.yAxis = d3.svg.axis().scale(y).orient('left')
    el

  _draw: ->
    pdfElems = @_getPdfElements()
    @pdfSvg = @_drawSvg(pdfElems, 'pdfplot', 'Density')
    for group in ['control', 'test']
      @pdfSvg.append('path')
             .datum(@pdfData[group])
             .attr('class', 'line')
             .attr('d', pdfElems["#{group}Line"])
             .attr('id', "#{group}-line")

    histElems = @_getHistogramElements()
    @histogramSvg = @_drawSvg(histElems, 'histogram', 'Samples')
    @histogramSvg.selectAll('.bar')
                 .data(histElems.histogram)
                 .enter()
                 .append('g')
                 .attr('class', 'bar')
                 .attr('transform', (d) -> "translate(#{histElems.x(d.x)},0)")
                 .append('rect').attr('x', 1)
                 .attr('y', (d) -> histElems.y(d.y))
                 .attr('width', histElems.histogram[0].dx / 2 * @width)
                 .attr('height', (d) -> histElems.height - histElems.y(d.y))

    @_drawSummaryStatistics()

  _drawSvg: (el, plotId, plotTitle) ->
    document.getElementById(plotId).innerHTML = ''
    svg = d3.select('#' + plotId).append('svg').attr('width', @width + el.margin.left + el.margin.right)
                                               .attr('height', el.height + el.margin.top + el.margin.bottom)
                                 .append('g').attr('transform', "translate(#{el.margin.left},#{el.margin.top})")
    svg.append('g').attr('class', 'x axis').attr('transform', "translate(0,#{el.height})").call(el.xAxis)
    svg.append('g').attr('class', 'y axis').call(el.yAxis).append('text').attr('y', -10)
                                                                         .style('text-anchor', 'end')
                                                                         .text(plotTitle)
    svg

  _drawSummaryStatistics: ->
    dataToMeanStd = (data) -> "#{round(jStat.mean(data))}±#{round(jStat.stdev(data))}"
    quantiles = [0.01, 0.025, 0.05, 0.25, 0.5, 0.75, 0.95, 0.975, 0.99]
    quantileDiffs = jStat.quantiles(@histData.diffs, quantiles)
    tb = '<tr><td>Percentile</td><td>Value</td></tr>'
    for i in [0..quantileDiffs.length - 1]
      tb += "<tr><td>#{quantiles[i] * 100}%</td><td>#{round(quantileDiffs[i])}</td></tr>"
    document.getElementById('quantile-table').innerHTML = tb
    document.getElementById('control-success-rate').innerHTML = dataToMeanStd(@histData.control)
    document.getElementById('test-success-rate').innerHTML = dataToMeanStd(@histData.test)
    testSuccessProbability = round(1.0 - BetaModel::percentileOfScore(@histData.diffs, 0))
    document.getElementById('test-success-probability').innerHTML = testSuccessProbability
    document.getElementById('difference-mean').innerHTML = dataToMeanStd(@histData.diffs)
    document.getElementById('recommendation').innerHTML =
      if testSuccessProbability > 0.95
        'Implement test variant'
      else if testSuccessProbability < 0.05
        'Implement control variant'
      else
        'Keep testing'

  redraw: ->
    pdfElems = @_getPdfElements()
    for group in ['control', 'test']
      @pdfSvg.select("##{group}-line")
             .datum(@pdfData[group])
             .transition()
             .duration(1000)
             .attr('d', pdfElems["#{group}Line"])
    @pdfSvg.select('.y.axis').transition().duration(1000).call(pdfElems.yAxis)
    @pdfSvg.select('.x.axis').transition().call(pdfElems.xAxis)

    histElems = @_getHistogramElements()
    @histogramSvg.selectAll('rect')
                 .data(histElems.histogram)
                 .transition()
                 .duration(1000)
                 .attr('y', (d) -> histElems.y(d.y))
                 .attr('height', (d) -> histElems.height - histElems.y(d.y))

    @_drawSummaryStatistics()

  update: ->
    populateParamElement = (id, alpha, beta) ->
      document.getElementById(id).innerHTML = """&alpha;=#{round(alpha)} &beta;=#{round(beta)}"""
    errorMessage = document.getElementById('error-message')
    setError = (msg) ->
      errorMessage.hidden = false
      errorMessage.innerHTML = msg
    errorMessage.hidden = true
    inputs = @_getInputs()
    # See http://stats.stackexchange.com/a/12239 -- the mean is in (0, 1) and variance is in (0, mean * (1 - mean))
    mean = inputs['prior-mean']
    return setError('Success rate must be between 0 and 1 (exclusive)') if mean <= 0 or mean >= 1
    uncertainty = inputs['prior-uncertainty']
    return setError('Uncertainty must be between 0 and 1 (exclusive)') if uncertainty <= 0 or uncertainty >= 1
    variance = Math.pow(uncertainty, 2) * mean * (1 - mean)
    priorAlpha = Math.pow(mean, 2) * (((1 - mean) / variance) - (1 / mean))
    priorBeta = priorAlpha * ((1 / mean) - 1)
    populateParamElement('prior-params', priorAlpha, priorBeta)
    for group in ['control', 'test']
      failures = inputs["#{group}-trials"] - inputs["#{group}-successes"]
      return setError('Number of trials cannot be smaller than number of successes') if failures < 0
      groupAlpha = priorAlpha + inputs["#{group}-successes"]
      groupBeta = priorBeta + failures
      populateParamElement("#{group}-params", groupAlpha, groupBeta)
      @models[group] = new BetaModel(groupAlpha, groupBeta)
    @_generatePlotData()
    document.location.hash = ["#{key}=#{value}" for key, value of inputs].join(',')

  _getInputs: ->
    new class then constructor: ->
      @[id] = Number(elem.value) for id, elem of INPUTS

  resize: =>
    newWidth = @_calculateWidth()
    if newWidth != @width
      @width = newWidth
      @_draw()

# Read default inputs from the hash
for inputPair in document.location.hash.slice(1).split(',')
  [key, value] = inputPair.split('=')
  INPUTS[key]?.value = Number(value)
window.plots = new Plots()
form = document.getElementById('form')
form.onsubmit = form.onchange = (event) ->
  event.preventDefault()
  window.plots.update()
  window.plots.redraw()
window.onresize = window.plots.resize
