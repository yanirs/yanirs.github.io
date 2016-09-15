global.jQuery = global.$ = require('jquery')
require('selectize')
global._ = require('underscore')

createSiteObject = (code, [realm, ecoregion, name, longtitude, latitude, numSurveys, speciesCounts]) ->
  code: code
  realm: realm
  ecoregion: ecoregion
  name: name
  longtitude: longtitude
  latitude: latitude
  numSurveys: numSurveys
  speciesCounts: speciesCounts

deferredJsons = $.when(
  $.getJSON('api-site-surveys.json'),
  $.getJSON('api-species.json'),
  $.getScript('https://maps.googleapis.com/maps/api/js')
)
deferredJsons.always ->
  $('body').removeClass('loading')
deferredJsons.fail ->
  $('.js-error-container').removeClass('hidden')
deferredJsons.done ([sites], [species]) ->
  # Fairly zoomed out map, centred on Australia.
  map = new google.maps.Map($('.js-map')[0], {
    center: { lat: -30, lng: 150 }
    zoom: 3
  })
  currentSiteMarker = null

  sites = (createSiteObject(code, data) for code, data of sites)
  $selectSite = $('#select-site')
  sites.sort (siteA, siteB) ->
    property =
      if siteA.ecoregion == siteB.ecoregion
        'code'
      else if siteA.realm == siteB.realm
        'ecoregion'
      else
        'realm'
    siteA[property].localeCompare(siteB[property])
  siteCodeToSite = {}
  _.each sites, (site) ->
    $('<option>').val(site.code)
                 .html("#{site.realm}: #{site.ecoregion} &rarr; #{site.code}: #{site.name}")
                 .appendTo($selectSite)
    siteCodeToSite[site.code] = site

  siteInfoTemplate = _.template($('#site-info-template').html())
  speciesCountRowTemplate = _.template($('#species-count-row-template').html())

  $selectSite.selectize
    onChange: (siteCode, numTopCounts = 25) ->
      return unless siteCode
      site = siteCodeToSite[siteCode]

      currentSiteMarker.setMap(null) if currentSiteMarker
      siteLatLng =
        lat: site.latitude
        lng: site.longtitude
      currentSiteMarker = new google.maps.Marker
        position: siteLatLng,
        map: map,
        title: site.name
      map.panTo(siteLatLng)
      google.maps.event.addListener currentSiteMarker, 'click', =>
        infoWindow = new google.maps.InfoWindow
          content: "<b>#{site.name} (#{site.code})</b><br>
                    #{site.realm} &ndash; #{site.ecoregion}<br>
                    <i>#{site.latitude}, #{site.longtitude}</i>"
        infoWindow.open(map, currentSiteMarker)

      $('#site-info').html(siteInfoTemplate(site))
      siteTableData = []
      for id, count of site.speciesCounts
        [name, commonName, speciesUrl, method, speciesClass] = species[id]
        siteTableData.push({
            name: name
            commonName: commonName or 'N/A'
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
