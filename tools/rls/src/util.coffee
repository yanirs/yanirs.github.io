class SurveyData
  constructor: (rawSites, rawSpecies) ->
    @_processRawSites(rawSites)
    @_processRawSpecies(rawSpecies)

  _processRawSites: (rawSites) ->
    @siteCodeToSite = {}
    @sites = []
    for code, [realm, ecoregion, name, lng, lat, numSurveys, speciesCounts] of rawSites
      site =
        code: code
        realm: realm
        ecoregion: ecoregion
        name: name
        latLng:
          lat: lat
          lng: lng
        numSurveys: numSurveys
        speciesCounts: speciesCounts
      @sites.push(site)
      @siteCodeToSite[site.code] = site
    @sites.sort (siteA, siteB) ->
      property =
        if siteA.ecoregion == siteB.ecoregion
          'code'
        else if siteA.realm == siteB.realm
          'ecoregion'
        else
          'realm'
      siteA[property].localeCompare(siteB[property])

  _processRawSpecies: (rawSpecies) ->
    @species = {}
    for id, [name, commonName, url, method, speciesClass, images] of rawSpecies
      @species[id] =
        name: name
        commonName: commonName or 'N/A'
        speciesClass: speciesClass
        url: url
        method: switch method
          when 0 then 'M1'
          when 1 then 'M2'
          else 'Both'
        images: images

  # Return the number of surveys and overall species counts for the given site codes.
  sumSites: (siteCodes) ->
    numSurveys = 0
    speciesCounts = {}
    for siteCode in siteCodes
      site = @siteCodeToSite[siteCode]
      numSurveys += site.numSurveys
      for speciesId, count of site.speciesCounts
        speciesCounts[speciesId] = 0 unless speciesCounts[speciesId]
        speciesCounts[speciesId] += count
    [numSurveys, speciesCounts]

# Load the survey data asynchronously, calling the passed callback with a SurveyData object when done.
exports.loadSurveyData = (doneCallback) ->
  $.when($.getJSON('/tools/rls/api-site-surveys.json'), $.getJSON('/tools/rls/api-species.json'))
   .always(-> $('body').removeClass('loading'))
   .fail(-> $('.js-error-container').removeClass('hidden'))
   .done(([rawSites], [rawSpecies]) -> doneCallback(new SurveyData(rawSites, rawSpecies)))
