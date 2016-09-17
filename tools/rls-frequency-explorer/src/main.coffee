global.jQuery = global.$ = require('jquery')
require('selectize')
global._ = require('underscore')

siteInfoTemplate = _.template($('#site-info-template').html())
speciesCountRowTemplate = _.template($('#species-count-row-template').html())

createSiteObject = (code, [realm, ecoregion, name, lng, lat, numSurveys, speciesCounts]) ->
  code: code
  realm: realm
  ecoregion: ecoregion
  name: name
  latLng:
    lat: lat
    lng: lng
  numSurveys: numSurveys
  speciesCounts: speciesCounts

class Map
  constructor: ->
    # Fairly zoomed out map, centred on Australia.
    @gmap = new google.maps.Map($('.js-map')[0], {
      center: { lat: -30, lng: 150 }
      zoom: 3
      scrollwheel: false
      streetViewControl: false
    })
    @siteCodeToMarker = {}
    @siteCodeToInfoWindow = {}

  showSiteInfoWindow: (siteCode) ->
    @openInfoWindow.close() if @openInfoWindow
    @openInfoWindow = @siteCodeToInfoWindow[siteCode]
    @openInfoWindow.open(@gmap, @siteCodeToMarker[siteCode])

  createSiteMarker: (site, handleSiteSelection) ->
    marker = new google.maps.Marker
      position: site.latLng
      map: @gmap
      title: site.name
    @siteCodeToMarker[site.code] = marker
    @siteCodeToInfoWindow[site.code] = new google.maps.InfoWindow
      content: "<b>#{site.name} (#{site.code})</b><br>
                #{site.realm} &ndash; #{site.ecoregion}<br>
                <i>#{site.latLng.lat}, #{site.latLng.lng}</i>"
    google.maps.event.addListener(marker, 'click', -> handleSiteSelection(site.code))

  animateSiteMarker: (siteCode, bounceTimeout = 2500) ->
    @currentPolygon.setMap(null) if @currentPolygon
    marker = @siteCodeToMarker[siteCode]
    @gmap.panTo(marker.getPosition())
    marker.setAnimation(google.maps.Animation.BOUNCE)
    window.setTimeout((-> marker.setAnimation(null)), bounceTimeout)

  enableDrawing: (sites, handleSitesSelected) ->
    drawingManager = new google.maps.drawing.DrawingManager
      drawingControl: true
      drawingControlOptions:
        position: google.maps.ControlPosition.TOP_RIGHT
        drawingModes: ['polygon']
      map: @gmap
    google.maps.event.addListener drawingManager, 'polygoncomplete', (polygon) =>
      drawingManager.setDrawingMode(null)
      @currentPolygon.setMap(null) if @currentPolygon
      @currentPolygon = polygon
      @openInfoWindow.close() if @openInfoWindow
      containsLocation = google.maps.geometry.poly.containsLocation
      handleSitesSelected(site for site in sites when containsLocation(new google.maps.LatLng(site.latLng), polygon))

deferredJsons = $.when(
  $.getJSON('api-site-surveys.json'),
  $.getJSON('api-species.json'),
  $.getScript('https://maps.googleapis.com/maps/api/js?' +
              'key=AIzaSyCB7yf2Q30bz9qnsd0wy6KvtdTGyke7Fag&libraries=drawing,geometry')
)
deferredJsons.always ->
  $('body').removeClass('loading')
deferredJsons.fail ->
  $('.js-error-container').removeClass('hidden')
deferredJsons.done ([sites], [species]) ->
  map = new Map()
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

  populateSiteInfo = (numSurveys, speciesCounts, numSites = 1) ->
    $('#site-info').html(siteInfoTemplate(numSurveys: numSurveys, speciesCounts: speciesCounts, numSites: numSites))
    siteTableData = []
    for id, count of speciesCounts
      [name, commonName, speciesUrl, method, speciesClass] = species[id]
      siteTableData.push({
        name: name
        commonName: commonName or 'N/A'
        count: count
        percentage: (100 * count / numSurveys).toFixed(2)
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
      csvData = 'Scientific name\tCommon name\tMethod\tSpecies class\tSurveys seen\tTotal surveys\n'
      for row in siteTableData
        csvData += "#{row.name}\t#{row.commonName}\t#{row.method}\t#{row.speciesClass}\t#{row.count}\t#{numSurveys}\n"
      $(this).attr('download', 'rls-data-export.csv')
      $(this).attr('href', encodeURI("data:text/csv;charset=utf-8,#{csvData}"))

  handleSiteSelection = (siteCode) ->
    return unless siteCode
    site = siteCodeToSite[siteCode]
    populateSiteInfo(site.numSurveys, site.speciesCounts)
    map.showSiteInfoWindow(siteCode)
    map.animateSiteMarker(siteCode)

  for site in sites
    $('<option>').val(site.code)
                 .html("#{site.realm}: #{site.ecoregion} &rarr; #{site.code}: #{site.name}")
                 .appendTo($selectSite)
    siteCodeToSite[site.code] = site
    map.createSiteMarker(site, handleSiteSelection)

  $selectSite.selectize
    onChange: handleSiteSelection
    onDropdownClose: (dropdown) -> $(dropdown).prev().find('input').blur()

  $('.js-site-select-container').removeClass('hidden')

  map.enableDrawing sites, (selectedSites) ->
    numSurveys = 0
    speciesCounts = {}
    for site in selectedSites
      numSurveys += site.numSurveys
      for speciesId, count of site.speciesCounts
        speciesCounts[speciesId] = 0 unless speciesCounts[speciesId]
        speciesCounts[speciesId] += count
    populateSiteInfo(numSurveys, speciesCounts, selectedSites.length)
