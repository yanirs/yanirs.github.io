d3 = require('d3')
jStat = require('jStat').jStat

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
  WIDTH: 690 - Plots::MARGIN.left - Plots::MARGIN.right
  HEIGHT: 350 - Plots::MARGIN.top - Plots::MARGIN.bottom

  NUM_SAMPLES: 5000
  NUM_HISTOGRAM_BINS: 200
  PDF_INTERPOLATION_MODE: 'cardinal'

  constructor: (inputs) ->
    @update(inputs)

  getHistogramElements: ->
    controlData = @controlBeta.getRvs(@NUM_SAMPLES)
    testData = @testBeta.getRvs(@NUM_SAMPLES)
    differenceData = (testData[i] - controlData[i] for i in [0..controlData.length - 1])
    x = d3.scale.linear().domain([-1, 1]).range([0, @WIDTH])
    histogram = d3.layout.histogram().bins(x.ticks(@NUM_HISTOGRAM_BINS))(differenceData)
    y = d3.scale.linear().domain([0, d3.max(histogram, (d) -> d.y)]).range([@HEIGHT, 0])
    el = {
      'x': x
      'y': y
      'differenceData': differenceData
      'histogram': histogram
    }
    @addCommonElements(el, x, y)

  getPdfElements: ->
    controlData = @controlBeta.getPdf(@NUM_SAMPLES)
    testData = @testBeta.getPdf(@NUM_SAMPLES)
    allData = controlData.concat(testData)
    x = d3.scale.linear().domain(d3.extent(allData, (d) -> d.x)).range([0, @WIDTH])
    y = d3.scale.linear().domain([0, d3.max(allData, (d) -> d.y) + 1]).range([@HEIGHT, 0])
    el = {
      'testLine': d3.svg.area().x((d) -> x d.x).y1(@HEIGHT).y0((d) -> y d.y).interpolate(@PDF_INTERPOLATION_MODE)
      'controlLine': d3.svg.area().x((d) -> x d.x).y1(@HEIGHT).y0((d) -> y d.y).interpolate(@PDF_INTERPOLATION_MODE)
      'testData': testData
      'controlData': controlData
    }
    @addCommonElements(el, x, y)

  addCommonElements: (el, x, y) ->
    el.margin = @MARGIN
    el.width = @WIDTH
    el.height = @HEIGHT
    el.xAxis = d3.svg.axis().scale(x).orient('bottom')
    el.yAxis = d3.svg.axis().scale(y).orient('left')
    el

  drawHistogram: ->
    el = @getHistogramElements()
    svg = @drawSvg(el, '#histogram', 'Samples')
    bar = svg.selectAll('.bar').data(el.histogram).enter().append('g').attr('class', 'bar')
                                                                      .attr('transform',
                                                                            (d) -> "translate(#{el.x(d.x)},0)")
    bar.append('rect').attr('x', 1)
                      .attr('y', (d) -> el.y(d.y))
                      .attr('width', el.histogram[0].dx / 2 * el.width)
                      .attr('height', (d) -> el.height - el.y(d.y))
    @histogramSvg = svg
    @drawSummaryStatistics(el)

  drawPdf: ->
    el = @getPdfElements()
    svg = @drawSvg(el, '#pdfplot', 'Density')
    svg.append('path').datum(el.testData).attr('class', 'line').attr('d', el.testLine).attr('id', 'testLine')
    svg.append('path').datum(el.controlData).attr('class', 'area').attr('d', el.controlLine).attr('id', 'controlLine')
    @pdfSvg = svg

  drawSvg: (el, plotId, plotTitle) ->
    svg = d3.select(plotId).append('svg').attr('width', el.width + el.margin.left + el.margin.right)
                                         .attr('height', el.height + el.margin.top + el.margin.bottom)
                           .append('g').attr('transform', "translate(#{el.margin.left},#{el.margin.top})")
    svg.append('g').attr('class', 'x axis').attr('transform', "translate(0,#{el.height})").call(el.xAxis)
    svg.append('g').attr('class', 'y axis').call(el.yAxis).append('text').attr('transform', 'rotate(-90)')
                                                                         .attr('y', 6)
                                                                         .attr('dy', '.71em')
                                                                         .style('text-anchor', 'end')
                                                                         .text(plotTitle)
    svg

  drawSummaryStatistics: (el) ->
    quantiles = [0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.975, 0.99]
    round = (x) -> Math.round(x * 100) / 100
    differenceQuantiles = jStat.quantiles(el.differenceData, quantiles)
    tb = '<tr><td class="table-row-title">Percentiles</td>'
    for quantile in quantiles
      tb += "<td>#{quantile * 100}%</td>"
    tb += '</tr><tr><td class="table-row-title">Value</td>'
    for differenceQuantile in differenceQuantiles
      tb += "<td>#{round(differenceQuantile)}</td>"
    tb += '</tr>'
    document.getElementById('quantileTable').innerHTML = tb
    document.getElementById('testSuccessProbability').innerHTML =
      round(1.0 - BetaModel::percentileOfScore(el.differenceData, 0))
    document.getElementById('differenceMean').innerHTML = round(jStat.mean(el.differenceData))

  redrawHistogram: ->
    el = @getHistogramElements()
    svg = @histogramSvg
    svg.selectAll('rect').data(el.histogram).transition().duration(1000).attr('y', (d) -> el.y(d.y))
                                                                        .attr('height', (d) -> el.height - el.y(d.y))
    @drawSummaryStatistics(el)

  redrawPdf: ->
    d = @getPdfElements()
    svg = @pdfSvg
    svg.select('#testLine').datum(d.testData).transition().duration(1000).attr('d', d.testLine)
    svg.select('#controlLine').datum(d.controlData).transition().duration(1000).attr('d', d.controlLine)
    svg.select('.y.axis').transition().duration(1000).call(d.yAxis)
    svg.select('.x.axis').transition().call(d.xAxis)

  update: (inputs) ->
    @controlBeta = new BetaModel(inputs.priorAlpha + inputs.controlSuccesses,
                                 inputs.priorBeta + inputs.controlFailures)
    @testBeta = new BetaModel(inputs.priorAlpha + inputs.testSuccesses,
                              inputs.priorBeta + inputs.testFailures)

getInputs = ->
  new class then constructor: ->
    @[id] = Number(document.getElementById(id).value) for id in \
      ['priorAlpha', 'priorBeta', 'controlSuccesses', 'controlFailures', 'testSuccesses', 'testFailures']

initializePlots = ->
  window.plots = new Plots(getInputs())
  window.plots.drawPdf()
  window.plots.drawHistogram()

bindInputs = ->
  document.getElementById('form').onsubmit = (event) ->
    event.preventDefault()
    window.plots.update(getInputs())
    window.plots.redrawPdf()
    window.plots.redrawHistogram()
    return

initializePlots()
bindInputs()
