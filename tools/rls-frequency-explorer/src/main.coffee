global.jQuery = global.$ = require('jquery')
require('selectize')
global._ = require('underscore')

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
      siteTableData = []
      for id, count of site.speciesCounts
        [name, commonName, speciesUrl, method, speciesClass] = species[id]
        siteTableData.push({
            name: name
            commonName: commonName
            count: count
            percentage: (100 * count / site.numSurveys).toFixed(2)
            speciesClass: speciesClass
            method: switch method
                    when 0 then 'M1'
                    when 1 then 'M2'
                    else 'Both'
        })

      $speciesTableBody = $('.js-species-table tbody')
      renderTableBody = (sortColumn = '-count') ->
        $speciesTableBody.html('')
        if sortColumn[0] == '-'
          sortColumn = sortColumn.slice(1)
          cmp = (elem) -> -elem[sortColumn]
        else
          cmp = sortColumn
        for rowData in _.sortBy(siteTableData, cmp)
          $speciesTableBody.append(speciesCountRowTemplate(rowData))
      $('.js-species-table thead a').click (event) ->
        event.preventDefault()
        renderTableBody($(this).data().sortColumn)
      renderTableBody()

      $('.js-export').click ->
        csvData = 'Scientific name,Common name,Method,Species class,Surveys seen,Total surveys\n'
        for row in siteTableData
          csvData += "#{row.name},#{row.commonName},#{row.method},#{row.speciesClass},#{row.count},#{site.numSurveys}\n"
        $(this).attr('download', "rls-#{siteCode.toLowerCase()}.csv")
        $(this).attr('href', encodeURI("data:text/csv;charset=utf-8,#{csvData}"))

    onDropdownClose: (dropdown) ->
      $(dropdown).prev().find('input').blur()

  $('.js-site-select-container').removeClass('hidden')
