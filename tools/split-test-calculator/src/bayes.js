"use strict";

var d3 = require("d3");
var jStat = require("jStat").jStat;

var BetaDistribution = function (alpha, beta) {
  var gammaln = jStat.gammaln;
  this.alpha = alpha;
  this.beta = beta;

  this.betaInverse = (gammaln(this.alpha + this.beta) - gammaln(this.alpha) - gammaln(this.beta));
};

BetaDistribution.prototype.lpdf = function(x) {
  if (x < 0 || x > 1) {
    return Number.NEGATIVE_INFINITY;
  }
  return (this.betaInverse + (this.alpha - 1) * Math.log(x) + (this.beta - 1) * Math.log(1 - x));
};

BetaDistribution.prototype.pdf = function(x) {
  if (x < 0 || x > 1) {
    return 0;
  }
  if (this.alpha == 1 && this.beta == 1) {
    return 1;
  }
  return Math.exp(this.lpdf(x));
};

BetaDistribution.prototype.rv = function () {
  return jStat.beta.sample(this.alpha, this.beta);
};

BetaDistribution.prototype.rvs = function(n) {
  var rvs = [];

  for (var i=0; i < n; i++) {
    rvs.push(this.rv());
  }

  return rvs;
};

var BetaModel = function (alpha, beta) {
  this.alpha = alpha;
  this.beta = beta;
};

BetaModel.prototype.distribution = function () {
  return new BetaDistribution(this.alpha, this.beta);
};

BetaModel.prototype.getPDF = function (noPoints) {
  var pdf = [];
  var distribution = this.distribution();
  for (var i = 0; i < noPoints; i++) {
    var val = distribution.pdf(i / noPoints);
    // Get rid of density singularities for plotting
    if (val == Number.POSITIVE_INFINITY) {
      val = 0;
    }
    pdf.push({'x': i / noPoints, 'y': val});
  }
  return pdf;
};

BetaModel.prototype.getRvs = function (noSamples) {
  return this.distribution().rvs(noSamples);
};

BetaModel.prototype.update = function (successes, failures) {
  this.alpha = this.alpha + successes;
  this.beta = this.beta + failures;
};

BetaModel.prototype.percentileOfScore = function (arr, score, kind) {
  var counter = 0;
  var len = arr.length;
  var strict = false;
  var value, i;

  if (kind === 'strict') strict = true;

  for (i = 0; i < len; i++) {
    value = arr[i];
    if ((strict && value < score) ||
      (!strict && value <= score)) {
      counter++;
    }
  }

  return counter / len;
};

BetaModel.prototype.mean = function (arr) {
  var i = 0;
  var counter = 0;

  for (i = 0; i < arr.length; i++) {
    counter = counter + arr[i];
  }

  return counter / i;
};

// -----------------------------------------------

var Plots = function (alpha, beta) {
  this.controlBeta = new BetaModel(alpha, beta);
  this.testBeta = new BetaModel(alpha, beta);
};

Plots.prototype.getHistogramElements = function () {

  var noSamples = 5000;
  var noBins = 200;

  var controlData = this.controlBeta.getRvs(noSamples);
  var testData = this.testBeta.getRvs(noSamples);
  var differenceData = [];

  for (var i = 0; i < controlData.length; i++) {
    differenceData.push(testData[i] - controlData[i]);
  }

  var margin = {top: 20, right: 20, bottom: 30, left: 50};
  var width = 690 - margin.left - margin.right;
  var height = 350 - margin.top - margin.bottom;

  var x = d3.scale.linear()
    .domain([-1, 1])
    .range([0, width]);

  var histogram = d3.layout.histogram()
    .bins(x.ticks(noBins))(differenceData);

  var y = d3.scale.linear()
    .domain([0, d3.max(histogram, function (d) {
      return d.y;
    })])
    .range([height, 0]);

  var xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom");

  var yAxis = d3.svg.axis()
    .scale(y)
    .orient("left");

  return {
    "margin": margin,
    "width": width,
    "height": height,
    "xAxis": xAxis,
    "yAxis": yAxis,
    "x": x,
    "y": y,
    "differenceData": differenceData,
    "histogram": histogram
  };
};

