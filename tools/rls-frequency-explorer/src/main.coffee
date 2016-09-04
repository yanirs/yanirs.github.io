global.jQuery = global.$ = require('jquery')
require('selectize')
global._ = require('underscore')
Plotly = require('plotly.js/lib/core')
Plotly.register([require('plotly.js/lib/bar')])

# TODO: fetch async
data = require('./sample-data')

ecoregionToSite = {}

compareSites = (siteA, siteB) ->
  if siteA.ecoregion == siteB.ecoregion
    siteA.code.localeCompare(siteB.code)
  else
    siteA.ecoregion.localeCompare(siteB.ecoregion)

_.each data.sites, (site) ->
  unless ecoregionToSite[site.ecoregion]
    ecoregionToSite[site.ecoregion] =
      realm: site.realm
      ecoregion: site.ecoregion
      code: 'ECO' + _.size(ecoregionToSite)
      latitude: site.latitude
      longtitude: site.longtitude
      num_surveys: 0
      species_counts: {}
  ecoregionSite = ecoregionToSite[site.ecoregion]
  ecoregionSite.num_surveys += site.num_surveys
  _.each site.species_counts, (count, species) ->
    unless ecoregionSite.species_counts[species]
      ecoregionSite.species_counts[species] = 0
    ecoregionSite.species_counts[species] += count

$selectSite = $('#select-site')
data.sites.sort(compareSites)
data.sites = _.sortBy(_.values(ecoregionToSite), 'ecoregion').concat(data.sites)
siteCodeToSite = {}
_.each data.sites, (site) ->
  if site.name
    $('<option>').val(site.code).html("#{site.ecoregion} &rarr; #{site.code}: #{site.name}").appendTo($selectSite)
  else
    $('<option>').val(site.code).html("Ecoregion: #{site.ecoregion}").appendTo($selectSite)
  siteCodeToSite[site.code] = site

siteInfoTemplate = _.template($('#site-info-template').html())
speciesCountRowTemplate = _.template($('#species-count-row-template').html())

$selectSite.selectize
  onChange: (siteCode, numTopCounts = 25) ->
    site = siteCodeToSite[siteCode]
    $('#site-info').html(siteInfoTemplate(site))
    $speciesTable = $('#species-table-body')
    sortedCounts = _.map(_.pairs(site.species_counts).sort((a, b) -> b[1] - (a[1])), (nameCount) ->
      commonName = data.species[nameCount[0]]
      {
        name: nameCount[0]
        count: nameCount[1]
        percentage: (100 * nameCount[1] / site.num_surveys).toFixed(2)
        title: "<i>#{nameCount[0]}</i>" + (if commonName then " (#{commonName})" else '')
      }
    )
    _.each sortedCounts, (species, index) ->
      $speciesTable.append(speciesCountRowTemplate(_.extend(species, index: index)))
    topCounts = sortedCounts.slice(0, numTopCounts)
    topCounts.reverse()
    Plotly.newPlot 'top-species-chart', [ {
      type: 'bar'
      orientation: 'h'
      x: _.map(topCounts, (sc) -> sc.percentage)
      y: _.map(topCounts, (sc) -> sc.name)
      text: _.map(topCounts, (sc) -> sc.title)
    } ],
      title: 'Top species'
      autosize: true
      margin:
        l: 200
        r: 0
        t: 40
        b: 40
      yaxis: nticks: numTopCounts
      xaxis:
        title: 'Frequency [%]'
        tickmode: 'linear'
        dtick: 10
  onDropdownClose: (dropdown) ->
    $(dropdown).prev().find('input').blur()
