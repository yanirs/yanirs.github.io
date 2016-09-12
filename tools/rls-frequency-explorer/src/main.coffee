global.jQuery = global.$ = require('jquery')
require('selectize')
global._ = require('underscore')
Plotly = require('plotly.js/lib/core')
Plotly.register([require('plotly.js/lib/bar')])

createSiteObject = (code, [realm, ecoregion, name, longtitude, latitude, numSurveys, speciesCounts]) ->
  {
    code: code
    realm: realm
    ecoregion: ecoregion
    name: name
    longtitude: longtitude
    latitude: latitude
    numSurveys: numSurveys
    speciesCounts: speciesCounts
  }

createEcoregionSites = (sites) ->
  ecoregionToSite = {}
  _.each sites, (site) ->
    unless ecoregionToSite[site.ecoregion]
      ecoregionToSite[site.ecoregion] =
        realm: site.realm
        ecoregion: site.ecoregion
        code: 'ECO' + _.size(ecoregionToSite)
        latitude: site.latitude
        longtitude: site.longtitude
        numSurveys: 0
        speciesCounts: {}
    ecoregionSite = ecoregionToSite[site.ecoregion]
    ecoregionSite.numSurveys += site.numSurveys
    _.each site.speciesCounts, (count, species) ->
      unless ecoregionSite.speciesCounts[species]
        ecoregionSite.speciesCounts[species] = 0
      ecoregionSite.speciesCounts[species] += count
  _.values(ecoregionToSite)

deferredJsons = $.when($.getJSON('api-site-surveys.json'), $.getJSON('api-species.json'))
deferredJsons.always ->
  $('body').removeClass('loading')
deferredJsons.fail ->
  $('.js-error-container').removeClass('hidden')
deferredJsons.done (sites, species) ->
  sites = (createSiteObject(code, data) for code, data of sites[0])
  species = species[0]
  $selectSite = $('#select-site')
  sites.sort (siteA, siteB) ->
    property = if siteA.ecoregion == siteB.ecoregion then 'code' else 'ecoregion'
    siteA[property].localeCompare(siteB[property])
  sites = _.sortBy(createEcoregionSites(sites), 'ecoregion').concat(sites)
  siteCodeToSite = {}
  _.each sites, (site) ->
    if site.name
      $('<option>').val(site.code).html("#{site.ecoregion} &rarr; #{site.code}: #{site.name}").appendTo($selectSite)
    else
      $('<option>').val(site.code).html("Ecoregion: #{site.ecoregion}").appendTo($selectSite)
    siteCodeToSite[site.code] = site

  siteInfoTemplate = _.template($('#site-info-template').html())
  speciesCountRowTemplate = _.template($('#species-count-row-template').html())

  $selectSite.selectize
    onChange: (siteCode, numTopCounts = 25) ->
      return unless siteCode
      site = siteCodeToSite[siteCode]
      $('#site-info').html(siteInfoTemplate(site))
      $speciesTable = $('#species-table-body')
      sortedCounts = _.map(_.pairs(site.speciesCounts).sort((a, b) -> b[1] - (a[1])), ([id, count]) ->
        [name, commonName, speciesUrl, method, speciesClass] = species[id]
        {
          name: name
          commonName: commonName
          count: count
          percentage: (100 * count / site.numSurveys).toFixed(2)
          title: "<i>#{name}</i>" + (if commonName then " (#{commonName})" else '')
          speciesClass: speciesClass
          method: switch method
                  when 0 then 'M1'
                  when 1 then 'M2'
                  else 'Both'
        }
      )
      _.each sortedCounts, (species, index) ->
        $speciesTable.append(speciesCountRowTemplate(_.extend(species, index: index)))
      $('.js-export').click ->
        csvData = 'Scientific name,Common name,Method,Species class,Surveys seen,Total surveys\n'
        for row in sortedCounts
          csvData += "#{row.name},#{row.commonName},#{row.method},#{row.speciesClass},#{row.count},#{site.numSurveys}\n"
        $(this).attr('download', "rls-#{siteCode.toLowerCase()}.csv")
        $(this).attr('href', encodeURI("data:text/csv;charset=utf-8,#{csvData}"))
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

  $('.js-site-select-container').removeClass('hidden')