Plots.prototype.getPDFElements = function () {
  var numSamples = 2500;
  var controlData = this.controlBeta.getPDF(numSamples);
  var testData = this.testBeta.getPDF(numSamples);
  var allData = controlData.concat(testData);
  var interpolationMode = 'cardinal';

  var margin = {top: 20, right: 20, bottom: 30, left: 50};
  var width = 690 - margin.left - margin.right;
  var height = 350 - margin.top - margin.bottom;

  var x = d3.scale.linear()
    .domain(d3.extent(allData, function (d) {
      return d.x;
    }))
    .range([0, width]);

  var y = d3.scale.linear()
    .domain([0, d3.max(allData, function (d) {
      return d.y;
    }) + 1])
    .range([height, 0]);

  var xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom");

  var yAxis = d3.svg.axis()
    .scale(y)
    .orient("left");

  var controlLine = d3.svg.area()
    .x(function (d) {
      return x(d.x);
    })
    .y1(height)
    .y0(function (d) {
      return y(d.y);
    })
    .interpolate(interpolationMode);

  var testLine = d3.svg.area()
    .x(function (d) {
      return x(d.x);
    })
    .y1(height)
    .y0(function (d) {
      return y(d.y);
    })
    .interpolate(interpolationMode);

  return {
    "margin": margin,
    "width": width,
    "height": height,
    "xAxis": xAxis,
    "yAxis": yAxis,
    "testLine": testLine,
    "controlLine": controlLine,
    "testData": testData,
    "controlData": controlData
  };
};

Plots.prototype.drawHistogram = function () {
  var el = this.getHistogramElements();

  var svg = d3.select("#histogram").append("svg")
    .attr("width", el.width + el.margin.left + el.margin.right)
    .attr("height", el.height + el.margin.top + el.margin.bottom)
    .append("g")
    .attr("transform", "translate(" + el.margin.left + "," + el.margin.top + ")");

  svg.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(0," + el.height + ")")
    .call(el.xAxis);

  svg.append("g")
    .attr("class", "y axis")
    .call(el.yAxis)
    .append("text")
    .attr("transform", "rotate(-90)")
    .attr("y", 6)
    .attr("dy", ".71em")
    .style("text-anchor", "end")
    .text("Samples");

  var bar = svg.selectAll(".bar")
    .data(el.histogram)
    .enter().append("g")
    .attr("class", "bar")
    .attr("transform", function (d) {
      return "translate(" + el.x(d.x) + ",0)";
    });

  bar.append("rect")
    .attr("x", 1)
    .attr("y", function (d) {
      return el.y(d.y);
    })
    .attr("width", el.histogram[0].dx / 2 * el.width)
    .attr("height", function (d) {
      return el.height - el.y(d.y);
    });

  this.histogramSVG = svg;

  this.drawSummaryStatistics(el);
};


Plots.prototype.drawPDF = function () {
  var d = this.getPDFElements();

  var svg = d3.select("#pdfplot").append("svg")
    .attr("width", d.width + d.margin.left + d.margin.right)
    .attr("height", d.height + d.margin.top + d.margin.bottom)
    .append("g")
    .attr("transform", "translate(" + d.margin.left + "," + d.margin.top + ")");

  svg.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(0," + d.height + ")")
    .call(d.xAxis);

  svg.append("g")
    .attr("class", "y axis")
    .call(d.yAxis)
    .append("text")
    .attr("transform", "rotate(-90)")
    .attr("y", 6)
    .attr("dy", ".71em")
    .style("text-anchor", "end")
    .text("Density");

  svg.append("path")
    .datum(d.testData)
    .attr("class", "line")
    .attr("d", d.testLine)
    .attr("id", "testLine");

  svg.append("path")
    .datum(d.controlData)
    .attr("class", "area")
    .attr("d", d.controlLine)
    .attr("id", "controlLine");

  this.pdfSVG = svg;
};


Plots.prototype.drawTable = function (arr1, arr2) {
  var tb = '';

  tb += "<tr>";
  tb += "<td class=\"table-row-title\">Percentiles</td>";
  for (var i = 0; i < arr1.length; i++) {
    tb += ("<td>" + arr1[i] * 100 + "%</td>");
  }

  tb += "</tr><tr>";
  tb += "<td class=\"table-row-title\">Value</td>";
  for (var i = 0; i < arr1.length; i++) {
    tb += ("<td>" + (Math.round(100 * arr2[i]) / 100) + "</td>");
  }

  tb += "</tr>";

  return tb;
};

Plots.prototype.drawSummaryStatistics = function (el) {
  var quantiles = [0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.975, 0.99];
  var differenceQuantiles = jStat.quantiles(el.differenceData, quantiles);
  var tableElement = document.getElementById('quantileTable');
  tableElement.innerHTML = this.drawTable(quantiles, differenceQuantiles);

  var percentileOfZero = BetaModel.prototype.percentileOfScore(el.differenceData, 0);
  var testSuccessProbability = document.getElementById('testSuccessProbability');
  testSuccessProbability.innerHTML = Math.round((1.0 - percentileOfZero) * 100) / 100;

  var differenceMeanHTML = document.getElementById('differenceMean');
  var differenceMean = BetaModel.prototype.mean(el.differenceData);
  differenceMeanHTML.innerHTML = Math.round(100 * differenceMean) / 100;
};


Plots.prototype.redrawHistogram = function () {
  var el = this.getHistogramElements();

  var svg = this.histogramSVG;

  svg.selectAll("rect")
    .data(el.histogram)
    .transition()
    .duration(1000)
    .attr("y", function (d) {
      return el.y(d.y);
    })
    .attr("height", function (d) {
      return el.height - el.y(d.y);
    });

  this.drawSummaryStatistics(el);
};

Plots.prototype.redrawPDF = function () {

  var d = this.getPDFElements();

  var svg = this.pdfSVG;

  svg.select('#testLine')
    .datum(d.testData)
    .transition()
    .duration(1000)
    .attr("d", d.testLine);

  svg.select('#controlLine')
    .datum(d.controlData)
    .transition()
    .duration(1000)
    .attr("d", d.controlLine);

  svg.select('.y.axis')
    .transition()
    .duration(1000)
    .call(d.yAxis);

  svg.select('.x.axis')
    .transition()
    .call(d.xAxis);
};

Plots.prototype.updatePrior = function (alpha, beta) {
  this.controlBeta = new BetaModel(alpha, beta);
  this.testBeta = new BetaModel(alpha, beta);
};

Plots.prototype.updatePosterior = function (testSuccesses, testFailures, controlSuccesses, controlFailures) {
  this.testBeta.update(testSuccesses, testFailures);
  this.controlBeta.update(controlSuccesses, controlFailures);
};

var getInputs = function () {
  var priorAlpha = Number(document.getElementById("priorAlpha").value);
  var priorBeta = Number(document.getElementById("priorBeta").value);
  var controlSuccesses = Number(document.getElementById("controlSuccesses").value);
  var controlFailures = Number(document.getElementById("controlFailures").value);
  var testSuccesses = Number(document.getElementById("testSuccesses").value);
  var testFailures = Number(document.getElementById("testFailures").value);

  return {
    "priorAlpha": priorAlpha,
    "priorBeta": priorBeta,
    "controlSuccesses": controlSuccesses,
    "controlFailures": controlFailures,
    "testSuccesses": testSuccesses,
    "testFailures": testFailures
  };
};

var initializePlots = function () {
  var inputs = getInputs();
  var plots = new Plots(inputs.priorAlpha, inputs.priorBeta);
  plots.drawPDF();
  plots.drawHistogram();
  window.plots = plots;
};

initializePlots();

var updatePlots = function () {
  var inputs = getInputs();
  var plots = window.plots;
  plots.updatePrior(inputs.priorAlpha, inputs.priorBeta);
  plots.updatePosterior(inputs.testSuccesses, inputs.testFailures, inputs.controlSuccesses, inputs.controlFailures);
  plots.redrawPDF();
  plots.redrawHistogram();

};

var bindInputs = function () {
  document.getElementById("form").onsubmit = function (event) {
    event.preventDefault();
    updatePlots();
  };
};


bindInputs();
